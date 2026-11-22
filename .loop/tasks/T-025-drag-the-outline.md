---
id: T-025
title: Drag the outline
lane: frontend
depends_on: [T-024a]
status: todo
round: 0
base_sha:
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
