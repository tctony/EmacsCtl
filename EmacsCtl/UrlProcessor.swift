//
//  UrlProcessor.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2024/1/1.
//

import Foundation
import Cocoa

let UrlScheme = "org-protocol"

let UrlHostOrgRoamRef = "roam-ref"

class UrlProcessor {

    static let shared = UrlProcessor()

    var pendingSet = Set<UrlCaptureBaseWindow>()

    private init() {
        // do nothing
    }

    func process(_ url: URL) {
        var className: String = ""

        if (url.host == UrlHostOrgRoamRef) {
            className = "OrgRoamCaptureWindow"
        }

        if let windowClass = NSClassFromString("EmacsCtl.\(className)") as? UrlCaptureBaseWindow.Type {
            let window = windowClass.init(windowNibName: className)
            window.url = url

            window.showWindow(self)
            NSApp.activate(ignoringOtherApps: true)
            window.window?.makeKeyAndOrderFront(self)

            window.onClose { [weak self] in
                self?.pendingSet.remove(window)
            }
            pendingSet.insert(window)
        } else {
            EmacsControl.handleUrl(url.absoluteString)
        }
    }
}
