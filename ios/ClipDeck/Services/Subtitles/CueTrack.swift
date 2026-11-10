import Foundation

/// Sorted cues with fast lookup. All `subtitleMs` values are in the subtitle file's clock;
/// convert from video time with `subtitleMs = videoMs - offsetMs`.
struct CueTrack: Equatable {
    let cues: [SubtitleCue]

    static let empty = CueTrack(cues: [])

    var isEmpty: Bool { cues.isEmpty }

    /// Index of the last cue whose start is at or before `subtitleMs`.
    func lastIndex(startingAtOrBefore subtitleMs: Int) -> Int? {
        var low = 0
        var high = cues.count
        while low < high {
            let mid = (low + high) / 2
            if cues[mid].startMs <= subtitleMs { low = mid + 1 } else { high = mid }
        }
        return low == 0 ? nil : low - 1
    }

    /// The cue on screen at `subtitleMs` (start ≤ t < end). With overlapping cues, the latest-starting wins.
    func indexOfCue(at subtitleMs: Int) -> Int? {
        guard let last = lastIndex(startingAtOrBefore: subtitleMs) else { return nil }
        var index = last
        // Overlaps are short in practice; look back a few cues only.
        while index >= 0, last - index < 8 {
            if cues[index].endMs > subtitleMs { return index }
            index -= 1
        }
        return nil
    }

    /// Cues that overlap the half-open range [startMs, endMs).
    func cues(overlappingStart startMs: Int, end endMs: Int) -> [SubtitleCue] {
        cues.filter { $0.startMs < endMs && $0.endMs > startMs }
    }
}

/// A span of the video, in video time (offset already applied).
struct ClipRange: Equatable, Hashable, Sendable {
    var startMs: Int
    var endMs: Int

    var durationMs: Int { endMs - startMs }
    var midpointMs: Int { startMs + durationMs / 2 }
}

/// The asbplayer-style range rules used by Make a Card.
enum ClipMath {
    static let minimumDurationMs = 200

    /// The video-time range of a cue.
    static func range(of cue: SubtitleCue, offsetMs: Int) -> ClipRange {
        ClipRange(startMs: cue.startMs + offsetMs, endMs: cue.endMs + offsetMs)
    }

    /// Text of every cue that overlaps the range (partial overlaps included), one cue per line.
    static func sentence(for range: ClipRange, track: CueTrack, offsetMs: Int) -> String {
        track.cues(overlappingStart: range.startMs - offsetMs, end: range.endMs - offsetMs)
            .map(\.text)
            .joined(separator: "\n")
    }

    /// Moves the start back to the start of the previous line (or of the line the start is inside).
    static func extendToPreviousLine(_ range: ClipRange, track: CueTrack, offsetMs: Int) -> ClipRange {
        guard let cue = track.cues.last(where: { $0.startMs + offsetMs < range.startMs }) else { return range }
        return ClipRange(startMs: max(0, cue.startMs + offsetMs), endMs: range.endMs)
    }

    /// Moves the end forward to the end of the next line (or of the line the end is inside).
    static func extendToNextLine(_ range: ClipRange, track: CueTrack, offsetMs: Int) -> ClipRange {
        guard let cue = track.cues.first(where: {
            $0.endMs + offsetMs > range.endMs && $0.startMs + offsetMs >= range.startMs
        }) else { return range }
        return ClipRange(startMs: range.startMs, endMs: cue.endMs + offsetMs)
    }

    /// Shifts the start and/or end, keeping 0 ≤ start, end ≤ duration and a minimum length.
    static func adjusted(_ range: ClipRange, startDeltaMs: Int = 0, endDeltaMs: Int = 0, videoDurationMs: Int) -> ClipRange {
        var start = max(0, range.startMs + startDeltaMs)
        var end = range.endMs + endDeltaMs
        if videoDurationMs > 0 { end = min(end, videoDurationMs) }
        if end - start < minimumDurationMs {
            if startDeltaMs != 0 {
                start = max(0, end - minimumDurationMs)
            } else {
                end = start + minimumDurationMs
            }
        }
        return ClipRange(startMs: start, endMs: end)
    }
}

enum TimeFormat {
    /// `1:45.2`, or `1:02:03.4` past an hour.
    static func clock(_ ms: Int) -> String {
        let totalTenths = max(0, ms) / 100
        let tenths = totalTenths % 10
        let totalSeconds = totalTenths / 10
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%d", hours, minutes, seconds, tenths)
        }
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    /// `+0.3 s`, `−1.2 s`, `0.0 s`.
    static func offset(_ ms: Int) -> String {
        let value = String(format: "%.1f s", Double(abs(ms)) / 1000)
        if ms > 0 { return "+" + value }
        if ms < 0 { return "−" + value }
        return value
    }
}
