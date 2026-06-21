//
//  SettingWindow.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/7.
//

import Cocoa
import UserNotifications

class SettingWindowController: BaseWindowController {


    @IBOutlet var pidFileTextField: NSTextField!

    @IBOutlet var installDirTextField: NSTextField!

    @IBOutlet var focusCodeTextField: NSTextField!

    @IBOutlet var gitOpenFunctionTextField: NSTextField!

    @IBOutlet var fileExtensionsTextField: NSTextField!

    override class var displayInDock: Bool {
        return true
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        self.window?.title = "EmacsCtl v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")!)"

        if let window = self.window, let screen = window.screen ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - window.frame.width / 2
            let y = screenFrame.midY - window.frame.height / 2 + 100
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        if let filePath = ConfigStore.shared.config.emacsPidFile {
            pidFileTextField.stringValue = filePath
        }
        if let dir = ConfigStore.shared.config.emacsInstallDir {
            installDirTextField.stringValue = dir
        }
        if let focusCode = ConfigStore.shared.config.focusCode {
            focusCodeTextField.stringValue = focusCode
        }
        if let gitFn = ConfigStore.shared.config.gitOpenFunction {
            gitOpenFunctionTextField.stringValue = gitFn
        }
        if let exts = ConfigStore.shared.config.fileExtensions {
            fileExtensionsTextField.stringValue = exts
        }

        // Auto-restore layout row (below "Launch At Login", above separator)
        if let contentView = window?.contentView {
            let rowY: CGFloat = 310

            // Checkbox: auto restore layout
            let checkbox = NSButton(checkboxWithTitle: NSLocalizedString("auto_restore_layout", comment: ""),
                                    target: self, action: #selector(autoRestoreLayoutChanged(_:)))
            checkbox.state = ConfigStore.shared.config.autoRestoreLayout ? .on : .off
            checkbox.sizeToFit()
            checkbox.frame.origin = NSPoint(x: 8, y: rowY)
            checkbox.autoresizingMask = [.maxXMargin, .minYMargin]
            contentView.addSubview(checkbox)

            // Info icon button
            let infoButton = NSButton(frame: NSRect(x: checkbox.frame.maxX + 4, y: rowY + 1, width: 14, height: 14))
            infoButton.image = NSImage(named: NSImage.infoName)
            infoButton.imageScaling = .scaleProportionallyDown
            infoButton.isBordered = false
            infoButton.target = self
            infoButton.action = #selector(showAutoRestoreInfo(_:))
            infoButton.autoresizingMask = [.maxXMargin, .minYMargin]
            contentView.addSubview(infoButton)

            // Save Layout button (same row, rightmost, vertically centered with checkbox)
            let saveButton = NSButton(title: NSLocalizedString("save_layout", comment: ""),
                                      target: self, action: #selector(saveWindowLayout(_:)))
            saveButton.bezelStyle = .rounded
            saveButton.sizeToFit()
            saveButton.frame.origin.x = contentView.bounds.size.width - saveButton.frame.size.width - 8
            saveButton.frame.origin.y = checkbox.frame.midY - saveButton.frame.height / 2 - 2
            saveButton.autoresizingMask = [.minXMargin, .minYMargin]
            contentView.addSubview(saveButton)
        }

        #if DEBUG
        let resetButton = NSButton(title: "reset", target: self, action: #selector(resetData(_:)))
        resetButton.bezelStyle = .rounded
        resetButton.sizeToFit()
        if let contentView = window?.contentView {
            resetButton.frame.origin.x = 123
            // Above "Launch At Login" checkbox, top-left corner
            resetButton.frame.origin.y = contentView.bounds.size.height - resetButton.frame.size.height + 6
            resetButton.autoresizingMask = [.maxXMargin, .minYMargin]
            contentView.addSubview(resetButton)
        }
        #endif
    }

    @IBAction func selectPidFilePath(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false

        if let defaultDirectoryURL = URL(string: pidFileTextField.stringValue) {
            openPanel.directoryURL = defaultDirectoryURL
        }

        if openPanel.runModal() == NSApplication.ModalResponse.OK {
            if let url = openPanel.url {
                let filePath = url.path
                Logger.debug("did select pid file path: \(filePath)")

                pidFileTextField.stringValue = filePath

                ConfigStore.shared.setPidFile(filePath)
            }
        } else {
            Logger.debug("select pid file path not ok")
        }
    }

    @IBAction func selectInstallDir(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false

        if let defaultDirectoryURL = URL(string: installDirTextField.stringValue) {
            openPanel.directoryURL = defaultDirectoryURL
        }

        if openPanel.runModal() == NSApplication.ModalResponse.OK {
            if let url = openPanel.url {
                let directoryPath = url.path
                Logger.debug("did selecte install dir: \(directoryPath)")

                installDirTextField.stringValue = directoryPath

                ConfigStore.shared.setInstallDir(directoryPath)
            }
        } else {
            Logger.debug("select install dir not ok")
        }
    }

    @IBAction func focusCodeDidChange(_ sender: Any) {
        let focusCode = focusCodeTextField.stringValue
        Logger.debug("focus code changed: \(focusCode)")
        ConfigStore.shared.setFocusCode(focusCode)
    }

    @IBAction func gitOpenFunctionDidChange(_ sender: Any) {
        let gitFn = gitOpenFunctionTextField.stringValue
        Logger.debug("git open function changed: \(gitFn)")
        ConfigStore.shared.setGitOpenFunction(gitFn)
    }

    @IBAction func fileExtensionsDidChange(_ sender: Any) {
        let raw = fileExtensionsTextField.stringValue
        let current = ConfigStore.shared.config.fileExtensions ?? ""
        guard raw != current else {
            Logger.debug("file extensions unchanged, skip")
            return
        }
        Logger.debug("file extensions changed: \(raw)")
        ConfigStore.shared.setFileExtensions(raw)

        let exts = DefaultAppRegistrar.parseExtensions(raw)
        DefaultAppRegistrar.shared.registerAsDefault(forExtensions: exts)
    }

    @objc func saveWindowLayout(_ sender: Any?) {
        guard let errorMsg = WindowLayoutManager.shared.saveLayout() else { return }
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("layout_save_failed_title", comment: "")
        content.body = errorMsg
        content.sound = .default
        displayNotification(content)
    }

    @objc func autoRestoreLayoutChanged(_ sender: NSButton) {
        ConfigStore.shared.setAutoRestoreLayout(sender.state == .on)
    }

    @objc func showAutoRestoreInfo(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("auto_restore_layout", comment: "")
        alert.informativeText = NSLocalizedString("auto_restore_info", comment: "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func resetData(_ sender: Any?) {
        Logger.info("reset data")
        ConfigStore.shared.reset()

        close()
    }

}
