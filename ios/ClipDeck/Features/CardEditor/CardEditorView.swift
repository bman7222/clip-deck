@preconcurrency import AVFoundation
import SwiftData
import SwiftUI
import UIKit

/// Make a Card screen: check the clip, adjust its range (whole or partial lines), re-record,
/// edit the fields, and save the card to the offline sync queue.
struct CardEditorView: View {
    let draft: CardDraft
    let videoURL: URL
    let track: CueTrack
    let offsetMs: Int
    let videoDurationMs: Int
    let onSaved: (Int) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    @State private var range: ClipRange
    @State private var recordedRange: ClipRange
    @State private var values: [CardField: String]
    @State private var hasImage: Bool
    @State private var mediaVersion = 0
    @State private var isRecording = false
    @State private var errorMessage: String?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var savedCount = 0

    private let store = FileStore.live

    init(draft: CardDraft, videoURL: URL, track: CueTrack, offsetMs: Int, videoDurationMs: Int, onSaved: @escaping (Int) -> Void) {
        self.draft = draft
        self.videoURL = videoURL
        self.track = track
        self.offsetMs = offsetMs
        self.videoDurationMs = videoDurationMs
        self.onSaved = onSaved
        _range = State(initialValue: draft.range)
        _recordedRange = State(initialValue: draft.range)
        _hasImage = State(initialValue: draft.hasImage)
        _values = State(initialValue: [
            .sentence: draft.sentence,
            .source: CardDraft.sourceText(show: draft.showName, episode: draft.episodeTitle, startMs: draft.range.startMs),
        ])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    screenshot
                    clipPanel
                    if let errorMessage { ErrorBanner(message: errorMessage) }
                    fieldsPanel
                }
                .padding(Spacing.l)
            }
            .background(Theme.shell)
            .navigationTitle("Make a Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        audioPlayer?.stop()
                        CardDraft.discardMedia(id: draft.id, store: store)
                        dismiss()
                    }
                    .accessibilityIdentifier("card.discard")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save card", action: save)
                        .font(.deckHeadline)
                        .disabled(isRecording || needsRerecord)
                        .accessibilityIdentifier("card.save")
                }
            }
            .interactiveDismissDisabled()
            .sensoryFeedback(.success, trigger: savedCount)
            .task { playClip() }
        }
    }

    private var needsRerecord: Bool { range != recordedRange }

    // MARK: Sections

    @ViewBuilder
    private var screenshot: some View {
        if hasImage, let image = UIImage(contentsOfFile: store.cardMediaURL(draft.imageFileName).path(percentEncoded: false)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .id(mediaVersion)
                .accessibilityLabel("Screenshot from the clip")
        }
    }

    private var clipPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Button(action: playClip) {
                    Label("Play clip", systemImage: "play.fill")
                }
                .buttonStyle(DeckPrimaryButtonStyle())
                .disabled(isRecording || needsRerecord)
                .accessibilityIdentifier("card.playClip")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(TimeFormat.clock(range.startMs)) – \(TimeFormat.clock(range.endMs))")
                        .font(.deckHeadline.monospacedDigit())
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("card.range")
                    Text(String(format: "%.1f s", Double(range.durationMs) / 1000))
                        .font(.deckTime)
                        .foregroundStyle(Theme.inkSoft)
                }
            }

            nudgeRow(title: "Start", isStart: true)
            nudgeRow(title: "End", isStart: false)

            HStack(spacing: Spacing.s) {
                Button("Add previous line", systemImage: "arrow.left.to.line") {
                    range = ClipMath.extendToPreviousLine(range, track: track, offsetMs: offsetMs)
                }
                .accessibilityIdentifier("card.addPrevious")
                Spacer()
                Button("Add next line", systemImage: "arrow.right.to.line") {
                    range = ClipMath.extendToNextLine(range, track: track, offsetMs: offsetMs)
                }
                .accessibilityIdentifier("card.addNext")
            }
            .font(.deckCallout)

            if needsRerecord || isRecording {
                Button {
                    Task { await rerecord() }
                } label: {
                    Label(isRecording ? "Recording…" : "Re-record clip", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DeckPrimaryButtonStyle(tint: Theme.danger))
                .disabled(isRecording)
                .accessibilityIdentifier("card.rerecord")
                Text("The range changed. Re-record to update the audio, screenshot and sentence.")
                    .font(.deckCaption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(Spacing.l)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
    }

    private func nudgeRow(title: String, isStart: Bool) -> some View {
        HStack(spacing: Spacing.s) {
            Text(title)
                .font(.deckCallout)
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 44, alignment: .leading)
            ForEach([-500, -100, 100, 500], id: \.self) { delta in
                Button(String(format: "%+.1f", Double(delta) / 1000)) {
                    range = ClipMath.adjusted(
                        range,
                        startDeltaMs: isStart ? delta : 0,
                        endDeltaMs: isStart ? 0 : delta,
                        videoDurationMs: videoDurationMs
                    )
                }
                .font(.deckCaption.monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Theme.shell, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                .accessibilityLabel("\(title) \(delta > 0 ? "later" : "earlier") by \(abs(delta)) milliseconds")
            }
        }
    }

    private var fieldsPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ForEach(CardField.editable + [.source]) { field in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(field.label)
                            .font(.deckCallout)
                            .foregroundStyle(Theme.inkSoft)
                        if settings.anki.target(for: field) == nil {
                            Text("not sent to Anki")
                                .font(.deckCaption)
                                .foregroundStyle(Theme.inkSoft.opacity(0.7))
                        }
                    }
                    TextField(field.label, text: binding(for: field), axis: .vertical)
                        .font(field == .sentence ? .deckTitle : .deckBody)
                        .lineLimit(field == .sentence ? 2...6 : 1...4)
                        .padding(Spacing.m)
                        .background(Theme.shell, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                        .accessibilityIdentifier("card.field.\(field.rawValue)")
                }
            }
        }
        .padding(Spacing.l)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
    }

    private func binding(for field: CardField) -> Binding<String> {
        Binding(get: { values[field] ?? "" }, set: { values[field] = $0 })
    }

    // MARK: Actions

    private func playClip() {
        do {
            let player = try AVAudioPlayer(contentsOf: store.cardMediaURL(draft.audioFileName))
            audioPlayer = player
            player.play()
        } catch {
            errorMessage = "The clip's audio couldn't be played. Try Re-record clip."
        }
    }

    private func rerecord() async {
        isRecording = true
        errorMessage = nil
        audioPlayer?.stop()
        let extractor = ClipExtractor(
            startPaddingMs: settings.anki.audioPaddingStartMs,
            endPaddingMs: settings.anki.audioPaddingEndMs
        )
        do {
            hasImage = try await CardDraft.recordMedia(id: draft.id, videoURL: videoURL, range: range, extractor: extractor, store: store)
            recordedRange = range
            values[.sentence] = ClipMath.sentence(for: range, track: track, offsetMs: offsetMs)
            values[.source] = CardDraft.sourceText(show: draft.showName, episode: draft.episodeTitle, startMs: range.startMs)
            mediaVersion += 1
            isRecording = false
            playClip()
        } catch {
            isRecording = false
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        audioPlayer?.stop()
        var fields: [String: String] = [:]
        for (field, value) in values where !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fields[field.rawValue] = value
        }
        let card = PendingCard(
            id: draft.id,
            showName: draft.showName,
            episodeTitle: draft.episodeTitle,
            startMs: recordedRange.startMs,
            endMs: recordedRange.endMs,
            fields: fields,
            audioFileName: draft.audioFileName,
            imageFileName: hasImage ? draft.imageFileName : nil
        )
        context.insert(card)
        do {
            try context.save()
        } catch {
            errorMessage = "The card couldn't be saved: \(error.localizedDescription)"
            return
        }
        let waiting = (try? context.fetchCount(FetchDescriptor<PendingCard>(
            predicate: #Predicate { $0.statusRaw == "pending" || $0.statusRaw == "failed" }
        ))) ?? 1
        savedCount += 1
        onSaved(waiting)
        dismiss()
    }
}
