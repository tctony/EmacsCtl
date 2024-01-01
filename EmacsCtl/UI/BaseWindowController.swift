//
//  BaseWindowController.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/10.
//

import Cocoa

var windowCount = 0

class BaseWindowController: NSWindowController, NSWindowDelegate {

    class var displayInDock: Bool {
        return false
    }

    private var closeCallbacks: [() -> Void] = []

    override func windowDidLoad() {
        super.windowDidLoad()

        if type(of: self).displayInDock {
            windowCount += 1
            if windowCount == 1 {
                NSApp.setActivationPolicy(.regular)
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        if type(of: self).displayInDock {
            windowCount -= 1
            if windowCount == 0 {
                NSApp.setActivationPolicy(.accessory)
            }
        }

        closeCallbacks.forEach{ callback in
            callback()
        }
        closeCallbacks.removeAll()
    }

    func onClose(callback: @escaping () -> Void) {
        closeCallbacks.append(callback)
    }
}
