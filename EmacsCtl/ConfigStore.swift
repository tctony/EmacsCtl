//
//  Config.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/8.
//

import Combine
import Dispatch
import Foundation

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

    private init() {
        if let data = try? Data(contentsOf: ConfigFile.fileURL),
           let cfg = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = cfg
            Logger.info("Loaded config from \(ConfigFile.fileURL.path)")
        } else {
            config = ConfigFile.migrateFromUserDefaults()
            persist()
            Logger.info("Created config file at \(ConfigFile.fileURL.path)")
        }
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
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: ConfigFile.fileURL, options: .atomic)
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

    private init() {
        var gitOpenFn = store.config.gitOpenFunction ?? ""
        // Migrate old function-name format to template format
        if !gitOpenFn.isEmpty && !gitOpenFn.contains("%") {
            gitOpenFn = "(\(gitOpenFn) \"%gitdir\" :file \"%file\")"
            store.update { $0.gitOpenFunction = gitOpenFn }
        }

        config = Config(emacsPidFile: store.config.pidFile,
                        emacsInstallDir: store.config.installDir,
                        focusCode: store.config.focusCode,
                        fileExtensions: store.config.fileExtensions
                            ?? ConfigStore.defaultFileExtensions,
                        gitOpenFunction: gitOpenFn,
                        autoRestoreLayout: store.config.autoRestoreLayout ?? false)
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
}
