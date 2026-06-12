import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    enum Phase: Equatable {
        case idle
        case working(String)   // status label
        case done
        case failed(String)
    }

    @Published var inputText = ""
    @Published var outputText = ""
    @Published var feedbackText = ""
    @Published var phase: Phase = .idle
    @Published var statusLine = ""
    @Published var sourceFileURL: URL?
    @Published var selectedProfileID: UUID?

    let settings = AppSettings()
    let styleStore = StyleProfileStore()
    let sounds = SoundLibrary()
    private let client = AnthropicClient()

    /// Conversation history for the current humanize session (iterative refinement).
    private var messages: [AnthropicClient.ChatMessage] = []
    private var currentTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        // Forward nested-store changes so views observing AppState refresh.
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        styleStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        sounds.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var isWorking: Bool {
        if case .working = phase { return true }
        return false
    }

    var activeProfile: CustomProfile? {
        guard let id = selectedProfileID else { return nil }
        return settings.profiles.first { $0.id == id }
    }

    // MARK: - Actions

    func humanizeClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed("Clipboard has no text.")
            return
        }
        inputText = text
        sourceFileURL = nil
        humanize()
    }

    func humanize() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            phase = .failed("Nothing to humanize — paste or drop some text first.")
            return
        }
        messages = [.init(role: "user", content: "Humanize the following text:\n\n\(text)")]
        runRewrite(status: "Humanizing…")
    }

    func refine() {
        let feedback = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !feedback.isEmpty, !outputText.isEmpty else { return }
        messages.append(.init(role: "assistant", content: outputText))
        messages.append(.init(role: "user", content: "Adjust the rewrite based on this feedback, and return the full revised text: \(feedback)"))
        feedbackText = ""
        runRewrite(status: "Adjusting wording…")
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        phase = .idle
        statusLine = "Cancelled."
    }

    func reset() {
        cancel()
        inputText = ""
        outputText = ""
        feedbackText = ""
        sourceFileURL = nil
        messages = []
        phase = .idle
        statusLine = ""
    }

    private func runRewrite(status: String) {
        guard let apiKey = settings.apiKey, !apiKey.isEmpty else {
            phase = .failed("No API key set. Add your Anthropic API key in Settings.")
            return
        }
        currentTask?.cancel()
        phase = .working(status)
        statusLine = status
        outputText = ""

        let system = SkillPrompt.systemBlocks(
            voiceSample: styleStore.voiceSample,
            styleProfile: styleStore.styleProfile,
            customProfilePrompt: activeProfile?.prompt
        )
        let body = AnthropicClient.RequestBody(
            model: settings.model,
            maxTokens: 32000,
            system: system,
            messages: messages,
            adaptiveThinking: settings.model.hasPrefix("claude-opus") || settings.model.hasPrefix("claude-sonnet")
        )

        currentTask = Task {
            do {
                let final = try await client.streamMessage(apiKey: apiKey, body: body) { delta in
                    Task { @MainActor in self.outputText += delta }
                }
                guard !Task.isCancelled else { return }
                outputText = final
                phase = .done
                statusLine = "Done."
                copyOutputToClipboard()
                if sourceFileURL != nil {
                    saveOutputToFile()
                }
            } catch is CancellationError {
                // ignore
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed(error.localizedDescription)
                statusLine = ""
            }
        }
    }

    // MARK: - Clipboard / files

    func copyOutputToClipboard() {
        guard !outputText.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(outputText, forType: .string)
        statusLine = "Copied to clipboard ✓"
        Notifier.notify(
            title: "Humanizer",
            body: "Output copied to clipboard.",
            sound: sounds.resolveForNotification(settings.rewriteDoneSound)
        )
    }

    func loadDroppedFile(_ url: URL, autoRun: Bool = false) {
        do {
            let text = try TextExtractor.extractText(from: url)
            inputText = text
            sourceFileURL = url
            outputText = ""
            phase = .idle
            statusLine = "Loaded \(url.lastPathComponent)"
            if autoRun && settings.hasAPIKey {
                humanize()
            }
        } catch {
            phase = .failed("Couldn't read \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    func openFilePanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = TextExtractor.supportedExtensions
            .compactMap { UTType(filenameExtension: $0) }
        panel.prompt = "Humanize"
        if panel.runModal() == .OK, let url = panel.url {
            loadDroppedFile(url, autoRun: true)
        }
    }

    func saveOutputToFile() {
        guard !outputText.isEmpty else { return }
        let baseName: String
        let ext: String
        if let src = sourceFileURL {
            baseName = src.deletingPathExtension().lastPathComponent + "-humanized"
            let srcExt = src.pathExtension.lowercased()
            ext = (srcExt == "md") ? "md" : "txt"
        } else {
            baseName = "humanized"
            ext = "txt"
        }

        if let folder = settings.resolvedOutputFolder() {
            let didAccess = folder.startAccessingSecurityScopedResource()
            defer { if didAccess { folder.stopAccessingSecurityScopedResource() } }
            var dest = folder.appendingPathComponent("\(baseName).\(ext)")
            var counter = 2
            while FileManager.default.fileExists(atPath: dest.path) {
                dest = folder.appendingPathComponent("\(baseName)-\(counter).\(ext)")
                counter += 1
            }
            do {
                try outputText.write(to: dest, atomically: true, encoding: .utf8)
                statusLine = "Saved \(dest.lastPathComponent) ✓"
                Notifier.notify(
                    title: "Humanizer",
                    body: "Saved \(dest.lastPathComponent) to \(folder.lastPathComponent).",
                    sound: sounds.resolveForNotification(settings.fileSavedSound)
                )
            } catch {
                phase = .failed("Couldn't save file: \(error.localizedDescription)")
            }
        } else {
            // No output folder configured — fall back to a save panel.
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "\(baseName).\(ext)"
            panel.allowedContentTypes = [ext == "md" ? .init(filenameExtension: "md")! : .plainText]
            if panel.runModal() == .OK, let url = panel.url {
                do {
                    try outputText.write(to: url, atomically: true, encoding: .utf8)
                    statusLine = "Saved \(url.lastPathComponent) ✓"
                    Notifier.notify(
                        title: "Humanizer",
                        body: "Saved \(url.lastPathComponent).",
                        sound: sounds.resolveForNotification(settings.fileSavedSound)
                    )
                } catch {
                    phase = .failed("Couldn't save file: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Style learning

    /// Distill the feedback given this session into durable preferences and merge
    /// them into the persistent style profile.
    func learnFromSession() {
        guard let apiKey = settings.apiKey, !apiKey.isEmpty else {
            phase = .failed("No API key set. Add your Anthropic API key in Settings.")
            return
        }
        let feedbackTurns = messages.filter { $0.role == "user" }.dropFirst()
        guard !feedbackTurns.isEmpty else {
            statusLine = "Nothing to learn yet — refine the wording first, then teach."
            return
        }
        phase = .working("Updating your style profile…")
        statusLine = "Updating your style profile…"

        let transcript = feedbackTurns.map { "- \($0.content)" }.joined(separator: "\n")
        let currentProfile = styleStore.styleProfile ?? "(empty)"
        let prompt = """
        CURRENT STYLE PROFILE:
        \(currentProfile)

        FEEDBACK THE USER GAVE DURING THIS REWRITE SESSION:
        \(transcript)

        Return the updated style profile.
        """
        let body = AnthropicClient.RequestBody(
            model: settings.model,
            maxTokens: 2000,
            system: [.init(text: SkillPrompt.profileUpdaterInstructions)],
            messages: [.init(role: "user", content: prompt)],
            adaptiveThinking: false
        )
        currentTask = Task {
            do {
                let updated = try await client.streamMessage(apiKey: apiKey, body: body) { _ in }
                guard !Task.isCancelled else { return }
                styleStore.styleProfile = updated.trimmingCharacters(in: .whitespacesAndNewlines)
                phase = .done
                statusLine = "Style profile updated ✓"
                Notifier.notify(
                    title: "Humanizer",
                    body: "Your style profile was updated from this session's feedback.",
                    sound: sounds.resolveForNotification(settings.rewriteDoneSound)
                )
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed("Profile update failed: \(error.localizedDescription)")
            }
        }
    }
}
