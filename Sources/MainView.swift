import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @EnvironmentObject private var state: AppState
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if !state.settings.hasAPIKey {
                apiKeyBanner
            }
            inputSection
            actionRow
            outputSection
            if case .failed(let message) = state.phase {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }
        }
        .padding(14)
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            handleDrop(providers)
        }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        Label("Drop a txt, md, docx, rtf, or pdf file", systemImage: "doc.text")
                            .font(.headline)
                    }
                    .padding(4)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Humanizer", systemImage: "wand.and.stars")
                .font(.headline)
            Spacer()
            Picker("Profile", selection: $state.selectedProfileID) {
                Text("No profile").tag(UUID?.none)
                ForEach(state.settings.profiles) { profile in
                    Text(profile.name).tag(Optional(profile.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 150)
            .help("Profiles are extra instructions sent with the rewrite — manage them in Settings")
            settingsButton
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit Humanizer")
        }
    }

    private var settingsButton: some View {
        SettingsLink {
            Image(systemName: "gearshape")
        }
        .buttonStyle(.borderless)
        .help("Settings")
        // SettingsLink doesn't focus an already-open Settings window in a
        // menu bar app — force it to the front on every click.
        .simultaneousGesture(TapGesture().onEnded {
            SettingsWindowFocus.bringToFront()
        })
    }

    private var apiKeyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("Add your Anthropic API key to get started")
                    .font(.callout.weight(.medium))
                Text("console.anthropic.com → API keys, then paste it in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SettingsLink {
                Text("Open Settings")
            }
            .simultaneousGesture(TapGesture().onEnded {
                SettingsWindowFocus.bringToFront()
            })
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Input")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let file = state.sourceFileURL {
                    Label(file.lastPathComponent, systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !state.inputText.isEmpty {
                    Text(wordCount(state.inputText))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Button("Clear") { state.reset() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }
            TextEditor(text: $state.inputText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(minHeight: 110, maxHeight: 150)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08))
                }
                .overlay(alignment: .topLeading) {
                    if state.inputText.isEmpty {
                        Text("Paste text here, or drop a file anywhere in this window…")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 12)
                            .padding(.leading, 10)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button {
                state.humanize()
            } label: {
                Label("Humanize", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(state.isWorking || state.inputText.isEmpty)
            .help("⌘↩")

            Button("Humanize Clipboard") {
                state.humanizeClipboard()
            }
            .disabled(state.isWorking)
            .help("Grab whatever is on the clipboard and humanize it")

            Spacer()

            if state.isWorking {
                ProgressView()
                    .controlSize(.small)
                Button("Cancel") { state.cancel() }
                    .buttonStyle(.borderless)
            }
        }
    }

    // MARK: - Output

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Output")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if !state.outputText.isEmpty {
                    Text(wordCount(state.outputText))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if !state.statusLine.isEmpty {
                    Text(state.statusLine)
                        .font(.caption)
                        .foregroundStyle(state.statusLine.contains("✓") ? .green : .secondary)
                }
            }
            TextEditor(text: $state.outputText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(minHeight: 140, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08))
                }
                .overlay(alignment: .topLeading) {
                    if state.outputText.isEmpty && !state.isWorking {
                        Text("The humanized text appears here and is copied to your clipboard automatically.")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 12)
                            .padding(.leading, 10)
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: 8) {
                TextField("Adjust the wording — e.g. “less formal, shorter sentences”", text: $state.feedbackText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { state.refine() }
                Button("Refine") { state.refine() }
                    .disabled(state.isWorking || state.outputText.isEmpty || state.feedbackText.isEmpty)
            }

            HStack(spacing: 8) {
                Button {
                    state.copyOutputToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(state.outputText.isEmpty)

                Button {
                    state.saveOutputToFile()
                } label: {
                    Label("Save to File", systemImage: "square.and.arrow.down")
                }
                .disabled(state.outputText.isEmpty)

                Spacer()

                Button {
                    state.learnFromSession()
                } label: {
                    Label("Teach My Style", systemImage: "graduationcap")
                }
                .help("Distill this session's feedback into your permanent style profile")
                .disabled(state.isWorking || state.outputText.isEmpty)
            }
        }
    }

    // MARK: - Helpers

    private func wordCount(_ text: String) -> String {
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        return "\(words) word\(words == 1 ? "" : "s")"
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let u = item as? URL {
                url = u
            }
            guard let fileURL = url else { return }
            Task { @MainActor in
                state.loadDroppedFile(fileURL)
            }
        }
        return true
    }
}
