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
    
    /// Find the Emacs server socket path
    /// macOS stores it in $TMPDIR/emacs$UID/server
    static func findSocketPath() -> String? {
        let uid = getuid()
        
        // Use NSTemporaryDirectory() which works correctly for GUI apps on macOS
        let nsTemp = NSTemporaryDirectory()
        let nsTempSocketPath = "\(nsTemp)emacs\(uid)/server"
        Logger.debug("checking socket at NSTemporaryDirectory: \(nsTempSocketPath)")
        if FileManager.default.fileExists(atPath: nsTempSocketPath) {
            Logger.debug("found socket at: \(nsTempSocketPath)")
            return nsTempSocketPath
        }
        
        // Try TMPDIR environment variable
        if let tmpdir = ProcessInfo.processInfo.environment["TMPDIR"] {
            let socketPath = "\(tmpdir)emacs\(uid)/server"
            Logger.debug("checking socket at TMPDIR: \(socketPath)")
            if FileManager.default.fileExists(atPath: socketPath) {
                Logger.debug("found socket at: \(socketPath)")
                return socketPath
            }
        } else {
            Logger.debug("TMPDIR not set in environment")
        }
        
        // Try /tmp/emacs$UID (Linux default)
        let tmpSocket = "/tmp/emacs\(uid)/server"
        if FileManager.default.fileExists(atPath: tmpSocket) {
            Logger.debug("found socket at: \(tmpSocket)")
            return tmpSocket
        }
        
        // Try XDG_RUNTIME_DIR (some Linux systems)
        if let xdgRuntime = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] {
            let socketPath = "\(xdgRuntime)/emacs/server"
            if FileManager.default.fileExists(atPath: socketPath) {
                Logger.debug("found socket at: \(socketPath)")
                return socketPath
            }
        }
        
        Logger.warning("could not find emacs socket")
        return nil
    }
    
    /// Build emacsclient arguments with socket path if needed
    static func buildEmacsClientArgs(_ args: [String]) -> [String] {
        if let socketPath = findSocketPath() {
            return ["-s", socketPath] + args
        }
        return args
    }

    static func startEmacsDaemon(_ succeed: ((Bool) -> Void)? = nil) {
        (NSApplication.shared.delegate as! AppDelegate).isDeamonStarting = true

        // Run emacs --daemon in background using shell, since Process doesn't support '&'
        runShellCommandViaShell("\(ConfigStore.shared.config.emacsInstallDir!)/\(Emacs) --daemon &") { code, msg in
            (NSApplication.shared.delegate as! AppDelegate).isDeamonStarting = false

            Logger.info("startEmacsDaemon result: \(code) \(msg)")
            if code == 0 {
                // Wait a bit for daemon to be fully ready before creating window
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    newEmacsWindow(succeed)
                }
            } else {
                displayError(#function, code, msg)
                succeed?(false)
            }
        }
    }

    static func newEmacsWindow(_ succeed: ((Bool) -> Void)? = nil) {
        // Use --eval to explicitly create a macOS GUI frame (ns = NextStep/Cocoa)
        runShellCommand(EmacsClient, buildEmacsClientArgs(["-n", "--eval", "(make-frame '((window-system . ns)))"])) { code, msg in
            Logger.info("newEmacsWindow result: \(code) \(msg)")
            if code == 0 {
                focusOnEmacs(succeed)
            } else {
                displayError(#function, code, msg)
                succeed?(false)
            }
        }
    }

    static func focusOnEmacs(_ succeed: ((Bool) -> Void)? = nil) {
        let workspace = NSWorkspace.shared

        if isRunning() {
            Logger.debug("emacs is running")
            
            if isFrontMost() {
                if let focusCode = ConfigStore.shared.config.focusCode,
                   !focusCode.isEmpty {
                    Logger.debug("using custom focus code: \(focusCode)")
                    runShellCommand(EmacsClient, buildEmacsClientArgs(["--eval", focusCode])) { code, msg in
                        Logger.info("focusOnEmacs (custom) result: \(code) \(msg)")
                        if code == 0 {
                            succeed?(true)
                        } else {
                            displayError("focusOnEmacs", code, msg)
                            succeed?(false)
                        }
                    }
                    return
                }

            } else {
                // Fallback to default behavior: bring Emacs app to front
                if let appURL = workspace.urlForApplication(withBundleIdentifier: EmacsBundleId) {
                    Logger.debug("focus on running emacs")
                    workspace.openApplication(at: appURL, configuration: .init())
                    
                    succeed?(true)
                    return
                } else {
                    Logger.debug("emacs is not running")
                }
            }
        }
        
        succeed?(false)
    }

    static func stopEmacs(_ succeed: ((Bool) -> Void)? = nil) {
        runShellCommand(EmacsClient, buildEmacsClientArgs(["--eval", "(kill-emacs)"])) { code, msg in
            Logger.info("stopEmacs result: \(code) \(msg)")
            if code == 0 {
                succeed?(true)
            } else {
                displayError(#function, code, msg)
                succeed?(false)
            }
        }
    }

    static func restartEmacsDaemon(_ succeed: ((Bool) -> Void)? = nil) {
        if !isRunning() {
            Logger.info("Emacs is not running, start it directly")
            startEmacsDaemon(succeed)
            return
        }

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
        runShellCommand(EmacsClient, buildEmacsClientArgs(["--eval", "(iconify-or-deiconify-frame)"])) { code, msg in
            Logger.info("minimizeEmacs result: \(code) \(msg)")
            if code == 0 {
                succeed?(true)
            } else {
                displayError(#function, code, msg)
                succeed?(false)
            }
        }
    }

    @objc static func switchToEmacs() {
        guard isRunning() else {
            // displayError("switchToEmacs", -1, "Emacs is not running!")
            Logger.debug("Emacs is not running, start it")
            startEmacsDaemon { succeed in
                if (!succeed) {
                    displayError("switchToEmacs", -1, "Start emacs failed!");
                }
            }
            return
        }

        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            return $0.bundleIdentifier == EmacsBundleId
        }) else {
            displayError("switchToEmacs", -1, "Emacs is not running!")
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
        runShellCommand(EmacsClient, buildEmacsClientArgs(["-n", url])) { code, msg in
            Logger.info("handleUrl result: \(code) \(msg)")
            if code == 0 {
                focusOnEmacs(succeed)
            } else {
                displayError(#function, code, msg)
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
    
    /// Run a command via /bin/sh, allowing shell features like '&' for background execution
    static func runShellCommandViaShell(_ command: String,
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
                process.launchPath = "/bin/sh"
                process.arguments = ["-c", command]
                
                // Set environment variables
                var env = ProcessInfo.processInfo.environment
                env["TERM"] = env["TERM"] ?? "xterm-256color"
                process.environment = env
                
                // Capture stderr to get error messages
                let stderrPipe = Pipe()
                process.standardError = stderrPipe
                
                Logger.info("run shell command: \(command)")

                try process.run()
                process.waitUntilExit()
                
                // Read stderr output
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrOutput = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                Logger.info("shell command finished. status \(process.terminationStatus)")
                if !stderrOutput.isEmpty {
                    Logger.debug("stderr: \(stderrOutput)")
                }

                callback(process.terminationStatus, stderrOutput)
            } catch let error as NSError {
                Logger.error("shell command error: \(error.localizedDescription)")

                callback(numericCast(error.code), error.localizedDescription)
            } catch {
                Logger.error("shell command error: \(error.localizedDescription)")

                callback(-1, "unknown error: \(error.localizedDescription)")
            }
        }
    }

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
                
                // Set environment variables to avoid "Unknown terminal type" error
                var env = ProcessInfo.processInfo.environment
                env["TERM"] = env["TERM"] ?? "xterm-256color"
                process.environment = env
                
                // Capture stderr to get error messages
                let stderrPipe = Pipe()
                process.standardError = stderrPipe
                
                Logger.info("run command: \(process.launchPath ?? "") \((process.arguments ?? []).joined(separator: " "))")

                try process.run()
                process.waitUntilExit()
                
                // Read stderr output
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrOutput = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                Logger.info("run command finished. status \(process.terminationStatus)")
                if !stderrOutput.isEmpty {
                    Logger.debug("stderr: \(stderrOutput)")
                }

                callback(process.terminationStatus, stderrOutput)
            } catch let error as NSError {
                Logger.error("run command error: \(error.localizedDescription)")

                callback(numericCast(error.code), error.localizedDescription)
            } catch {
                Logger.error("run command error: \(error.localizedDescription)")

                callback(-1, "unknown error: \(error.localizedDescription)")
            }
        }
    }

    static func displayError(_ action: String, _ code: Int32, _ msg: String) {
        Logger.error("\(action) error: \(msg)")

        let content = UNMutableNotificationContent()
        content.title = action.replacingOccurrences(of: "\\(.*\\)", with: "", options: .regularExpression)
        content.subtitle = "code \(code)"
        content.body = msg.lengthOfBytes(using: .utf8) > 0 ? msg : "unknown"
        content.sound = .default

        displayNotification(content)
    }
}
