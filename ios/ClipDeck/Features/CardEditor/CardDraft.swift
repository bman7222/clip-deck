import Foundation

/// A card being made: its clip range and starting text. Media is written straight to the
/// card media folder under names derived from `id`, so saving needs no copying.
struct CardDraft: Identifiable, Equatable {
    let id: UUID
    let showName: String
    let episodeTitle: String
    let range: ClipRange
    let sentence: String
    let hasImage: Bool

    var audioFileName: String { CardMediaNames.audio(for: id) }
    var imageFileName: String { CardMediaNames.image(for: id) }

    /// Cuts the audio clip and screenshot for `range`. Returns whether a screenshot was saved
    /// (audio is required; a missing screenshot is not fatal).
    static func recordMedia(id: UUID, videoURL: URL, range: ClipRange, extractor: ClipExtractor, store: FileStore) async throws -> Bool {
        try await extractor.exportAudio(
            videoURL: videoURL,
            range: range,
            to: store.cardMediaURL(CardMediaNames.audio(for: id))
        )
        do {
            try await extractor.exportScreenshot(
                videoURL: videoURL,
                atMs: range.midpointMs,
                to: store.cardMediaURL(CardMediaNames.image(for: id))
            )
            return true
        } catch {
            return false
        }
    }

    static func discardMedia(id: UUID, store: FileStore) {
        try? FileManager.default.removeItem(at: store.cardMediaURL(CardMediaNames.audio(for: id)))
        try? FileManager.default.removeItem(at: store.cardMediaURL(CardMediaNames.image(for: id)))
    }

    /// "Attack on Titan Episode 3 (1:45.2)"
    static func sourceText(show: String, episode: String, startMs: Int) -> String {
        [show, episode].filter { !$0.isEmpty }.joined(separator: " ") + " (\(TimeFormat.clock(startMs)))"
    }
}
