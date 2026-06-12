import Foundation
import AppKit
import UserNotifications

enum Notifier {
    /// `sound` is "None", "Default", or a system alert sound name (e.g. "Glass").
    static func notify(title: String, body: String, sound: String = "Default") {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        switch sound {
        case "None":
            content.sound = nil
        case "Default":
            content.sound = .default
        default:
            content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

}
