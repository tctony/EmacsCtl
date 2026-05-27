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
}


class ConfigStore {

    static let shared = ConfigStore()

    static let defaultFocusCode = "(tctony/toggle-between-emacs-and-cmux)"

    static let defaultGitOpenFunction = "(tctony/persp-switch-by-git-dir \"%gitdir\" :file \"%file\")"

    static let defaultFileExtensions = "h,c,cpp,rs,ts,tsx,js,py"

    @Published var config: Config

    private let store = UserDefaults.standard

    private init() {
        var gitOpenFn = store.string(forKey: UserDefaultsKeys.gitOpenFunction)
            ?? ConfigStore.defaultGitOpenFunction
        // Migrate old function-name format to template format
        if !gitOpenFn.isEmpty && !gitOpenFn.contains("%") {
            gitOpenFn = "(\(gitOpenFn) \"%gitdir\" :file \"%file\")"
            store.set(gitOpenFn, forKey: UserDefaultsKeys.gitOpenFunction)
        }

        config = Config(emacsPidFile: store.string(forKey: UserDefaultsKeys.pidFile),
                        emacsInstallDir: store.string(forKey: UserDefaultsKeys.installDir),
                        focusCode: store.string(forKey: UserDefaultsKeys.focusCode)
                            ?? ConfigStore.defaultFocusCode,
                        fileExtensions: store.string(forKey: UserDefaultsKeys.fileExtensions)
                            ?? ConfigStore.defaultFileExtensions,
                        gitOpenFunction: gitOpenFn)
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
}
