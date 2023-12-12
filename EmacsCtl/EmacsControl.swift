//
//  Control.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/8.
//

import Foundation
import AppKit
import UserNotifications

class EmacsControl: NSObject {

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

        if isRunning() {
            print("emacs is running")
            if let appURL = workspace.urlForApplication(withBundleIdentifier: EmacsBundleId) {
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

    static func minimizeEmacs(_ succeed: ((Bool) -> Void)? = nil) {
        runShellCommand(EmacsClient, ["--eval", "(iconify-or-deiconify-frame)"]) { code, msg in
            print("\(#function) result: \(code) \(msg)")
            if code == 0 {
                succeed?(true)
            } else {
                displayError(#function, msg)
                succeed?(false)
            }
        }
    }

    @objc static func switchToEmacs() {
        guard isRunning() else {
            displayError("switchToEmacs", "Emacs is not running!")
            return
        }

        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            return $0.bundleIdentifier == EmacsBundleId
        }) else {
            displayError("switchToEmacs", "Emacs is not running!")
            return
        }

        if isFrontMost() {
            minimizeEmacs()
            return
        }

        let windowListInfo = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as! [[String: Any]]
        let windowIDs = windowListInfo.compactMap { $0[kCGWindowOwnerPID as String] as? Int }
        if windowIDs.contains(numericCast(app.processIdentifier)) {
            focusOnEmacs()
        } else {
            newEmacsWindow()
        }
    }

    static func handleUrl(_ url: String, _ succeed: ((Bool) -> Void)? = nil) {
        runShellCommand(EmacsClient, ["-c", "-n", "\"\(url)\""]) { code, msg in
            print("\(#function) result: \(code) \(msg)")
            if code == 0 {
                succeed?(true)
            } else {
                displayError(#function, msg)
                succeed?(false)
            }
        }
    }

    // MARK: -

    static let EmacsBundleId = "org.gnu.Emacs"

    static func isRunning() -> Bool {
        return NSWorkspace.shared.runningApplications.contains(where: {
            return $0.bundleIdentifier == EmacsBundleId
        })
    }

    static func isFrontMost() -> Bool {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier == EmacsBundleId
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
        print("\(action) error: \(msg)")

        let content = UNMutableNotificationContent()
        content.title = action.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression)
        content.body = msg.lengthOfBytes(using: .utf8) > 0 ? msg : "unknown"
        content.sound = .default

        displayNotification(content)
    }
}
