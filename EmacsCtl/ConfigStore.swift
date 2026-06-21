//
//  Config.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/8.
//

import Combine
import Dispatch
import Foundation
import UserNotifications

struct Config {
    var emacsPidFile: String?

    var emacsInstallDir: String?

    var focusCode: String?

    var fileExtensions: String?

    /// Elisp function symbol invoked when EmacsCtl opens a file from
    /// LaunchServices and the file is inside a git repo. Default:
    /// `tctony/persp-switch-by-git-dir`. An empty value disables this and
    /// falls back to `emacsclient -n <file>`.
    var gitOpenFunction: String?

    var autoRestoreLayout: Bool = false
}

/// On-disk representation of every persisted setting. Stored as JSON at
/// `~/.config/emacsctl/config.json`. All fields are optional so a missing
/// key decodes to `nil`, mirroring the old `UserDefaults` defaults.
///
/// Private to this file: `ConfigStore` is the only entry point for config;
/// nothing else should touch the on-disk layout directly.
private struct AppConfig: Codable {
    var pidFile: String?
    var installDir: String?
    var focusCode: String?
    var fileExtensions: String?
    var gitOpenFunction: String?
    var autoRestoreLayout: Bool?
    var launchAtLogin: Bool?
    var didShowSettingOnFirstLaunch: Bool?
    var savedWindowLayout: [SavedWindowInfo]?
}

/// Single source of truth for persisted config, backed by a JSON file under
/// `~/.config/emacsctl/`. The file path is independent of the bundle ID, so
/// the Debug and release builds share the same config. On first run (no file
/// yet) it migrates the legacy values out of `UserDefaults`.
///
/// Private to this file — reach it through `ConfigStore`.
private final class ConfigFile {

    static let shared = ConfigFile()

    static let directoryURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/emacsctl", isDirectory: true)
    static let fileURL = directoryURL.appendingPathComponent("config.json")

    private(set) var config: AppConfig

    /// The exact bytes last written to (or read from) disk. Used to tell our own
    /// writes apart from external edits: a file-change event whose on-disk bytes
    /// equal `lastData` is one we caused and can be ignored.
    private(set) var lastData: Data?

    private init() {
        if let data = try? Data(contentsOf: ConfigFile.fileURL),
           let cfg = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = cfg
            lastData = data
            Logger.info("Loaded config from \(ConfigFile.fileURL.path)")
        } else {
            config = ConfigFile.migrateFromUserDefaults()
            persist()
            Logger.info("Created config file at \(ConfigFile.fileURL.path)")
        }
    }

    /// Outcome of re-reading the config file after a file-system event.
    enum ReloadResult {
        case unchanged   // bytes equal our last write — our own change, ignore
        case changed     // external edit, decoded and applied to `config`
        case invalidJSON // external edit could not be decoded; `config` untouched
        case missing     // file could not be read; `config` untouched
    }

    /// Re-read the config file from disk. On a valid external change, updates
    /// `config` and `lastData` and returns `.changed`.
    func reloadFromDisk() -> ReloadResult {
        guard let data = try? Data(contentsOf: ConfigFile.fileURL) else {
            return .missing
        }
        if data == lastData {
            return .unchanged
        }
        guard let cfg = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return .invalidJSON
        }
        config = cfg
        lastData = data
        return .changed
    }

    /// Mutate the config and write it back to disk.
    func update(_ mutate: (inout AppConfig) -> Void) {
        mutate(&config)
        persist()
    }

    /// Clear all settings. Persists an empty config rather than deleting the
    /// file: a missing file would make the next launch re-run the UserDefaults
    /// migration and resurrect the values we just cleared.
    func reset() {
        config = AppConfig()
        persist()
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: ConfigFile.directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(config)
            try data.write(to: ConfigFile.fileURL, options: .atomic)
            lastData = data
        } catch {
            Logger.error("Failed to write config file: \(error)")
        }
    }

    /// One-time migration: read the legacy keys from `UserDefaults.standard`
    /// (the app's own domain) into an `AppConfig`.
    private static func migrateFromUserDefaults() -> AppConfig {
        let d = UserDefaults.standard
        var cfg = AppConfig()
        cfg.pidFile = d.string(forKey: UserDefaultsKeys.pidFile)
        cfg.installDir = d.string(forKey: UserDefaultsKeys.installDir)
        cfg.focusCode = d.string(forKey: UserDefaultsKeys.focusCode)
        cfg.fileExtensions = d.string(forKey: UserDefaultsKeys.fileExtensions)
        cfg.gitOpenFunction = d.string(forKey: UserDefaultsKeys.gitOpenFunction)
        if d.object(forKey: UserDefaultsKeys.autoRestoreLayout) != nil {
            cfg.autoRestoreLayout = d.bool(forKey: UserDefaultsKeys.autoRestoreLayout)
        }
        if d.object(forKey: UserDefaultsKeys.launchAtLogin) != nil {
            cfg.launchAtLogin = d.bool(forKey: UserDefaultsKeys.launchAtLogin)
        }
        if d.object(forKey: UserDefaultsKeys.didShowSettingOnFirstLaunch) != nil {
            cfg.didShowSettingOnFirstLaunch =
                d.bool(forKey: UserDefaultsKeys.didShowSettingOnFirstLaunch)
        }
        if let data = d.data(forKey: UserDefaultsKeys.savedWindowLayout) {
            cfg.savedWindowLayout = try? JSONDecoder()
                .decode([SavedWindowInfo].self, from: data)
        }
        Logger.info("Migrated config from UserDefaults")
        return cfg
    }
}


class ConfigStore {

    static let shared = ConfigStore()

    static let defaultFileExtensions = "h,c,cpp,rs,ts,tsx,js,py"

    @Published var config: Config

    private let store = ConfigFile.shared

    /// Live watcher on the config *directory* (not the file): its inode is stable
    /// across atomic file replacement, so a single source needs no re-arming.
    private var configDirSource: DispatchSourceFileSystemObject?

    /// On-disk path of the config file, for opening it in an editor.
    var configFileURL: URL { ConfigFile.fileURL }

    private init() {
        // Migrate old function-name format to template format.
        let gitOpenFn = store.config.gitOpenFunction ?? ""
        if !gitOpenFn.isEmpty && !gitOpenFn.contains("%") {
            store.update {
                $0.gitOpenFunction = "(\(gitOpenFn) \"%gitdir\" :file \"%file\")"
            }
        }

        config = ConfigStore.deriveConfig(from: store.config)

        startWatchingConfigDir()
    }

    /// Map the on-disk `AppConfig` to the observable `Config`, applying defaults.
    private static func deriveConfig(from c: AppConfig) -> Config {
        Config(emacsPidFile: c.pidFile,
               emacsInstallDir: c.installDir,
               focusCode: c.focusCode,
               fileExtensions: c.fileExtensions ?? ConfigStore.defaultFileExtensions,
               gitOpenFunction: c.gitOpenFunction ?? "",
               autoRestoreLayout: c.autoRestoreLayout ?? false)
    }

    func setPidFile(_ pidFile: String) {
        store.update { $0.pidFile = pidFile }

        config.emacsPidFile = pidFile
    }

    func setInstallDir(_ installDir: String) {
        store.update { $0.installDir = installDir }

        config.emacsInstallDir = installDir
    }

    func setFocusCode(_ focusCode: String) {
        store.update { $0.focusCode = focusCode }

        config.focusCode = focusCode
    }

    func setFileExtensions(_ fileExtensions: String) {
        store.update { $0.fileExtensions = fileExtensions }

        config.fileExtensions = fileExtensions
    }

    func setGitOpenFunction(_ gitOpenFunction: String) {
        store.update { $0.gitOpenFunction = gitOpenFunction }

        config.gitOpenFunction = gitOpenFunction
    }

    func setAutoRestoreLayout(_ enabled: Bool) {
        store.update { $0.autoRestoreLayout = enabled }

        config.autoRestoreLayout = enabled
    }

    // MARK: - Settings not surfaced in the Settings window
    //
    // These are persisted alongside the UI config but are not part of the
    // observable `Config`; they get plain accessors that delegate to the
    // backing file.

    var savedWindowLayout: [SavedWindowInfo]? {
        get { store.config.savedWindowLayout }
        set { store.update { $0.savedWindowLayout = newValue } }
    }

    var launchAtLogin: Bool {
        get { store.config.launchAtLogin ?? false }
        set { store.update { $0.launchAtLogin = newValue } }
    }

    var didShowSettingOnFirstLaunch: Bool {
        get { store.config.didShowSettingOnFirstLaunch ?? false }
        set { store.update { $0.didShowSettingOnFirstLaunch = newValue } }
    }

    /// Clear all persisted settings and reset the in-memory UI config.
    func reset() {
        store.reset()
        config = Config()
    }

    // MARK: - Watching for external edits

    /// Watch the config directory and live-apply edits made outside the app
    /// (e.g. saving the JSON from Emacs). Watching the directory rather than the
    /// file keeps the same watcher valid across atomic replacements.
    private func startWatchingConfigDir() {
        try? FileManager.default.createDirectory(
            at: ConfigFile.directoryURL, withIntermediateDirectories: true)

        let fd = open(ConfigFile.directoryURL.path, O_EVTONLY)
        guard fd >= 0 else {
            Logger.error("failed to open config dir for watching")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            self?.reloadIfChanged()
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        configDirSource = source
        Logger.info("watching config dir for external changes")
    }

    /// Re-read the config file after a directory event and apply any external
    /// change. Our own writes are recognised by content comparison and ignored,
    /// which also filters unrelated events in the directory.
    private func reloadIfChanged() {
        let oldExtensions = store.config.fileExtensions

        switch store.reloadFromDisk() {
        case .unchanged, .missing:
            return
        case .invalidJSON:
            Logger.warning("external config edit is invalid JSON, keeping current config")
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("config_invalid_title", comment: "")
            content.body = NSLocalizedString("config_invalid_body", comment: "")
            content.sound = .default
            displayNotification(content)
        case .changed:
            Logger.info("applying external config change")
            config = ConfigStore.deriveConfig(from: store.config)

            // Mirror the Settings window: re-register default-app handlers when
            // the watched extensions actually changed.
            if store.config.fileExtensions != oldExtensions {
                let exts = DefaultAppRegistrar.parseExtensions(config.fileExtensions ?? "")
                DefaultAppRegistrar.shared.registerAsDefault(forExtensions: exts)
            }
        }
    }
}
