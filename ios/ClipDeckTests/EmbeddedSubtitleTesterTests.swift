import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import ClipDeck

// T-005, written by loop-tester (round 1) against the public interfaces. Covers what the builders' tests don't:
// - `EmbeddedSubtitleTesterRuleTests`: the WebVTT packet shape FFmpeg really hands out, file-name limits and folder
//   containment for hostile track metadata;
// - `EmbeddedSubtitlePickerModelTests`: AC-6 on `VideoImportModel` (what the "Embedded subtitles" row binds to);
// - `EmbeddedSubtitleTimelineTesterTests`: AC-2/AC-5 measured against the converted MP4's own video clock.

// MARK: - Rules

@MainActor
struct EmbeddedSubtitleTesterRuleTests {
    /// FFmpeg n8.1 `matroska_parse_webvtt` (libavformat/matroskadec.c) copies only the cue payload into
    /// `pkt->data`; the identifier and settings lines go to AV_PKT_DATA_WEBVTT_IDENTIFIER / _SETTINGS side data.
    /// So a WebVTT packet is the payload, and every one of its lines is cue text.
    @Test func webVTTPacketsAreThePayloadAndKeepEveryLine() {
        let result = SubtitleFileWriter.subRip([
            SubtitleCuePacket(startMs: 1000, durationMs: 1000, text: "One\nTwo\nThree"),
            SubtitleCuePacket(startMs: 3000, durationMs: 1000, text: "Hello"),
            SubtitleCuePacket(startMs: 5000, durationMs: 1000, text: "Top\nBottom"),
        ], isWebVTT: true)
        #expect(result.cueCount == 3)
        let cues = SubtitleParser.parse(result.text, format: .srt)
        #expect(cues.map { $0.text } == ["One\nTwo\nThree", "Hello", "Top\nBottom"])
    }

    /// Track language and title come from the file. A name over 255 UTF-8 bytes can't be created on APFS, and the
    /// importer always extracts every text track, so one odd track would fail the whole import.
    @Test func subtitleFileNamesStayWithinTheFileSystemLimit() {
        let names = [
            ConversionPlan.subtitleFileName(number: 1, language: String(repeating: "x", count: 400), title: "Full", kind: .ass),
            ConversionPlan.subtitleFileName(number: 2, language: "jpn",
                                            title: String(repeating: "e\u{301}\u{302}\u{303}\u{304}", count: 100), kind: .subRip),
            ConversionPlan.subtitleFileName(number: 3, language: "jpn", title: String(repeating: "字", count: 200), kind: .subRip),
        ]
        for name in names {
            #expect(name.utf8.count <= 255, "\(name.utf8.count) bytes: \(name.prefix(40))…")
            #expect(name.hasSuffix(".ass") || name.hasSuffix(".srt"))
        }
    }

    /// Hostile metadata can't name a file outside the folder it is written to.
    @Test func trackMetadataCannotEscapeTheFolder() {
        let folder = URL(fileURLWithPath: "/tmp/Embedded", isDirectory: true)
        let titles: [String?] = [nil, "../../etc/passwd", "..", "/", "a/../../b", "..\\..\\x", ":", "\n..\n"]
        let languages: [String?] = [nil, "..", "../x", "/"]
        for title in titles {
            for language in languages {
                let name = ConversionPlan.subtitleFileName(number: 1, language: language, title: title, kind: .subRip)
                #expect(!name.contains("/"), "\(name)")
                #expect(!name.hasPrefix("."), "\(name)")
                let target = folder.appending(path: name)
                #expect(target.deletingLastPathComponent().standardizedFileURL.path == folder.standardizedFileURL.path,
                        "\(name) lands in \(target.path)")
            }
        }
    }
}

// MARK: - AC-6: the upload sheet's model

@MainActor
@Suite(.serialized)
struct EmbeddedSubtitlePickerModelTests {
    let root: URL
    let store: FileStore
    let temporaryFolder: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "EmbeddedSubtitlePickerModelTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        store = FileStore(documentsURL: root.appending(path: "Documents", directoryHint: .isDirectory),
                          libraryURL: root.appending(path: "Library", directoryHint: .isDirectory))
        temporaryFolder = root.appending(path: "tmp", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryFolder, withIntermediateDirectories: true)
        store.ensureFolders()
    }

    func makeModel() -> VideoImportModel {
        VideoImportModel(importer: EpisodeImporter(store: store, temporaryFolder: temporaryFolder, supportsAV1: false,
                                                   availableCapacity: { _ in 1 << 40 }))
    }

    func waitUntil(seconds: Double = 30, _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func anMKVWithTextTracksPreselectsTheDefaultAndSavesEveryTrack() async throws {
        let model = makeModel()
        model.pick(try MediaConverterTests.fixtureURL(MediaConverterTests.fixture1))
        try await waitUntil { model.canImport }
        try #require(model.canImport, "fixture 1 should be ready: \(model.videoError ?? "no error")")
        defer { model.clear() }
        let prepared = try #require(model.prepared)

        #expect(model.usableSubtitleTracks.map { $0.formatName } == ["SRT", "ASS"], "the row lists both text tracks")
        #expect(model.usableSubtitleTracks.map { $0.label } == ["jpn · SRT · SRT", "jpn · Full · ASS"])
        #expect(model.unusableSubtitleTracks.isEmpty)
        #expect(model.selectedSubtitle != nil, "a text track is preselected")
        #expect(model.selectedSubtitle == prepared.defaultSubtitleStreamIndex)
        #expect(model.options.embeddedSubtitleStreams == prepared.usableSubtitleStreamIndices)
        #expect(model.options.chosenSubtitleStream == model.selectedSubtitle)

        model.selectSubtitle(nil)
        #expect(model.options.chosenSubtitleStream == nil)
        #expect(model.options.embeddedSubtitleStreams == prepared.usableSubtitleStreamIndices, "None still saves every track")
        #expect(model.canImport)

        let ass = try #require(model.usableSubtitleTracks.last).streamIndex
        model.selectSubtitle(ass)
        #expect(model.options.chosenSubtitleStream == ass)
        #expect(model.canImport)

        model.clear()
        #expect(model.selectedSubtitle == nil)
        #expect(model.usableSubtitleTracks.isEmpty)
        #expect(model.options.embeddedSubtitleStreams.isEmpty)
    }

    @Test func anMKVWithoutTextTracksHidesTheRowAndChoosesNothing() async throws {
        let model = makeModel()
        model.pick(try MediaConverterTests.fixtureURL(MediaConverterTests.fixture4))
        try await waitUntil { model.canImport }
        try #require(model.canImport, "fixture 4 should be ready: \(model.videoError ?? "no error")")
        defer { model.clear() }

        #expect(model.usableSubtitleTracks.isEmpty, "the row is hidden")
        #expect(model.unusableSubtitleTracks.isEmpty)
        #expect(model.selectedSubtitle == nil)
        #expect(model.options == EpisodeImportOptions(audioStreamIndex: model.selectedAudio))
        #expect(model.prepared?.warnings.isEmpty == true, "and nothing is said")
    }
}

// MARK: - AC-2 / AC-5: the MP4's clock

@MainActor
@Suite(.serialized)
struct EmbeddedSubtitleTimelineTesterTests {
    /// Fixture 3's SRT cues are at 1.0, 3.0 and 5.0 s relative to the first video frame (all inputs start together,
    /// then `-output_ts_offset 1`). On the converted MP4, as AVFoundation plays it, each cue must be that far after
    /// the video's first media time: the subtitle file needs no offset.
    @Test func fixture3CueTimesMatchTheConvertedMP4sVideoClock() async throws {
        let source = try MediaConverterTests.fixtureURL(MediaConverterTests.fixture3)
        let probe = try await MediaProber.load(url: source)
        let plan = try ConversionPlan.make(probe: probe, supportsAV1: false,
                                           extractingSubtitleStreams: probe.subtitleTracks.map { $0.streamIndex })
        let folder = try MediaConverter.makeStagingFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let output = folder.appending(path: "Episode.mp4")
        let report = try await MediaConverter.convert(source: source, plan: plan, to: output)

        let file = try #require(report.subtitleFiles.first, "fixture 3's SRT track should be written")
        let cues = try SubtitleParser.parse(contentsOf: file.url)
        let video = try #require(try await AVURLAsset(url: output).loadTracks(withMediaType: .video).first)
        let videoStartMs = try await MediaConverterTests.firstMediaTime(of: video) * 1000
        #expect(videoStartMs > 900, "the MP4 keeps the 1 s start (no rebase): \(videoStartMs) ms")

        let offsets: [Double] = [1000, 3000, 5000]
        #expect(cues.count == offsets.count)
        for (cue, offset) in zip(cues, offsets) {
            let error = abs(Double(cue.startMs) - (videoStartMs + offset))
            #expect(error <= MediaConverterTests.frame * 1000,
                    "cue at \(cue.startMs) ms, expected \(videoStartMs + offset) ms on the MP4 clock")
        }
    }
}
