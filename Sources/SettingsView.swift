import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            ProfilesSettingsView()
                .tabItem { Label("Profiles", systemImage: "person.crop.rectangle.stack") }
            StyleSettingsView()
                .tabItem { Label("Voice & Style", systemImage: "textformat") }
        }
        .frame(width: 540, height: 440)
        .environmentObject(state)
        .onAppear {
            // Menu bar apps open Settings behind other windows — pull it forward.
            SettingsWindowFocus.bringToFront()
        }
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var apiKeyField = ""
    @State private var keySaved = false
    @State private var importError: String?

    var body: some View {
        Form {
            Section("Anthropic API key") {
                SecureField("sk-ant-…", text: $apiKeyField)
                HStack {
                    Button("Save Key") {
                        state.settings.apiKey = apiKeyField.trimmingCharacters(in: .whitespacesAndNewlines)
                        keySaved = true
                    }
                    .disabled(apiKeyField.isEmpty)
                    if keySaved || state.settings.apiKey?.isEmpty == false {
                        Label("Key stored in Keychain", systemImage: "checkmark.seal")
                            .foregroundStyle(.green)
                            .font(.callout)
                    }
                }
                Text("Get a key at console.anthropic.com. It is stored in the macOS Keychain and only sent to api.anthropic.com.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Model") {
                Picker("Model", selection: Binding(
                    get: { state.settings.model },
                    set: { state.settings.model = $0 }
                )) {
                    ForEach(AppSettings.availableModels, id: \.id) { model in
                        Text(model.label).tag(model.id)
                    }
                }
            }

            Section("Notification sounds") {
                soundRow(
                    label: "Rewrite finished",
                    selection: Binding(
                        get: { state.settings.rewriteDoneSound },
                        set: { state.settings.rewriteDoneSound = $0 }
                    )
                )
                soundRow(
                    label: "File saved",
                    selection: Binding(
                        get: { state.settings.fileSavedSound },
                        set: { state.settings.fileSavedSound = $0 }
                    )
                )
                HStack {
                    Button("Add Custom Sound…") { importCustomSound() }
                    Text("Any audio file (mp3, m4a, wav…) — converted and trimmed to 29 s automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let importError {
                    Text(importError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Saved documents") {
                HStack {
                    Text(state.settings.outputFolderDisplayPath.isEmpty
                         ? "No folder chosen — you'll be asked where to save each time."
                         : state.settings.outputFolderDisplayPath)
                        .font(.callout)
                        .foregroundStyle(state.settings.outputFolderDisplayPath.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose Folder…") { chooseFolder() }
                    if !state.settings.outputFolderDisplayPath.isEmpty {
                        Button("Clear") { state.settings.clearOutputFolder() }
                    }
                }
                Text("Humanized versions of dropped files are saved here as “name-humanized.txt/.md”.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if let key = state.settings.apiKey { apiKeyField = key }
        }
    }

    private func soundRow(label: String, selection: Binding<String>) -> some View {
        HStack {
            Picker(label, selection: selection) {
                Text("None").tag("None")
                Text("Default").tag("Default")
                Divider()
                ForEach(SoundLibrary.systemSounds, id: \.self) { name in
                    Text(name).tag(name)
                }
                if !state.sounds.customSounds.isEmpty {
                    Divider()
                    ForEach(state.sounds.customSounds, id: \.self) { file in
                        Text(file.replacingOccurrences(of: ".wav", with: "") + " (custom)").tag(file)
                    }
                }
            }
            Button {
                state.sounds.preview(selection.wrappedValue)
            } label: {
                Image(systemName: "speaker.wave.2")
            }
            .buttonStyle(.borderless)
            .help("Preview")
            .disabled(selection.wrappedValue == "None")
        }
    }

    private func importCustomSound() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.audio]
        panel.prompt = "Import Sound"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let imported = try state.sounds.importSound(from: url)
            importError = nil
            state.sounds.preview(imported)
        } catch {
            importError = error.localizedDescription
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use This Folder"
        if panel.runModal() == .OK, let url = panel.url {
            state.settings.setOutputFolder(url)
        }
    }
}

// MARK: - Profiles

struct ProfilesSettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var selection: UUID?

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(state.settings.profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                HStack(spacing: 4) {
                    Button {
                        let profile = CustomProfile(name: "New Profile", prompt: "")
                        state.settings.profiles.append(profile)
                        selection = profile.id
                    } label: { Image(systemName: "plus") }
                    Button {
                        if let id = selection {
                            state.settings.profiles.removeAll { $0.id == id }
                            selection = nil
                        }
                    } label: { Image(systemName: "minus") }
                    .disabled(selection == nil)
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(6)
            }
            .frame(minWidth: 150, maxWidth: 200)

            if let index = state.settings.profiles.firstIndex(where: { $0.id == selection }) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Profile name", text: Binding(
                        get: { state.settings.profiles[index].name },
                        set: { state.settings.profiles[index].name = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    Text("Extra instructions sent with every rewrite while this profile is active:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: Binding(
                        get: { state.settings.profiles[index].prompt },
                        set: { state.settings.profiles[index].prompt = $0 }
                    ))
                    .font(.body)
                }
                .padding(10)
            } else {
                VStack {
                    Text("Profiles are custom prompts sent along with a rewrite — e.g. “Cover letter mode: confident, first person, no buzzwords.”")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Voice & Style

struct StyleSettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Voice calibration sample") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Paste 2–3 paragraphs of your own writing. Rewrites will match its rhythm and word choice instead of a generic voice.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: Binding(
                        get: { state.styleStore.voiceSample ?? "" },
                        set: { state.styleStore.voiceSample = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.body)
                    .frame(minHeight: 110)
                }
                .padding(4)
            }

            GroupBox("Learned style profile") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Built automatically from your “Teach My Style” feedback. You can edit it directly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: Binding(
                        get: { state.styleStore.styleProfile ?? "" },
                        set: { state.styleStore.styleProfile = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.body)
                    .frame(minHeight: 110)
                    HStack {
                        Spacer()
                        Button("Reset Profile", role: .destructive) {
                            state.styleStore.resetProfile()
                        }
                        .disabled((state.styleStore.styleProfile ?? "").isEmpty)
                    }
                }
                .padding(4)
            }
        }
        .padding(14)
    }
}
