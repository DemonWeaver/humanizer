import Foundation

/// Persists the learned style profile and the voice calibration sample as
/// markdown files in the app's Application Support container.
@MainActor
final class StyleProfileStore: ObservableObject {
    private let directory: URL
    private var profileURL: URL { directory.appendingPathComponent("style-profile.md") }
    private var voiceURL: URL { directory.appendingPathComponent("voice-sample.md") }

    @Published var styleProfile: String? {
        didSet { write(styleProfile, to: profileURL) }
    }

    @Published var voiceSample: String? {
        didSet { write(voiceSample, to: voiceURL) }
    }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = support.appendingPathComponent("Humanizer", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        styleProfile = try? String(contentsOf: directory.appendingPathComponent("style-profile.md"), encoding: .utf8)
        voiceSample = try? String(contentsOf: directory.appendingPathComponent("voice-sample.md"), encoding: .utf8)
    }

    func resetProfile() {
        styleProfile = nil
    }

    private func write(_ value: String?, to url: URL) {
        if let value, !value.isEmpty {
            try? value.write(to: url, atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
