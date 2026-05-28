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


class ConfigStore {

    static let shared = ConfigStore()

    static let defaultFileExtensions = "h,c,cpp,rs,ts,tsx,js,py"

    @Published var config: Config

    private let store = UserDefaults.standard

    private init() {
        var gitOpenFn = store.string(forKey: UserDefaultsKeys.gitOpenFunction) ?? ""
        // Migrate old function-name format to template format
        if !gitOpenFn.isEmpty && !gitOpenFn.contains("%") {
            gitOpenFn = "(\(gitOpenFn) \"%gitdir\" :file \"%file\")"
            store.set(gitOpenFn, forKey: UserDefaultsKeys.gitOpenFunction)
        }

        config = Config(emacsPidFile: store.string(forKey: UserDefaultsKeys.pidFile),
                        emacsInstallDir: store.string(forKey: UserDefaultsKeys.installDir),
                        focusCode: store.string(forKey: UserDefaultsKeys.focusCode),
                        fileExtensions: store.string(forKey: UserDefaultsKeys.fileExtensions)
                            ?? ConfigStore.defaultFileExtensions,
                        gitOpenFunction: gitOpenFn,
                        autoRestoreLayout: store.bool(forKey: UserDefaultsKeys.autoRestoreLayout))
    }

    func setPidFile(_ pidFile: String) {
        store.set(pidFile, forKey: UserDefaultsKeys.pidFile)
        store.synchronize()

        config.emacsPidFile = pidFile
    }

    func setInstallDir(_ installDir: String) {
        store.set(installDir, forKey: UserDefaultsKeys.installDir)
        store.synchronize()
        
        config.emacsInstallDir = installDir
    }

    func setFocusCode(_ focusCode: String) {
        store.set(focusCode, forKey: UserDefaultsKeys.focusCode)
        store.synchronize()

        config.focusCode = focusCode
    }

    func setFileExtensions(_ fileExtensions: String) {
        store.set(fileExtensions, forKey: UserDefaultsKeys.fileExtensions)
        store.synchronize()

        config.fileExtensions = fileExtensions
    }

    func setGitOpenFunction(_ gitOpenFunction: String) {
        store.set(gitOpenFunction, forKey: UserDefaultsKeys.gitOpenFunction)
        store.synchronize()

        config.gitOpenFunction = gitOpenFunction
    }

    func setAutoRestoreLayout(_ enabled: Bool) {
        store.set(enabled, forKey: UserDefaultsKeys.autoRestoreLayout)
        store.synchronize()

        config.autoRestoreLayout = enabled
    }
}
