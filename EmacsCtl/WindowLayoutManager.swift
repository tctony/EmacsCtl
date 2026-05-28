//
//  WindowLayoutManager.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2026/5/26.
//

import Cocoa
import ApplicationServices

struct SavedWindowInfo: Codable {
    let ownerName: String
    let bundleIdentifier: String?
    let windowName: String?
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

class WindowLayoutManager {

    static let shared = WindowLayoutManager()

    private let store = UserDefaults.standard

    func saveLayout() -> Int {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
                as? [[String: Any]] else {
            Logger.error("Failed to get window list")
            return 0
        }

        var savedWindows: [SavedWindowInfo] = []

        for windowInfo in windowList {
            // Only save normal windows (layer 0)
            guard let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 0 else {
                continue
            }

            guard let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds["X"] as? Double,
                  let y = bounds["Y"] as? Double,
                  let width = bounds["Width"] as? Double,
                  let height = bounds["Height"] as? Double else {
                continue
            }

            // Skip tiny windows (likely invisible or system UI)
            guard width > 50 && height > 50 else { continue }

            let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32 ?? 0

            // Skip our own windows
            guard ownerPID != ProcessInfo.processInfo.processIdentifier else { continue }

            let windowName = windowInfo[kCGWindowName as String] as? String

            // Get bundle identifier from PID
            let bundleId = NSRunningApplication(processIdentifier: ownerPID)?
                .bundleIdentifier

            let info = SavedWindowInfo(
                ownerName: ownerName,
                bundleIdentifier: bundleId,
                windowName: windowName,
                x: x, y: y, width: width, height: height
            )
            savedWindows.append(info)
            Logger.debug("  [\(ownerName)] bundle=\(bundleId ?? "nil") title=\(windowName ?? "nil") frame=(\(x),\(y),\(width),\(height))")
        }

        // Save to UserDefaults as JSON
        if let data = try? JSONEncoder().encode(savedWindows) {
            store.set(data, forKey: UserDefaultsKeys.savedWindowLayout)
            store.synchronize()
        }

        Logger.info("Saved layout: \(savedWindows.count) windows")
        return savedWindows.count
    }

    func restoreLayout() -> Int {
        guard let data = store.data(forKey: UserDefaultsKeys.savedWindowLayout),
              let savedWindows = try? JSONDecoder().decode(
                [SavedWindowInfo].self, from: data) else {
            Logger.info("No saved layout found")
            return 0
        }

        // Prompt for accessibility permission if not yet granted
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            Logger.warning("Accessibility permission not granted")
            return 0
        }

        var restoredCount = 0

        let runningApps = NSWorkspace.shared.runningApplications

        // Group saved windows by app (bundle ID or owner name)
        // so we can match them by order within the same app
        var usedWindowIndices: [pid_t: Int] = [:]

        for savedWindow in savedWindows {
            let matchingApp = runningApps.first { app in
                if let savedBundleId = savedWindow.bundleIdentifier,
                   let appBundleId = app.bundleIdentifier {
                    return savedBundleId == appBundleId
                }
                return app.localizedName == savedWindow.ownerName
            }

            guard let app = matchingApp else { continue }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)

            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                appElement, kAXWindowsAttribute as CFString, &windowsRef)

            if result == .cannotComplete || result == .apiDisabled {
                Logger.warning("AX API denied for \(savedWindow.ownerName)")
                continue
            }
            guard result == .success,
                  let windows = windowsRef as? [AXUIElement] else {
                continue
            }

            // Pick the next unused window for this app
            let nextIndex = usedWindowIndices[app.processIdentifier] ?? 0
            guard nextIndex < windows.count else { continue }
            let window = windows[nextIndex]
            usedWindowIndices[app.processIdentifier] = nextIndex + 1

            // Set position
            var position = CGPoint(x: savedWindow.x, y: savedWindow.y)
            var posRestored = false
            if let posValue = AXValueCreate(.cgPoint, &position) {
                let posResult = AXUIElementSetAttributeValue(
                    window, kAXPositionAttribute as CFString, posValue)
                if posResult == .success {
                    posRestored = true
                } else {
                    Logger.debug("Set position failed for \(savedWindow.ownerName): \(posResult.rawValue)")
                }
            }

            // Set size
            var size = CGSize(width: savedWindow.width, height: savedWindow.height)
            var sizeRestored = false
            if let sizeValue = AXValueCreate(.cgSize, &size) {
                let sizeResult = AXUIElementSetAttributeValue(
                    window, kAXSizeAttribute as CFString, sizeValue)
                if sizeResult == .success {
                    sizeRestored = true
                } else {
                    Logger.debug("Set size failed for \(savedWindow.ownerName): \(sizeResult.rawValue)")
                }
            }

            // If AX failed, try AppleScript fallback
            if !posRestored || !sizeRestored {
                let restored = restoreViaAppleScript(
                    appName: savedWindow.ownerName,
                    x: Int(savedWindow.x), y: Int(savedWindow.y),
                    width: Int(savedWindow.width), height: Int(savedWindow.height))
                if restored {
                    Logger.debug("Restored \(savedWindow.ownerName) via AppleScript")
                } else if !sizeRestored {
                    // Last resort: try zoom button
                    var zoomButtonRef: CFTypeRef?
                    let zbResult = AXUIElementCopyAttributeValue(
                        window, kAXZoomButtonAttribute as CFString, &zoomButtonRef)
                    if zbResult == .success, let zoomButton = zoomButtonRef {
                        AXUIElementPerformAction(
                            zoomButton as! AXUIElement, kAXPressAction as CFString)
                    }
                }
            }

            restoredCount += 1
        }

        Logger.info("Restored \(restoredCount) of \(savedWindows.count) windows")
        return restoredCount
    }

    func hasSavedLayout() -> Bool {
        return store.data(forKey: UserDefaultsKeys.savedWindowLayout) != nil
    }

    /// Check if Emacs window position differs from saved layout (threshold: 10px).
    func needsRestore() -> Bool {
        guard let data = store.data(forKey: UserDefaultsKeys.savedWindowLayout),
              let savedWindows = try? JSONDecoder().decode(
                [SavedWindowInfo].self, from: data) else {
            Logger.debug("needsRestore: no saved layout data")
            return false
        }

        guard let savedEmacs = savedWindows.first(where: {
            $0.bundleIdentifier == "org.gnu.Emacs"
        }) else {
            Logger.debug("needsRestore: no Emacs entry in saved layout")
            return false
        }
        Logger.debug("needsRestore: saved Emacs at (\(savedEmacs.x),\(savedEmacs.y))")

        let runningApps = NSWorkspace.shared.runningApplications
        guard let emacsApp = runningApps.first(where: {
            $0.bundleIdentifier == "org.gnu.Emacs"
        }) else {
            Logger.debug("needsRestore: Emacs not running")
            return false
        }

        let appElement = AXUIElementCreateApplication(emacsApp.processIdentifier)
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement, kAXWindowsAttribute as CFString, &windowsRef)
        guard result == .success,
              let windows = windowsRef as? [AXUIElement],
              let window = windows.first else {
            Logger.debug("needsRestore: AX windows query failed, result=\(result.rawValue)")
            return false
        }

        var posRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef)
        guard let posRef = posRef else {
            Logger.debug("needsRestore: could not get position attribute")
            return false
        }

        var position = CGPoint.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &position)

        let threshold: Double = 10
        let dx = abs(position.x - savedEmacs.x)
        let dy = abs(position.y - savedEmacs.y)
        Logger.debug("needsRestore: current=(\(position.x),\(position.y)) saved=(\(savedEmacs.x),\(savedEmacs.y)) dx=\(dx) dy=\(dy)")

        if dx > threshold || dy > threshold {
            return true
        }
        return false
    }

    /// Fallback: use AppleScript via System Events to set window position/size
    private func restoreViaAppleScript(appName: String, x: Int, y: Int,
                                       width: Int, height: Int) -> Bool {
        let script = """
            tell application "System Events"
                tell process "\(appName)"
                    set position of window 1 to {\(x), \(y)}
                    set size of window 1 to {\(width), \(height)}
                end tell
            end tell
            """
        let appleScript = NSAppleScript(source: script)
        var errorInfo: NSDictionary?
        appleScript?.executeAndReturnError(&errorInfo)
        if let error = errorInfo {
            Logger.debug("AppleScript fallback failed for \(appName): \(error)")
            return false
        }
        return true
    }
}
