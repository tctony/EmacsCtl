//
//  SettingWindow.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/7.
//

import Cocoa

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

        #if DEBUG
        let button = NSButton(title: "reset", target: self, action: #selector(resetData(_:)))
        button.sizeToFit()
        if let contentView = window?.contentView {
            button.frame.origin.x = contentView.bounds.size.width - button.frame.size.width - 4
            button.frame.origin.y = contentView.bounds.size.height - button.frame.size.height - 4
            button.autoresizingMask = [.minXMargin, .minYMargin]
            contentView.addSubview(button)
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

    @objc func resetData(_ sender: Any?) {
        Logger.info("reset data")
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        ConfigStore.shared.config = Config()

        close()
    }

}
