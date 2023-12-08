//
//  AppDelegate.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/7.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        print("did launch as agent")

        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("tray"))
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

