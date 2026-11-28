import CoreGraphics
import Testing
@testable import ClipDeck

@MainActor
struct ClipTimelineTests {
    /// 0.5-2.0, 2.0-4.0, 4.0-5.5 s.
    let sample = CueTrack(cues: [
        SubtitleCue(id: 0, startMs: 500, endMs: 2_000, text: "a"),
        SubtitleCue(id: 1, startMs: 2_000, endMs: 4_000, text: "b"),
        SubtitleCue(id: 2, startMs: 4_000, endMs: 5_500, text: "c"),
    ])

    /// A 6 s episode on a 300 pt track: 20 ms per point, the window is the whole episode.
    func sixSeconds(range: ClipRange = ClipRange(startMs: 1_000, endMs: 3_000), track: CueTrack? = nil) -> ClipTimeline {
        ClipTimeline(track: track ?? sample, offsetMs: 0, videoDurationMs: 6_000, range: range, widthPt: 300)
    }

    func long(_ range: ClipRange, duration: Int = 600_000, window: ClipRange? = nil) -> ClipTimeline {
        ClipTimeline(track: .empty, offsetMs: 0, videoDurationMs: duration, range: range, widthPt: 300, window: window)
    }

    // MARK: Notches

    @Test func notchesAtLineEdgesAndOffset() {
        #expect(sixSeconds().notches == [500, 2_000, 4_000, 5_500])
        let shifted = ClipTimeline(track: sample, offsetMs: 300, videoDurationMs: 6_000,
                                   range: ClipRange(startMs: 1_000, endMs: 3_000), widthPt: 300)
        #expect(shifted.notches == [800, 2_300, 4_300, 5_800])
    }

    @Test func boundariesWithinOneMsMerge() {
        let track = CueTrack(cues: [
            SubtitleCue(id: 0, startMs: 0, endMs: 1_000, text: "a"),
            SubtitleCue(id: 1, startMs: 1_001, endMs: 2_000, text: "b"),
            SubtitleCue(id: 2, startMs: 2_003, endMs: 3_000, text: "c"),
        ])
        #expect(sixSeconds(track: track).notches == [0, 1_000, 2_000, 2_003, 3_000])
    }

    @Test func drawnNotchesMergeCloserThanTwoPoints() {
        let track = CueTrack(cues: [
            SubtitleCue(id: 0, startMs: 0, endMs: 1_000, text: "a"),
            SubtitleCue(id: 1, startMs: 1_030, endMs: 2_000, text: "b"),   // 1.5 pt after 1_000
            SubtitleCue(id: 2, startMs: 2_040, endMs: 3_000, text: "c"),   // exactly 2 pt: kept
        ])
        let timeline = sixSeconds(track: track)
        #expect(timeline.notches.count == 6)
        #expect(timeline.drawnNotches == [0, 1_000, 2_000, 2_040, 3_000])
    }

    @Test func noCuesNoNotches() {
        #expect(sixSeconds(track: .empty).notches.isEmpty)
    }

    // MARK: Window

    @Test func windowCentresOnTheClipMidpoint() {
        let window = long(ClipRange(startMs: 100_000, endMs: 102_000)).window
        #expect(window == ClipRange(startMs: 86_000, endMs: 116_000))
    }

    @Test func longClipGetsItsLengthPlusTwentyPercent() {
        let window = long(ClipRange(startMs: 100_000, endMs: 130_000)).window
        #expect(window == ClipRange(startMs: 97_000, endMs: 133_000))
        // 25 s exactly is not longer than 25 s.
        let edge = long(ClipRange(startMs: 100_000, endMs: 125_000)).window
        #expect(edge.durationMs == 30_000)
    }

    @Test func windowShiftsAtBothEpisodeEdgesWithoutShrinking() {
        #expect(long(ClipRange(startMs: 0, endMs: 2_000)).window == ClipRange(startMs: 0, endMs: 30_000))
        #expect(long(ClipRange(startMs: 598_000, endMs: 600_000)).window == ClipRange(startMs: 570_000, endMs: 600_000))
    }

    @Test func shortEpisodeIsTheWholeWindow() {
        #expect(sixSeconds().window == ClipRange(startMs: 0, endMs: 6_000))
    }

    @Test func durationFallsBackToLastCueEndWhileVideoDurationIsZero() {
        let range = ClipRange(startMs: 1_000, endMs: 3_000)
        let plain = ClipTimeline(track: sample, offsetMs: 0, videoDurationMs: 0, range: range, widthPt: 300)
        #expect(plain.durationMs == 5_500)
        #expect(plain.window == ClipRange(startMs: 0, endMs: 5_500))
        let shifted = ClipTimeline(track: sample, offsetMs: 300, videoDurationMs: 0, range: range, widthPt: 300)
        #expect(shifted.durationMs == 5_800)
        let empty = ClipTimeline(track: .empty, offsetMs: 0, videoDurationMs: 0, range: range, widthPt: 300)
        #expect(empty.durationMs == 0)
        #expect(empty.x(forMs: 500) == 0)
    }

    @Test func xAndMsMapBothWaysAndClamp() {
        let timeline = sixSeconds()
        #expect(timeline.x(forMs: 2_000) == 100)
        #expect(timeline.ms(forX: 100) == 2_000)
        for ms in stride(from: 0, through: 6_000, by: 250) {
            #expect(abs(timeline.ms(forX: timeline.x(forMs: ms)) - ms) <= 1)
        }
        #expect(timeline.x(forMs: -5) == 0)
        #expect(timeline.x(forMs: 99_999) == 300)
        #expect(timeline.ms(forX: -10) == 0)
        #expect(timeline.ms(forX: 400) == 6_000)
    }

    @Test func needsRecentringWhenRangeLeavesTheWindow() {
        let first = long(ClipRange(startMs: 100_000, endMs: 102_000))
        #expect(!first.needsRecentring())
        let moved = long(ClipRange(startMs: 100_000, endMs: 120_000), window: first.window)
        #expect(moved.needsRecentring())
        #expect(!long(ClipRange(startMs: 100_000, endMs: 120_000)).needsRecentring())
    }

    @Test func needsRecentringWhenADragEndsAtAWindowEdge() {
        let window = ClipRange(startMs: 86_000, endMs: 116_000)
        let atEdge = long(ClipRange(startMs: 100_000, endMs: 116_000), window: window)
        #expect(!atEdge.needsRecentring())
        #expect(!atEdge.needsRecentring(draggedHandle: .start))
        #expect(atEdge.needsRecentring(draggedHandle: .end))
    }

    // MARK: Snapping

    func expectSnapped(_ result: (ms: Int, notch: Int?)) {
        #expect(result.ms == 2_000)
        #expect(result.notch == 2_000)
    }

    @Test func snapsInAtTenPointsAndNotBefore() {
        let timeline = sixSeconds()   // notch 2_000 sits at x = 100
        expectSnapped(timeline.snap(pointerX: 110, current: nil, enabled: true))
        expectSnapped(timeline.snap(pointerX: 90, current: nil, enabled: true))
        let free = timeline.snap(pointerX: 111, current: nil, enabled: true)
        #expect(free.ms == 2_220 && free.notch == nil)
    }

    @Test func staysSnappedUntilMoreThanSixteenPoints() {
        let timeline = sixSeconds()
        expectSnapped(timeline.snap(pointerX: 115, current: 2_000, enabled: true))
        expectSnapped(timeline.snap(pointerX: 116, current: 2_000, enabled: true))
        let released = timeline.snap(pointerX: 117, current: 2_000, enabled: true)
        #expect(released.ms == 2_340 && released.notch == nil)
    }

    @Test func switchOffOrNoNotchesNeverSnaps() {
        let off = sixSeconds().snap(pointerX: 100, current: 2_000, enabled: false)
        #expect(off.ms == 2_000 && off.notch == nil)
        let none = sixSeconds(track: .empty).snap(pointerX: 100, current: nil, enabled: true)
        #expect(none.ms == 2_000 && none.notch == nil)
    }

    // MARK: Clamps and handle choice

    @Test func startClamps() {
        let timeline = sixSeconds()   // 1_000-3_000
        #expect(timeline.dragged(.start, toMs: -500) == ClipRange(startMs: 0, endMs: 3_000))
        #expect(timeline.dragged(.start, toMs: 2_900) == ClipRange(startMs: 2_800, endMs: 3_000))
        #expect(timeline.dragged(.start, toMs: 2_000) == ClipRange(startMs: 2_000, endMs: 3_000))
    }

    @Test func endClamps() {
        let timeline = sixSeconds()
        #expect(timeline.dragged(.end, toMs: 9_000) == ClipRange(startMs: 1_000, endMs: 6_000))
        #expect(timeline.dragged(.end, toMs: 1_100) == ClipRange(startMs: 1_000, endMs: 1_200))
        #expect(timeline.dragged(.end, toMs: 4_000) == ClipRange(startMs: 1_000, endMs: 4_000))
    }

    @Test func touchPicksTheNearestHandle() {
        let timeline = sixSeconds()   // handles at x 50 and 150
        #expect(timeline.handle(forTouchX: 60, dragDeltaX: 5) == .start)
        #expect(timeline.handle(forTouchX: 140, dragDeltaX: -5) == .end)
    }

    @Test func tieGoesByDragDirection() {
        let timeline = sixSeconds(range: ClipRange(startMs: 2_000, endMs: 2_200))   // x 100 and 110
        #expect(timeline.handle(forTouchX: 105, dragDeltaX: -3) == .start)
        #expect(timeline.handle(forTouchX: 105, dragDeltaX: 3) == .end)
    }
}
