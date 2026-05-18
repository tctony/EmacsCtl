//
//  EmacsCtlUrlProcessor.swift
//  EmacsCtl
//
//  Handles the `emacsctl://` URL scheme used by Emacs (or other tools) to
//  drive EmacsCtl itself, e.g. to display actionable notifications.
//

import Cocoa
import Foundation
import UserNotifications

let EmacsCtlUrlScheme = "emacsctl"

let EmacsCtlUrlHostNotify = "notify"

class EmacsCtlUrlProcessor {

    static let shared = EmacsCtlUrlProcessor()

    private init() {
        // do nothing
    }

    func process(_ url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            Logger.warning("invalid emacsctl url: \(url.absoluteString)")
            return
        }

        switch url.host {
        case EmacsCtlUrlHostNotify:
            handleNotify(comps)
        default:
            Logger.warning("ignored unknown emacsctl url: \(url.absoluteString)")
        }
    }

    private func handleNotify(_ comps: URLComponents) {
        let items = comps.queryItems ?? []
        let title = items.first(where: { $0.name == "title" })?.value ?? "Emacs"
        let body = items.first(where: { $0.name == "body" })?.value ?? ""
        let group = items.first(where: { $0.name == "group" })?.value
        let actionEval = items.first(where: { $0.name == "actionEval" })?.value

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let group = group, !group.isEmpty {
            content.threadIdentifier = group
        }
        if let eval = actionEval, !eval.isEmpty {
            content.userInfo = ["actionEval": eval]
        }
        // Use group as request identifier so notifications in the same
        // group replace earlier ones (avoids stacking in Notification
        // Center).  Fall back to a random id when no group provided.
        let identifier = (group?.isEmpty == false) ? group! : UUID().uuidString
        displayNotification(content, identifier: identifier)
    }
}
