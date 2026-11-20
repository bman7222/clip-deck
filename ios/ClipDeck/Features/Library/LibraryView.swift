import SwiftData
import SwiftUI

/// Home: shows as rounded-square tiles, a Subtitles folder tab, Sync, and Upload.
struct LibraryView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case shows = "Shows"
        case subtitles = "Subtitles"
        var id: String { rawValue }
    }

    @Query(sort: \Show.name) private var shows: [Show]
    @Query(filter: #Predicate<PendingCard> { $0.statusRaw == "pending" || $0.statusRaw == "failed" })
    private var unsyncedCards: [PendingCard]

    @State private var tab: Tab = .shows
    @State private var showUpload = false
    @State private var showSync = false
    @State private var showSettings = false

    @Environment(\.scenePhase) private var scenePhase
    /// Read once per launch; the profile can't change while the app runs.
    @State private var expiry = InstallExpiry.currentExpiry()
    @State private var expiryStore = ExpiryReminderStore(
        defaults: LaunchFlags.isUITesting ? (UserDefaults(suiteName: "uiTesting") ?? .standard) : .standard)
    @State private var bannerNow = Date()
    @State private var showExpiryBanner = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showExpiryBanner, let expiry {
                    ExpiryBanner(expiry: expiry, now: bannerNow) {
                        expiryStore.recordDismissal()
                        showExpiryBanner = false
                    }
                }
                Picker("View", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.s)
                .accessibilityIdentifier("library.tabs")

                switch tab {
                case .shows: showsGrid
                case .subtitles: SubtitleBrowserView(folder: "Subtitles")
                }
            }
            .background(Theme.shell)
            .navigationTitle("Clip Deck")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape.fill") }
                        .accessibilityLabel("Anki settings")
                        .accessibilityIdentifier("library.settings")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showSync = true } label: { syncLabel }
                        .accessibilityLabel("Sync to Anki")
                        .accessibilityValue("\(unsyncedCards.count) waiting")
                        .accessibilityIdentifier("library.sync")
                    Button { showUpload = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Upload episode")
                        .accessibilityIdentifier("library.upload")
                }
            }
            .navigationDestination(for: Show.self) { ShowDetailView(show: $0) }
            .navigationDestination(for: Episode.self) { EpisodeDestination(episode: $0) }
            .sheet(isPresented: $showUpload) { UploadEpisodeView() }
            .sheet(isPresented: $showSync) { SyncView() }
            .sheet(isPresented: $showSettings) { AnkiSettingsView() }
            .onAppear(perform: refreshExpiryBanner)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshExpiryBanner() }
            }
        }
    }

    private func refreshExpiryBanner() {
        bannerNow = Date()
        showExpiryBanner = expiryStore.shouldShowBanner(now: bannerNow, expiry: expiry)
    }

    private var syncLabel: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "arrow.triangle.2.circlepath")
            if !unsyncedCards.isEmpty { PendingBadge(count: unsyncedCards.count) }
        }
    }

    @ViewBuilder
    private var showsGrid: some View {
        if shows.isEmpty {
            ContentUnavailableView {
                Label("Your library is empty", systemImage: "play.rectangle.on.rectangle")
            } description: {
                Text("Upload an episode (MP4, MOV, M4V or MKV) to start watching and making cards.")
            } actions: {
                Button("Upload episode") { showUpload = true }
                    .buttonStyle(DeckPrimaryButtonStyle())
                    .accessibilityIdentifier("library.emptyUpload")
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Spacing.l)], spacing: Spacing.xl) {
                    ForEach(shows) { show in
                        NavigationLink(value: show) {
                            ShowTileLabel(show: show)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("library.show.\(show.name)")
                    }
                }
                .padding(Spacing.l)
            }
        }
    }
}

private struct ShowTileLabel: View {
    let show: Show

    var body: some View {
        VStack(spacing: Spacing.s) {
            DeckTile(glyph: DeckTile.glyph(for: show.name), hue: Theme.hue(show.colorIndex))
            Text(show.name)
                .font(.deckCallout)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(show.episodes.count == 1 ? "1 episode" : "\(show.episodes.count) episodes")
                .font(.deckCaption)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Opens the player, or explains which file is missing and where it should be.
struct EpisodeDestination: View {
    let episode: Episode
    private let store = FileStore.live

    var body: some View {
        if store.exists(episode.videoPath) {
            PlayerView(episode: episode)
        } else {
            MissingFileView(episode: episode)
        }
    }
}
