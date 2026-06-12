import SwiftUI
import UserNotifications

@main
struct HumanizerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The menu bar UI is an AppKit NSStatusItem (see StatusItemController)
        // so the icon itself can accept file drops. Settings stays SwiftUI.
        Settings {
            SettingsView()
                .environmentObject(AppState.shared)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        MainActor.assumeIsolated {
            statusController = StatusItemController(state: AppState.shared)
        }
    }

    // Show banners even while the app is active (it is a menu bar app).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
