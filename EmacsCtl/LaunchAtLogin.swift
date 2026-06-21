//
//  LaunchAtLogin.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/10.
//

import Foundation
import ServiceManagement

class LaunchAtLogin: NSObject {

    @objc var isEnabled: Bool {
        didSet {
            Logger.info("launch at login changed to \(isEnabled)")
            onChange()
        }
    }

    override init() {
        isEnabled = ConfigStore.shared.launchAtLogin
    }

    private func onChange() {
        ConfigStore.shared.launchAtLogin = isEnabled

        let bundleid = "\(Bundle.main.bundleIdentifier!).LaunchHelper"
        SMLoginItemSetEnabled(bundleid as CFString, isEnabled)
    }
}
