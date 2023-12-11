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

    override class var displayInDock: Bool {
        return true
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        if let filePath = ConfigStore.shared.config.emacsPidFile {
            pidFileTextField.stringValue = filePath
        }
        if let dir = ConfigStore.shared.config.emacsInstallDir {
            installDirTextField.stringValue = dir
        }

        #if DEBUG
        let button = NSButton(title: "reset data", target: self, action: #selector(resetData(_:)))
        button.sizeToFit()
        button.frame.origin.x = window!.frame.size.width - button.frame.size.width
        window?.contentView?.addSubview(button)
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
                print("did select pid file path: \(filePath)")

                pidFileTextField.stringValue = filePath

                do {
                    
                    let bookmarkData = try url.bookmarkData(options: .withSecurityScope,
                                                                      includingResourceValuesForKeys: nil,
                                                                      relativeTo: nil)
                    ConfigStore.shared.setPidFile(path: filePath, data: bookmarkData)
                } catch {
                    print("Failed to create bookmark: \(error)")
                }
            }
        } else {
            print("select pid file path not ok")
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
                print("did selecte install dir: \(directoryPath)")

                installDirTextField.stringValue = directoryPath

                ConfigStore.shared.setInstallDir(directoryPath)
            }
        } else {
            print("select install dir not ok")
        }
    }

    @objc func resetData(_ sender: Any?) {
        print("reset data");
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
    }

}
