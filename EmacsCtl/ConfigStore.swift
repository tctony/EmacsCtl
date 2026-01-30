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
}


class ConfigStore {

    static let shared = ConfigStore()

    @Published var config: Config

    private let store = UserDefaults.standard

    private init() {
        config = Config(emacsPidFile: store.string(forKey: UserDefaultsKeys.pidFile),
                        emacsInstallDir: store.string(forKey: UserDefaultsKeys.installDir),
                        focusCode: store.string(forKey: UserDefaultsKeys.focusCode))
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
}
