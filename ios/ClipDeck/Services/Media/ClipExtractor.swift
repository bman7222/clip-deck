@preconcurrency import AVFoundation
import UIKit

enum ClipExtractorError: LocalizedError {
    case noAudioTrack
    case exportUnavailable
    case exportFailed(String)
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .noAudioTrack: "This video has no audio track, so there's nothing to record."
        case .exportUnavailable: "This video's audio format can't be exported on this device."
        case .exportFailed(let reason): "Recording the clip failed: \(reason)"
        case .imageEncodingFailed: "The screenshot couldn't be saved."
        }
    }
}

/// Cuts card media straight from the video file: exact, faster than real time, and works offline.
struct ClipExtractor {
    var startPaddingMs: Int = 0
    var endPaddingMs: Int = 500

    /// Writes the audio of `range` (plus padding) to an .m4a file.
    func exportAudio(videoURL: URL, range: ClipRange, to outputURL: URL) async throws {
        let asset = AVURLAsset(url: videoURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else { throw ClipExtractorError.noAudioTrack }
        let duration = try await asset.load(.duration)
        let durationMs = Int((duration.seconds * 1000).rounded())

        let start = max(0, range.startMs - startPaddingMs)
        let end = min(durationMs, range.endMs + endPaddingMs)
        guard end > start else { throw ClipExtractorError.exportFailed("The clip is outside the video.") }

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ClipExtractorError.exportUnavailable
        }
        try? FileManager.default.removeItem(at: outputURL)
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        session.outputURL = outputURL
        session.outputFileType = .m4a
        session.timeRange = CMTimeRange(
            start: CMTime(value: CMTimeValue(start), timescale: 1000),
            end: CMTime(value: CMTimeValue(end), timescale: 1000)
        )
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { continuation.resume() }
        }
        guard session.status == .completed else {
            throw ClipExtractorError.exportFailed(session.error?.localizedDescription ?? "Unknown error")
        }
    }

    /// Saves a JPEG of the frame at `atMs` (longest side at most 1280 px).
    func exportScreenshot(videoURL: URL, atMs: Int, to outputURL: URL) async throws {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 1280)
        generator.requestedTimeToleranceBefore = CMTime(value: 100, timescale: 1000)
        generator.requestedTimeToleranceAfter = CMTime(value: 100, timescale: 1000)
        let (cgImage, _) = try await generator.image(at: CMTime(value: CMTimeValue(atMs), timescale: 1000))
        guard let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.8) else {
            throw ClipExtractorError.imageEncodingFailed
        }
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: outputURL, options: .atomic)
    }

    /// Duration of a media file in milliseconds (used by tests and the editor).
    static func durationMs(of url: URL) async throws -> Int {
        let duration = try await AVURLAsset(url: url).load(.duration)
        return Int((duration.seconds * 1000).rounded())
    }
}

/// Stable media file names for a card, so re-syncing never creates duplicate media in Anki.
enum CardMediaNames {
    static func audio(for id: UUID) -> String { "clipdeck_\(id.uuidString.lowercased()).m4a" }
    static func image(for id: UUID) -> String { "clipdeck_\(id.uuidString.lowercased()).jpg" }
}
