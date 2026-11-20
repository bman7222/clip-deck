import SwiftUI

/// Where cards go: AnkiConnect address, deck, note type, and which note field gets each part.
/// Lists come from AnkiConnect while connected and are remembered for offline use.
struct AnkiSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var status: ConnectionStatus = .idle
    @State private var installExpiry = InstallExpiry.currentExpiry()

    enum ConnectionStatus: Equatable {
        case idle, checking
        case connected(Int)
        case failed(String)
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    TextField("http://192.168.1.20:8765", text: $store.anki.url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("settings.url")
                    SecureField("API key (only if set in AnkiConnect)", text: $store.anki.apiKey)
                        .accessibilityIdentifier("settings.apiKey")
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            Text("Test connection")
                            Spacer()
                            statusView
                        }
                    }
                    .disabled(status == .checking)
                    .accessibilityIdentifier("settings.test")
                    if case .failed(let message) = status {
                        Text(message)
                            .font(.deckCallout)
                            .foregroundStyle(Theme.danger)
                            .accessibilityIdentifier("settings.error")
                    }
                } header: {
                    Text("AnkiConnect on your computer")
                } footer: {
                    Text("Use your computer's local IP address and port 8765. Testing also loads your decks and note types.")
                }

                Section("Cards go to") {
                    namePicker("Deck", selection: $store.anki.deckName, options: store.anki.cachedDecks, identifier: "settings.deck")
                    namePicker("Note type", selection: $store.anki.noteType, options: store.anki.cachedNoteTypes, identifier: "settings.noteType")
                        .onChange(of: store.anki.noteType) { _, _ in Task { await loadFields() } }
                    TextField("Tags (space separated)", text: $store.anki.tags)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    ForEach(CardField.allCases) { field in
                        fieldPicker(field)
                    }
                    Button("Use Lapis / Yomitan defaults") {
                        store.anki.fieldMap = AnkiSettings.defaultFieldMap
                    }
                } header: {
                    Text("Note fields")
                } footer: {
                    Text("Match these to the fields of your mining note type so cards from Clip Deck, asbplayer and Yomitan look the same.")
                }

                Section("Audio clip") {
                    Stepper("Start \(store.anki.audioPaddingStartMs) ms earlier", value: $store.anki.audioPaddingStartMs, in: 0...2_000, step: 100)
                    Stepper("End \(store.anki.audioPaddingEndMs) ms later", value: $store.anki.audioPaddingEndMs, in: 0...2_000, step: 100)
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Text("About and licences")
                    }
                    .accessibilityIdentifier("settings.about")
                    if let installExpiry {
                        Text(InstallExpiry.settingsText(expiry: installExpiry))
                            .font(.deckCallout)
                            .foregroundStyle(Theme.inkSoft)
                            .accessibilityIdentifier("settings.expiry")
                    }
                }

                Section("Set up AnkiConnect (once)") {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text("1. In Anki on your computer: Tools › Add-ons › Get Add-ons, code 2055492159.")
                        Text("2. Tools › Add-ons › AnkiConnect › Config: set \"webBindAddress\" to \"0.0.0.0\", then restart Anki.")
                        Text("3. Allow Anki through your computer's firewall on private networks.")
                        Text("4. Enter http://<your computer's IP>:8765 above and tap Test connection.")
                    }
                    .font(.deckCallout)
                    .foregroundStyle(Theme.inkSoft)
                }
            }
            .navigationTitle("Anki settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .idle:
            EmptyView()
        case .checking:
            ProgressView()
        case .connected(let version):
            Label("Connected (v\(version))", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.accent)
                .accessibilityIdentifier("settings.connected")
        case .failed(let message):
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Theme.danger)
                .accessibilityLabel(message)
        }
    }

    /// Picker when we have a list from Anki; free text otherwise (e.g. never connected yet).
    @ViewBuilder
    private func namePicker(_ title: String, selection: Binding<String>, options: [String], identifier: String) -> some View {
        if options.isEmpty {
            TextField(title, text: selection)
                .autocorrectionDisabled()
                .accessibilityIdentifier(identifier)
        } else {
            Picker(title, selection: selection) {
                if !options.contains(selection.wrappedValue) {
                    Text(selection.wrappedValue.isEmpty ? "Choose…" : selection.wrappedValue).tag(selection.wrappedValue)
                }
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .accessibilityIdentifier(identifier)
        }
    }

    @ViewBuilder
    private func fieldPicker(_ field: CardField) -> some View {
        let binding = Binding<String>(
            get: { store.anki.fieldMap[field.rawValue] ?? "" },
            set: { store.anki.fieldMap[field.rawValue] = $0 }
        )
        let options = store.anki.cachedFields[store.anki.noteType] ?? []
        if options.isEmpty {
            HStack {
                Text(field.label)
                TextField("Not used", text: binding)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        } else {
            Picker(field.label, selection: binding) {
                Text("Not used").tag("")
                if !binding.wrappedValue.isEmpty, !options.contains(binding.wrappedValue) {
                    Text("\(binding.wrappedValue) (not in this note type)").tag(binding.wrappedValue)
                }
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
        }
    }

    // MARK: AnkiConnect

    private func testConnection() async {
        guard let client = AnkiConnectClient(settings: store.anki) else {
            status = .failed(AnkiError.notConfigured.localizedDescription)
            return
        }
        status = .checking
        do {
            let version = try await client.version()
            store.anki.cachedDecks = try await client.deckNames().sorted()
            store.anki.cachedNoteTypes = try await client.modelNames().sorted()
            status = .connected(version)
            await loadFields()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func loadFields() async {
        let noteType = store.anki.noteType
        guard !noteType.isEmpty, let client = AnkiConnectClient(settings: store.anki),
              let fields = try? await client.modelFieldNames(noteType)
        else { return }
        store.anki.cachedFields[noteType] = fields
    }
}
