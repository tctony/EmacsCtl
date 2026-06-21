//
//  AppDelegate.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/7.
//

import Cocoa
import Combine
import Sparkle
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)

    let menu: NSMenu = NSMenu()

    private var updator: SPUStandardUpdaterController?

    var cancellable: AnyCancellable?

    var pidFileObserver: DispatchSourceFileSystemObject?

    var isDeamonStarting: Bool = false {
        didSet {
            refreshMenu(ConfigStore.shared.config)
        }
    }

    var settingWindowCtrl: SettingWindowController!

    // MARK: -

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Logger.info("did launch as agent")
        Logger.info("bundle path: \(Bundle.main.bundlePath)")

        statusItem.isVisible = true

        if let button = statusItem.button {
            if var image = NSImage(named: "tray") {
                #if DEBUG
                image = image.flipped(flipHorizontally: true)
                #endif
                image.isTemplate = true;
                button.image = image
            }
        }

        statusItem.menu = menu;

        self.updator = SPUStandardUpdaterController(updaterDelegate: nil, userDriverDelegate: nil)

        cancellable = ConfigStore.shared.$config.sink { [weak self] in
            Logger.debug("config changed to: \($0)")
            self?.rescheduleObserver($0)
            self?.refreshMenu($0)
        }

        ShortcutsController.bindShortcuts()

        UNUserNotificationCenter.current().delegate = self

        showSettingIfFirstLaunch()
    }

    private var lastOpenedFile: (path: String, time: Date)?

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == OrgUrlScheme {
                OrgUrlProcessor.shared.process(url)
            } else if url.scheme == EmacsCtlUrlScheme {
                EmacsCtlUrlProcessor.shared.process(url)
            } else if url.isFileURL {
                // Deduplicate rapid-fire open events for the same file
                if let last = lastOpenedFile,
                   last.path == url.path,
                   Date().timeIntervalSince(last.time) < 0.5 {
                    Logger.debug("skipping duplicate open for: \(url.path)")
                    continue
                }
                lastOpenedFile = (url.path, Date())
                Logger.info("open file via LaunchServices: \(url.path)")
                EmacsControl.openFile(url.path)
            } else {
                Logger.warning("ignored unknown url: \(url.absoluteString)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // We are an LSUIElement agent app; without this the system may
        // suppress banners while our app is "foreground".
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        defer { completionHandler() }

        let userInfo = response.notification.request.content.userInfo
        let actionType: String
        if let value = userInfo["actionType"] {
            guard let value = value as? String else {
                Logger.warning("ignored notification with non-string actionType")
                return
            }
            actionType = value
        } else {
            actionType = "eval"
        }

        switch actionType {
        case "eval":
            if let eval = userInfo["actionEval"] as? String, !eval.isEmpty {
                EmacsControl.evalAndFocus(eval)
            } else {
                EmacsControl.focusOnEmacs()
            }
        case "noop":
            break
        case "deeplink":
            if let deeplink = userInfo["actionDeeplink"] as? String,
               !deeplink.isEmpty,
               let url = URL(string: deeplink),
               let scheme = url.scheme,
               !scheme.isEmpty {
                NSWorkspace.shared.open(url)
            } else {
                Logger.warning("ignored notification with invalid or missing actionDeeplink")
            }
        default:
            Logger.warning("ignored notification with unknown actionType: \(actionType)")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: -

    func rescheduleObserver(_ config: Config) {
        pidFileObserver?.cancel()

        guard let pidFile = config.emacsPidFile else {
            return
        }

        let url = URL(fileURLWithPath: pidFile)
        let fd = open(url.path, O_EVTONLY)
        pidFileObserver = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .all)
        pidFileObserver?.setEventHandler { [weak self] in
            Logger.debug("pid file changed")
            DispatchQueue.main.async {
                self?.refreshMenu(config)
            }
        }
        pidFileObserver?.setCancelHandler {
            close(fd)
        }
        pidFileObserver?.resume()
        Logger.info("monitoring pid file change")
    }

    func refreshMenu(_ config: Config) {
        Logger.debug("refreshing menu")

        menu.removeAllItems()

        if config.emacsPidFile != nil && config.emacsInstallDir != nil {
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
                Logger.debug("content of pidFile: '\(pidStr)'")
                if let pid = Int(pidStr), pid > 0 {
                    runningItem.attributedTitle = makeStatusAttrString(
                        "\(NSLocalizedString(isDeamonStarting ? "starting" : "running", comment: "")) \(pid)"
                    )

                    menu.addItem(NSMenuItem.separator())
                    menu.addItem(NSMenuItem(title: NSLocalizedString("new_window", comment: ""),
                                            action: #selector(AppDelegate.createEmacsWindow(_:)), 
                                            keyEquivalent: ""))
                    menu.addItem(NSMenuItem(title: NSLocalizedString("stop", comment: ""),
                                            action: #selector(AppDelegate.stopEmacs(_:)), 
                                            keyEquivalent: ""))
                    menu.addItem(NSMenuItem(title: NSLocalizedString("restart", comment: ""),
                                            action: #selector(AppDelegate.restartEmacs(_:)),
                                            keyEquivalent: ""))
                } else {
                    runningItem.attributedTitle = makeStatusAttrString("\(NSLocalizedString("not_running", comment: ""))")

                    menu.addItem(NSMenuItem.separator())
                    menu.addItem(NSMenuItem(title: NSLocalizedString("start", comment: ""),
                                            action: #selector(AppDelegate.startEmacs(_:)),
                                            keyEquivalent: ""))
                }
            } catch {
                Logger.error("read pid file failed: \(error)")
                menu.removeItem(runningItem)
            }
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("restore_layout", comment: ""),
                                action: #selector(AppDelegate.restoreWindowLayout(_:)),
                                keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: NSLocalizedString("setting", comment: ""),
                                action: #selector(AppDelegate.showSettingWindow(_:)),
                                keyEquivalent: ""))

        menu.addItem(NSMenuItem(title: NSLocalizedString("check_update", comment: ""),
                                target: self,
                                action: #selector(AppDelegate.checkForUpdates(_:)),
                                keyEquivalent: ""))

        menu.addItem(withTitle: NSLocalizedString("quit", comment: ""),
                     action: #selector(AppDelegate.quitEmacsCtl(_:)),
                     keyEquivalent: "")


        Logger.debug("finish refreshing menu")
    }

    func showSettingIfFirstLaunch() {
        if ConfigStore.shared.didShowSettingOnFirstLaunch {
            return
        }

        showSettingWindow(nil)

        ConfigStore.shared.didShowSettingOnFirstLaunch = true
    }

    @objc func checkForUpdates(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)
        updator?.checkForUpdates(sender)
    }

    @objc func showSettingWindow(_ sender: NSMenuItem?) {
        Logger.info("show configure window")

        if settingWindowCtrl != nil {
            NSApp.activate(ignoringOtherApps: true)
            settingWindowCtrl!.window?.makeKeyAndOrderFront(self)
            return
        }

        settingWindowCtrl = SettingWindowController(windowNibName: "SettingWindow")

        NSApp.activate(ignoringOtherApps: true)
        settingWindowCtrl.showWindow(self)
        self.settingWindowCtrl.window?.makeKeyAndOrderFront(self)

        settingWindowCtrl.onClose { [weak self] in
            self?.settingWindowCtrl = nil
        }
    }

    @objc func createEmacsWindow(_ sender: NSMenuItem) {
        Logger.info("create new emacs window")
        EmacsControl.newEmacsWindow()
    }

    @objc func restartEmacs(_ sender: NSMenuItem) {
        Logger.info("restart emacs daemon")
        EmacsControl.restartEmacsDaemon()
    }

    @objc func stopEmacs(_ sender: NSMenuItem) {
        Logger.info("stop emacs")
        EmacsControl.stopEmacs()
    }

    @objc func startEmacs(_ sender: NSMenuItem) {
        Logger.info("start emacs daemon")
        EmacsControl.startEmacsDaemon()
    }

    @objc func restoreWindowLayout(_ sender: NSMenuItem) {
        Logger.info("restore window layout")
        let count = WindowLayoutManager.shared.restoreLayout()
        if count == 0 {
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("restore_layout_title", comment: "")
            content.body = NSLocalizedString("restore_layout_none", comment: "")
            content.sound = .default
            displayNotification(content)
        }
    }

    @objc func quitEmacsCtl(_ sender: NSMenuItem) {
        Logger.info("quit emacs ctl")
        NSApplication.shared.terminate(self)
    }
}
