//
//  Control.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/8.
//

import Foundation

class EmacsControl {

    static func runShellCommand(_ binary: String,
                                _ arguments: [String] ,
                                completion: @escaping ((Int32, String) -> Void)) {
        let queue = DispatchQueue.global(qos: .background)
        queue.async {
            do {
                let process = Process()
                process.launchPath = "\(ConfigStore.shared.config.emacsInstallDir!)/\(binary)"
                process.arguments = arguments

                try process.run()
                process.waitUntilExit()

                completion(process.terminationStatus, "")
            } catch let error as NSError {
                print("run command error: \(error)")
                completion(numericCast(error.code), error.localizedDescription)
            } catch {
                print("run command error: \(error)")
                completion(-1, "unknown error")
            }
        }
    }

    static func stopEmacs() {
        runShellCommand("emacsclient", ["--eval", "(version)",  "--alternate-editor=nil"]) { code, msg in
            print("stop emacs result: \(code) \(msg)")
            if code != 0 {
                // TODO show error notification
            }
        }
    }
}
