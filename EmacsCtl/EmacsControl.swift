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

    static func startEmacsDaemon(_ succeed: ((Bool) -> Void)? = nil) {
        runShellCommand(Emacs, ["--daemon"]) { code, msg in
            print("\(#function) result: \(code) \(msg)")
            if code == 0 {
                newEmacsWindow(succeed)
            } else {
                displayError(#function, msg)
                succeed?(false)
            }
        }
    }

    static func newEmacsWindow(_ succeed: ((Bool) -> Void)? = nil) {
        runShellCommand(EmacsClient, ["-c", "-n"]) { code, msg in
            print("\(#function) result: \(code) \(msg)")
            if code == 0 {
                focusOnEmacs(succeed)
            } else {
                displayError(#function, msg)
                succeed?(false)
            }
        }
    }

    static func focusOnEmacs(_ succeed: ((Bool) -> Void)? = nil) {
        let workspace = NSWorkspace.shared
        let bundleId = "org.gnu.Emacs"
        if workspace.runningApplications.contains(where: { $0.bundleIdentifier == bundleId }) {
            print("emacs is running")
            if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) {
                print("focus on running emacs")
                workspace.openApplication(at: appURL, configuration: .init())

                succeed?(true)
                return
            } else {
                print("emacs is not running")
            }
        }
        succeed?(false)
    }

    static func stopEmacs(_ succeed: ((Bool) -> Void)? = nil) {
        runShellCommand(EmacsClient, ["--eval", "(kill-emacs)"]) { code, msg in
            print("\(#function) result: \(code) \(msg)")
            if code == 0 {
                succeed?(true)
            } else {
                displayError(#function, msg)
                succeed?(false)
            }
        }
    }

    static func restartEmacsDaemon(_ succeed: ((Bool) -> Void)? = nil) {
        stopEmacs { ok in
            if ok {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startEmacsDaemon(succeed)
                }
            } else {
                succeed?(false)
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
