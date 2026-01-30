//
//  UrlCaptureBaseWindow.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2024/1/1.
//

import Cocoa

class UrlCaptureBaseWindow: BaseWindowController {

    override class var displayInDock: Bool {
        return true
    }

    public var url: URL? {
        didSet {
            Logger.info("start edit captured url: \(url?.absoluteString ?? "")")
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

            Logger.info("did commit capture url: \(url)")

            EmacsControl.handleUrl(url)

            self.close()
        }
    }

    @IBAction func onCancel(_ sender: Any) {
        Logger.info("did cancel capture url")

        close()
    }

}
