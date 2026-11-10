import SwiftData
import SwiftUI

/// A show's episodes. Each row has a subtitle button to assign or change its subtitles.
struct ShowDetailView: View {
    @Bindable var show: Show
    @Environment(\.modelContext) private var context
    @State private var subtitleEpisode: Episode?
    @State private var episodeToDelete: Episode?

    private let store = FileStore.live

    var body: some View {
        List {
            Section {
                HStack(spacing: Spacing.l) {
                    DeckTile(glyph: DeckTile.glyph(for: show.name), hue: Theme.hue(show.colorIndex), size: 72)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(show.name)
                            .font(.deckTitle)
                            .foregroundStyle(Theme.ink)
                        Text(show.episodes.count == 1 ? "1 episode" : "\(show.episodes.count) episodes")
                            .font(.deckCallout)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .listRowBackground(Color.clear)
            }

            Section("Episodes") {
                ForEach(show.sortedEpisodes) { episode in
                    HStack(spacing: Spacing.m) {
                        NavigationLink(value: episode) {
                            EpisodeRow(episode: episode, hue: Theme.hue(show.colorIndex), store: store)
                        }
                        .accessibilityIdentifier("episode.row.\(episode.title)")
                        Button {
                            subtitleEpisode = episode
                        } label: {
                            Image(systemName: episode.subtitlePath == nil ? "captions.bubble" : "captions.bubble.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(episode.subtitlePath == nil ? Theme.inkSoft : Theme.accent)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Subtitles for \(episode.title)")
                        .accessibilityIdentifier("episode.subtitles.\(episode.title)")
                    }
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) { episodeToDelete = episode }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.shell)
        .navigationTitle(show.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $subtitleEpisode) { SubtitlePickerSheet(episode: $0) }
        .confirmationDialog(
            "Delete \(episodeToDelete?.title ?? "episode")?",
            isPresented: Binding(get: { episodeToDelete != nil }, set: { if !$0 { episodeToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete episode and video file", role: .destructive) { deleteEpisode() }
        } message: {
            Text("Subtitle files and cards you've made are kept.")
        }
    }

    private func deleteEpisode() {
        guard let episode = episodeToDelete else { return }
        store.deleteFile(episode.videoPath)
        context.delete(episode)
        try? context.save()
        episodeToDelete = nil
    }
}

private struct EpisodeRow: View {
    let episode: Episode
    let hue: Color
    let store: FileStore

    var body: some View {
        HStack(spacing: Spacing.m) {
            Text(episode.number.map(String.init) ?? "•")
                .font(.deckHeadline.monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(hue, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .font(.deckHeadline)
                    .foregroundStyle(Theme.ink)
                Text(statusText)
                    .font(.deckCaption)
                    .foregroundStyle(isMissing ? Theme.danger : Theme.inkSoft)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var isMissing: Bool { !store.exists(episode.videoPath) }

    private var statusText: String {
        if isMissing { return "Video file missing" }
        guard let path = episode.subtitlePath else { return "No subtitles yet" }
        return (path as NSString).lastPathComponent
    }
}
