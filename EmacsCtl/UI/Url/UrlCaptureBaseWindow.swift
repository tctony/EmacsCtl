//
//  UrlCaptureBaseWindow.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2024/1/1.
//

import Cocoa
import os.log

class UrlCaptureBaseWindow: BaseWindowController {

    override class var displayInDock: Bool {
        return true
    }

    public var url: URL? {
        didSet {
            os_log("start edit captured url: %s", type: .info, url?.absoluteString ?? "")
            unpackUrl()
        }
    }

    public func unpackUrl() {
        // subclass implements detail
    }

    public func packUrl() -> String {
        // subclass implements detail
        return ""
    }

    @IBAction func onCommit(_ sender: Any) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let url = self.packUrl()

            os_log("did commit capture url: %s", type: .info, url)

            EmacsControl.handleUrl(url)

            self.close()
        }
    }

    @IBAction func onCancel(_ sender: Any) {
        os_log("did cancel capture url")

        close()
    }

}
