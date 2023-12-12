//
//  Control.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/8.
//

import Foundation
import AppKit

class EmacsControl {

    static let Emacs = "emacs"
    static let EmacsClient = "emacsclient"

    static func startEmacsDaemon() {
        runShellCommand(Emacs, ["--daemon"]) { code, msg in
            print("\(#function) result: \(code) \(msg)")
            if code == 0 {
                newEmacsWindow()
            } else {
                displayError(#function, msg)
            }
        }
    }

    static func newEmacsWindow() {
        runShellCommand(EmacsClient, ["-c", "-n"]) { code, msg in
            print("\(#function) result: \(code) \(msg)")
            if code == 0 {
                focusOnEmacs()
            } else {
                displayError(#function, msg)
            }
        }
    }

    static func focusOnEmacs() {
        let workspace = NSWorkspace.shared
        let bundleId = "org.gnu.Emacs"
        if workspace.runningApplications.contains(where: { $0.bundleIdentifier == bundleId }) {
            print("emacs is running")
            if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) {
                print("focus on running emacs")
                workspace.openApplication(at: appURL, configuration: .init())
            } else {
                print("emacs is not running")
            }
        }
    }

    static func stopEmacs() {
        runShellCommand(EmacsClient, ["--eval", "(kill-emacs)"]) { code, msg in
            print("\(#function) result: \(code) \(msg)")
            if code != 0 {
                displayError(#function, msg)
            }
        }
    }

    static func restartEmacsDaemon() {
        runShellCommand(EmacsClient, ["--eval", "(kill-emacs nil t)"]) { code, msg in
            print("\(#function) result: \(code) \(msg)")
            if code == 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                    newEmacsWindow()
                }
            } else {
                displayError(#function, msg)
            }
        }
    }

    // MARK: -

    static func runShellCommand(_ binary: String,
                                _ arguments: [String] ,
                                completion: @escaping ((Int32, String) -> Void)) {
        let queue = DispatchQueue.global()
        let callback: (Int32, String) -> Void = { code, msg in
            DispatchQueue.main.async {
                completion(code, msg)
            }
        }
        queue.async {
            do {
                let process = Process()
                process.launchPath = "\(ConfigStore.shared.config.emacsInstallDir!)/\(binary)"
                process.arguments = arguments

                try process.run()
                process.waitUntilExit()

                callback(process.terminationStatus, "")
            } catch let error as NSError {
                print("run command error: \(error)")
                callback(numericCast(error.code), error.localizedDescription)
            } catch {
                print("run command error: \(error)")
                callback(-1, "unknown error")
            }
        }
    }

    static func displayError(_ action: String, _ msg: String) {
        // TODO show error notification
        print("\(action) error: \(msg)")
    }
}
