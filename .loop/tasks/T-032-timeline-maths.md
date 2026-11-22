---
id: T-032
title: Timeline maths
lane: backend
depends_on: []
status: todo
round: 0
base_sha:
issue: 29
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Work out the clip timeline's rules: notches at line edges, the zoom window, snapping and handle limits

### What are we building?
The Make a Card timeline (T-033) needs exact rules: where notches go, which part of the episode the zoomed track shows, how a handle snaps to a line edge, and how far each handle may go. This task builds those rules as one tested piece with no UI. Nothing on screen changes.

### Why?
The view stays simple, and the fiddly maths is proven by unit tests before anyone drags anything.

### Done when
- AC-1 A pure `ClipTimeline`: a `nonisolated` value type built from the cues, `offsetMs`, `videoDurationMs`, the clip range and the track width in points. Times are Int ms, like `ClipRange`. While `videoDurationMs` is 0, the duration falls back to the last cue's end in video time.
- AC-2 Notches: every cue start and end in video time (offset applied), sorted, with boundaries within 1 ms merged into one. A second list, for drawing, merges notches closer than 2 pt at the current window and width.
- AC-3 Zoom window: 30 s centred on the clip's midpoint. A clip longer than 25 s gets its own length + 20 % instead. The window shifts, without shrinking, to stay inside [0, duration], and becomes the whole duration when that's shorter. `x(forMs:)` and `ms(forX:)` map both ways and clamp. `needsRecentring` is true when the range isn't fully inside the window, or when a drag ended with a handle at a window edge.
- AC-4 Snapping, while the switch is on: a dragged handle within 10 pt of a notch snaps exactly onto it, and stays snapped until the pointer is more than 16 pt from that notch. The caller passes the current snapped notch in and gets the new one out. With the switch off, or no notches, nothing snaps.
- AC-5 Clamps: start ≥ 0, end ≤ duration, and start ≤ end − `ClipMath.minimumDurationMs` (200), so a handle never passes the other. Handle choice: a touch picks the nearest handle, and on a tie (overlapping hit areas, equal distance) the drag direction decides: left takes the start, right takes the end.
- AC-6 Unit tests (`ClipTimelineTests`):
  - the sample track (0.5–2.0, 2.0–4.0, 4.0–5.5 s) gives notches at 0.5, 2.0, 4.0 and 5.5 s, and an offset of +300 ms shifts them all;
  - the 1 ms merge and the 2 pt drawing merge;
  - window centring, the long-clip rule, both episode edges, the duration-0 fallback, and a 6 s episode;
  - an x ↔ ms round trip;
  - snapping in at 10 pt, still snapped at 15 pt, released at 17 pt;
  - every clamp, the nearest-handle rule and the tie rule.
  ARCHITECTURE.md gets a line on the type.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check that `ClipTimelineTests` all pass and that the existing ClipMathTests still pass.

### Agent notes
- Depends on: none. Source: spec T-032.
- Code: `ClipRange`, `ClipMath.adjusted` and `minimumDurationMs` are at CueTrack.swift:42-94. Reuse the 200 ms rule rather than copying it. CardEditorView already has `track`, `offsetMs` and `videoDurationMs`, which is 0 until the video is loaded.
- Points are CGFloat. Keep the type free of SwiftUI so it's trivially testable.
- Learned: no mutating call inside `#expect`.

### Out of scope
- Any view or gesture (T-033), a playhead.
