import SwiftUI
import Combine
import Sparkle

/// Wraps Sparkle's updater so SwiftUI views can trigger a manual check and the
/// app gets automatic background update checks (feed + key come from Info.plist:
/// SUFeedURL, SUPublicEDKey).
@MainActor
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    private let controller: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false

    private init() {
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
