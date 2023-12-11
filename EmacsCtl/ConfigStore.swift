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
}

let storeKeyPidFile = UserDefaultsKeys.pidFile
let storeKeyInstallDir = UserDefaultsKeys.installDir

class ConfigStore {

    static let shared = ConfigStore()

    @Published var config: Config

    private let store = UserDefaults.standard

    private init() {
        config = Config(emacsPidFile: store.string(forKey: storeKeyPidFile),
                        emacsInstallDir: store.string(forKey: storeKeyInstallDir))
    }

    func setPidFile(_ pidFile: String) {
        store.set(pidFile, forKey: storeKeyPidFile)
        store.synchronize()

        config.emacsPidFile = pidFile
    }

    func setInstallDir(_ installDir: String) {
        store.set(installDir, forKey: storeKeyInstallDir)
        store.synchronize()
        
        config.emacsInstallDir = installDir
    }
}
