//
//  OrgRoamCaptureWindow.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2024/1/1.
//

import Cocoa
import os.log

@objc
class OrgRoamCaptureWindow: UrlCaptureBaseWindow {

    @objc var template: String = ""
    @objc var ref: String = ""
    @objc var title: String = ""
    @objc var body: String = ""

    @IBOutlet var titleTextField: NSTextField!

    private var unknownItems: [URLQueryItem] = []

    override func windowDidLoad() {
        super.windowDidLoad()

        titleTextField.becomeFirstResponder()
    }

    override func unpackUrl() {
        if (url == nil) {
            print("url is nil")
            return
        }

        if let components = URLComponents(url: url!, resolvingAgainstBaseURL: false) {
            if let queryItems = components.queryItems {
                unknownItems = []
                for item in queryItems {
                    switch (item.name) {
                    case "template": self.template = item.value ?? ""
                    case "ref": self.ref = item.value ?? ""
                    case "title": self.title = item.value ?? ""
                    case "body": self.body = item.value ?? ""
                    default:
                        os_log("unknwon param: %s=%s", type: .info, item.name, item.value ?? "")
                        unknownItems.append(item)
                    }
                }
            }
        }
    }

    override func packUrl() -> String {
        if (url == nil) {
            return ""
        }

        if var components = URLComponents(url: url!, resolvingAgainstBaseURL: false) {
            components.queryItems = unknownItems + [
                URLQueryItem(name: "template", value: template),
                URLQueryItem(name: "ref", value: ref),
                URLQueryItem(name: "title", value: title),
                URLQueryItem(name: "body", value: body),
            ]
            if let url = components.url {
                return url.absoluteString
            }
        }
        return ""
    }
}
