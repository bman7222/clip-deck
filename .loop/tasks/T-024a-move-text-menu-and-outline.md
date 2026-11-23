---
id: T-024a
title: Move-Text button and menu with the blue outline
lane: frontend
depends_on: [T-021, T-023]
status: todo
round: 0
base_sha:
issue: 26
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Move the subtitles from their own Move-Text menu, with a blue outline showing where the line goes

### What are we building?
Moving the line is tucked away inside the Font menu today. After this task a new ✥A button next to Aa opens a Move-Text menu: four arrows, the current place in words, a Reset for the position only, and Done. A blue outline shows where the line is, or where it will be when no line is showing. Portrait gets a short sheet under the video; landscape gets a compact card in place of the top bar. Opening the menu pauses the video. The Font menu keeps its arrows until T-024b.

### Why?
Positioning becomes a clear job of its own, and the outline shows the place even between lines.

### Done when
- AC-1 Button: an "A" with four small outward arrows, drawn as a SwiftUI view, in `DeckIconButtonStyle`. It's aqua when the position isn't the default. Id `player.moveText`, label "Move subtitles", value = `positionText`. It sits right after Aa in portrait and in every landscape bar variant, at T-021's markers.
- AC-2 Portrait: a sheet `moveText.sheet`, sized with SheetFit/SheetClearance like the Font sheet so the video and the line stay visible. It holds:
  - a title;
  - arrows `moveText.left|up|down|right`, each ±5 % per tap, dimmed at its limit, with spoken values as today;
  - a value line `moveText.value`;
  - Reset `moveText.reset` (icon `arrow.counterclockwise`), which calls `resetPosition()` only and is disabled at the default place;
  - Done `moveText.done`.
- AC-3 Landscape: a compact card `moveText.card` with the same controls replaces the top bar. The value text drops out first if the row doesn't fit. While it's open, the bottom bar and the centre overlay are hidden, so the line shows at its true saved place, with the card as the only obstruction (at the top). Up dims, with the value "Highest", when one more step can't visibly move the line: the T-018 rule with `stepsFromObstruction: false` and the card as the top obstruction. The first Down from above the reachable top jumps to one step below it (T-018 AC-5). The controls stay up while the card is open.
- AC-4 Pausing: opening the menu pauses the video if it's playing. Done, a swipe-down of the sheet, or a tap on the video closes the menu, and playback resumes only if opening the menu paused it. A rotation closes the menu without resuming.
- AC-4b The centred overlay (T-021) is hidden while the menu is open, in both orientations (Q3, Brent 2026-11-22), so T-022's avoidance never moves the line while you position it. It returns when the menu closes on Done (or a swipe-down or a tap on the video) and then follows its normal rules: it stays while paused, and hides 3 s after playback resumes.
- AC-5 Outline `moveText.outline`: while the menu is open, a 2 pt `Theme.accent` rounded rectangle 6 pt outside the line's frame (the same `SubtitlePlacement` frame the line uses). With no line on screen, it frames a one-line sample "あいう Abc" in the current font and size, drawn at 50 % opacity in the subtitle style. It disappears when the menu closes.
- AC-6 UI tests in portrait and landscape:
  - ✥A sits right after Aa;
  - opening the menu while playing makes `player.playPause` read "Paused", and Done resumes playback; opened while paused, Done leaves it paused;
  - no `player.overlay.*` button exists while the menu is open, and opened while paused, the overlay is back after Done;
  - Up and Right move `player.subtitle` by 5 % of the region (±1 pt);
  - Reset puts the line back and leaves a seeded serif font and size alone;
  - with no cue (after 5.5 s) the outline exists, and with a cue it sits 6 ± 1 pt outside `player.subtitle` on every side;
  - in landscape, `player.topBar` and `player.bottomBar` are absent while the card shows, and Up dims at "Highest" just under the card, after taps that each moved the line by more than 1 pt.
  Every existing test passes, and DESIGN.md describes the menu and the outline.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check the new Move-Text UI tests and their frames, plus the SubtitleStyle* and PlayerLandscape* suites.
- Unverified for Brent: how the outline and the sample look on real subtitles.

### Agent notes
- Depends on: T-021 (the bar markers) and T-023 (fractions, `resetPosition()`, helpers with `stepsFromObstruction`). Source: spec T-024; section G "Move menu at the top in landscape", defaults 2 and 7.
- Q3, answered by Brent on 2026-11-22: hide the centred overlay while the Move-Text menu is open; it returns on Done (AC-3, AC-4b). Otherwise T-022's avoidance would push the line off its true place, and a drag (T-025) couldn't follow the outline.
- Code: the Aa button (PlayerView.swift:670-681) shows the pattern: a Button plus a presented state, never a Menu (Learned, iOS 26). The landscape top bar is at 435-462. The Font card replaces the bottom bar in the stack at 263-293; do the same for the top. `keepsControlsUp` is at 569, and the rotation reset at 91-103. SheetFit is in SubtitleStyleSheet.swift:59-130 and 231-400: reuse it, and pass the clearance (Learned).
- To get a no-cue state in a UI test, let the 6 s sample play to its end (it pauses there), or move the scrubber to about 0.97.
- Give the card a background so XCUITest reports its real frame (Learned: a `.contain` container reports the union of its children). Known flakes are in CONTEXT "Learned".
- From T-021/T-022/T-034 (orchestrator, 2026-11-23):
  - The overlay already hides while either Aa menu is open, in both orientations (`showsOverlay` in PlayerView.swift; DESIGN.md "Style menus"). Extend that same gate for Move-Text instead of adding a parallel one. T-022's avoidance follows `showsOverlay`, so the line then sits at its true place.
  - UI tests: build on `ios/ClipDeckUITests/UITestSupport.swift` (`launchAndOpenSampleEpisode`, `rotateToLandscape` with its idle-stall guard, `readTogether`, `tapStep`). Use `-uiTestingSampleSeconds 30` for anything checked while playing. Landscape taps within about 50 pt of the leading edge land on the Dynamic Island (Learned). Put a new UI class in `SHARD1_UI`.
  - Optional Could fix (test support):
    - C3: after a failed snapshot, `UITestSupport.readTogether` (UITestSupport.swift:184-187) can sit silent for 20 s on a slow runner. Check `exists` before the snapshot.
    - T-034's carry-overs: `UITestAnimationWatch` logs iOS 26 Liquid Glass animations (infinite duration, no delegate) as noise; skip them, and reword docs/DEVELOPMENT.md:167-170. The 6 mid-test landscape rotations are unguarded.

### Out of scope
- Removing the Font menu's arrows and splitting its Reset (T-024b).
- Dragging the outline (T-025).
