---
id: T-033
title: Timeline view in Make a Card
lane: frontend
depends_on: [T-032]
status: done
round: 1
base_sha: 7df9baa14ed58f5a7d615c9075c9b92ac81e2709
issue: 30
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Drag the clip's start and end on a timeline in Make a Card

### What are we building?
Make a Card only has ±0.1/±0.5 s nudge buttons for the clip range. After this task a timeline sits above them. A thin strip shows the whole episode with the clip marked. Below it, a zoomed track has blue notches at line edges and two round handles you drag to set the start and end, snapping to line edges when Snap is on. Handles and nudges stay in sync, and a changed range still needs a re-record, as today.

### Why?
Picking a clip by eye is faster and more accurate than counting nudges.

### Done when
- AC-1 `card.timeline` sits above the nudge rows and has two parts:
  - an overview strip covering the whole episode, 8 pt tall, with an aqua block for the clip;
  - a zoomed track: a rounded track in the normal theme with solid `Theme.accent` 2×10 pt notches, a 25 % accent fill between the handles, and two 28 pt white handles with a 3 pt accent border and 44 pt hit areas (`card.timeline.start`, `card.timeline.end`).
  Labels show the window's start and end (m:ss.t).
- AC-2 Dragging a handle moves it live, using T-032's clamps and handle choice. While dragging, a bubble shows the time (m:ss.t), and it flips inward at the track's edges. The window re-centres with a 0.2 s animation (plain under Reduce Motion) when a drag ends at an edge, or when the range leaves the window, for example after nudges.
- AC-3 The Snap chip `card.timeline.snap` is an on/off switch that starts on and is remembered across launches (cleared on `-uiTesting` launches unless a keep flag is passed). When on, handles snap to notches (T-032). With no cues there are no notches, and the chip is disabled.
- AC-4 One source of truth: the handles and the nudge rows both write the editor's `range`. After a drag, `needsRerecord` behaves exactly as after a nudge: Save is disabled and the red Re-record button appears. Re-record updates the media and the sentence as today, and the `card.range` text always matches the handles.
- AC-5 VoiceOver: each handle is adjustable by ±0.1 s, labelled "Clip start" or "Clip end", with an m:ss.t value. The timeline works in light and dark mode and at a large Dynamic Type size, and the track is full width on small phones.
- AC-6 UI tests (MiningFlow style: Make a Card on the sample's line 2, 2.0–4.0 s):
  - the timeline and both handles exist;
  - with Snap on, dragging the end handle right lands exactly on 5.5 s (`card.range` reads "0:02.0 – 0:05.5"); Save is disabled and Re-record shows; Re-record, then Save, works;
  - with Snap off, a drag lands between notches;
  - a +0.1 nudge moves the end handle right;
  - the chip's state survives a relaunch with the keep flag.
  Every existing test passes, and DESIGN.md describes the timeline.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check the new timeline UI tests, MiningFlowUITests, and screenshots of the editor in light and dark mode.
- Unverified for Brent: handle feel on a real 24-minute episode.

### Agent notes
- Depends on: T-032 (`ClipTimeline`). Source: spec T-033; section G default 6 (blue notches, 25 % fill, white handles with a 3 pt accent border) and "Snap with an on/off switch".
- Code in CardEditorView.swift: `range`/`recordedRange` are at lines 20-21, `needsRerecord` at 84, `clipPanel` at 100-154 and `nudgeRow` at 156-178. The editor is a sheet inside the player; UI tests reach it through `player.makeCard` (see MiningFlowUITests).
- Put one DragGesture on the track and let T-032's handle choice pick the handle, rather than one gesture per handle, so overlapping hit areas follow the rule.
- The sample video is 6 s with offset 0, so the window is the whole 6 s.
- The spec's optional playhead line during Play clip isn't required.
- Learned: a `.contain` container reports the union of its children's frames.

- Could-fix from T-032's tester: `drawnNotches` compares x values with `<` at exactly 2 pt (fragile at the boundary); the 0.5 pt tie tolerance is tested only at a 0 pt gap; `dragged` with duration 0 is untested. Fix any that the view's use touches.
- `ClipTimeline` is MainActor by default like `CueTrack` and `ClipMath` (AC-1 of T-032 said nonisolated); the view is MainActor, so it doesn't matter here.

### Out of scope
- A playhead, lookups in the editor (T-031), changing ClipMath's rules.

## Implementation notes (round 1)
_by loop-frontend · 2026-11-28_
- Changed: new `ClipTimelineView` (overview strip, zoomed track with notches, 25 % fill, two 28 pt handles in 44 pt hit areas, drag bubble, Snap chip, window labels); `CardEditorView` shows it above the nudge rows, bound to `range`, so `needsRerecord` and `card.range` need no change. One DragGesture on the track; `ClipTimeline` does handle choice, snap, clamps and re-centring. Snap is `@AppStorage("cardEditor.timelineSnap")`, default on, cleared on `-uiTesting` launches unless `-uiTestingKeepTimelineSnap`.
- Files: ios/ClipDeck/Features/CardEditor/ClipTimelineView.swift (new), CardEditorView.swift (+2 lines), ios/ClipDeck/App/ClipDeckApp.swift (+3, clears the snap key), ios/ClipDeckUITests/CardTimelineUITests.swift (new, 5 tests, 120 s sample), docs/DESIGN.md, docs/DEVELOPMENT.md, CLAUDE.md (flag).
- Checked: not compiled (Windows). Hand-checked every API against ClipTimeline/ClipMath/TimeFormat; scanned the changed Swift files for odd `"` counts (none). CI classes: ClipDeckTests/ClipTimelineTests (unchanged), ClipDeckUITests/CardTimelineUITests, MiningFlowUITests.
- Tester, look at: drag start (min distance 2 pt, handle chosen on the first event; a tie takes the drag direction); the handle accessibility frame (44 pt, midX is used to compute points per second); the bubble at the edges; the track inside the editor's ScrollView (drag on the track must not scroll); light/dark screenshot `timeline-editor`.
- Gotchas: window labels and notches use `window` state, re-centred by `onChange(of: range)` and on drag end; T-032 Could-fix items (2 pt float compare, tie tolerance test, duration-0 drag) not touched, the view only uses `drawnNotches` for drawing. No playhead (out of scope). Snap chip is "disabled" by `track.cues.isEmpty`, which equals "no notches".

### Orchestrator gate (round 1)
- Ponytail review (205 product lines): no Must or Should fix. Every rule goes through `ClipTimeline`; the theme tokens, `TimeFormat.clock` (m:ss.t), the UITestSupport helpers and the nudge label "End later by 100 milliseconds" all exist. Comments 2 %: no comment pass.
- Known limit, left: `window` is set once at init, so if `videoDurationMs` arrives after the editor opens, the window keeps the last-cue fallback until a drag or nudge re-centres it.
- Not committed yet: CI waits for run 46115783465 (T-024b verify, T-026). Its round runs scope=all (new UI class in shard 4, app code changed).
- CI: run 46118672166 (b6e8831, scope=all), shared with T-026's verify-only pass. Pending, not watched.

## Test report (round 1)
_by loop-tester · 2026-11-28 15:00_

Reviewed `git diff 0ad1e5d b6e8831` against CI 46118672166 (b6e8831, scope=all; orchestrator read it). No Swift compiler here.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 timeline above nudge rows, overview 8 pt + aqua block, zoomed track (notches, 25 % fill, 28 pt handles, 3 pt border, 44 pt hit areas, ids), window labels | Pass | CardEditorView.swift:121 (above nudgeRow); ClipTimelineView.swift:65-116, 120-127; testTimelineAndBothHandlesExist green in 46118672166 (ids, label, value 0:04.0). Look not seen: screenshot not opened by me |
| AC-2 live drag via T-032 clamps and handle choice, bubble m:ss.t clamped inward, re-centre 0.2 s / plain under Reduce Motion | Pass (drag, clamps) / Unverified (bubble look, animation) | dragChanged → `handle(forTouchX:)`, `snap`, `dragged` (ClipTimelineView.swift:178-190); recentre → `needsRecentring` + `.easeInOut(0.2)`/reduceMotion (:192-200); drag tests green. Bubble clamps with `.position` (:143); no screenshot of it mid-drag |
| AC-3 Snap chip on/off, starts on, remembered, cleared on -uiTesting unless keep flag, disabled with no cues | Pass | testSnapChipSurvivesARelaunchWithTheKeepFlag green; clearing is proven by order: testSnapOffDragLandsBetweenEdges runs after it and its `tapStep(from: "On")` passes; ClipDeckApp.swift:36-38. No-cue disabled: read only (`.disabled(track.cues.isEmpty)`) |
| AC-4 one source of truth, drag behaves like a nudge (Save disabled, Re-record), Re-record then Save, card.range matches handles | Pass, snap evidence weak (see finding) | Binding `$range`; handles derive from `range` only. testSnapOnDrag… green (Save disabled, Re-record shown, Save then toast); testNudgeMovesTheEndHandleRight green |
| AC-5 VoiceOver adjustable ±0.1 s, labels, m:ss.t value; light/dark; large Dynamic Type; full width on small phones | Partly | Label/value asserted in testTimelineAndBothHandlesExist. Adjustable action read only (:133-136). Added testTimelineFitsAtALargeDynamicTypeSize (not yet run). Dark: CI simulator stays light (Learned). Small phone: CI has only iPhone 17 Pro; GeometryReader fills the width by construction |
| AC-6 UI tests (exist, snap → 5.5 + re-record + save, snap off between notches, +0.1 nudge, chip survives relaunch); every test passes; DESIGN.md | Partly | 5 tests green in shard 4. Snap test does not prove snapping (finding below), tightened. Shard 3's MoveTextTesterUITests landscape failure is pre-existing (player/Move-Text, untouched here). DESIGN.md "Clip timeline" section added |

### Findings
Should fix (test, fixed by tester)
Where: ios/ClipDeckUITests/CardTimelineUITests.swift (testSnapOnDragLandsOnTheNextEdgeThenRerecordAndSave)
Problem: the drag was 1.5 s from 4.0 to 5.5, so an unsnapped landing also reads "0:05.5" (m:ss.t rounds ±50 ms; 1 pt ≈ 97 ms). The test passes with Snap broken. Also, at 30 s over a ~310 pt track, 1.5 s is ~15.5 pt, just under the 16 pt snap-out hold on the 4.0 notch, so the end should stay at 4.0. It passed in CI only by XCUITest drag slack. On a narrower phone it would fail.
Proof: Traced it: ClipTimeline.swift snap() checks `current` within snapOutPt=16 first; track width 402 − 4×16 − 28 = 310 pt / 30 s window.
Trigger: any CI run or a different simulator width.
Fix (done, test file only): drag 2.0 s. Unsnapped reads 0:06.0, and snapped reads 0:05.5 (5.5 s is ~5 pt from the pointer, inside snapInPt 10). The pointer is ~20.7 pt from 4.0, past the hold. Mutation check not run: no compiler here. With `enabled: false` the label would read 0:06.0, and the test would fail.

Could fix
Where: ClipTimelineView.swift:108-115
Problem: the track's DragGesture ignores direction. A vertical scroll that starts on the track moves the nearest handle by the finger's horizontal drift (with Snap off, or when the handle isn't on a notch), which changes `range` and forces a re-record. It probably also stops the ScrollView from scrolling from that strip.
Proof: Read it.
Fix: ignore a drag whose first movement is mostly vertical (for example |dy| > |dx| on the first change).

Could fix: the timeline clamps with `ClipTimeline.durationMs` (it falls back to the last cue when `videoDurationMs` is 0), while the nudges clamp with the raw `videoDurationMs`. Same as the gate's known limit on `window`.

```text
VERDICT: Blocked
NEEDED: verify-only pass: only_testing=ClipDeckUITests/CardTimelineUITests (tightened testSnapOnDragLandsOnTheNextEdgeThenRerecordAndSave, new testTimelineFitsAtALargeDynamicTypeSize)
SPEC: AC-1 met, AC-2 met (bubble look unverified), AC-3 met, AC-4 met pending the tightened snap test, AC-5 partly (dark, small phone, VoiceOver gesture unverified), AC-6 met pending verify
CHECKS_RUN: CI 46118672166 (orchestrator-read): shards 1, 2, 4 and ipa green; shard 3 one pre-existing MoveTextTester landscape failure. Odd-quote scan of the edited test file: clean
UNVERIFIED: dark mode look, a small phone (SE width), VoiceOver swipe up/down on the handles, handle feel on a real 24-min episode
REVIEWED_AT: b6e8831
```

### Verify-only pass (round 1)
- Tester: Blocked for evidence only; it tightened the snap test (2.0 s drag: 0:06.0 unsnapped, 0:05.5 snapped) and added testTimelineFitsAtALargeDynamicTypeSize. Re-committed on base 91dc544 after T-026 landed; product tree unchanged since b6e8831.
- CI: run 46121764180 (f80cf5e, scope=all), shared with T-025 round 1. Pending, not watched.
- CI: run 46121764180 ran the tester's tests: CardTimelineUITests (shard 4) green. The red shards 2 and 3 are T-025 and slow-simulator failures. Landing run: 46124710697 (b8a4128, scope=all), pending.

### Round 1 addendum (orchestrator)
- CI 46124710697 (b8a4128, the same tree as b80376b after the trailer cleanup, scope=all): every job green, including the tester's tightened snap test and testTimelineFitsAtALargeDynamicTypeSize (shard 4). The tester's only open condition was this run, so the verdict is Pass.
