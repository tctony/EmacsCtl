//
//  AppMenu.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/10.
//

import Cocoa

class AppMenu: NSMenu {
    private lazy var applicationName = ProcessInfo.processInfo.processName

    override init(title: String) {
        super.init(title: title)

        let mainMenu = NSMenuItem()
        mainMenu.submenu = NSMenu(title: "MainMenu")
        mainMenu.submenu?.items = [
            NSMenuItem(title: NSLocalizedString("about", comment: ""),
                       action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                       keyEquivalent: ""),
            NSMenuItem.separator(),
            NSMenuItem(title: NSLocalizedString("quit", comment: ""),
                       action: #selector(NSApplication.shared.terminate(_:)),
                       keyEquivalent: "q")
        ]

        let fileMenu = NSMenuItem()
        fileMenu.submenu = NSMenu(title: NSLocalizedString("file", comment: ""))
        fileMenu.submenu?.items = [
            NSMenuItem(title: NSLocalizedString("close", comment: ""),
                       action: #selector(NSWindow.performClose(_:)),
                       keyEquivalent: "w"),
        ]

        items = [mainMenu, fileMenu]
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

}


extension NSMenuItem {
    convenience init(title string: String,
                     target: AnyObject,
                     action selector: Selector?,
                     keyEquivalent charCode: String,
                     modifier: NSEvent.ModifierFlags = .command) {
        self.init(title: string, action: selector, keyEquivalent: charCode)
        keyEquivalentModifierMask = modifier
        self.target = target
    }

    convenience init(title string: String,
                     submenuItems: [NSMenuItem]) {
        self.init(title: string, action: nil, keyEquivalent: "")
        self.submenu = NSMenu()
        self.submenu?.items = submenuItems
    }
}
