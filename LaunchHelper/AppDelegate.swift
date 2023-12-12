//
//  AppDelegate.swift
//  LaunchHelper
//
//  Created by Tony Tang on 2023/12/12.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let mainAppBundleId = Bundle.main.bundleIdentifier!.replacingOccurrences(of: ".LaunchHelper", with: "")

        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains {
            $0.bundleIdentifier == mainAppBundleId
        }


        if !isRunning {
            print("not running")
            var path = Bundle.main.bundlePath as NSString
            for _ in 1...4 {
                path = path.deletingLastPathComponent as NSString
            }
            let applicationPathString = path as String
            print("opening \(applicationPathString)")
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: applicationPathString),
                                                  configuration: .init()) { _, error in
                print("succeed")
                if error != nil {
                    print(error!)
                }
                NSApp.terminate(nil)
            }
        } else {
            print("already running")
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

