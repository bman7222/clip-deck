---
id: T-032
title: Timeline maths
lane: backend
depends_on: []
status: done
round: 2
base_sha: 7e98e225abec28b3284a4b1eba64441442a8b045
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

## Implementation notes (round 1) · sonnet
_by loop-backend · 2026-11-27_
- Added `ClipTimeline` (Services/Subtitles/ClipTimeline.swift): plain struct like `CueTrack`/`ClipRange` (not marked `nonisolated`, because those types are MainActor by default and a nonisolated type could not read them); tests are `@MainActor`.
- API: `init(track:offsetMs:videoDurationMs:range:widthPt:window:)`; `notches`, `drawnNotches`, `window`, `durationMs`, `x(forMs:)`, `ms(forX:)`, `needsRecentring(draggedHandle:)`, `snap(pointerX:current:enabled:) -> (ms, notch)`, `dragged(_:toMs:) -> ClipRange`, `handle(forTouchX:dragDeltaX:)`.
- `window:` is optional so the view can keep the window while a handle moves; omit it to re-centre. A new timeline per range change is the intended use.
- Clamps go through `ClipMath.adjusted`, so the 200 ms rule is not copied. It also clamps the other end to the duration.
- Choices: `drawnNotches` only covers notches inside the window; snapping only considers notches in the window; a tie with zero drag takes the end handle; a window edge hit at episode edge 0 still reports recentring (no-op).
- Checks: not compiled (Windows, CI only). Every identifier was checked against CueTrack.swift and SubtitleCue.
- Tests: 19 in `ClipTimelineTests` (ios/ClipDeckTests), no mutating calls inside `#expect`. ARCHITECTURE.md has a line on the type.
- Tester: run `ClipDeckTests/ClipTimelineTests` and `ClipDeckTests/ClipMathTests`; check the CI build for isolation errors first.

### CI round 1
- CI: pending, run 46098852435 (b1c50df, scope=tests, only_testing=ClipDeckTests). Dispatched once and not watched. There is no local gate, because Swift can't build on Windows; `git diff --check` is clean.

## Fix round 2
- CI 46098852435 failed only `ClipTimelineTests.tieGoesByDragDirection`: x(2000) and x(2200) in floating point aren't exactly 5 pt from 105, so the exact `!=` tie test missed. The orchestrator fixed it directly (policy rule 20, a one-line edit): distances within 0.5 pt count as a tie.
- CI: shared with T-024b's full run (below), since the two tasks touch no common files.

### CI (shared run)
- CI: pending, run 46100218606 (be1ed79, scope=all). It covers T-032 round 2 (e049b9b, unit tests) and T-024b round 1. Dispatched once and not watched.
- Run 46100218606 failed in all 4 test jobs: SubtitleStyleCardUITests.swift:193 had a real line break inside a string literal (T-024b), so the UI test bundle didn't compile. The ipa job was green. The orchestrator fixed it (`
`), and the rerun is 46102226923 (8e727cb, scope=all), pending and not watched.

## Test report (round 2)
_by loop-tester · 2026-11-28_

Evidence: CI run 46102226923 (8e727cb, scope=all). Shard 1 (ClipDeckTests) green, so all 19 ClipTimelineTests and ClipMathTests pass. Shard 3 failed on two T-024b/T-024a UI tests; ClipTimeline has no UI caller, so unrelated. No Swift compiler here; the revert-the-code check was not run locally (CI only). Read ClipTimeline.swift and the tests at e049b9b.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 pure value type, Int ms, duration-0 fallback | Pass | ClipTimeline.swift:24-26; durationFallsBackToLastCueEndWhileVideoDurationIsZero. Not marked `nonisolated` (explained in round 1: CueTrack is MainActor by default); no SwiftUI import; CI compiles it |
| AC-2 notches, 1 ms merge, 2 pt drawing merge | Pass | :30-35, :64-71; notchesAtLineEdgesAndOffset, boundariesWithinOneMsMerge, drawnNotchesMergeCloserThanTwoPoints |
| AC-3 window, long clip, edges, x/ms, recentring | Pass | :40-45, 49-59, 74-79; the window, long-clip, edge, short-episode, xAndMs and two needsRecentring tests |
| AC-4 snap 10/16 pt, switch off, no notches | Pass | :84-95; snapsInAtTenPointsAndNotBefore (110 in, 111 out), staysSnappedUntilMoreThanSixteenPoints (115, 116 held, 117 released), switchOffOrNoNotchesNeverSnaps |
| AC-5 clamps, nearest handle, tie rule | Pass | :98-111 via ClipMath.adjusted (no copied 200 ms); startClamps, endClamps, touchPicksTheNearestHandle, tieGoesByDragDirection |
| AC-6 tests and ARCHITECTURE line | Pass | 19 tests listed, CI green on shard 1; docs/ARCHITECTURE.md +1 line |

### Findings
Could fix
Where: ClipTimeline.swift:67
Problem: the 2 pt drawing merge compares floating-point x values with `<`. The "exactly 2 pt kept" test (2000 vs 2040 ms) passes in CI but sits on a rounding edge.
Fix: compare in ms (or round x) if it ever flickers.

Could fix
Where: ClipTimeline.swift:109 / ClipTimelineTests.swift:173
Problem: the 0.5 pt tie tolerance is tested only at a 0 pt gap, not just outside it (for example 0.6 pt apart picks the nearer handle). Also `dragged` with durationMs 0 (no cues, no video) is untested; it relies on ClipMath.adjusted.

Edge review: empty track gives no notches, duration 0, x = 0, no crash. Zero width and zero window return the window start. Window clamps are right (shift without shrinking, whole episode when shorter, 25 s exactly is not "long"). Snap hysteresis holds, and a stale `current` outside the window is ignored. The tie-with-zero-drag rule (takes end) is documented.

```text
VERDICT: Pass
SPEC: AC-1 to AC-6 met
CHECKS_RUN: CI 46102226923 shard 1 green (ClipTimelineTests 19/19, ClipMathTests); shard 3 failures are T-024b UI tests, not T-032
UNVERIFIED: revert-test not run locally (no compiler); nothing visible on screen
REVIEWED_AT: e049b9b (CI on 8e727cb)
```
