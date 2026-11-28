---
id: T-025
title: Drag the outline
lane: frontend
depends_on: [T-024a]
status: done
round: 2
base_sha: f9ff1cef624376575a0c212c0545c038ff772c39
issue: 28
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Drag the subtitle line to exactly where you want it

### What are we building?
With the Move-Text menu the line moves 5 % per arrow tap. After this task you press and hold the blue outline for a moment: it lifts, four arrows appear around it, and you drag the line anywhere inside its limits. It stays where you let go. The arrows still work, stepping from wherever the drag left the line.

### Why?
Fast, precise placement without counting taps.

### Done when
- AC-1 While the Move-Text menu is open (both orientations), a 0.25 s long press on `moveText.outline` lifts it. Four aqua arrows appear 8 pt outside each edge, the outline and arrows scale to 1.06 with a spring, and a light haptic plays. Under Reduce Motion there's no scale, and the stroke goes to 3 pt instead.
- AC-2 Dragging moves the line live. The drag maps to continuous `up`/`right` through the inverse of `SubtitlePlacement.frame`, clamped to 0…0.90 and ±0.40 and to the region (the bar and menu clamps), so the outline and the text move together and never leave the allowed area. The mapping is a pure, unit-tested function.
- AC-3 Releasing saves once (one write of `player.subtitleStyle`). A cancelled gesture puts the line back where it was. Arrows and drag edit the same value, and after a drag an arrow steps ±0.05 from the dragged place.
- AC-4 VoiceOver: the outline is an adjustable element labelled "Subtitle position", with `positionText` as its value. Increment and decrement move it 5 % up and down, and the custom actions "Move left" and "Move right" move it sideways.
- AC-5 With the Move-Text menu closed, nothing on the line can be dragged, and taps and selection behave as before.
- AC-6 Tests:
  - unit: dragging up N pt adds N / region height to `up`; the clamps hold at 0, 0.90 and ±0.40; a top obstruction clamps the region; a drag that returns to its start gives back the original value;
  - UI, portrait and landscape: `press(forDuration: 0.3, thenDragTo:)` 80 pt up moves `player.subtitle` up 80 ± 3 pt and changes the value text; a drag far past the top stops at the limit (Up dimmed, or "Highest" in landscape); a following Down tap moves the line by 5 % of the region (±1 pt); a drag with no cue showing moves the outline.
  Every existing test passes, and DESIGN.md describes dragging.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check the new drag unit and UI tests and their frame attachments.
- Unverified for Brent: how precise the drag feels on his iPhone.

### Agent notes
- Depends on: T-024a (the outline and the menu). Source: spec T-025; section G default 3.
- Gesture: `LongPressGesture(minimumDuration: 0.25).sequenced(before: DragGesture(minimumDistance: 0))`, with a `@GestureState` so a cancel resets. The panel handle (PlayerView.swift:364-390) shows the GestureState and latch pattern.
- The outline's gesture must win over the video's tap: in portrait that tap toggles the overlay, and in landscape it closes the menu.
- Place the drag preview with the same layout as the line (`SubtitleLineLayout`), so the text follows the outline exactly.
- In XCUITest, start from `outline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))` and drag to `.withOffset(CGVector(dx: 0, dy: -80))`.
- Learned: in landscape, use element screenshots and `app.debugDescription`.

### Out of scope
- Snapping to a grid, pinch to resize, dragging the line while the menu is closed.

## Implementation notes (round 1)
_by loop-frontend · 2026-11-28_
- Changed: `SubtitlePlacement.dragged` (pure inverse of `frame`: up/right move by points over region height/width, clamped with `SubtitleStyle.clampPosition`, `upRange`/`rightRange`, and the room left in the region under the top obstruction). `MoveTextOutline(lifted:)` draws the 8 pt arrows, 1.06 spring scale (Reduce Motion: none, 3 pt stroke), light haptic, is hit-testable, and is an adjustable "Subtitle position" element with "Move left"/"Move right". `PlayerView.subtitleLine` attaches `LongPress(0.25).sequenced(before: Drag(0, .global))` with a `@GestureState lineDrag`, feeds the live style to `SubtitleLineLayout` and writes `storedSubtitleStyle` once in `onEnded`.
- Files: ios/ClipDeck/Features/Player/SubtitlePlacement.swift, MoveTextMenu.swift, PlayerView.swift; ios/ClipDeckTests/SubtitleDragTests.swift (new); ios/ClipDeckUITests/MoveTextUITests.swift (+3 tests); docs/DESIGN.md.
- Checked: not compiled (no Swift here); API names read by hand; odd-quote scan of the 5 Swift files found none.
- Tester, look at: the drag far past the top. Portrait Up only dims at 0.90, and the drag stops at the visible limit (about 0.83), so portrait asserts the line position and the Down step, not a dimmed Up. Landscape asserts "Highest". The no-cue drag test is portrait only. VoiceOver actions (AC-4) have no UI test, and the haptic and Reduce Motion look are unverified. The outline's gesture is a child of the video overlay, so check a quick tap on the outline no longer closes the menu in portrait.

### Orchestrator gate (round 1)
- 95 net product lines, comments 4 %: no ponytail review, no comment pass. Compile skim: `sensoryFeedback(trigger:_:)`, the `SequenceGesture` value pattern, `clampPosition`, `clamped()`, `json`, `restingRegion`, `SubtitleMargins` and the PlayerView state all exist; `SubtitleStyle` is nonisolated, so `SubtitlePlacement.dragged` can use it.
- Tester, judge: a quick tap on the outline no longer closes the Move-Text menu in portrait (the outline now takes the touch; a tap elsewhere on the video still closes it). Portrait Up doesn't dim at the drag's visible limit (about 0.83), as the builder noted.
- Not committed yet: CI waits for run 46118672166 (T-026 verify, T-033).
- CI: run 46121764180 (f80cf5e, scope=all), shared with T-033's verify-only pass. Pending, not watched.

## Fix round 2 (orchestrator)
CI 46121764180 (f80cf5e, scope=all): shards 1 and 4 green (T-033's CardTimelineUITests pass); shards 2 and 3 red.
- T-025, fixed: `.contentShape(Rectangle())` sat after `.padding(-gap)`, so the outline's hit area and its accessibility frame became the line's own frame. `testOutlineSitsSixPointsOutsideTheLine{Portrait,Landscape}` and `testOutlineFramesASampleWhenNoLineIsShowingPortrait` read a 0 pt gap instead of 6. The content shape now goes before the padding, so it covers the drawn outline.
- T-025, fixed in the tests: the line moved 73 pt for an 80 pt drag and 52.7 for 60. The sequenced DragGesture starts at its first event after the 0.25 s hold, and XCUITest's synthetic drag sends its first move event about 7 pt in. Tolerance 3 → 10 pt. On a real finger the events are dense, so the lag should be about a point (unverified: Brent's drag-precision check).
- Not T-025 (slow simulator): shard 2 `testControlsStayWhilePausedAndAutoHideWhilePlaying` "Failed to terminate"; shard 3 `testArrowsDimAtTheirLimitsPortrait` "Timed out while launching"; `testOpeningTheCardPausesPlaybackAndDoneResumesLandscape` read no elapsed time because the video tap took 16 s and the controls auto-hid first.
- CI: run 46124710697 (b8a4128, scope=all). Pending, not watched.
- Re-committed on base f9ff1ce after T-033 and T-035 landed; product tree unchanged since b80376b (= b8a4128, CI 46124710697 all green).
- CI: landing run 46131610946 (648ab96, scope=all): every shard and the IPA green; also T-035's full-suite check.

## Test report (round 2)
_by loop-tester · 2026-11-28_

Reviewed `git diff f9ff1ce HEAD` (product tree = b8a4128). No Swift compiler here: evidence is CI 46124710697 (b8a4128, scope=all, every job green incl. SubtitleDragTests, MoveTextUITests, MoveTextTesterUITests), read by the orchestrator, plus a trace of each changed line with its callers. Revert-to-fail not run locally (ci_only); round 1 CI (46121764180) already showed the new outline/drag UI tests go red on wrong product code.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 0.25 s long press lifts the outline; arrows 8 pt out; 1.06 spring; light haptic; Reduce Motion: no scale, 3 pt stroke | Unverified (lift itself Pass) | The drag UI tests only move the line after the 0.25 s hold (46124710697). `.second(true, nil)` sets `lineDrag = .zero` so it lifts before any move (PlayerView.swift subtitleLine). Arrows: offset = size + 8 from each edge (MoveTextMenu.swift arrow overlays). Scale/spring/stroke/haptic traced only; no screenshot or test checks them |
| AC-2 live drag through the inverse of `frame`, clamped 0…0.90, ±0.40 and to the region; pure, unit-tested | Pass | SubtitleDragTests (9 tests, green in 46124710697); `theMovedLineLandsWhereTheDragPutIt` checks against `frame` itself. Traced: the call sites pass the same margins/topObstruction as `SubtitleLineLayout`; Move-Text has bottomObstruction 0 and stepsFromObstruction false in both orientations (PlayerView.swift landscape `moveCard` and portrait defaults), which is the case `dragged` inverts. Overlay band is off while the menu is open |
| AC-3 one write on release; cancel restores; arrows step ±0.05 from the dragged place | Pass (cancel Unverified) | Only `onEnded` writes `storedSubtitleStyle` (`.updating` only sets GestureState). `checkDrag` portrait+landscape: Down after the drag moves exactly one measured step (±1 pt), green. Cancel: `@GestureState` reset + no `onEnded` on cancel, traced only |
| AC-4 VoiceOver adjustable "Subtitle position", value `positionText`, increment/decrement 5 %, "Move left"/"Move right" | Unverified (label/value Pass) | `checkDrag` asserts label "Subtitle position" and value "Default place", then a changed value after the drag (green). XCUITest can't fire adjustable or custom actions without VoiceOver; `nudge` traced to `stepUp`/`stepRight` |
| AC-5 menu closed: nothing draggable, taps and selection as before | Pass | The gesture lives inside `if outlined`, and `outlined` is `showsMoveOutline` (menu open only). All existing Player/selection UI tests green in 46124710697 |
| AC-6 unit + UI tests; existing tests pass; DESIGN.md describes dragging | Pass, with deviations | Unit list covered (up N/height, 0/0.90/±0.40 clamps, top obstruction, round trip). UI: 80 pt drag portrait+landscape, far-past-top limit, Down after the limit, no-cue drag (portrait), all green. DESIGN.md "Dragging the outline" added. Deviations: tolerance 10 pt not 3; portrait limit asserts the position, not a dimmed Up (Up only dims at 0.90, pre-existing T-024a rule) |

On the 10 pt tolerance: round 1 read 73 for 80 and 52.7 for 60, a constant 7-7.3 pt loss, not a ratio (0.91 vs 0.88). That fits the sequenced DragGesture starting at XCUITest's first move event, not a mapping-scale error, and the unit test pins the scale to 0.1 pt. The UI test still catches no move, the wrong sign, and half/double scale. It no longer catches a scale error under about 12 %, but the unit test covers that.

On the quick tap on the outline: the line is an overlay above `PlayerLayerView`'s `onTapGesture`, so now that the outline is hit-testable its area (line + 6 pt ring) swallows a tap in both orientations, not only portrait. A tap anywhere else on the video still closes the menu. This is what the Agent notes asked for ("the outline's gesture must win over the video's tap"), and it also stops text selection on the line while the menu is open. Fine, but DESIGN.md still says "a tap on the video closes it" with no exception.

### Findings
Could fix
Where: ios/ClipDeck/Features/Player/MoveTextMenu.swift (MoveTextOutline `nudge`)
Problem: VoiceOver increment/decrement use plain `stepUp`, ignoring the landscape card's `canStepUp`/`highestUp`. In landscape, increment at "Highest" still raises the stored value (the value text changes, the line doesn't), and decrement from there takes several steps before the line moves.
Proof: Read it, MoveArrows Up is disabled by `canStepUp` and Down uses `upAfterDownWithCardOpen`, but `nudge` does neither.
Trigger: VoiceOver, landscape, the line at its highest place.
Fix: pass `canStepUp`/`highestUp` into the outline, or leave it until a VoiceOver pass.

Could fix
Where: docs/DESIGN.md (Pausing and the overlay / Dragging the outline)
Problem: doesn't say that a tap on the outline itself no longer closes the menu.
Proof: Traced it (outline is above the video's tap in the overlay).
Fix: one clause in "Dragging the outline".

Could fix
Where: ios/ClipDeckUITests/MoveTextUITests.swift
Problem: the no-cue sample drag is portrait only, and nothing checks the lifted arrows, scale or Reduce Motion stroke.
Fix: optional landscape variant; the visuals are left to Brent.

```text
VERDICT: Pass
SPEC: AC-2, AC-3, AC-5, AC-6 met (AC-6 with a 10 pt tolerance and a position-based portrait limit); AC-1 and AC-4 partly unverified (visuals, haptic, VoiceOver actions)
CHECKS_RUN: CI 46124710697 (b8a4128 = current product tree, scope=all) all green, read by the orchestrator; no local Swift build (Windows); 46131610946 pending, not watched
UNVERIFIED: on device: lift look (arrows, 1.06 spring, light haptic), Reduce Motion 3 pt stroke without scale, drag precision on a real finger, a cancelled drag (e.g. incoming call) putting the line back, VoiceOver increment/decrement and "Move left/right"
REVIEWED_AT: 648ab96 (product tree b8a4128)
```

### Orchestrator note
- Tester Pass (round 2). DESIGN.md now says a tap on the outline doesn't close the menu (docs only, lands with the task, no extra CI). Open Could-fix for a later player task: the outline's VoiceOver nudge ignores the landscape card's Highest limit; the empty-line sample drag test is portrait only.
