import Foundation
import SwiftUI

struct CustomProfile: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var prompt: String
}

@MainActor
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    static let availableModels: [(id: String, label: String)] = [
        ("claude-opus-4-8", "Claude Opus 4.8 — best quality"),
        ("claude-sonnet-4-6", "Claude Sonnet 4.6 — fast & cheaper"),
        ("claude-haiku-4-5", "Claude Haiku 4.5 — cheapest"),
    ]


    @Published var model: String {
        didSet { defaults.set(model, forKey: "model") }
    }

    @Published var profiles: [CustomProfile] {
        didSet {
            if let data = try? JSONEncoder().encode(profiles) {
                defaults.set(data, forKey: "profiles")
            }
        }
    }

    @Published var outputFolderDisplayPath: String

    /// Cached so views don't hit the Keychain on every render.
    @Published private(set) var hasAPIKey: Bool

    @Published var rewriteDoneSound: String {
        didSet { defaults.set(rewriteDoneSound, forKey: "rewriteDoneSound") }
    }

    @Published var fileSavedSound: String {
        didSet { defaults.set(fileSavedSound, forKey: "fileSavedSound") }
    }

    init() {
        self.model = defaults.string(forKey: "model") ?? "claude-opus-4-8"
        self.rewriteDoneSound = defaults.string(forKey: "rewriteDoneSound") ?? "Default"
        self.fileSavedSound = defaults.string(forKey: "fileSavedSound") ?? "Glass"
        if let data = defaults.data(forKey: "profiles"),
           let decoded = try? JSONDecoder().decode([CustomProfile].self, from: data) {
            self.profiles = decoded
        } else {
            self.profiles = []
        }
        self.outputFolderDisplayPath = defaults.string(forKey: "outputFolderDisplayPath") ?? ""
        self.hasAPIKey = KeychainHelper.read()?.isEmpty == false

        // Seed an example profile on first launch so the feature is discoverable.
        if profiles.isEmpty, !defaults.bool(forKey: "didSeedProfiles") {
            profiles = [CustomProfile(
                name: "Casual email",
                prompt: "This is an email to someone I know. Keep it friendly and direct, contractions are fine, no corporate phrasing, and keep it shorter than the original if possible."
            )]
            defaults.set(true, forKey: "didSeedProfiles")
        }
    }

    // MARK: - API key (Keychain)

    var apiKey: String? {
        get { KeychainHelper.read() }
        set {
            if let value = newValue, !value.isEmpty {
                KeychainHelper.save(value)
            } else {
                KeychainHelper.delete()
            }
            hasAPIKey = newValue?.isEmpty == false
        }
    }

    // MARK: - Output folder (security-scoped bookmark for the sandbox)

    func setOutputFolder(_ url: URL) {
        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(bookmark, forKey: "outputFolderBookmark")
            outputFolderDisplayPath = url.path
            defaults.set(url.path, forKey: "outputFolderDisplayPath")
        } catch {
            NSLog("Failed to bookmark output folder: \(error)")
        }
    }

    func clearOutputFolder() {
        defaults.removeObject(forKey: "outputFolderBookmark")
        defaults.removeObject(forKey: "outputFolderDisplayPath")
        outputFolderDisplayPath = ""
    }

    func resolvedOutputFolder() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: "outputFolderBookmark") else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        if stale { setOutputFolder(url) }
        return url
    }
}
