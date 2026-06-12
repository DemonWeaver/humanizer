import AppKit
import AVFoundation

/// Manages notification sounds. macOS only plays notification sounds from the
/// app container's Library/Sounds folder, in PCM formats, up to 30 seconds —
/// so imports (mp3, m4a, anything AVFoundation reads) are converted to 16-bit
/// WAV and trimmed to 29 s. System alert sounds are copied in on first use.
@MainActor
final class SoundLibrary: ObservableObject {
    static let systemSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]

    enum ImportError: LocalizedError {
        case unreadable
        case empty

        var errorDescription: String? {
            switch self {
            case .unreadable: return "Couldn't read that audio file."
            case .empty: return "That audio file has no audio in it."
            }
        }
    }

    /// Imported sound filenames (with extension), shown in the pickers.
    @Published private(set) var customSounds: [String] = []

    private let soundsDir: URL

    init() {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        soundsDir = library.appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        refresh()
    }

    func refresh() {
        let files = (try? FileManager.default.contentsOfDirectory(at: soundsDir, includingPropertiesForKeys: nil)) ?? []
        customSounds = files
            .filter { ["wav", "aiff", "aif", "caf"].contains($0.pathExtension.lowercased()) }
            .map(\.lastPathComponent)
            .filter { !$0.hasPrefix("sys-") }  // hide cached system-sound copies
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Import any audio file: convert to 16-bit PCM WAV, trimmed to 29 seconds.
    /// Returns the imported filename.
    @discardableResult
    func importSound(from url: URL) throws -> String {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let input = try? AVAudioFile(forReading: url) else {
            throw ImportError.unreadable
        }
        let format = input.processingFormat
        let maxFrames = AVAudioFrameCount(min(Double(input.length), format.sampleRate * 29))
        guard maxFrames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: maxFrames) else {
            throw ImportError.empty
        }
        try input.read(into: buffer, frameCount: maxFrames)

        var base = url.deletingPathExtension().lastPathComponent
            .components(separatedBy: CharacterSet(charactersIn: "/:")).joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        if base.isEmpty { base = "custom-sound" }
        var dest = soundsDir.appendingPathComponent("\(base).wav")
        var counter = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = soundsDir.appendingPathComponent("\(base)-\(counter).wav")
            counter += 1
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let output = try AVAudioFile(
            forWriting: dest,
            settings: settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        try output.write(from: buffer)
        refresh()
        return dest.lastPathComponent
    }

    func deleteSound(_ filename: String) {
        try? FileManager.default.removeItem(at: soundsDir.appendingPathComponent(filename))
        refresh()
    }

    /// Resolve a picker selection into what Notifier needs. Selections are
    /// "None", "Default", a bare system sound name ("Glass"), or a custom
    /// filename ("airhorn.wav"). System sounds are cached into our container's
    /// Sounds folder on first use, since the sandbox lookup starts there.
    func resolveForNotification(_ selection: String) -> String {
        if selection == "None" || selection == "Default" || selection.contains(".") {
            return selection
        }
        let cachedName = "sys-\(selection).aiff"
        let cached = soundsDir.appendingPathComponent(cachedName)
        if !FileManager.default.fileExists(atPath: cached.path) {
            let system = URL(fileURLWithPath: "/System/Library/Sounds/\(selection).aiff")
            try? FileManager.default.copyItem(at: system, to: cached)
        }
        return cachedName
    }

    func preview(_ selection: String) {
        switch selection {
        case "None":
            return
        case "Default":
            NSSound.beep()
        case let custom where custom.contains("."):
            NSSound(contentsOf: soundsDir.appendingPathComponent(custom), byReference: true)?.play()
        default:
            NSSound(named: NSSound.Name(selection))?.play()
        }
    }
}
