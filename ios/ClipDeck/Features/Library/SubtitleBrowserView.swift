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
/// "Choose the video again" goes through `EpisodeImporter` like the upload sheet: an MKV is converted (default
/// audio track) with the same progress and Cancel, and `videoPath` then points at the new file (spec J-6).
struct MissingFileView: View {
    @Bindable var episode: Episode
    @Environment(\.modelContext) private var context
    @State private var isPicking = false
    @State private var video = VideoImportModel()
    @State private var errorMessage: String?
    @State private var relinked = false
    /// Notes from a finished relink (e.g. damaged audio skipped), shown over the player.
    @State private var relinkWarnings: [String] = []
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
                                .disabled(video.isRunning || video.isPreparing)
                                .accessibilityIdentifier("missing.relink")
                        }
                        if video.isPreparing {
                            VideoPreparingRow(text: video.preparingText, identifier: "missing.preparing")
                                .padding(Spacing.m)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.panel, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                        }
                        if video.isRunning {
                            ImportProgressView(model: video, identifierPrefix: "missing")
                                .padding(Spacing.m)
                                .background(Theme.panel, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                        }
                        if let videoError = video.videoError {
                            ErrorBanner(message: videoError)
                                .accessibilityIdentifier("missing.videoError")
                        }
                        if let errorMessage {
                            // The file is still prepared after a failure, so offer to try again without re-picking.
                            ErrorBanner(
                                message: errorMessage,
                                actionTitle: video.canImport ? "Try again" : nil,
                                action: video.canImport ? { startRelink() } : nil
                            )
                            .accessibilityIdentifier("missing.error")
                        }
                    }
                    .padding(Spacing.l)
                }
                .background(Theme.shell)
                .navigationTitle(episode.title)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(video.isRunning)
            }
        }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: FileTypes.videos) { result in
            switch result {
            case .success(let url):
                errorMessage = nil
                // Relinking starts as soon as the file is checked (default audio track).
                video.pick(url) { startRelink() }
            case .failure(let error):
                errorMessage = "The file couldn't be opened: \(error.localizedDescription)"
            }
        }
        .alert("Video added", isPresented: showWarnings) {
            Button("OK") { relinkWarnings = [] }
                .accessibilityIdentifier("missing.warningsOK")
        } message: {
            Text(relinkWarnings.joined(separator: "\n\n"))
        }
        // Leaving (back, or the tab going away) stops a running relink and closes the picked file.
        .onDisappear { video.leave() }
    }

    private var fileName: String { (episode.videoPath as NSString).lastPathComponent }

    private var showWarnings: Binding<Bool> {
        Binding(
            get: { !relinkWarnings.isEmpty },
            set: { if !$0 { relinkWarnings = [] } }
        )
    }

    private func startRelink() {
        errorMessage = nil
        let episode = self.episode
        let context = self.context
        video.run({ importer, prepared, options, progress in
            try await importer.relink(episode, to: prepared, options: options, in: context, progress: progress)
        }, completion: { outcome in
            switch outcome {
            case .added(let result):
                relinkWarnings = result.warnings
                relinked = true
            case .cancelled:
                break
            case .failed(let message):
                errorMessage = message
            }
        })
    }
}
