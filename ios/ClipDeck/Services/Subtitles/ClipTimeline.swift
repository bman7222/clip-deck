import CoreGraphics
import Foundation

/// The rules behind the Make a Card timeline: notches, the zoom window, snapping and handle limits.
/// All times are video time in ms (offset applied); x values are points inside a track `widthPt` wide.
struct ClipTimeline: Equatable {
    enum Handle: Equatable { case start, end }

    static let snapInPt: CGFloat = 10
    static let snapOutPt: CGFloat = 16
    static let drawMergePt: CGFloat = 2
    static let mergeMs = 1
    static let defaultWindowMs = 30_000
    static let longClipMs = 25_000

    let durationMs: Int
    let range: ClipRange
    let widthPt: CGFloat
    /// Every cue start and end, sorted, boundaries within 1 ms merged.
    let notches: [Int]
    let window: ClipRange

    /// Pass `window` to keep the current window while a handle moves; omit it to centre on `range`.
    init(track: CueTrack, offsetMs: Int, videoDurationMs: Int, range: ClipRange, widthPt: CGFloat, window: ClipRange? = nil) {
        let fallback = (track.cues.map(\.endMs).max() ?? 0) + offsetMs
        durationMs = videoDurationMs > 0 ? videoDurationMs : max(0, fallback)
        self.range = range
        self.widthPt = widthPt

        var merged: [Int] = []
        for ms in track.cues.flatMap({ [$0.startMs + offsetMs, $0.endMs + offsetMs] }).sorted() {
            if let last = merged.last, ms - last <= Self.mergeMs { continue }
            merged.append(ms)
        }
        notches = merged

        self.window = window ?? Self.centredWindow(on: range, durationMs: durationMs)
    }

    private static func centredWindow(on range: ClipRange, durationMs: Int) -> ClipRange {
        let length = range.durationMs > longClipMs ? Int((Double(range.durationMs) * 1.2).rounded()) : defaultWindowMs
        if length >= durationMs { return ClipRange(startMs: 0, endMs: durationMs) }
        let start = min(max(0, range.midpointMs - length / 2), durationMs - length)
        return ClipRange(startMs: start, endMs: start + length)
    }

    // MARK: Mapping

    func x(forMs ms: Int) -> CGFloat {
        guard window.durationMs > 0 else { return 0 }
        let clamped = min(max(ms, window.startMs), window.endMs)
        return CGFloat(clamped - window.startMs) / CGFloat(window.durationMs) * widthPt
    }

    func ms(forX x: CGFloat) -> Int {
        guard widthPt > 0 else { return window.startMs }
        let clamped = min(max(x, 0), widthPt)
        return window.startMs + Int((clamped / widthPt * CGFloat(window.durationMs)).rounded())
    }

    private var visibleNotches: [Int] { notches.filter { $0 >= window.startMs && $0 <= window.endMs } }

    /// Notches in the window, with any closer than 2 pt to the previous one dropped.
    var drawnNotches: [Int] {
        var kept: [Int] = []
        for ms in visibleNotches {
            if let last = kept.last, x(forMs: ms) - x(forMs: last) < Self.drawMergePt { continue }
            kept.append(ms)
        }
        return kept
    }

    /// `draggedHandle` is the handle of a drag that just ended; at a window edge it means the user wants more room.
    func needsRecentring(draggedHandle: Handle? = nil) -> Bool {
        if range.startMs < window.startMs || range.endMs > window.endMs { return true }
        guard let draggedHandle else { return false }
        let ms = draggedHandle == .start ? range.startMs : range.endMs
        return ms <= window.startMs || ms >= window.endMs
    }

    // MARK: Dragging

    /// Where a handle dragged to `pointerX` lands. Pass the notch it is snapped to (`current`) and keep the returned one.
    func snap(pointerX: CGFloat, current: Int?, enabled: Bool) -> (ms: Int, notch: Int?) {
        let visible = visibleNotches
        guard enabled, !visible.isEmpty else { return (ms(forX: pointerX), nil) }
        if let current, visible.contains(current), abs(x(forMs: current) - pointerX) <= Self.snapOutPt {
            return (current, current)
        }
        if let nearest = visible.min(by: { abs(x(forMs: $0) - pointerX) < abs(x(forMs: $1) - pointerX) }),
           abs(x(forMs: nearest) - pointerX) <= Self.snapInPt {
            return (nearest, nearest)
        }
        return (ms(forX: pointerX), nil)
    }

    /// The range after moving one handle to `ms`, held to 0...duration and the minimum length.
    func dragged(_ handle: Handle, toMs ms: Int) -> ClipRange {
        switch handle {
        case .start: ClipMath.adjusted(range, startDeltaMs: ms - range.startMs, videoDurationMs: durationMs)
        case .end: ClipMath.adjusted(range, endDeltaMs: ms - range.endMs, videoDurationMs: durationMs)
        }
    }

    /// The nearest handle to a touch; on a tie the drag direction decides (left takes the start).
    func handle(forTouchX touchX: CGFloat, dragDeltaX: CGFloat) -> Handle {
        let toStart = abs(touchX - x(forMs: range.startMs))
        let toEnd = abs(touchX - x(forMs: range.endMs))
        if abs(toStart - toEnd) > 0.5 { return toStart < toEnd ? .start : .end }
        return dragDeltaX < 0 ? .start : .end
    }
}
