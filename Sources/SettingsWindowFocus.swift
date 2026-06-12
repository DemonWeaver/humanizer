import AppKit

/// In an LSUIElement (menu bar) app the SwiftUI Settings window opens behind
/// other apps, and clicking the settings button again does nothing visible if
/// the window is already open. This activates the app and forces the Settings
/// window to the front.
enum SettingsWindowFocus {
    static func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        // SettingsLink needs a beat to create the window on first open.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusSettingsWindow()
        }
    }

    private static func focusSettingsWindow() {
        let window = NSApp.windows.first {
            $0.identifier?.rawValue.contains("Settings") == true
                || $0.title.localizedCaseInsensitiveContains("settings")
                || $0.title.localizedCaseInsensitiveContains("general")
        }
        if let window {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}
