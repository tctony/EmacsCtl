//
//  Util.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/12.
//

import Cocoa
import Foundation
import UserNotifications

func displayNotification(_ content: UNNotificationContent) {
    let display: () -> Void = {
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    UNUserNotificationCenter.current().getNotificationSettings {
        switch $0.authorizationStatus {
        case .notDetermined:
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                if granted {
                    display()
                }
            }
        case .denied:
            Logger.warning("can't display notification")
        default: // take rest as granted
            display()
        }
    }
}

extension NSImage {
    func flipped(flipHorizontally: Bool = false, flipVertically: Bool = false) -> NSImage {
        let flippedImage = NSImage(size: size)

        flippedImage.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high

        let transform = NSAffineTransform()
        transform.translateX(by: flipHorizontally ? size.width : 0, yBy: flipVertically ? size.height : 0)
        transform.scaleX(by: flipHorizontally ? -1 : 1, yBy: flipVertically ? -1 : 1)
        transform.concat()

        draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1)

        flippedImage.unlockFocus()

        return flippedImage
    }
}
