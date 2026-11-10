import Testing
@testable import ClipDeck

@MainActor
struct ClipMathTests {
    /// The example from the spec: line 1 is 1:45–1:53, line 2 is 1:53–2:00.
    let track = CueTrack(cues: [
        SubtitleCue(id: 0, startMs: 100_000, endMs: 105_000, text: "前の行"),
        SubtitleCue(id: 1, startMs: 105_000, endMs: 113_000, text: "一行目"),
        SubtitleCue(id: 2, startMs: 113_000, endMs: 120_000, text: "二行目"),
        SubtitleCue(id: 3, startMs: 125_000, endMs: 130_000, text: "三行目"),
    ])

    @Test func findsCueOnScreen() {
        #expect(track.indexOfCue(at: 107_000) == 1)   // 1:47 is inside 1:45–1:53
        #expect(track.indexOfCue(at: 113_000) == 2)   // boundary belongs to the next line
        #expect(track.indexOfCue(at: 121_000) == nil) // gap
        #expect(track.indexOfCue(at: 50_000) == nil)  // before the first line
        #expect(track.lastIndex(startingAtOrBefore: 121_000) == 2)
    }

    @Test func overlappingCuesPreferLatestStart() {
        let overlapping = CueTrack(cues: [
            SubtitleCue(id: 0, startMs: 0, endMs: 10_000, text: "long sign"),
            SubtitleCue(id: 1, startMs: 2_000, endMs: 3_000, text: "dialogue"),
        ])
        #expect(overlapping.indexOfCue(at: 2_500) == 1)
        #expect(overlapping.indexOfCue(at: 5_000) == 0)
    }

    @Test func offsetShiftsTheClipRange() {
        let range = ClipMath.range(of: track.cues[1], offsetMs: 300)
        #expect(range == ClipRange(startMs: 105_300, endMs: 113_300))
    }

    @Test func sentenceIncludesPartiallyCoveredLines() {
        // 1:45 → 1:55 covers all of line 1 and part of line 2.
        let range = ClipRange(startMs: 105_000, endMs: 115_000)
        #expect(ClipMath.sentence(for: range, track: track, offsetMs: 0) == "一行目\n二行目")
        // Touching a boundary exactly doesn't pull in the neighbour.
        #expect(ClipMath.sentence(for: ClipRange(startMs: 105_000, endMs: 113_000), track: track, offsetMs: 0) == "一行目")
    }

    @Test func extendToNextAndPreviousLine() {
        let line1 = ClipRange(startMs: 105_000, endMs: 113_000)
        #expect(ClipMath.extendToNextLine(line1, track: track, offsetMs: 0) == ClipRange(startMs: 105_000, endMs: 120_000))
        #expect(ClipMath.extendToPreviousLine(line1, track: track, offsetMs: 0) == ClipRange(startMs: 100_000, endMs: 113_000))

        // A partial end (1:55, inside line 2) extends to the end of line 2.
        let partial = ClipRange(startMs: 105_000, endMs: 115_000)
        #expect(ClipMath.extendToNextLine(partial, track: track, offsetMs: 0).endMs == 120_000)

        // Nothing before the first line: unchanged.
        let first = ClipRange(startMs: 100_000, endMs: 105_000)
        #expect(ClipMath.extendToPreviousLine(first, track: track, offsetMs: 0) == first)
    }

    @Test func adjustClampsAndKeepsMinimumLength() {
        let range = ClipRange(startMs: 1_000, endMs: 2_000)
        #expect(ClipMath.adjusted(range, startDeltaMs: -5_000, videoDurationMs: 10_000).startMs == 0)
        #expect(ClipMath.adjusted(range, endDeltaMs: 20_000, videoDurationMs: 10_000).endMs == 10_000)
        let squeezed = ClipMath.adjusted(range, startDeltaMs: 1_000, videoDurationMs: 10_000)
        #expect(squeezed.durationMs == ClipMath.minimumDurationMs)
        #expect(squeezed.endMs == 2_000)
    }

    @Test func formatsTimes() {
        #expect(TimeFormat.clock(107_250) == "1:47.2")
        #expect(TimeFormat.clock(3_723_400) == "1:02:03.4")
        #expect(TimeFormat.offset(300) == "+0.3 s")
        #expect(TimeFormat.offset(-1_200) == "−1.2 s")
        #expect(TimeFormat.offset(0) == "0.0 s")
    }
}
