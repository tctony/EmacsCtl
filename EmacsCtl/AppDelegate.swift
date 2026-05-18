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

let EmacsCtlUrlScheme = "emacsctl"
let EmacsCtlUrlHostNotify = "notify"

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

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == UrlScheme {
                UrlProcessor.shared.process(url)
            } else if url.scheme == EmacsCtlUrlScheme {
                handleEmacsCtlUrl(url)
            } else if url.isFileURL {
                Logger.info("open file via LaunchServices: \(url.path)")
                EmacsControl.openFile(url.path)
            } else {
                Logger.warning("ignored unknown url: \(url.absoluteString)")
            }
        }
    }

    // MARK: - emacsctl:// URL

    private func handleEmacsCtlUrl(_ url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            Logger.warning("invalid emacsctl url: \(url.absoluteString)")
            return
        }

        switch url.host {
        case EmacsCtlUrlHostNotify:
            let items = comps.queryItems ?? []
            let title = items.first(where: { $0.name == "title" })?.value ?? "Emacs"
            let body = items.first(where: { $0.name == "body" })?.value ?? ""
            let group = items.first(where: { $0.name == "group" })?.value
            let actionEval = items.first(where: { $0.name == "actionEval" })?.value

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            if let group = group, !group.isEmpty {
                content.threadIdentifier = group
            }
            if let eval = actionEval, !eval.isEmpty {
                content.userInfo = ["actionEval": eval]
            }
            // Use group as request identifier so notifications in the same
            // group replace earlier ones (avoids stacking in Notification
            // Center).  Fall back to a random id when no group provided.
            let identifier = (group?.isEmpty == false) ? group! : UUID().uuidString
            displayNotification(content, identifier: identifier)
        default:
            Logger.warning("ignored unknown emacsctl url: \(url.absoluteString)")
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
        let userInfo = response.notification.request.content.userInfo
        if let eval = userInfo["actionEval"] as? String, !eval.isEmpty {
            EmacsControl.evalAndFocus(eval)
        } else {
            EmacsControl.focusOnEmacs()
        }
        completionHandler()
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
        menu.addItem(NSMenuItem(title: NSLocalizedString("setting", comment: ""),
                                action: #selector(AppDelegate.showSettingWindow(_:)), 
                                keyEquivalent: ""))

        menu.addItem(NSMenuItem(title: NSLocalizedString("check_update", comment: ""),
                                target: self.updator!,
                                action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
                                keyEquivalent: ""))

        menu.addItem(withTitle: NSLocalizedString("quit", comment: ""),
                     action: #selector(AppDelegate.quitEmacsCtl(_:)),
                     keyEquivalent: "")


        Logger.debug("finish refreshing menu")
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
        Logger.info("show configure window")

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

    @objc func quitEmacsCtl(_ sender: NSMenuItem) {
        Logger.info("quit emacs ctl")
        NSApplication.shared.terminate(self)
    }
}
