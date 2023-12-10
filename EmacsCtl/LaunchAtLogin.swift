//
//  LaunchAtLogin.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/10.
//

import Foundation

class LaunchAtLogin: NSObject {

    @objc var isEnabled: Bool {
        didSet {
            print("launch at login changed to \(isEnabled)")
            onChange()
        }
    }

    override init() {
        isEnabled = UserDefaults.standard.bool(forKey: "launch_at_login")
    }

    private func onChange() {
        UserDefaults.standard.set(isEnabled, forKey: "launch_at_login")
        UserDefaults.standard.synchronize()

        print("TODO implement launch at login")
    }
}
