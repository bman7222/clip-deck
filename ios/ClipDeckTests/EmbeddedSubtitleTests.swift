import Foundation
import SwiftData
import Testing
@testable import ClipDeck

// T-005: subtitles built into an MKV become ordinary .srt / .ass files. Three suites:
// - `EmbeddedSubtitleRuleTests`: the plan rules and the file writer, on values only (no FFmpeg, no files);
// - `EmbeddedSubtitleFixtureTests`: real conversions of fixtures 1, 3 and 4 with `MediaConverter`;
// - `EmbeddedSubtitleImportTests`: the same through `EpisodeImporter`.

// MARK: - Rules and writer

@MainActor
struct EmbeddedSubtitleRuleTests {
    static func sub(_ index: Int, _ codec: String, isText: Bool = true, isDefault: Bool = false,
                    language: String? = nil, title: String? = nil) -> MediaProbe.Subtitle {
        MediaProbe.Subtitle(streamIndex: index, codec: codec, language: language, title: title,
                            isDefault: isDefault, isText: isText)
    }

    static func probe(_ subtitles: [MediaProbe.Subtitle]) -> MediaProbe {
        ConversionPlanTests.probe(subtitles: subtitles)
    }

    static func cue(_ startMs: Int, _ durationMs: Int, _ text: String) -> SubtitleCuePacket {
        SubtitleCuePacket(startMs: startMs, durationMs: durationMs, text: text)
    }

    // MARK: Default choice (AC-4)

    @Test func defaultIsTheDefaultFlaggedTextTrack() {
        let probe = Self.probe([Self.sub(2, "subrip"), Self.sub(3, "ass", isDefault: true)])
        #expect(ConversionPlan.defaultSubtitleTrack(in: probe)?.streamIndex == 3)
    }

    @Test func defaultFallsBackToTheFirstTextTrack() {
        let probe = Self.probe([Self.sub(2, "subrip"), Self.sub(3, "ass")])
        #expect(ConversionPlan.defaultSubtitleTrack(in: probe)?.streamIndex == 2)
    }

    @Test func aDefaultFlaggedPictureTrackIsNotTheDefault() {
        let probe = Self.probe([
            Self.sub(2, "hdmv_pgs_subtitle", isText: false, isDefault: true),
            Self.sub(3, "subrip"),
            Self.sub(4, "ass"),
        ])
        #expect(ConversionPlan.defaultSubtitleTrack(in: probe)?.streamIndex == 3)
    }

    @Test func noDefaultForPictureOnlyOrNoSubtitles() throws {
        let pictures = Self.probe([
            Self.sub(2, "hdmv_pgs_subtitle", isText: false, isDefault: true),
            Self.sub(3, "dvd_subtitle", isText: false),
        ])
        #expect(ConversionPlan.defaultSubtitleTrack(in: pictures) == nil)
        #expect(ConversionPlan.defaultSubtitleTrack(in: Self.probe([])) == nil)

        // Neither case warns or plans an extraction.
        for probe in [pictures, Self.probe([])] {
            let plan = try ConversionPlan.make(probe: probe, supportsAV1: false,
                                               extractingSubtitleStreams: probe.subtitleTracks.map { $0.streamIndex })
            #expect(plan.warnings.isEmpty)
            #expect(plan.subtitles.isEmpty)
        }
    }

    @Test func aTextFormatWeCannotWriteIsUnusable() {
        let probe = Self.probe([Self.sub(2, "mov_text"), Self.sub(3, "usf")])
        #expect(ConversionPlan.defaultSubtitleTrack(in: probe) == nil)
        #expect(!ConversionPlan.isUsableSubtitle(Self.sub(2, "mov_text")))
        #expect(ConversionPlan.isUsableSubtitle(Self.sub(2, "webvtt")))
    }

    // MARK: Plan

    @Test func theDefaultPlanExtractsNothing() throws {
        let probe = Self.probe([Self.sub(2, "subrip"), Self.sub(3, "ass")])
        #expect(try ConversionPlan.make(probe: probe, supportsAV1: false).subtitles.isEmpty)
    }

    @Test func thePlanExtractsTheRequestedTextTracksInFileOrder() throws {
        let probe = Self.probe([
            Self.sub(2, "subrip", language: "eng", title: "Dialogue"),
            Self.sub(3, "ass", language: "jpn", title: "Full"),
            Self.sub(4, "hdmv_pgs_subtitle", isText: false, language: "eng"),
            Self.sub(5, "webvtt"),
        ])
        let plan = try ConversionPlan.make(probe: probe, supportsAV1: false, extractingSubtitleStreams: [5, 3, 4, 3])
        #expect(plan.warnings.isEmpty)
        #expect(plan.subtitles.map { $0.streamIndex } == [3, 5], "the picture track is skipped, each track once")
        #expect(plan.subtitles.map { $0.fileName } == ["2 jpn Full.ass", "4 Subtitles.srt"])
        #expect(plan.subtitles.map { $0.kind } == [.ass, .webVTT])
        #expect(plan.subtitles.map { $0.number } == [2, 4])
    }

    @Test func aStreamThatIsNotASubtitleTrackIsRefused() {
        let probe = Self.probe([Self.sub(2, "subrip")])
        do {
            _ = try ConversionPlan.make(probe: probe, supportsAV1: false, extractingSubtitleStreams: [9])
            Issue.record("expected .subtitleChoice")
        } catch {
            #expect((error as Error) as? UnsupportedMediaError == .subtitleChoice(9))
        }
    }

    @Test func subtitleFileNamesFollowNumberLanguageTitle() {
        #expect(ConversionPlan.subtitleFileName(number: 2, language: "jpn", title: "Signs", kind: .ass) == "2 jpn Signs.ass")
        #expect(ConversionPlan.subtitleFileName(number: 1, language: "und", title: nil, kind: .subRip) == "1 Subtitles.srt")
        #expect(ConversionPlan.subtitleFileName(number: 3, language: nil, title: "A/B: C", kind: .webVTT) == "3 A-B- C.srt")
        #expect(ConversionPlan.subtitleFileName(number: 4, language: "eng", title: "", kind: .subRip) == "4 eng.srt")
        let long = ConversionPlan.subtitleFileName(number: 1, language: nil, title: String(repeating: "x", count: 300), kind: .subRip)
        #expect(long.utf8.count <= ConversionPlan.maximumSubtitleFileNameBytes)
        let wide = ConversionPlan.subtitleFileName(number: 12, language: String(repeating: "x", count: 100),
                                                   title: String(repeating: "字", count: 100), kind: .ass)
        #expect(wide.utf8.count <= ConversionPlan.maximumSubtitleFileNameBytes)
        #expect(wide.hasPrefix("12 xxxxxxxxxxxxxxxx") && wide.hasSuffix(".ass"), "the language is capped at 16 characters")
        #expect(FileStore.safeName("A\nB\tC") == "A B C", "control characters become spaces")
        #expect(FileStore.safeName("Show: 1/2") == "Show- 1-2", "normal names are unchanged")
    }

    @Test func codecsMapToFileKinds() {
        #expect(ConversionPlan.SubtitleKind(codec: "subrip") == .subRip)
        #expect(ConversionPlan.SubtitleKind(codec: "text") == .subRip)
        #expect(ConversionPlan.SubtitleKind(codec: "webvtt") == .webVTT)
        #expect(ConversionPlan.SubtitleKind(codec: "ass") == .ass)
        #expect(ConversionPlan.SubtitleKind(codec: "ssa") == .ass)
        #expect(ConversionPlan.SubtitleKind(codec: "hdmv_pgs_subtitle") == nil)
        #expect(ConversionPlan.SubtitleKind.ass.fileExtension == "ass")
        #expect(ConversionPlan.SubtitleKind.webVTT.fileExtension == "srt")
    }

    // MARK: Clock

    @Test func clocks() {
        #expect(SubtitleFileWriter.srtClock(3_723_456) == "01:02:03,456")
        #expect(SubtitleFileWriter.srtClock(0) == "00:00:00,000")
        #expect(SubtitleFileWriter.srtClock(-5) == "00:00:00,000")
        #expect(SubtitleFileWriter.assClock(3_723_456) == "1:02:03.46")
        #expect(SubtitleFileWriter.assClock(1_000) == "0:00:01.00")
        #expect(SubtitleFileWriter.assClock(1_004) == "0:00:01.00")
        #expect(SubtitleFileWriter.assClock(1_005) == "0:00:01.01")
    }

    // MARK: SubRip

    @Test func writesSubRipCues() {
        let result = SubtitleFileWriter.subRip([
            Self.cue(3000, 0, "二"),
            Self.cue(1000, 1500, "こんにちは\r\n\r\n世界\r\n"),
            Self.cue(500, 1000, "   \n "),
        ], isWebVTT: false)
        #expect(result.cueCount == 2, "the blank cue is dropped")
        #expect(result.text == """
            1
            00:00:01,000 --> 00:00:02,500
            こんにちは
            世界

            2
            00:00:03,000 --> 00:00:05,000
            二


            """, "a missing duration shows for 2 s; blank lines inside a cue are removed; cues are in time order")
    }

    @Test func webVTTPacketsAreWrittenLikeSubRipWithEveryLine() {
        let result = SubtitleFileWriter.subRip([
            Self.cue(1000, 1000, "cue-1\nline:0\nHello"),
            Self.cue(3000, 1000, "\n\nNo id"),
            Self.cue(5000, 1000, "id\nsettings\nTwo\nlines"),
        ], isWebVTT: true)
        #expect(result.cueCount == 3)
        let cues = SubtitleParser.parse(result.text, format: .srt)
        // FFmpeg's demuxer already moved the WebVTT identifier and settings to side data, so every line here is cue
        // text and is kept; only blank lines are removed (they would end an SRT cue).
        #expect(cues.map { $0.text } == ["cue-1\nline:0\nHello", "No id", "id\nsettings\nTwo\nlines"])
    }

    // MARK: ASS

    static let header = """
        [Script Info]
        Title: Test
        ScriptType: v4.00+

        [V4+ Styles]
        Format: Name, Fontname
        Style: Default,Arial

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text

        """

    @Test func rebuildsAnASSFileFromTheHeaderAndPackets() {
        let result = SubtitleFileWriter.ass(header: Self.header, cues: [
            Self.cue(3000, 2000, "1,0,Default,,0,0,0,,二, と三"),
            Self.cue(1000, 2000, "0,1,Signs,Bob,5,6,7,Karaoke,一\\Nline"),
            Self.cue(9000, 2000, "2,0,Default"),
            Self.cue(8000, 2000, "3,0,Default,,0,0,0,,"),
        ])
        #expect(result.cueCount == 2, "a packet with too few fields or no text is dropped")
        let lines = result.text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(lines.filter { $0 == "[Events]" }.count == 1, "the CodecPrivate's own [Events] is replaced")
        #expect(lines.contains("Title: Test"))
        #expect(lines.contains("Style: Default,Arial"))
        #expect(lines.contains(SubtitleFileWriter.assEventsFormat))
        #expect(lines.filter { $0.hasPrefix("Dialogue:") } == [
            "Dialogue: 1,0:00:01.00,0:00:03.00,Signs,Bob,5,6,7,Karaoke,一\\Nline",
            "Dialogue: 0,0:00:03.00,0:00:05.00,Default,,0,0,0,,二, と三",
        ], "Dialogue lines follow ReadOrder, with the packet's start and end")
    }

    @Test func anASSTrackWithoutAHeaderGetsADefaultOne() {
        let result = SubtitleFileWriter.ass(header: "", cues: [Self.cue(0, 1000, "0,0,Default,,0,0,0,,Hi")])
        #expect(result.text.contains("[Script Info]"))
        #expect(result.text.contains("[V4+ Styles]"))
        #expect(result.text.contains("Style: Default,"))
        #expect(result.text.contains("Dialogue: 0,0:00:00.00,0:00:01.00,Default,,0,0,0,,Hi"))
    }

    // MARK: The existing parser reads what we write

    @Test func theSubtitleParserReadsTheWrittenSRT() {
        let packets = [
            Self.cue(1000, 1500, "こんにちは、世界。"),
            Self.cue(3000, 1500, "これはテストです。\nさようなら。"),
        ]
        let cues = SubtitleParser.parse(SubtitleFileWriter.subRip(packets, isWebVTT: false).text, format: .srt)
        #expect(cues.map { $0.startMs } == [1000, 3000])
        #expect(cues.map { $0.endMs } == [2500, 4500])
        #expect(cues.map { $0.text } == ["こんにちは、世界。", "これはテストです。\nさようなら。"])
    }

    @Test func theSubtitleParserReadsTheWrittenASS() {
        let packets = [
            Self.cue(1000, 1500, "0,0,Default,,0,0,0,,こんにちは、世界。"),
            Self.cue(3000, 1500, "1,0,Default,,0,0,0,,これは、テストです。\\Nさようなら。"),
        ]
        let cues = SubtitleParser.parse(SubtitleFileWriter.ass(header: Self.header, cues: packets).text, format: .ass)
        #expect(cues.map { $0.startMs } == [1000, 3000])
        #expect(cues.map { $0.endMs } == [2500, 4500])
        #expect(cues.map { $0.text } == ["こんにちは、世界。", "これは、テストです。\nさようなら。"])
    }

    // MARK: Collector

    @Test func aTrackWithoutCuesWritesNoFile() {
        let extraction = ConversionPlan.SubtitleExtraction(streamIndex: 2, codec: "subrip", kind: .subRip, language: nil,
                                                           title: nil, number: 1, fileName: "1 Subtitles.srt")
        var collector = SubtitleCollector(extraction: extraction, header: "")
        #expect(collector.file() == nil)
        collector.add(startMs: 0, durationMs: 1000, text: "  ")
        #expect(collector.file() == nil, "only blank text")
        collector.add(startMs: 0, durationMs: 1000, text: "Hi")
        #expect(collector.file()?.cueCount == 1)
    }

    @Test func anAbsurdlyLargeTrackIsDropped() {
        let extraction = ConversionPlan.SubtitleExtraction(streamIndex: 2, codec: "subrip", kind: .subRip, language: nil,
                                                           title: nil, number: 1, fileName: "1 Subtitles.srt")
        var collector = SubtitleCollector(extraction: extraction, header: "")
        collector.add(startMs: 0, durationMs: 1000, text: "Hi")
        collector.add(startMs: 1000, durationMs: 1000, text: String(repeating: "a", count: SubtitleCollector.maximumBytes))
        #expect(collector.isTooLarge)
        #expect(collector.file() == nil)
        collector.add(startMs: 2000, durationMs: 1000, text: "Later")
        #expect(collector.file() == nil, "stays dropped")
    }
}

// MARK: - Fixtures through the converter

@MainActor
@Suite(.serialized)
struct EmbeddedSubtitleFixtureTests {
    /// The cues of the SRT/ASS source in `scripts/make-test-media.sh`, before the source's start offset.
    struct SourceCue {
        let start: Int
        let end: Int
        let text: String
    }

    static let sourceCues = [
        SourceCue(start: 1000, end: 2500, text: "こんにちは、世界。"),
        SourceCue(start: 3000, end: 4500, text: "これはテストです。"),
        SourceCue(start: 5000, end: 6500, text: "さようなら。"),
    ]

    struct Extracted {
        let probe: MediaProbe
        let folder: URL
        let subtitles: URL
        let report: MediaConverter.Report

        /// Where the first video frame is on the source clock. The fixtures' cues are shifted by the same amount
        /// as the picture (fixture 3's 1.0 s offset, or a B-frame delay in fixture 1).
        var videoStartMs: Int { Int(((probe.video?.startSeconds ?? 0) * 1000).rounded()) }
    }

    /// Converts a fixture and extracts all of its usable subtitle tracks.
    static func extract(_ name: String) async throws -> Extracted {
        let source = try MediaConverterTests.fixtureURL(name)
        let probe = try await MediaProber.load(url: source)
        let usable = probe.subtitleTracks.filter { ConversionPlan.isUsableSubtitle($0) }.map { $0.streamIndex }
        let plan = try ConversionPlan.make(probe: probe, supportsAV1: false, extractingSubtitleStreams: usable)
        let folder = try MediaConverter.makeStagingFolder()
        let subtitles = folder.appending(path: "Embedded", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: subtitles, withIntermediateDirectories: true)
        let report = try await MediaConverter.convert(source: source, plan: plan, to: folder.appending(path: "Episode.mp4"),
                                                      subtitlesFolder: subtitles)
        return Extracted(probe: probe, folder: folder, subtitles: subtitles, report: report)
    }

    static func names(in folder: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []).sorted()
    }

    static func checkCues(_ cues: [SubtitleCue], shiftMs: Int, toleranceMs: Int, _ label: String) {
        #expect(cues.count == Self.sourceCues.count, "\(label): \(cues.count) cues")
        for (cue, expected) in zip(cues, Self.sourceCues) {
            #expect(cue.text == expected.text, "\(label): \(cue.text)")
            let startError = abs(cue.startMs - (expected.start + shiftMs))
            let endError = abs(cue.endMs - (expected.end + shiftMs))
            #expect(startError <= toleranceMs, "\(label) start \(cue.startMs) vs \(expected.start + shiftMs)")
            #expect(endError <= toleranceMs, "\(label) end \(cue.endMs) vs \(expected.end + shiftMs)")
        }
    }

    @Test func fixture1WritesItsSRTAndASSTracks() async throws {
        let extracted = try await Self.extract(MediaConverterTests.fixture1)
        defer { try? FileManager.default.removeItem(at: extracted.folder) }
        #expect(extracted.report.warnings.isEmpty, "\(extracted.report.warnings)")
        #expect(Self.names(in: extracted.subtitles) == ["1 jpn SRT.srt", "2 jpn Full.ass"])
        #expect(Self.names(in: extracted.folder) == ["Embedded", "Episode.mp4"], "nothing else is written")
        #expect(extracted.report.subtitleFiles.map { $0.cueCount } == [3, 3])

        let srt = try SubtitleParser.parse(contentsOf: extracted.subtitles.appending(path: "1 jpn SRT.srt"))
        Self.checkCues(srt, shiftMs: extracted.videoStartMs, toleranceMs: 10, "fixture 1 SRT")

        let assURL = extracted.subtitles.appending(path: "2 jpn Full.ass")
        let ass = try SubtitleParser.parse(contentsOf: assURL)
        Self.checkCues(ass, shiftMs: extracted.videoStartMs, toleranceMs: 10, "fixture 1 ASS")

        let assText = try String(contentsOf: assURL, encoding: .utf8)
        #expect(assText.contains("[Script Info]"))
        #expect(assText.contains("[V4+ Styles]"))
        #expect(assText.contains("Style: Default,Arial"), "the CodecPrivate styles are kept")
        #expect(assText.components(separatedBy: "[Events]").count == 2, "exactly one [Events] section")
        #expect(assText.contains(SubtitleFileWriter.assEventsFormat))
    }

    @Test func fixture3SubtitleTimesLineUpWithTheConvertedTimelineDespiteTheOffset() async throws {
        let extracted = try await Self.extract(MediaConverterTests.fixture3)
        defer { try? FileManager.default.removeItem(at: extracted.folder) }
        #expect(extracted.report.warnings.isEmpty, "\(extracted.report.warnings)")
        #expect(Self.names(in: extracted.subtitles) == ["1 jpn.srt"])
        #expect(extracted.videoStartMs >= 950, "the fixture starts 1.0 s in: \(extracted.videoStartMs) ms")

        let cues = try SubtitleParser.parse(contentsOf: extracted.subtitles.appending(path: "1 jpn.srt"))
        Self.checkCues(cues, shiftMs: extracted.videoStartMs, toleranceMs: 40, "fixture 3 SRT")
        // No rebase: the first cue is 1.0 s later than in the source file.
        #expect(cues.first.map { $0.startMs >= 1000 + 950 } == true, "first cue at \(cues.first?.startMs ?? -1) ms")
    }

    @Test func fixture4HasNoSubtitlesAndStillConvertsWithoutWarnings() async throws {
        let extracted = try await Self.extract(MediaConverterTests.fixture4)
        defer { try? FileManager.default.removeItem(at: extracted.folder) }
        #expect(extracted.probe.subtitleTracks.isEmpty)
        #expect(extracted.report.warnings.isEmpty)
        #expect(extracted.report.subtitleFiles.isEmpty)
        #expect(Self.names(in: extracted.subtitles).isEmpty)
    }

    @Test func aPlanWithoutSubtitlesWritesNoSubtitleFiles() async throws {
        let converted = try await MediaConverterTests.convert(MediaConverterTests.fixture1)
        defer { try? FileManager.default.removeItem(at: converted.folder) }
        #expect(converted.report.subtitleFiles.isEmpty)
        #expect(Self.names(in: converted.folder) == ["Episode.mp4"])
    }

    @Test func anExistingSubtitleFileIsNeverOverwritten() async throws {
        let source = try MediaConverterTests.fixtureURL(MediaConverterTests.fixture1)
        let probe = try await MediaProber.load(url: source)
        let plan = try ConversionPlan.make(probe: probe, supportsAV1: false,
                                           extractingSubtitleStreams: probe.subtitleTracks.map { $0.streamIndex })
        let folder = try MediaConverter.makeStagingFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let taken = folder.appending(path: plan.subtitles[1].fileName)
        try Data("mine".utf8).write(to: taken)

        do {
            _ = try await MediaConverter.convert(source: source, plan: plan, to: folder.appending(path: "Episode.mp4"))
            Issue.record("expected outputExists")
        } catch {
            if case .outputExists(let name)? = error as? MediaConversionError {
                #expect(name == plan.subtitles[1].fileName)
            } else {
                Issue.record("expected outputExists, got \(error)")
            }
        }
        #expect(try String(contentsOf: taken, encoding: .utf8) == "mine")
        #expect(Self.names(in: folder) == [plan.subtitles[1].fileName], "no video and no other subtitle file was written")
    }

    @Test func aMissingSubtitleFolderIsRefusedBeforeAnythingIsWritten() async throws {
        let source = try MediaConverterTests.fixtureURL(MediaConverterTests.fixture1)
        let probe = try await MediaProber.load(url: source)
        let plan = try ConversionPlan.make(probe: probe, supportsAV1: false,
                                           extractingSubtitleStreams: probe.subtitleTracks.map { $0.streamIndex })
        let folder = try MediaConverter.makeStagingFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        do {
            _ = try await MediaConverter.convert(source: source, plan: plan, to: folder.appending(path: "Episode.mp4"),
                                                 subtitlesFolder: folder.appending(path: "Nope", directoryHint: .isDirectory))
            Issue.record("expected outputFolderMissing")
        } catch {
            #expect(error is MediaConversionError, "got \(error)")
        }
        #expect(Self.names(in: folder).isEmpty)
    }
}

// MARK: - Through the importer

@MainActor
@Suite(.serialized)
struct EmbeddedSubtitleImportTests {
    let root: URL
    let store: FileStore
    let temporaryFolder: URL
    let container: ModelContainer

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "EmbeddedSubtitleImportTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        store = FileStore(documentsURL: root.appending(path: "Documents", directoryHint: .isDirectory),
                          libraryURL: root.appending(path: "Library", directoryHint: .isDirectory))
        temporaryFolder = root.appending(path: "tmp", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryFolder, withIntermediateDirectories: true)
        store.ensureFolders()
        container = try ModelContainer(for: Show.self, Episode.self, PendingCard.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    var context: ModelContext { container.mainContext }

    func makeImporter() -> EpisodeImporter {
        EpisodeImporter(store: store, temporaryFolder: temporaryFolder, supportsAV1: false, availableCapacity: { _ in 1 << 40 })
    }

    func files(in folder: URL) -> [String] {
        let fileManager = FileManager.default
        let subpaths = (try? fileManager.subpathsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        return subpaths.filter { subpath in
            var isFolder: ObjCBool = false
            let exists = fileManager.fileExists(atPath: folder.appending(path: subpath).path(percentEncoded: false),
                                                isDirectory: &isFolder)
            return exists && !isFolder.boolValue
        }.sorted()
    }

    var videoFiles: [String] { files(in: store.videosFolder) }
    var subtitleFiles: [String] { files(in: store.subtitlesFolder) }

    var stagingEntries: [String] {
        let path = EpisodeImporter.stagingRoot(in: temporaryFolder).path(percentEncoded: false)
        return (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
    }

    func prepareFixture1() async throws -> (EpisodeImporter, PreparedVideo) {
        let importer = makeImporter()
        let prepared = try await importer.prepare(MediaConverterTests.fixtureURL(MediaConverterTests.fixture1))
        return (importer, prepared)
    }

    static let folder = "Subtitles/MKV Show/Episode 1"
    static let details = NewEpisodeDetails(showName: "MKV Show", title: "Episode 1")

    // MARK: What the sheet sees

    @Test func preparedVideoListsTheTracksForThePicker() async throws {
        let (_, prepared) = try await prepareFixture1()
        defer { prepared.close() }
        let tracks = prepared.subtitleTracks
        #expect(tracks.map { $0.label } == ["jpn · SRT · SRT", "jpn · Full · ASS"])
        #expect(tracks.map { $0.formatName } == ["SRT", "ASS"])
        #expect(tracks.map { $0.isUsable } == [true, true])
        #expect(prepared.usableSubtitleStreamIndices == tracks.map { $0.streamIndex })
        let probe = try #require(prepared.probe)
        #expect(prepared.defaultSubtitleStreamIndex == ConversionPlan.defaultSubtitleTrack(in: probe)?.streamIndex)
        #expect(prepared.defaultSubtitleStreamIndex != nil)
        #expect(prepared.warnings.isEmpty)
    }

    @Test func aFileWithNoSubtitlesHasNoTracksAndNoDefault() async throws {
        let importer = makeImporter()
        let prepared = try await importer.prepare(MediaConverterTests.fixtureURL(MediaConverterTests.fixture4))
        defer { prepared.close() }
        #expect(prepared.subtitleTracks.isEmpty)
        #expect(prepared.usableSubtitleTracks.isEmpty)
        #expect(prepared.defaultSubtitleStreamIndex == nil)
        #expect(prepared.warnings.isEmpty)
    }

    @Test func anInvalidSubtitleChoiceIsRefusedByThePlan() async throws {
        let (_, prepared) = try await prepareFixture1()
        defer { prepared.close() }
        do {
            _ = try prepared.plan(for: EpisodeImportOptions(embeddedSubtitleStreams: [99]))
            Issue.record("expected an error")
        } catch {
            #expect(error as? EpisodeImportError == .unsupported(.subtitleChoice(99)))
        }
    }

    // MARK: Import

    @Test func importsEveryTextTrackAndChoosesTheDefault() async throws {
        let (importer, prepared) = try await prepareFixture1()
        let chosen = try #require(prepared.defaultSubtitleStreamIndex)
        let streams = prepared.usableSubtitleStreamIndices
        let options = EpisodeImportOptions(embeddedSubtitleStreams: streams, chosenSubtitleStream: chosen)

        let result = try await importer.importEpisode(prepared, as: Self.details, options: options, into: context)

        let expected = ["\(Self.folder)/1 jpn SRT.srt", "\(Self.folder)/2 jpn Full.ass"]
        #expect(videoFiles == ["MKV Show/Episode 1.mp4"])
        #expect(subtitleFiles == ["MKV Show/Episode 1/1 jpn SRT.srt", "MKV Show/Episode 1/2 jpn Full.ass"])
        let chosenPath = streams.firstIndex(of: chosen).map { expected[$0] }
        #expect(result.episode.subtitlePath == chosenPath)
        #expect(result.warnings.isEmpty, "\(result.warnings)")
        #expect(stagingEntries.isEmpty)
        for path in expected {
            let cues = try SubtitleParser.parse(contentsOf: store.absoluteURL(path))
            #expect(cues.count == 3, "\(path)")
            #expect(cues.first?.text == "こんにちは、世界。")
        }
        // They are what "Load different subtitles" lists.
        #expect(store.subtitleFiles(show: "MKV Show", episode: "Episode 1").map { $0.name }.sorted() == ["1 jpn SRT.srt", "2 jpn Full.ass"])
    }

    @Test func theDefaultOptionsExtractNothing() async throws {
        let (importer, prepared) = try await prepareFixture1()
        let result = try await importer.importEpisode(prepared, as: Self.details, into: context)
        #expect(result.episode.subtitlePath == nil)
        #expect(subtitleFiles.isEmpty)
        #expect(videoFiles == ["MKV Show/Episode 1.mp4"])
    }

    @Test func chosenNoneStillSavesTheTracksForLater() async throws {
        let (importer, prepared) = try await prepareFixture1()
        let options = EpisodeImportOptions(embeddedSubtitleStreams: prepared.usableSubtitleStreamIndices, chosenSubtitleStream: nil)
        let result = try await importer.importEpisode(prepared, as: Self.details, options: options, into: context)
        #expect(result.episode.subtitlePath == nil)
        #expect(subtitleFiles.count == 2)
    }

    @Test func onlyTheChosenTrackIsExtractedWhenNoneIsListed() async throws {
        let (importer, prepared) = try await prepareFixture1()
        let ass = try #require(prepared.subtitleTracks.last).streamIndex
        let result = try await importer.importEpisode(
            prepared, as: Self.details, options: EpisodeImportOptions(chosenSubtitleStream: ass), into: context)
        #expect(result.episode.subtitlePath == "\(Self.folder)/2 jpn Full.ass")
        #expect(subtitleFiles == ["MKV Show/Episode 1/2 jpn Full.ass"])
    }

    @Test func aSubtitleFileTheUserPickedWinsAndTheTracksAreStillSaved() async throws {
        let picked = root.appending(path: "Picked", directoryHint: .isDirectory).appending(path: "sample.srt")
        try FileManager.default.createDirectory(at: picked.deletingLastPathComponent(), withIntermediateDirectories: true)
        try TestMediaFactory.sampleSRT.write(to: picked, atomically: true, encoding: .utf8)

        let (importer, prepared) = try await prepareFixture1()
        let options = EpisodeImportOptions(embeddedSubtitleStreams: prepared.usableSubtitleStreamIndices,
                                           chosenSubtitleStream: prepared.defaultSubtitleStreamIndex)
        let result = try await importer.importEpisode(
            prepared,
            as: NewEpisodeDetails(showName: "MKV Show", title: "Episode 1", subtitleFile: picked),
            options: options, into: context)
        #expect(result.episode.subtitlePath == "\(Self.folder)/sample.srt")
        #expect(subtitleFiles == ["MKV Show/Episode 1/1 jpn SRT.srt", "MKV Show/Episode 1/2 jpn Full.ass", "MKV Show/Episode 1/sample.srt"])
    }

    @Test func aPickedFileWithTheSameNameAsATrackDoesNotCollideWithIt() async throws {
        let picked = root.appending(path: "Picked", directoryHint: .isDirectory).appending(path: "1 jpn SRT.srt")
        try FileManager.default.createDirectory(at: picked.deletingLastPathComponent(), withIntermediateDirectories: true)
        try TestMediaFactory.sampleSRT.write(to: picked, atomically: true, encoding: .utf8)

        let (importer, prepared) = try await prepareFixture1()
        let options = EpisodeImportOptions(embeddedSubtitleStreams: prepared.usableSubtitleStreamIndices)
        let result = try await importer.importEpisode(
            prepared,
            as: NewEpisodeDetails(showName: "MKV Show", title: "Episode 1", subtitleFile: picked),
            options: options, into: context)
        #expect(result.episode.subtitlePath == "\(Self.folder)/1 jpn SRT.srt", "the user's file keeps the plain name")
        #expect(subtitleFiles == ["MKV Show/Episode 1/1 jpn SRT (2).srt", "MKV Show/Episode 1/1 jpn SRT.srt", "MKV Show/Episode 1/2 jpn Full.ass"])
    }

    @Test func aSecondEpisodeNeverOverwritesExistingSubtitleFiles() async throws {
        let (importer, first) = try await prepareFixture1()
        let options = EpisodeImportOptions(embeddedSubtitleStreams: first.usableSubtitleStreamIndices)
        _ = try await importer.importEpisode(first, as: Self.details, options: options, into: context)
        let second = try await importer.prepare(MediaConverterTests.fixtureURL(MediaConverterTests.fixture1))
        // The same episode name again: the video becomes "Episode 1 (2).mp4"; the subtitles go to the same folder.
        _ = try await importer.importEpisode(second, as: Self.details, options: options, into: context)
        #expect(subtitleFiles == [
            "MKV Show/Episode 1/1 jpn SRT (2).srt", "MKV Show/Episode 1/1 jpn SRT.srt",
            "MKV Show/Episode 1/2 jpn Full (2).ass", "MKV Show/Episode 1/2 jpn Full.ass",
        ])
    }

    @Test func aFailedSaveRemovesTheExtractedSubtitleFilesToo() async throws {
        let (base, prepared) = try await prepareFixture1()
        var importer = base
        importer.save = { _ in throw SaveFailure() }
        let options = EpisodeImportOptions(embeddedSubtitleStreams: prepared.usableSubtitleStreamIndices,
                                           chosenSubtitleStream: prepared.defaultSubtitleStreamIndex)
        do {
            _ = try await importer.importEpisode(prepared, as: Self.details, options: options, into: context)
            Issue.record("expected saveFailed")
        } catch {
            #expect(error as? EpisodeImportError == .saveFailed("forced by the test"))
        }
        #expect(videoFiles.isEmpty)
        #expect(subtitleFiles.isEmpty, "left behind: \(subtitleFiles)")
        #expect(!FileManager.default.fileExists(atPath: store.absoluteURL("Subtitles/MKV Show").path(percentEncoded: false)))
        #expect(stagingEntries.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Episode>()).isEmpty)
        prepared.close()
    }

    @Test func aCancelledImportLeavesNoSubtitleFiles() async throws {
        let (importer, prepared) = try await prepareFixture1()
        defer { prepared.close() }
        let options = EpisodeImportOptions(embeddedSubtitleStreams: prepared.usableSubtitleStreamIndices)
        let details = Self.details
        let context = self.context
        let task = Task { @MainActor in
            _ = try await importer.importEpisode(prepared, as: details, options: options, into: context)
        }
        task.cancel()
        let result = await task.result
        if case .success = result {
            // The 8 s fixture can finish before the cancel lands; then the import is complete, not half done.
            #expect(subtitleFiles.count == 2)
        } else {
            #expect(videoFiles.isEmpty)
            #expect(subtitleFiles.isEmpty)
        }
        #expect(stagingEntries.isEmpty)
    }

    @Test func fixture4ImportsWithNoSubtitlesAndNoWarnings() async throws {
        let importer = makeImporter()
        let prepared = try await importer.prepare(MediaConverterTests.fixtureURL(MediaConverterTests.fixture4))
        let options = EpisodeImportOptions(embeddedSubtitleStreams: prepared.usableSubtitleStreamIndices,
                                           chosenSubtitleStream: prepared.defaultSubtitleStreamIndex)
        let result = try await importer.importEpisode(prepared, as: Self.details, options: options, into: context)
        #expect(result.warnings.isEmpty, "\(result.warnings)")
        #expect(result.episode.subtitlePath == nil)
        #expect(subtitleFiles.isEmpty)
        #expect(videoFiles == ["MKV Show/Episode 1.mp4"])
    }
}
