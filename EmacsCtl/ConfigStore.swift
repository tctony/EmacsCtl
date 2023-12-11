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
    var pidFileBookmarkData: Data!

    var emacsInstallDir: String?
}


class ConfigStore {

    static let shared = ConfigStore()

    @Published var config: Config

    private let store = UserDefaults.standard

    private init() {
        config = Config(emacsPidFile: store.string(forKey: UserDefaultsKeys.pidFile),
                        emacsInstallDir: store.string(forKey: UserDefaultsKeys.installDir))
    }

    func setPidFile(path: String, data: Data) {
        store.set(path, forKey: UserDefaultsKeys.pidFile)
        store.set(data, forKey: UserDefaultsKeys.pidFileBookmarkData)
        store.synchronize()
        
        var newValue = config
        newValue.emacsPidFile = path
        newValue.pidFileBookmarkData = data
        config = newValue
    }

    func setInstallDir(_ installDir: String) {
        store.set(installDir, forKey: UserDefaultsKeys.installDir)
        store.synchronize()
        
        config.emacsInstallDir = installDir
    }
}
