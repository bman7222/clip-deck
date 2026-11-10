import SwiftData
import SwiftUI

/// The Subtitles tab: browse Subtitles/<Show>/<Episode>/ folders like the Files app.
/// Tapping a file previews its lines.
struct SubtitleBrowserView: View {
    let folder: String
    @State private var entries: [FileStore.Entry] = []
    private let store = FileStore.live

    var body: some View {
        List {
            Section {
                ForEach(entries) { entry in
                    if entry.isFolder {
                        NavigationLink {
                            SubtitleBrowserView(folder: entry.relativePath)
                                .navigationTitle(entry.name)
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            Label(entry.name, systemImage: "folder.fill")
                                .foregroundStyle(Theme.ink)
                        }
                        .accessibilityIdentifier("browser.folder.\(entry.name)")
                    } else {
                        NavigationLink {
                            SubtitlePreviewView(relativePath: entry.relativePath)
                        } label: {
                            Label(entry.name, systemImage: "doc.text")
                                .foregroundStyle(Theme.ink)
                        }
                        .accessibilityIdentifier("browser.file.\(entry.name)")
                    }
                }
            } footer: {
                Text("Also in the Files app: \(store.locationDescription(ofRelativePath: folder + "/x")).")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.shell)
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No subtitle files here",
                    systemImage: "folder",
                    description: Text("Subtitles you add to episodes are filed here by show and episode.")
                )
            }
        }
        .onAppear { entries = store.contents(ofRelativeFolder: folder) }
        .refreshable { entries = store.contents(ofRelativeFolder: folder) }
    }
}

private struct SubtitlePreviewView: View {
    let relativePath: String
    @State private var cues: [SubtitleCue] = []
    @State private var errorMessage: String?
    private let store = FileStore.live

    var body: some View {
        List {
            if let errorMessage {
                ErrorBanner(message: errorMessage)
                    .listRowBackground(Color.clear)
            }
            ForEach(cues) { cue in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                    Text(TimeFormat.clock(cue.startMs))
                        .font(.deckTime)
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 56, alignment: .leading)
                    Text(cue.text)
                        .font(.deckBody)
                        .foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle((relativePath as NSString).lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                cues = try SubtitleParser.parse(contentsOf: store.absoluteURL(relativePath))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Shown instead of the player when an episode's video file isn't where it should be.
struct MissingFileView: View {
    @Bindable var episode: Episode
    @Environment(\.modelContext) private var context
    @State private var isPicking = false
    @State private var errorMessage: String?
    @State private var relinked = false
    private let store = FileStore.live

    var body: some View {
        Group {
            if relinked {
                PlayerView(episode: episode)
            } else {
                ScrollView {
                    VStack(spacing: Spacing.l) {
                        ContentUnavailableView {
                            Label("Video file is missing", systemImage: "questionmark.folder")
                        } description: {
                            Text("Clip Deck expected “\(fileName)” in \(store.locationDescription(ofRelativePath: episode.videoPath)). It may have been moved, renamed or deleted in the Files app.")
                        } actions: {
                            Button("Choose the video again") { isPicking = true }
                                .buttonStyle(DeckPrimaryButtonStyle())
                                .accessibilityIdentifier("missing.relink")
                        }
                        if let errorMessage { ErrorBanner(message: errorMessage) }
                    }
                    .padding(Spacing.l)
                }
                .background(Theme.shell)
                .navigationTitle(episode.title)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: FileTypes.videos) { result in
            Task { await relink(result) }
        }
    }

    private var fileName: String { (episode.videoPath as NSString).lastPathComponent }

    private func relink(_ result: Result<URL, Error>) async {
        switch result {
        case .success(let url):
            do {
                try await store.importFile(from: url, toRelativePath: episode.videoPath)
                try? context.save()
                relinked = true
            } catch {
                errorMessage = "The video couldn't be copied: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = "The file couldn't be opened: \(error.localizedDescription)"
        }
    }
}
