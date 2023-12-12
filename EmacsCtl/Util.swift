//
//  Util.swift
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/12.
//

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
            print("can't display notification")
        default: // take rest as granted
            display()
        }
    }
}

