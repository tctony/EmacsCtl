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

/// Settings that can be shared between machines. The public path remains
/// `~/.config/emacsctl/config.json`; it may be a symlink to another location.
private struct SharedConfig: Codable {
    var focusCode: String?
    var fileExtensions: String?
    var gitOpenFunction: String?
}

/// Settings that belong to one machine. The existence of `local.json` also
/// marks completion of the one-time split from the old combined config.
private struct LocalConfig: Codable {
    var pidFile: String?
    var installDir: String?
    var autoRestoreLayout: Bool?
    var launchAtLogin: Bool?
    var didShowSettingOnFirstLaunch: Bool?
    var savedWindowLayout: [SavedWindowInfo]?
}

/// The legacy on-disk shape, used only while splitting an existing config.
private struct LegacyConfig: Codable {
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

private struct MigrationSource {
    let legacy: LegacyConfig
    let sharedData: Data
}

/// Single entry point for the shared and machine-local JSON files.
private final class ConfigFile {

    static let shared = ConfigFile()

    static let directoryURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/emacsctl", isDirectory: true)
    static let fileURL = directoryURL.appendingPathComponent("config.json")
    static let localFileURL = directoryURL.appendingPathComponent("local.json")
    private static let migratingLocalFileURL = directoryURL
        .appendingPathComponent(".local.json.migrating")

    private(set) var sharedConfig: SharedConfig
    private(set) var localConfig: LocalConfig

    private var lastSharedData: Data?
    private var lastLocalData: Data?

    private init() {
        try? FileManager.default.createDirectory(
            at: ConfigFile.directoryURL, withIntermediateDirectories: true)

        do {
            try ConfigFile.splitLegacyConfigIfNeeded()
        } catch {
            Logger.error("Failed to split legacy config: \(error)")
        }

        let shared = ConfigFile.load(SharedConfig.self, from: ConfigFile.fileURL)
        sharedConfig = shared?.value ?? SharedConfig()
        lastSharedData = shared?.data

        let local = ConfigFile.load(LocalConfig.self, from: ConfigFile.localFileURL)
        localConfig = local?.value ?? LocalConfig()
        lastLocalData = local?.data

        Logger.info("Loaded shared config from \(ConfigFile.fileURL.path)")
        Logger.info("Loaded local config from \(ConfigFile.localFileURL.path)")
    }

    struct ReloadResult {
        var changed = false
        var invalidJSON = false
    }

    func reloadFromDisk() -> ReloadResult {
        var result = ReloadResult()

        if let data = try? Data(contentsOf: ConfigFile.fileURL), data != lastSharedData {
            if let value = try? JSONDecoder().decode(SharedConfig.self, from: data) {
                sharedConfig = value
                lastSharedData = data
                result.changed = true
            } else {
                result.invalidJSON = true
            }
        }

        if let data = try? Data(contentsOf: ConfigFile.localFileURL), data != lastLocalData {
            if let value = try? JSONDecoder().decode(LocalConfig.self, from: data) {
                localConfig = value
                lastLocalData = data
                result.changed = true
            } else {
                result.invalidJSON = true
            }
        }

        return result
    }

    func updateShared(_ mutate: (inout SharedConfig) -> Void) {
        mutate(&sharedConfig)
        persistShared()
    }

    func updateLocal(_ mutate: (inout LocalConfig) -> Void) {
        mutate(&localConfig)
        persistLocal()
    }

    func reset() {
        sharedConfig = SharedConfig()
        localConfig = LocalConfig()
        persistShared()
        persistLocal()
    }

    /// Directories whose changes can affect the two logical config paths.
    /// Resolving the shared path keeps this generic while supporting symlinks.
    var watchedDirectoryURLs: [URL] {
        let sharedDirectory = ConfigFile.storageURL(for: ConfigFile.fileURL)
            .deletingLastPathComponent()
        if sharedDirectory.path == ConfigFile.directoryURL.path {
            return [ConfigFile.directoryURL]
        }
        return [ConfigFile.directoryURL, sharedDirectory]
    }

    private func persistShared() {
        do {
            lastSharedData = try ConfigFile.write(sharedConfig, to: ConfigFile.fileURL)
        } catch {
            Logger.error("Failed to write shared config: \(error)")
        }
    }

    private func persistLocal() {
        do {
            lastLocalData = try ConfigFile.write(localConfig, to: ConfigFile.localFileURL)
        } catch {
            Logger.error("Failed to write local config: \(error)")
        }
    }

    /// Split the old combined config. `local.json` is written last and acts as
    /// the migration commit point. The temporary file makes the operation
    /// recoverable if the app exits after rewriting the shared config.
    private static func splitLegacyConfigIfNeeded() throws {
        guard !FileManager.default.fileExists(atPath: localFileURL.path) else {
            return
        }

        let local: LocalConfig
        if FileManager.default.fileExists(atPath: migratingLocalFileURL.path) {
            guard let pending = load(LocalConfig.self, from: migratingLocalFileURL) else {
                throw ConfigFileError.invalidJSON(migratingLocalFileURL)
            }
            local = pending.value
        } else {
            let legacy = try loadMigrationSource().legacy
            local = LocalConfig(pidFile: legacy.pidFile,
                                installDir: legacy.installDir,
                                autoRestoreLayout: legacy.autoRestoreLayout,
                                launchAtLogin: legacy.launchAtLogin,
                                didShowSettingOnFirstLaunch: legacy.didShowSettingOnFirstLaunch,
                                savedWindowLayout: legacy.savedWindowLayout)
            _ = try write(local, to: migratingLocalFileURL)
        }

        let source = try loadMigrationSource()
        try write(source.sharedData, to: fileURL)

        try FileManager.default.moveItem(at: migratingLocalFileURL, to: localFileURL)
        Logger.info("Split machine-local settings into \(localFileURL.path)")
    }

    private static func loadMigrationSource() throws -> MigrationSource {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            guard let data = try? Data(contentsOf: fileURL),
                  let legacy = try? JSONDecoder().decode(LegacyConfig.self, from: data),
                  var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ConfigFileError.invalidJSON(fileURL)
            }
            for key in localConfigKeys {
                object.removeValue(forKey: key)
            }
            let sharedData = try JSONSerialization.data(
                withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            return MigrationSource(legacy: legacy, sharedData: sharedData)
        }

        let legacy = migrateFromUserDefaults()
        let shared = SharedConfig(focusCode: legacy.focusCode,
                                  fileExtensions: legacy.fileExtensions,
                                  gitOpenFunction: legacy.gitOpenFunction)
        return MigrationSource(legacy: legacy, sharedData: try encode(shared))
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL) -> (value: T, data: Data)? {
        guard let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(type, from: data) else {
            return nil
        }
        return (value, data)
    }

    @discardableResult
    private static func write<T: Encodable>(_ value: T, to url: URL) throws -> Data {
        let data = try encode(value)
        try write(data, to: url)
        return data
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func write(_ data: Data, to url: URL) throws {
        try data.write(to: storageURL(for: url), options: .atomic)
    }

    private static func storageURL(for url: URL) -> URL {
        url.resolvingSymlinksInPath()
    }

    private static let localConfigKeys = [
        "pidFile",
        "installDir",
        "autoRestoreLayout",
        "launchAtLogin",
        "didShowSettingOnFirstLaunch",
        "savedWindowLayout"
    ]

    private static func migrateFromUserDefaults() -> LegacyConfig {
        let d = UserDefaults.standard
        var cfg = LegacyConfig()
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

private enum ConfigFileError: Error {
    case invalidJSON(URL)
}


class ConfigStore {

    static let shared = ConfigStore()

    static let defaultFileExtensions = "h,c,cpp,rs,ts,tsx,js,py"

    @Published var config: Config

    private let store = ConfigFile.shared

    /// Watch both the public config directory and a symlink target directory.
    private var configDirSources: [DispatchSourceFileSystemObject] = []
    private var watchedConfigDirectories = Set<String>()

    /// On-disk path of the config file, for opening it in an editor.
    var configFileURL: URL { ConfigFile.fileURL }

    private init() {
        // Migrate old function-name format to template format.
        let gitOpenFn = store.sharedConfig.gitOpenFunction ?? ""
        if !gitOpenFn.isEmpty && !gitOpenFn.contains("%") {
            store.updateShared {
                $0.gitOpenFunction = "(\(gitOpenFn) \"%gitdir\" :file \"%file\")"
            }
        }

        config = ConfigStore.deriveConfig(shared: store.sharedConfig, local: store.localConfig)

        updateConfigDirWatchers()
    }

    /// Combine the shared and local files and apply runtime defaults.
    private static func deriveConfig(shared: SharedConfig, local: LocalConfig) -> Config {
        Config(emacsPidFile: local.pidFile,
               emacsInstallDir: local.installDir,
               focusCode: shared.focusCode,
               fileExtensions: shared.fileExtensions ?? ConfigStore.defaultFileExtensions,
               gitOpenFunction: shared.gitOpenFunction ?? "",
               autoRestoreLayout: local.autoRestoreLayout ?? false)
    }

    func setPidFile(_ pidFile: String) {
        store.updateLocal { $0.pidFile = pidFile }

        config.emacsPidFile = pidFile
    }

    func setInstallDir(_ installDir: String) {
        store.updateLocal { $0.installDir = installDir }

        config.emacsInstallDir = installDir
    }

    func setFocusCode(_ focusCode: String) {
        store.updateShared { $0.focusCode = focusCode }

        config.focusCode = focusCode
    }

    func setFileExtensions(_ fileExtensions: String) {
        store.updateShared { $0.fileExtensions = fileExtensions }

        config.fileExtensions = fileExtensions
    }

    func setGitOpenFunction(_ gitOpenFunction: String) {
        store.updateShared { $0.gitOpenFunction = gitOpenFunction }

        config.gitOpenFunction = gitOpenFunction
    }

    func setAutoRestoreLayout(_ enabled: Bool) {
        store.updateLocal { $0.autoRestoreLayout = enabled }

        config.autoRestoreLayout = enabled
    }

    // MARK: - Settings not surfaced in the Settings window
    //
    // These are persisted alongside the UI config but are not part of the
    // observable `Config`; they get plain accessors that delegate to the
    // backing file.

    var savedWindowLayout: [SavedWindowInfo]? {
        get { store.localConfig.savedWindowLayout }
        set { store.updateLocal { $0.savedWindowLayout = newValue } }
    }

    var launchAtLogin: Bool {
        get { store.localConfig.launchAtLogin ?? false }
        set { store.updateLocal { $0.launchAtLogin = newValue } }
    }

    var didShowSettingOnFirstLaunch: Bool {
        get { store.localConfig.didShowSettingOnFirstLaunch ?? false }
        set { store.updateLocal { $0.didShowSettingOnFirstLaunch = newValue } }
    }

    /// Clear all persisted settings and reset the in-memory UI config.
    func reset() {
        store.reset()
        config = Config()
    }

    // MARK: - Watching for external edits

    /// Watch directories rather than files so atomic replacements keep working.
    /// If `config.json` is a symlink, also watch the resolved target directory.
    private func updateConfigDirWatchers() {
        try? FileManager.default.createDirectory(
            at: ConfigFile.directoryURL, withIntermediateDirectories: true)

        let directories = store.watchedDirectoryURLs
        let paths = Set(directories.map(\.path))
        guard paths != watchedConfigDirectories else {
            return
        }

        configDirSources.forEach { $0.cancel() }
        configDirSources = []
        watchedConfigDirectories = paths

        for directory in directories {
            let fd = open(directory.path, O_EVTONLY)
            guard fd >= 0 else {
                Logger.error("failed to watch config directory: \(directory.path)")
                continue
            }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: .write, queue: .main)
            source.setEventHandler { [weak self] in
                self?.reloadIfChanged()
                self?.updateConfigDirWatchers()
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            configDirSources.append(source)
            Logger.info("watching config directory: \(directory.path)")
        }
    }

    /// Re-read the config file after a directory event and apply any external
    /// change. Our own writes are recognised by content comparison and ignored,
    /// which also filters unrelated events in the directory.
    private func reloadIfChanged() {
        let oldExtensions = store.sharedConfig.fileExtensions
        let result = store.reloadFromDisk()

        if result.invalidJSON {
            Logger.warning("external config edit is invalid JSON, keeping current config")
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("config_invalid_title", comment: "")
            content.body = NSLocalizedString("config_invalid_body", comment: "")
            content.sound = .default
            displayNotification(content)
        }

        if result.changed {
            Logger.info("applying external config change")
            config = ConfigStore.deriveConfig(
                shared: store.sharedConfig, local: store.localConfig)

            // Mirror the Settings window: re-register default-app handlers when
            // the watched extensions actually changed.
            if store.sharedConfig.fileExtensions != oldExtensions {
                let exts = DefaultAppRegistrar.parseExtensions(config.fileExtensions ?? "")
                DefaultAppRegistrar.shared.registerAsDefault(forExtensions: exts)
            }
        }
    }
}
