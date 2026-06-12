import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @EnvironmentObject private var state: AppState
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            inputSection
            actionRow
            outputSection
            if case .failed(let message) = state.phase {
                Text(message)
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
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit Humanizer")
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Input")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let file = state.sourceFileURL {
                    Text("· \(file.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !state.inputText.isEmpty {
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
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(state.isWorking || state.inputText.isEmpty)

            Button("Humanize Clipboard") {
                state.humanizeClipboard()
            }
            .disabled(state.isWorking)

            Spacer()

            if state.isWorking {
                ProgressView()
                    .controlSize(.small)
                Button("Cancel") { state.cancel() }
                    .buttonStyle(.borderless)
            }
        }
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Output")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !state.statusLine.isEmpty {
                    Text(state.statusLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            TextEditor(text: $state.outputText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(minHeight: 140, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

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
