import Foundation
import Testing
@testable import ClipDeck

@MainActor
struct FileStoreTests {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    var store: FileStore { FileStore(documentsURL: root.appending(path: "Documents"), libraryURL: root.appending(path: "Library")) }

    @Test func safeNamesAndUniquePaths() throws {
        #expect(FileStore.safeName(" Re:Zero / S2 ") == "Re-Zero - S2")
        #expect(FileStore.safeName("...") == "Untitled")

        store.ensureFolders()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = store.uniquePath(folder: "Videos/Show", baseName: "Episode 1", fileExtension: "MP4")
        #expect(first == "Videos/Show/Episode 1.mp4")
        try FileManager.default.createDirectory(at: store.absoluteURL("Videos/Show"), withIntermediateDirectories: true)
        try Data().write(to: store.absoluteURL(first))
        #expect(store.uniquePath(folder: "Videos/Show", baseName: "Episode 1", fileExtension: "mp4") == "Videos/Show/Episode 1 (2).mp4")
    }

    @Test func describesMissingFileLocation() {
        #expect(store.locationDescription(ofRelativePath: "Subtitles/Attack on Titan/Episode 3/ep3.ass")
                == "On My iPhone › Clip Deck › Subtitles › Attack on Titan › Episode 3")
    }

    @Test func importsAndListsSubtitleFiles() async throws {
        store.ensureFolders()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "incoming.srt")
        try Data("1\n00:00:01,000 --> 00:00:02,000\nhi\n".utf8).write(to: source)
        let path = store.subtitleFolderPath(show: "Show", episode: "Ep 1") + "/incoming.srt"

        try await store.importFile(from: source, toRelativePath: path)

        #expect(store.exists(path))
        #expect(store.subtitleFiles(show: "Show", episode: "Ep 1").map(\.name) == ["incoming.srt"])
        let top = store.contents(ofRelativeFolder: "Subtitles")
        #expect(top == [FileStore.Entry(name: "Show", relativePath: "Subtitles/Show", isFolder: true)])
    }
}

/// Real AVFoundation clip extraction against a generated 6-second video.
@MainActor
@Suite(.serialized)
struct ClipExtractorTests {
    @Test func cutsExactAudioAndScreenshot() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let video = folder.appending(path: "sample.mp4")
        try await TestMediaFactory.makeVideo(at: video, seconds: 6)
        let videoDuration = try await ClipExtractor.durationMs(of: video)
        #expect(abs(videoDuration - 6_000) < 150)

        let audio = folder.appending(path: "clip.m4a")
        let image = folder.appending(path: "clip.jpg")
        let extractor = ClipExtractor(startPaddingMs: 0, endPaddingMs: 0)
        try await extractor.exportAudio(videoURL: video, range: ClipRange(startMs: 2_000, endMs: 4_000), to: audio)
        try await extractor.exportScreenshot(videoURL: video, atMs: 3_000, to: image)

        let clipDuration = try await ClipExtractor.durationMs(of: audio)
        #expect(abs(clipDuration - 2_000) < 150, "clip was \(clipDuration) ms")
        let imageSize = try #require(try FileManager.default.attributesOfItem(atPath: image.path(percentEncoded: false))[.size] as? Int)
        #expect(imageSize > 0)
    }

    @Test func paddingIsClampedToTheVideo() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let video = folder.appending(path: "sample.mp4")
        try await TestMediaFactory.makeVideo(at: video, seconds: 3)

        let audio = folder.appending(path: "clip.m4a")
        try await ClipExtractor(startPaddingMs: 1_000, endPaddingMs: 1_000)
            .exportAudio(videoURL: video, range: ClipRange(startMs: 500, endMs: 2_800), to: audio)
        let clipDuration = try await ClipExtractor.durationMs(of: audio)
        #expect(abs(clipDuration - 3_000) < 150, "clip was \(clipDuration) ms")
    }
}
