import SwiftData
import SwiftUI

/// Sends every card made offline to desktop Anki through AnkiConnect, and shows each card's status.
struct SyncView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings
    @Query(sort: \PendingCard.createdAt, order: .reverse) private var cards: [PendingCard]

    @State private var isSyncing = false
    @State private var progress: (done: Int, total: Int) = (0, 0)
    @State private var summary: SyncSummary?
    @State private var showSettings = false

    private let store = FileStore.live

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Text(waiting.isEmpty ? "Everything is in Anki." : waitingText)
                            .font(.deckTitle)
                            .foregroundStyle(Theme.ink)
                            .accessibilityIdentifier("sync.waiting")
                        if let problem = settings.anki.setupProblem {
                            ErrorBanner(message: problem, actionTitle: "Open Anki settings") { showSettings = true }
                        } else {
                            Text("Open Anki on your computer and connect this phone to the same network, then sync.")
                                .font(.deckCallout)
                                .foregroundStyle(Theme.inkSoft)
                        }
                        Button {
                            Task { await sync() }
                        } label: {
                            Group {
                                if isSyncing {
                                    Label("Syncing \(min(progress.done + 1, progress.total)) of \(progress.total)…", systemImage: "arrow.triangle.2.circlepath")
                                } else {
                                    Label(waiting.count == 1 ? "Sync 1 card" : "Sync \(waiting.count) cards", systemImage: "arrow.triangle.2.circlepath")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DeckPrimaryButtonStyle())
                        .disabled(isSyncing || waiting.isEmpty || settings.anki.setupProblem != nil)
                        .accessibilityIdentifier("sync.start")
                        if let summary {
                            Text(summary.message)
                                .font(.deckCallout)
                                .foregroundStyle(summary.stoppedReason == nil && summary.failed == 0 ? Theme.ink : Theme.danger)
                                .accessibilityIdentifier("sync.summary")
                        }
                    }
                    .padding(.vertical, Spacing.s)
                }

                if !cards.isEmpty {
                    Section("Cards") {
                        ForEach(cards) { card in
                            CardStatusRow(card: card)
                                .swipeActions {
                                    if card.status != .synced {
                                        Button("Delete", systemImage: "trash", role: .destructive) { delete(card) }
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Sync to Anki")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.disabled(isSyncing)
                }
            }
            .sheet(isPresented: $showSettings) { AnkiSettingsView() }
            .interactiveDismissDisabled(isSyncing)
        }
    }

    private var waiting: [PendingCard] { cards.filter { $0.status.needsSync } }

    private var waitingText: String {
        waiting.count == 1 ? "1 card waiting to sync" : "\(waiting.count) cards waiting to sync"
    }

    private func sync() async {
        guard let client = AnkiConnectClient(settings: settings.anki) else {
            summary = SyncSummary(stoppedReason: AnkiError.notConfigured.localizedDescription)
            return
        }
        isSyncing = true
        summary = nil
        let syncer = CardSyncer(transport: client, settings: settings.anki, mediaFolder: store.cardMediaFolder)
        let result = await syncer.sync(cards) { done, total in
            progress = (done, total)
        }
        try? context.save()
        summary = result
        isSyncing = false
    }

    private func delete(_ card: PendingCard) {
        CardDraft.discardMedia(id: card.id, store: store)
        context.delete(card)
        try? context.save()
    }
}

private struct CardStatusRow: View {
    let card: PendingCard

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.fields[CardField.sentence.rawValue] ?? "(no sentence)")
                    .font(.deckBody)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text("\(card.showName) \(card.episodeTitle), \(TimeFormat.clock(card.startMs))")
                    .font(.deckCaption)
                    .foregroundStyle(Theme.inkSoft)
                if let error = card.lastError, card.status == .failed {
                    Text(error)
                        .font(.deckCaption)
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(label)
    }

    private var icon: String {
        switch card.status {
        case .pending: "clock.fill"
        case .synced: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        case .duplicate: "equal.circle.fill"
        }
    }

    private var color: Color {
        switch card.status {
        case .pending: Theme.pending
        case .synced: Theme.accent
        case .failed: Theme.danger
        case .duplicate: Theme.inkSoft
        }
    }

    private var label: String {
        switch card.status {
        case .pending: "Waiting to sync"
        case .synced: "In Anki"
        case .failed: "Failed"
        case .duplicate: "Already in Anki"
        }
    }
}
