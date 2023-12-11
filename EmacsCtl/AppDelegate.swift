//
//  AppDelegate.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/7.
//

import Cocoa
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {

    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)

    let menu: NSMenu = NSMenu()

    var cancellable: AnyCancellable?

    var settingWindowCtrl: SettingWindowController!

    // MARK: -

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("did launch as agent")

        if let button = statusItem.button {
            if let image = NSImage(named: "tray") {
                image.isTemplate = true;
                button.image = image
            }
        }

        statusItem.menu = menu;

        cancellable = ConfigStore.shared.$config.sink { [weak self] in
            print("config changed to: \($0)")
            self?.refreshMenu($0)
        }

        showSettingIfFirstLaunch()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: -

    func refreshMenu(_ config: Config) {
        print("refreshing menu")

        menu.removeAllItems()

        if config.emacsPidFile != nil {
            let runningItem = NSMenuItem()
            menu.addItem(runningItem)

            let makeStatusAttrString: (_ title: String) -> NSAttributedString = { title in
                let paragraphStyle = NSMutableParagraphStyle()
                 paragraphStyle.alignment = .center
                let textAttributes = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13),
                                      NSAttributedString.Key.paragraphStyle: paragraphStyle]
                return NSAttributedString(string: title, attributes: textAttributes)
            }

            do {
                let pidStr = try String(contentsOfFile: config.emacsPidFile!, encoding: .utf8)
                if let pid = Int(pidStr), pid > 0 {
                    runningItem.attributedTitle = makeStatusAttrString("\(NSLocalizedString("running", comment: "")) \(pid)")

                    menu.addItem(NSMenuItem.separator())
                    menu.addItem(NSMenuItem(title: NSLocalizedString("new_window", comment: ""),
                                            action: #selector(AppDelegate.createEmacsWindow(_:)), keyEquivalent: "f"))
                    menu.addItem(NSMenuItem(title: NSLocalizedString("restart", comment: ""),
                                            action: #selector(AppDelegate.restartEmacs(_:)), keyEquivalent: "r"))
                    menu.addItem(NSMenuItem(title: NSLocalizedString("stop", comment: ""),
                                            action: #selector(AppDelegate.stopEmacs(_:)), keyEquivalent: "d"))
                } else {
                    runningItem.attributedTitle = makeStatusAttrString("\(NSLocalizedString("not_running", comment: ""))")
                    menu.addItem(NSMenuItem(title: NSLocalizedString("start", comment: ""),
                                            action: #selector(AppDelegate.startEmacs(_:)), keyEquivalent: "s"))
                }
            } catch {
                print("read pid file failed: \(error)")
            }
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("setting", comment: ""),
                                action: #selector(AppDelegate.showSettingWindow(_:)), keyEquivalent: "e"))
        menu.addItem(withTitle: NSLocalizedString("quit", comment: ""),
                     action: #selector(AppDelegate.quitEmacsCtl(_:)), keyEquivalent: "q")


        print("finish refreshing menu")
    }

    func showSettingIfFirstLaunch() {
        let key = UserDefaultsKeys.didShowSettingOnFirstLaunch
        if UserDefaults.standard.bool(forKey: key) {
            return
        }

        showSettingWindow(nil)

        UserDefaults.standard.set(true, forKey: key)
        UserDefaults.standard.synchronize()
    }

    @objc func showSettingWindow(_ sender: NSMenuItem?) {
        print("show configure window")

        if settingWindowCtrl != nil {
            NSApp.activate(ignoringOtherApps: true)
            settingWindowCtrl!.window?.makeKeyAndOrderFront(self)
            return
        }

        settingWindowCtrl = SettingWindowController(windowNibName: "SettingWindow")

        settingWindowCtrl.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
        self.settingWindowCtrl.window?.makeKeyAndOrderFront(self)

        settingWindowCtrl.onClose { [weak self] in
            self?.settingWindowCtrl = nil
        }
    }

    @objc func createEmacsWindow(_ sender: NSMenuItem) {
        print("create new emacs window");
        // WIP
    }

    @objc func restartEmacs(_ sender: NSMenuItem) {
        print("restart emacs");
        // WIP
    }

    @objc func stopEmacs(_ sender: NSMenuItem) {
        print("stop emacs");
        // WIP
    }

    @objc func startEmacs(_ sender: NSMenuItem) {
        print("start emacs deamon");
        // WIP
    }

    @objc func quitEmacsCtl(_ sender: NSMenuItem) {
        print("quit emacs ctl")
        NSApplication.shared.terminate(self)
    }
}
