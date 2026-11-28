---
id: T-024a
title: Move-Text button and menu with the blue outline
lane: frontend
depends_on: [T-021, T-023]
status: done
round: 2
base_sha: f8a3656b12e856e25eabb865c2340b8103eb8572
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
  - From T-023's tester:
    - **C1, important:** the landscape Move-Text card sits at the top, so use `stepsFromObstruction: false` there. When you do, pass `bottomObstruction: 0`, because the card hides the bottom bar. Otherwise `highestReachableUp` returns 0 when the line starts pinned at the bottom, and a Down from 0.5 would jump to 0 (SubtitlePlacement.swift:133-151; unit test `stepsFromObstructionFalseCountsFromTheRegionBottom`).
    - C2 (optional): an invalid new `up`/`right` key falls through to a valid old `upSteps`/`rightSteps` (SubtitleStyle.swift:81-90). CLAUDE.md:48 says invalid values give the default. Keep the code and reword the CLAUDE.md line to match.
    - T-023's API: `up`/`right` are Doubles, `stepUp(_:)`/`stepRight(_:)` take an Int number of 5 % steps, and there are `resetPosition()`, `isPositionDefault`, `positionText`, `highestReachableUp(...) -> Double` and `upAfterDownWithCardOpen(stored:highestReachable:)`.
  - Optional Could fix (test support):
    - C3: after a failed snapshot, `UITestSupport.readTogether` (UITestSupport.swift:184-187) can sit silent for 20 s on a slow runner. Check `exists` before the snapshot.
    - T-034's carry-overs: `UITestAnimationWatch` logs iOS 26 Liquid Glass animations (infinite duration, no delegate) as noise; skip them, and reword docs/DEVELOPMENT.md:167-170. The 6 mid-test landscape rotations are unguarded.

### Out of scope
- Removing the Font menu's arrows and splitting its Reset (T-024b).
- Dragging the outline (T-025).

## Implementation notes (round 1) · sonnet
_by loop-frontend · 2026-11-23_
- Changed: new `MoveTextMenu.swift` with `MoveTextGlyph` (an "A" with four small outward arrows, SwiftUI), `MoveTextSheet` (portrait; the first detent is fitted with `SheetFit`/`SheetClearance` and the rise cached by `SubtitleStyleSheet`), `MoveTextCard` (landscape, in place of the top bar; value text drops out first via `ViewThatFits`) and `MoveTextOutline` (2 pt accent `strokeBorder`, padded -6 so its element frame is exactly 6 pt outside the line). `PlayerView` gets the `player.moveText` button right after Aa (portrait and every landscape row), the sheet/card states, pause-and-resume (`moveTextPausedIt`; one `onChange(of: moveTextOpen)` resumes after Done, a swipe down or a tap on the video; the rotation handler clears it first so a rotation never resumes), the overlay gate (`showsOverlay` now also excludes the Move-Text menu), `keepsControlsUp`, and a no-cue sample "あいう Abc" (50 % opacity, id `moveText.sample`) so the outline always has a frame.
- Landscape placement: top obstruction = measured card height + `Spacing.s`, bottom obstruction 0 (T-023 C1), `stepsFromObstruction: false` for both `canStepUpWithCardOpen` and `highestReachableUp`; Down uses `upAfterDownWithCardOpen`. The line size is always taken as measured while the card is open (the line or the sample is always drawn).
- `StyleIconButton` got an optional `prefix` (default `subtitleStyle`, so no id changed); `SheetTopProbeView` is no longer `private` so the Move sheet reuses it.
- Could-fixes taken: C2 CLAUDE.md fall-through line reworded; C3 `UITestSupport.readTogether` checks `exists` first; `UITestAnimationWatch` skips infinite, delegate-less "Match" animations and docs/DEVELOPMENT.md says so. Not done: the 6 unguarded mid-test rotations (T-034 carry-over).
- Docs: DESIGN.md has a new "Move-Text menu and outline" section and the bar order shows ✥A.
- Tests: new `MoveTextUITests` (SHARD1_UI), 11 tests: button after Aa (both orientations); portrait pause/resume with Done; opened paused stays paused and the overlay returns; tap on the video closes the sheet; Up/Right move the line 5 % of the region (±1 pt); Reset keeps a seeded serif 150 % style; outline 6 ± 1 pt around a line and around the sample (scrubber at 0.97); landscape card hides both bars and the overlay, Done resumes; landscape opened paused; landscape Up taps each move the line more than 1 pt until Up dims at "Highest" with the line 8 ± 2 pt under the card; landscape outline gap.
- Checked: nothing compiled or run here (Windows, CI only). I read each identifier against the existing code by hand.
- Tester, look at: (1) compile: `StyleIconButton(... prefix:)` argument order, `private struct MoveArrows` used from `MoveTextCard`; (2) the outline element's frame (`.accessibilityElement()` on a padded shape must report the padded rect, else the 6 pt tests fail); (3) the landscape pause test taps Move-Text within the bar's 3 s after Play (about 1.6 s of slack) and reads `player.playPause` after Done, showing the controls first if they hid; (4) portrait sheet height: first detent from the cached rise, so a first-ever open may sit a few points off until it self-corrects; (5) the Aa sheet is still tappable while the Move sheet is open (background interaction), so the buttons ignore a tap while the other menu is open; (6) a rotation with the menu open should close it and stay paused (not tested).
- Gotchas: the sheet's fit code is a copy of `SubtitleStyleSheet.fitFirstDetent` minus the font picker (T-024b can dedupe); the Move-Text sheet and Aa sheet are never presented together by design.
- CI: ClipDeckTests + `ClipDeckUITests/MoveTextUITests`, plus the Aa/overlay classes it touches: `SubtitleStyleCardTesterUITests`, `SubtitleStyleSheetTesterUITests`, `SubtitleUpLimitTesterUITests`, `PlaybackOverlayUITests`, `SubtitleAvoidOverlayUITests`, `PlayerLandscapeUITests`, `PlayerLandscapeBehaviourUITests`.

## Test report (round 1)
_by loop-tester · 2026-11-23 11:05_

CI 45204137687 (63f71d8, scope=all, CI run 1 of 4). The app builds: the ipa job is green. Shards 2 and 3 are green (29/29 and 28/28). Shard 1 is red on 1 of 391 runs, so 447 of 448 runs passed with 0 other test issues. The one failure is the new `MoveTextUITests/testUpAndRightMoveTheLineByFivePercentPortrait`, failing on a bug in the test, not in the app (M1). Name set: T-023's landing set (398) + 13 new MoveTextUITests = 411, none lost. The builder's notes say 11, but the class has 13 tests. Evidence: %TEMP%\clip-deck-loop\T-024a-r1 (`run/`, `base/` = 45174397249, xcresult Data/ pruned; `rec-upright/` recording frames; `cmpattach-vs-45174397249.txt`; `freeze-pid13956-excerpt.txt`).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 Button: an "A" with four small outward arrows, drawn as a SwiftUI view, in `DeckIconButtonStyle`. It's aqua when the position isn't the default. Id `player.moveText`, label "Move subtitles", value = `positionText`. It sits right after Aa in portrait and in every landscape bar variant, at T-021's markers. | Partly (pending verify) | 45204137687: testButtonSitsAfterAaPortrait/Landscape pass. Portrait Aa (184,401) → ✥A (236,401); landscape Aa (246,327.7) → ✥A (298,327.7); both 8 pt gaps, label "Move subtitles", value "Default place". The recording frame (rec-upright/frame-000013.png) shows the glyph as "A" with 4 arrows, plain at the default place. Not run yet: aqua away from the default, and the panel-25 %/50 % bar variants. The panel-50 % bar is now the two-row variant (see cmpattach). Tester test `testButtonFollowsAaInEveryLandscapeBarVariantAndTheCardFitsAtHalfWidth` and `testFirstDown…` attach element screenshots of both button states. |
| AC-2 Portrait sheet `moveText.sheet`, SheetFit/SheetClearance like the Font sheet so the video and the line stay visible: a title; arrows `moveText.left\|up\|down\|right`, each ±5 % per tap, dimmed at its limit, with spoken values as today; a value line `moveText.value`; Reset `moveText.reset` (icon `arrow.counterclockwise`), `resetPosition()` only, disabled at the default place; Done `moveText.done` | **Fail** (test) | Sheet top 350.4 (innermost container; the grabber is at 345.6) is under the video bottom 342.0, so the line and the outline (y 300–336) stay visible. The title, the 4 arrows, the value text, Reset (with an `arrow.counterclockwise` image) and Done are all there (move-sheet-open tree). testResetPutsTheLineBackAndKeepsTheFontPortrait passes: "Up 20% · Left 20%" → "Default place", Reset disabled, Aa still shows 150 percent and serif selected. **±5 % per tap is not proven**: testUpAndRight… failed at :123 (M1). Its recording shows Up working (the last frame reads "Up 5%", Reset is enabled, and the line moves about 10 pt = 5 % of the 206 pt region), but the Right step and both ±1 pt frame checks never ran. "Dimmed at its limit": only Down at the default is seen; tester test `testArrowsDimAtTheirLimitsPortrait` covers Up 90 %, Left 40 % and Reset's frame |
| AC-3 Landscape card `moveText.card` replaces the top bar; value text drops out first; bottom bar and overlay hidden, line at its true place, card the only (top) obstruction; Up dims "Highest" (T-018 rule, `stepsFromObstruction: false`); first Down from above the reachable top jumps one step below it; controls stay up while open | Partly (pending verify) | move-card-open: card (0,0,874,60) and no `player.topBar`, `player.bottomBar` or `player.overlay.*`. move-card-up-taps: 16 Up taps, each moves the line (18.0–18.3 pt, the last 6.67 pt), from y 346 to 68.0 = card maxY 60 + 8. At "Highest" the stored value is "Up 80%" (Down "80 percent up"). So T-023 C1 is done right (bottomObstruction 0 and `stepsFromObstruction: false`: Up doesn't dim at 0). The card stayed up through the whole climb. Not run yet: the first-Down jump and the value text dropping out. Tester tests `testFirstDownFromAboveTheReachableTopMovesTheLineLandscape` (seed 0.9: expects "Highest" at y 68, Down → 75 % with a visible move, Up → back to 68) and the half-width card check |
| AC-4 Opening pauses a playing video; Done, a swipe-down or a tap on the video closes; resumes only if opening paused it; rotation closes without resuming | Partly (pending verify) | Portrait: testSheetPausesAndDoneResumesPortrait passes ("Paused" while open, "Playing" after Done). Opened paused, Done leaves it paused (portrait and landscape tests pass). testATapOnTheVideoClosesTheSheetPortrait passes. Landscape "pauses" is not proven: testCardReplacesTheBarsAndPausesLandscape only reads "Playing" after Done, which would also pass if opening never paused (C1). Swipe-down and rotation have no test. Tester tests `testOpeningTheCardPausesPlaybackAndDoneResumesLandscape` (the card held open 18 s; elapsed must stay under 18 s), `testSwipeDownClosesTheSheetAndResumesPortrait` and `testRotationClosesTheMenuWithoutResuming` |
| AC-4b Overlay hidden while the menu is open (both orientations); returns on close and follows its rules | Pass | testOpenedWhilePausedStaysPausedAndTheOverlayReturnsPortrait/Landscape: the overlay goes while the menu is open and is back after Done. move-card-open has no `player.overlay.*` while playing |
| AC-5 Outline `moveText.outline`: 2 pt `Theme.accent` rounded rect 6 pt outside the line's frame; with no line, a one-line sample "あいう Abc" in the current font and size at 50 % in the subtitle style; gone on close | Pass | Gaps L/T/R/B are 6.0/6.0/6.0/6.0 for the portrait line, the landscape line and the portrait sample (move-outline-*). Pixels (03AE882A…png): the stroke is exactly 2 pt (6 px) of (26,139,196) = AccentColor light. The sample fill is (228,170,197) = 50 % white over the video (201,85,138), and its edge is 50 % black; the real line is opaque. With the card open between cues, the sample shows in landscape too (move-card-open). The outline is gone after Done in both outline tests |
| AC-6 UI tests in portrait and landscape (7 bullets); every existing test passes; DESIGN.md describes the menu and the outline | **Fail** | 12 of 13 MoveTextUITests pass. The Up/Right 5 % bullet fails (M1). Every existing test passes: 435 of 435 runs outside MoveTextUITests. cmpattach vs 45174397249: 63 of 68 text attachments identical. The 5 differences are explained: 3 show the panel-50 % transport row at y 277.3 instead of 327.7, because ✥A pushes the bar into its two-row variant; 2 are skip-countdown timing logs. DESIGN.md:91-98 has the section, and the bar order shows ✥A |

Carry-overs checked: CLAUDE.md:48 now states the fall-through, which matches SubtitleStyle.swift:81-90. `readTogether` checks `exists` before the snapshot (UITestSupport.swift:186). UITestAnimationWatch: shard 1's app stdout had 102 "Match" lines in 45174397249 and has 0 now, and the spinner lines still print, so the watch still runs. docs/DEVELOPMENT.md:169 says so. The 6 unguarded mid-test rotations were not done, as the notes say.

Idle-stall guard: it fired twice and both tests recovered and passed: MoveTextUITests/testCardReplacesTheBarsAndPausesLandscape (probe 60.0 s, relaunch, 0.4 s) and SubtitleStyleCardUITests/testDoneAVideoTapAndARotationEachCloseTheCard (shard 3, probe 60.1 s). There was also a new kind of stall in testButtonSitsAfterAaPortrait: a 57.9 s wait after "Tap episode.row". The animations-idle replies were instant, but the main run loop didn't go idle until 15:36:49, and UIKit logged "_UISystemGestureGateGestureRecognizer … is blocking its subgraph for 57.47 seconds". The app logged nothing for 57 s after the player push, then audio setup started. That points at player setup, which this diff doesn't touch, and the test passed. I'm treating it as pre-existing.

Shard times (job): shard 1 33:49 (base 31:05; testing span 30.9 min against 24.6), shard 2 28:08, shard 3 26:51. MoveTextUITests adds 556 s to shard 1, and about 2 min of that is the stall and the freeze. That is under 35 min, but close (C2).

Mutation check: not run. This is CI-only and I may not dispatch.

### Tests added
- `ios/ClipDeckUITests/MoveTextTesterUITests.swift` (new class, so it lands in shard 3; **not run yet**), 6 tests: bar variants at panel closed/25 %/50 % plus the half-width card (every control hittable inside the card and the video column, plus element screenshots of the default button and the card); first Down from a seeded 0.9 (the jump, Up back, then an element screenshot of the aqua button); arrow limits and Reset's frame in portrait; the landscape pause (card held 18 s); the swipe-down resume; rotation without resume. The expected numbers come from this run's frames: the line is 24 pt tall, the card is 60 pt, and the reachable top is 0.80 at y 68.

### Findings
Must fix M1
Where: ios/ClipDeckUITests/MoveTextUITests.swift:123 and :127
Problem: `tapStep` uses `moveText.value` as its reader, but that SwiftUI Text has only a label and no accessibility value. `waitForValue` never matches it, so the test fails after the first Up tap. The Right step and both "5 % of the region (±1 pt)" frame checks never run, which leaves AC-2/AC-6 "Up and Right move `player.subtitle` by 5 %" unproven.
Proof: Ran it. CI 45204137687 shard 1: "XCTAssertTrue failed" at :123. The tree in move-sheet-open shows `StaticText … identifier: 'moveText.value', label: 'Default place'` with no value. The recording's last frame shows "Up 5%" and the line moved, so the app is right.
Trigger: every run of the test.
Fix: read a button's value instead. For Up use `app.buttons["moveText.down"]`, from "At the default height" to "5 percent up". For Right use `app.buttons["moveText.left"]`, from "Centred" to "5 percent right". Or add a label-based `tapStep` to UITestSupport.

Could fix C1
Where: ios/ClipDeckUITests/MoveTextUITests.swift:203-229
Problem: the landscape pause test reads "Playing" only after Done, so it would also pass if opening the card never paused.
Fix: none needed from the builder. `MoveTextTesterUITests/testOpeningTheCardPausesPlaybackAndDoneResumesLandscape` covers it.

Could fix C2
Where: .github/workflows/ios-simulator.yml SHARD1_UI
Problem: shard 1 now takes 33:49 against the 35-min target (MoveTextUITests 556 s). Shard 3 has the most room (26:51) and gets the tester class.
Fix: if shard 1 grows again, move a class out of SHARD1_UI.

Could fix C3
Where: ios/ClipDeck/Features/Player/PlayerView.swift:804-807
Problem: only the Move-Text button guards against the other menu. Aa has no `moveTextOpen` guard, although the notes say "the buttons ignore a tap". Today Aa can't be reached while the menu is open: in portrait it sits at y 401, under the sheet that starts at 350.4, and in landscape the bottom bar is hidden.
Fix: add the symmetric guard, or fix the note.

```text
VERDICT: Fail
SPEC: AC-1 partly (aqua and the panel-open variants pending the tester test); AC-2 fail (5 % step test broken, M1); AC-3 partly (first-Down jump and value-text drop pending); AC-4 partly (landscape pause, swipe-down and rotation pending); AC-4b met; AC-5 met; AC-6 fail (M1)
CHECKS_RUN: CI 45204137687 (63f71d8, scope=all) → ipa ok; shard 2 29/29, shard 3 28/28, shard 1 390/391 (fail: MoveTextUITests/testUpAndRightMoveTheLineByFivePercentPortrait at :123, test bug); 411 names = 398 + 13; cmpattach vs 45174397249 → 63 same, 5 explained; idle-stall guard fired 2× (both recovered)
UNVERIFIED: Brent: how the outline and the sample look on real subtitles (device), and in dark mode. Pending the next run: MoveTextTesterUITests (6 tests)
REVIEWED_AT: 63f71d81500f3381a1cc084ad03104ba1e009711
```

## Fix round 2
Round 1 failed M1: the test read moveText.value (a Text, which has no accessibility value). The app itself worked. Brent's decisions (2026-11-23):
- Sonnet retry. Fix M1 the way the tester suggested.
- Keep and commit the tester's MoveTextTesterUITests.swift.
- **Add a 4th parallel simulator job now.** Shard 1 took 33:49 against the 35-minute target. Split the UI tests four ways: SHARD1_UI, SHARD2_UI, SHARD3_UI as explicit lists, and shard 4 = everything else (skip-testing the three lists plus ClipDeckTests), so new classes still land somewhere. Aim for about 22–25 min each, using the per-class times in the round 1 Test report and the CONTEXT Learned timings. Keep T-020's rules: one job for a non-empty only_testing, an empty list leaves its shard out, and artifacts simulator-results-1..4. Update docs/DEVELOPMENT.md and CLAUDE.md. A full run is needed this round, because the workflow changes.
- C3 (Aa has no guard against the Move-Text menu): add the guard, so the menus are exclusive both ways.

## Implementation notes (round 2)
_by loop-frontend · 2026-11-23_
- M1 fixed: `MoveTextUITests.testUpAndRightMoveTheLineByFivePercentPortrait` now steps with `tapStep` on a button's spoken value: Up reads `moveText.down` ("At the default height" to "5 percent up"), Right reads `moveText.left` ("Centred" to "5 percent right"). The `moveText.value` label is asserted separately ("Up 5%", "Up 5% · Right 5%"). The two ±1 pt frame checks are unchanged.
- Tester's `MoveTextTesterUITests.swift` kept as written; it is in SHARD3_UI.
- 4th shard: the workflow now has SHARD1_UI, SHARD2_UI and SHARD3_UI as explicit lists and shard 4 = everything else (`-skip-testing` of ClipDeckTests and the three lists). A non-empty only_testing still runs one job (shard 1), an empty list leaves its shard out, whitespace is trimmed, artifacts `simulator-results-1` to `-4`. Split (an estimate from the round 1 job times and the CONTEXT per-class minutes, so it may need one rebalance):
  - shard 1 = ClipDeckTests + the old list without MoveTextUITests (about 33:49 less MoveText's 9.3 min);
  - shard 2 = the old list without PlaybackOverlayTesterUITests;
  - shard 3 = MoveTextUITests, MoveTextTesterUITests, SubtitleStyleSheetTesterUITests, SubtitleStyleCardUITests;
  - shard 4 = the rest (PlaybackOverlayTester, Expiry, Launch, MKVImport, PlayerLandscape, SubtitleStyleTester, new classes).
  Workflow comment, docs/DEVELOPMENT.md and CLAUDE.md updated (no class lists in the docs).
- C3: the Aa button now returns at once while the Move-Text menu is open (`guard !moveTextOpen`), so the menus are exclusive both ways.
- Checked: nothing compiled or run (CI only). A full run is needed because the workflow changed.
- Tester, look at: the plan job's matrix output (4 entries for scope=all; 1 for only_testing), each shard's job time, and that every class ran once (name set 411 + 6 tester tests = 417).

### CI round 2
- CI: pending, run 46092855663 (c7b4e65, scope=all). Dispatched once; not watched. Local gate: diff check and workflow YAML parse passed (no Swift build possible on Windows).

## Test report (round 2)
_by loop-tester · 2026-11-27 20:31_

CI 45230680205 (c7b4e65, scope=all, status from the orchestrator): plan, ipa and simulator shards 1–4 all succeeded (CI run 2 of 4). Duplicate 46092855663 on the same SHA ignored; the Implementation notes cite it as the dispatched run. Following the token policy, I did not download artifacts or read logs for this green run, so the 417-name count and the per-class times are not re-counted. Reviewed `git diff 63f71d8 c7b4e65` and the full task diff.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 Button: an "A" with four small outward arrows, drawn as a SwiftUI view, in `DeckIconButtonStyle`. It's aqua when the position isn't the default. Id `player.moveText`, label "Move subtitles", value = `positionText`. It sits right after Aa in portrait and in every landscape bar variant, at T-021's markers. | Pass (aqua pixels not opened) | Round 1 frames (glyph, id, label, order). 45230680205: `MoveTextTesterUITests/testButtonFollowsAaInEveryLandscapeBarVariantAndTheCardFitsAtHalfWidth` passed: same row, gap 0–16 pt, hittable, with the panel closed and at 25 % and 50 %. `testFirstDown…` passed and read the value "Up 90%". The aqua tint uses the same `isActive: !position.isPositionDefault` path as Aa (PlayerView.swift:821 vs :811). The element shot `tester-move-button-changed` is in simulator-results-3 but I did not open it |
| AC-2 Portrait sheet `moveText.sheet` … title; arrows ±5 % per tap, dimmed at their limits, spoken values; `moveText.value`; Reset `resetPosition()` only, disabled at default; Done | Pass | M1 fixed: `MoveTextUITests/testUpAndRightMoveTheLineByFivePercentPortrait` steps via `moveText.down` ("At the default height" → "5 percent up") and `moveText.left` ("Centred" → "5 percent right"). Both ±1 pt frame checks and the label checks now run, and the test passed in 45230680205. `testArrowsDimAtTheirLimitsPortrait` passed (Up dims at 90 %, Left at 40 % left, Down at the default; Reset re-centres the line on the region bottom and is then disabled). The sheet fit is in round 1 |
| AC-3 Landscape card replaces the top bar; value text drops out first; bottom bar and overlay hidden; Up dims "Highest" (`stepsFromObstruction: false`); first Down jumps one step below the reachable top; controls stay up | Pass | Round 1 (card frame, bars and overlay absent, 16-tap climb to "Highest" at card + 8). 45230680205: `testFirstDownFromAboveTheReachableTop…` passed (seed 0.9 opens with Up dimmed at "Highest" with the line 8 ± 2 pt under the card; the first Down moves the line and is not "85 percent up"; one Up returns within 1.5 pt and dims again). At panel 50 % every control is hittable inside the card and the video column (the value-text drop-out itself is logged, not asserted). `testOpeningTheCard…` checks the card stays up for 18 s |
| AC-4 Opening pauses a playing video; Done / swipe-down / tap on the video closes; resumes only if opening paused it; rotation closes without resuming | Pass | 45230680205: `testOpeningTheCardPausesPlaybackAndDoneResumesLandscape` (elapsed < 18 s after an 18 s hold, then "Playing"), `testSwipeDownClosesTheSheetAndResumesPortrait` ("Paused" while open, "Playing" after the swipe), `testRotationClosesTheMenuWithoutResuming` ("Paused", elapsed unchanged over 2 s), plus the round 1 tests (Done, video tap, opened-while-paused) |
| AC-4b Overlay hidden while open, returns on close | Pass | Round 1, re-run green in 45230680205 |
| AC-5 Outline 2 pt accent, 6 pt outside; sample "あいう Abc" at 50 % with no line; gone on close | Pass | Round 1 (gaps of exactly 6.0 pt, the stroke pixels, the sample's 50 %), re-run green in 45230680205 |
| AC-6 UI tests in portrait and landscape; every existing test passes; DESIGN.md describes the menu and the outline | Pass | All 13 MoveTextUITests and the 6 tester tests pass. All four shards are green, so every existing test passes. DESIGN.md:91-98 (round 1, unchanged) |

Round 1 findings: M1 fixed (above). C1 covered by the tester class. C2 handled by the 4th shard. C3 fixed: Aa now starts with `guard !moveTextOpen` (PlayerView.swift:806), which mirrors `openMoveText`'s guard (:722). No UI test can reach it, because Aa is covered or hidden while the menu is open (Read it).

4-shard plan (Ran it: the workflow's plan script with a jq stand-in, in the scratchpad):
- scope=all gives shards 1–4.
- 20 UI classes: 14 are listed with no duplicates, and every listed name is a real class. Shard 4 skips ClipDeckTests and the 14, so it runs the other 6 (ExpiryBanner, Launch, MKVImport, PlaybackOverlayTester, PlayerLandscape, SubtitleStyleTester).
- `only_testing="ClipDeckTests ClipDeckUITests/MoveTextUITests"` gives a single shard-1 job with screenshot false. A whitespace-only `only_testing` gives the full 4.
- Emptying SHARD2_UI gives shards [1,3,4]; emptying SHARD3_UI gives [1,2,4].
- Artifacts are `simulator-results-${shard}`.
- CLAUDE.md and docs/DEVELOPMENT.md match the workflow.

Shard times: 31 / 24 / 25 / 21 min. Shard 1 is at T-023's base (31:05 without MoveText). Removing MoveTextUITests did not give the estimated 24.5, because round 1's 33:49 was a fast run of the rest. 31 min is acceptable for landing, since it is 4 min under the 35 limit and wall time didn't grow. Cheap rebalance (C1).

Mutation check: not run. This is CI-only and I may not dispatch.

### Findings
Could fix C1
Where: .github/workflows/ios-simulator.yml:52 (SHARD1_UI)
Problem: shard 1 takes 31 min, against the 22–25 goal.
Proof: CI 45230680205 job times (from the orchestrator).
Fix: delete `SubtitleStyleCardTesterUITests` from SHARD1_UI. That is a one-word edit, and the skip rule then runs the class in shard 4. It took 3.7 min in 45002423211, so expect about 27 / 24 / 25 / 25. Do it in the next task that needs a full run anyway, not in a run of its own.

```text
VERDICT: Pass
SPEC: AC-1 met (aqua by code path and attached shot, not opened); AC-2 met; AC-3 met; AC-4 met; AC-4b met; AC-5 met; AC-6 met
CHECKS_RUN: CI 45230680205 (c7b4e65, scope=all) → plan, ipa, shards 1–4 success (31/24/25/21 min); plan script run locally with a jq stand-in → 4 shards / 1 for only_testing / empty lists dropped / 20 classes each in one shard
UNVERIFIED: Brent: how the outline and the sample look on real subtitles and in dark mode. Not opened: the aqua element shot `tester-move-button-changed` (simulator-results-3, 45230680205); the 417-name count
REVIEWED_AT: c7b4e65ac90165f5f62f1da31c42484257749205
```

## Debloat round (after the round 2 Pass)
Quality passes triggered: net product lines 396 (> 150) and comment share 13.5 % (> 10 %). Findings from the ponytail review (orchestrator, 2026-11-27):
- D1 (Should fix): `MoveTextSheet` copies about 60 lines of first-detent fitting from `SubtitleStyleSheet`: `MoveSheetFitKey`/`SheetFitKey`, `detents`, `backgroundInteraction`, `fitFirstDetent` and `useFirstDetent`. Move them into one shared modifier, for example `.fittedFirstDetent(clearance:paused:)`, where `paused` is the Aa sheet's font-picker wait, and use it in both sheets.
- D2 (Should fix, the pstack no-comments pass): delete the comments that restate code in the task's product diff and keep only the why-lines. The comment-sicko pass runs after D1/D3.
- D3 (Nice to have): one `SubtitleStyle.edited(_:_:)` for decode → change → clamp → json, replacing `movedStyle` and the copies at SubtitleStyleCard.swift:~172, SubtitleStyleSheet.swift:~640 and PlayerView.swift:168.
- Gate: if the round raises net product lines or breaks a test, revert it and land c7b4e65.

## Implementation notes (debloat)
_by loop-frontend · 2026-11-27_
- D1: one `FirstDetentFit` ViewModifier (`.fittedFirstDetent(clearance:waitWhile:)`) in SubtitleStyleSheet.swift now holds the detent state, `SheetFitKey`, detents, background interaction, `fitFirstDetent` and `useFirstDetent`, moved as written (450 ms settle, 12 x 100 ms, 0.5 pt test, `cachedRise` writes, same `.task(id:)` key). The Aa sheet passes `$showingFontPicker` as `waitWhile` (a Binding, so the loop reads it live); Move-Text uses the default `.constant(false)`. Both sheets keep a one-line `init(clearance:)` (private state keeps the memberwise init private).
- D3: `SubtitleStyle.edited(_:_:)` added; `movedStyle` removed; the `update` bodies in SubtitleStyleCard and SubtitleStyleSheet call it. PlayerView.swift:168 left alone: it only saves when `pickFont` succeeds, which `edited` can't express without contortion.
- Net: `git diff --numstat c7b4e65 -- ios/ClipDeck` is 128 added and 184 deleted, so about -56 lines. No identifier, behaviour or test file changed. Nothing compiled (CI only).

### Debloat result
- D1 and D3 done by the builder, D2 by the pstack comment-sicko pass (sonnet, medium). Product net went from +396 to +287, and the comment share from 13.5 % to 4 %. Code lines are unchanged by D2.
- Landing run: CI 46095180306 (scope=all, a3911e0), dispatched and not watched. It lands when it's green. If it's red, read only the failed step, and if the failure comes from the debloat, revert it and land c7b4e65 (green in 45230680205).
