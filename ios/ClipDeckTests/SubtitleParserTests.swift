import Foundation
import Testing
@testable import ClipDeck

@MainActor
struct SubtitleParserTests {
    @Test(arguments: [
        ("00:01:47,350", 107_350),
        ("01:00:00.000", 3_600_000),
        ("0:01:02.34", 62_340),   // ASS centiseconds
        ("01:02.5", 62_500),      // minutes:seconds
        ("00:00:01", 1_000),
    ])
    func parsesClockFormats(input: String, expected: Int) {
        #expect(SubtitleParser.parseClock(input) == expected)
    }

    @Test(arguments: ["", "abc", "1:2:3:4", "00:00:xx,000"])
    func rejectsBadClocks(input: String) {
        #expect(SubtitleParser.parseClock(input) == nil)
    }

    @Test func parsesSRTWithTagsAndCRLF() {
        let srt = "1\r\n00:00:01,000 --> 00:00:02,500\r\n<i>こんにちは</i>\r\n\r\n2\r\n00:00:03,000 --> 00:00:04,000 X1:10 X2:20\r\n{\\an8}二行目\r\nです\r\n"
        let cues = SubtitleParser.parse(srt, format: .srt)
        #expect(cues.count == 2)
        #expect(cues[0] == SubtitleCue(id: 0, startMs: 1_000, endMs: 2_500, text: "こんにちは"))
        #expect(cues[1].text == "二行目\nです")
        #expect(cues[1].startMs == 3_000)
    }

    @Test func srtWithoutBlankLineBetweenBlocks() {
        let srt = """
        1
        00:00:01,000 --> 00:00:02,000
        first
        2
        00:00:03,000 --> 00:00:04,000
        second
        """
        let cues = SubtitleParser.parse(srt, format: .srt)
        #expect(cues.map(\.text) == ["first", "second"])
    }

    @Test func parsesASSDialogueWithCommasAndOverrideTags() {
        let ass = """
        [Script Info]
        Title: Test

        [V4+ Styles]
        Format: Name, Fontname, Fontsize
        Style: Default,Arial,20

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:01:45.00,0:01:53.00,Default,,0,0,0,,{\\i1}待って、{\\i0}行かないで\\Nお願い
        Comment: 0,0:01:50.00,0:01:51.00,Default,,0,0,0,,this is a comment
        Dialogue: 0,0:01:53.00,0:02:00.00,Default,,0,0,0,,Hello, world
        Dialogue: 1,0:00:10.00,0:00:20.00,Sign,,0,0,0,,{\\p1}m 0 0 l 100 0 100 100{\\p0}
        """
        let cues = SubtitleParser.parse(ass, format: .ass)
        #expect(cues.count == 2)
        #expect(cues[0].startMs == 105_000)
        #expect(cues[0].endMs == 113_000)
        #expect(cues[0].text == "待って、行かないで\nお願い")
        #expect(cues[1].text == "Hello, world")
    }

    @Test func assHonoursCustomFormatOrder() {
        let ass = """
        [Events]
        Format: Start, End, Text
        Dialogue: 0:00:01.00,0:00:02.00,reordered
        """
        let cues = SubtitleParser.parse(ass, format: .ass)
        #expect(cues == [SubtitleCue(id: 0, startMs: 1_000, endMs: 2_000, text: "reordered")])
    }

    @Test func finalizeSortsAndDropsDuplicatesAndEmptyLines() {
        let raw: [SubtitleParser.RawCue] = [
            .init(startMs: 5_000, endMs: 6_000, text: "b"),
            .init(startMs: 1_000, endMs: 2_000, text: "a"),
            .init(startMs: 1_000, endMs: 2_000, text: "a"),
            .init(startMs: 3_000, endMs: 3_000, text: "zero length"),
            .init(startMs: 4_000, endMs: 4_500, text: ""),
        ]
        let cues = SubtitleParser.finalize(raw)
        #expect(cues.map(\.text) == ["a", "b"])
        #expect(cues.map(\.id) == [0, 1])
    }

    @Test func decodesUTF8BOMAndShiftJIS() throws {
        let bom = Data([0xEF, 0xBB, 0xBF]) + Data("1\n00:00:01,000 --> 00:00:02,000\nやあ\n".utf8)
        let fromBOM = try #require(SubtitleParser.decode(bom))
        #expect(SubtitleParser.parse(fromBOM, format: .srt).first?.text == "やあ")

        let sjis = try #require("1\n00:00:01,000 --> 00:00:02,000\n日本語\n".data(using: .shiftJIS))
        let fromSJIS = try #require(SubtitleParser.decode(sjis))
        #expect(SubtitleParser.parse(fromSJIS, format: .srt).first?.text == "日本語")
    }

    @Test func fileErrorsAreDescriptive() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let vtt = folder.appending(path: "a.vtt")
        try Data("WEBVTT".utf8).write(to: vtt)
        #expect(throws: SubtitleError.unsupportedFormat("vtt")) { try SubtitleParser.parse(contentsOf: vtt) }

        let empty = folder.appending(path: "empty.srt")
        try Data("no cues here".utf8).write(to: empty)
        #expect(throws: SubtitleError.empty("empty.srt")) { try SubtitleParser.parse(contentsOf: empty) }
    }
}
