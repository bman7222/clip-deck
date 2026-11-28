import SwiftUI
import UniformTypeIdentifiers

/// Library › Dictionaries: the installed list (drag to reorder: the order is the priority), the enable switch, swipe to
/// delete, Import from Files, the JMdict download, and the sources.
struct DictionariesView: View {
    @Environment(DictionaryManagerModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isPicking = false
    @State private var editMode = EditMode.inactive
    @State private var pendingDelete: DictionaryInfo?

    var body: some View {
        NavigationStack {
            List {
                if let message = model.errorMessage {
                    ErrorBanner(message: message)
                        .accessibilityIdentifier("dictionaries.error")
                        .listRowBackground(Color.clear)
                }
                if model.phase != .idle { progressSection }
                Section("Installed") {
                    if model.dictionaries.isEmpty {
                        Text("No dictionaries yet. Import a Yomitan dictionary (.zip) from Files, or download JMdict English below.")
                            .font(.deckCallout)
                            .foregroundStyle(Theme.inkSoft)
                            .accessibilityIdentifier("dictionaries.empty")
                    }
                    ForEach(model.dictionaries) { row($0) }
                        .onMove { model.move(fromOffsets: $0, toOffset: $1) }
                }
                Section {
                    Button { isPicking = true } label: { Label("Import from Files", systemImage: "folder") }
                        .accessibilityIdentifier("dictionaries.import")
                    Button { Task { await model.downloadJMdict() } } label: {
                        Label("Download JMdict English", systemImage: "arrow.down.circle")
                    }
                    .accessibilityIdentifier("dictionaries.downloadJMdict")
                } footer: {
                    Text("The download is about 16 MB and is the only thing here that uses the network. Lookups work offline.")
                }
                .disabled(model.phase != .idle)
                Section("Sources") { DictionarySourcesContent(dictionaries: model.dictionaries) }
            }
            .accessibilityIdentifier("dictionaries.sheet")
            .background(Theme.shell)
            .navigationTitle("Dictionaries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("dictionaries.done")
                }
                if model.dictionaries.count > 1 {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(editMode.isEditing ? "Stop reordering" : "Reorder") {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                        .accessibilityIdentifier("dictionaries.reorder")
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .fileImporter(isPresented: $isPicking, allowedContentTypes: [.zip]) { result in
                switch result {
                case .success(let url): Task { await model.importFile(url) }
                case .failure(let error): model.errorMessage = "The file couldn't be opened: \(error.localizedDescription)"
                }
            }
            .confirmationDialog("Delete this dictionary?", isPresented: deleteDialog, titleVisibility: .visible,
                                presenting: pendingDelete) { dictionary in
                Button("Delete dictionary", role: .destructive) { model.delete(dictionary.id) }
                    .accessibilityIdentifier("dictionaries.confirmDelete")
            } message: { dictionary in
                Text("\u{201C}\(dictionary.title)\u{201D} is removed from this phone. You can import it again later.")
            }
            .task { await model.reload() }
        }
    }

    private var deleteDialog: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private var progressSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                    Text(model.progressText)
                        .font(.deckHeadline)
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("dictionaries.progress")
                    Spacer(minLength: Spacing.s)
                    Button("Cancel", role: .destructive) { model.cancel() }
                        .font(.deckHeadline)
                        .foregroundStyle(Theme.danger)
                        .buttonStyle(.borderless)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("dictionaries.cancel")
                }
                if let value = model.progress {
                    ProgressView(value: value).tint(Theme.accent).accessibilityHidden(true)
                } else {
                    ProgressView().accessibilityHidden(true)
                }
                Text("Keep Clip Deck open until it finishes.")
                    .font(.deckCaption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private func row(_ dictionary: DictionaryInfo) -> some View {
        HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(dictionary.title)
                    .font(.deckHeadline)
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("dictionaries.title.\(dictionary.id)")
                Text(dictionary.summary)
                    .font(.deckCaption)
                    .foregroundStyle(Theme.inkSoft)
                    .accessibilityIdentifier("dictionaries.detail.\(dictionary.id)")
            }
            .opacity(dictionary.enabled ? 1 : 0.55)
            Spacer(minLength: Spacing.s)
            Toggle("Use \(dictionary.title)", isOn: Binding(
                get: { dictionary.enabled },
                set: { model.setEnabled(dictionary.id, $0) }))
                .labelsHidden()
                .accessibilityIdentifier("dictionaries.enabled.\(dictionary.id)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dictionaries.row.\(dictionary.id)")
        .accessibilityAction(named: "Move up") { model.move(dictionary.id, by: -1) }
        .accessibilityAction(named: "Move down") { model.move(dictionary.id, by: 1) }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { pendingDelete = dictionary } label: { Label("Delete", systemImage: "trash") }
                .accessibilityIdentifier("dictionaries.delete.\(dictionary.id)")
        }
    }
}

/// The EDRDG attribution and each installed dictionary's own, as the rows of a List section.
struct DictionarySourcesContent: View {
    let dictionaries: [DictionaryInfo]

    private static let projectURL = URL(string: "https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project")!
    private static let licenceURL = URL(string: "https://www.edrdg.org/edrdg/licence.html")!
    private static let ccURL = URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!
    private static let converterURL = URL(string: "https://github.com/yomidevs/jmdict-yomitan")!

    var body: some View {
        Text("JMdict English uses the JMdict/EDICT dictionary files. They are the property of the Electronic Dictionary Research and Development Group (EDRDG) and are used in conformance with the Group's licence. They are licensed under the Creative Commons Attribution-ShareAlike Licence (CC BY-SA 4.0).")
            .font(.deckCallout)
            .foregroundStyle(Theme.ink)
            .accessibilityIdentifier("dictionaries.sources")
        Link("JMdict-EDICT Dictionary Project", destination: Self.projectURL)
            .accessibilityIdentifier("dictionaries.link.project")
        Link("EDRDG licence", destination: Self.licenceURL)
            .accessibilityIdentifier("dictionaries.link.licence")
        Link("CC BY-SA 4.0", destination: Self.ccURL)
            .accessibilityIdentifier("dictionaries.link.cc")
        Link("JMdict for Yomitan (the download)", destination: Self.converterURL)
            .accessibilityIdentifier("dictionaries.link.converter")
        ForEach(dictionaries.filter { !$0.attribution.isEmpty }) { dictionary in
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(dictionary.title).font(.deckHeadline).foregroundStyle(Theme.ink)
                Text(dictionary.attribution)
                    .font(.deckCaption)
                    .foregroundStyle(Theme.inkSoft)
                    .textSelection(.enabled)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("dictionaries.attribution.\(dictionary.id)")
        }
    }
}

/// Settings › About and licences › Dictionary sources.
struct DictionarySourcesView: View {
    @Environment(DictionaryManagerModel.self) private var model

    var body: some View {
        List {
            Section("Sources") { DictionarySourcesContent(dictionaries: model.dictionaries) }
        }
        .navigationTitle("Dictionary sources")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.shell)
        .task { await model.reload() }
    }
}
