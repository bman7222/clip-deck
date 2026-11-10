import SwiftData
import SwiftUI

/// Assign (or change) an episode's subtitle file: pick one already stored for the episode,
/// or import a new one into its folder. Used from the episode list and "Load different subtitles".
struct SubtitlePickerSheet: View {
    @Bindable var episode: Episode
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var files: [FileStore.Entry] = []
    @State private var isImporting = false
    @State private var errorMessage: String?

    private let store = FileStore.live

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                Section {
                    if files.isEmpty {
                        Text("No subtitle files for this episode yet.")
                            .foregroundStyle(Theme.inkSoft)
                    }
                    ForEach(files) { file in
                        Button { choose(file.relativePath) } label: {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(Theme.inkSoft)
                                Text(file.name)
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                if file.relativePath == episode.subtitlePath {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.accent)
                                        .accessibilityLabel("In use")
                                }
                            }
                        }
                        .accessibilityIdentifier("subtitlePicker.file.\(file.name)")
                    }
                    if episode.subtitlePath != nil {
                        Button("Don't use subtitles", role: .destructive) { choose(nil) }
                    }
                } header: {
                    Text("Files in \(store.locationDescription(ofRelativePath: folder + "/x"))")
                        .textCase(nil)
                }

                Section {
                    Button("Import subtitle file…", systemImage: "square.and.arrow.down") { isImporting = true }
                        .accessibilityIdentifier("subtitlePicker.import")
                }
            }
            .navigationTitle("Subtitles for \(episode.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: FileTypes.subtitles) { result in
                Task { await importFile(result) }
            }
            .onAppear(perform: refresh)
        }
        .presentationDetents([.medium, .large])
    }

    private var showName: String { episode.show?.name ?? "Unsorted" }
    private var folder: String { store.subtitleFolderPath(show: showName, episode: episode.title) }

    private func refresh() {
        files = store.subtitleFiles(show: showName, episode: episode.title)
        // Keep showing the episode's file even if it lives elsewhere.
        if let current = episode.subtitlePath, !files.contains(where: { $0.relativePath == current }), store.exists(current) {
            files.insert(FileStore.Entry(name: (current as NSString).lastPathComponent, relativePath: current, isFolder: false), at: 0)
        }
    }

    private func choose(_ path: String?) {
        episode.subtitlePath = path
        try? context.save()
        errorMessage = nil
    }

    private func importFile(_ result: Result<URL, Error>) async {
        switch result {
        case .success(let url):
            guard SubtitleFormat(fileExtension: url.pathExtension) != nil else {
                errorMessage = SubtitleError.unsupportedFormat(url.pathExtension).localizedDescription
                return
            }
            let path = "\(folder)/\(FileStore.safeName(url.lastPathComponent))"
            do {
                try await store.importFile(from: url, toRelativePath: path)
                // Validate now so a broken file is reported here, not in the player.
                _ = try SubtitleParser.parse(contentsOf: store.absoluteURL(path))
                choose(path)
                refresh()
            } catch {
                errorMessage = error.localizedDescription
                refresh()
            }
        case .failure(let error):
            errorMessage = "The file couldn't be opened: \(error.localizedDescription)"
        }
    }
}
