---
id: T-015
title: Adjust the subtitle style from a menu in the portrait player
lane: frontend
depends_on: [T-014]
status: testing
round: 3
base_sha: 29491a8a99698de0de6b9141cd3e1ee961b711ca
issue: 16
spec: .loop/specs/subtitle-style.md
model: opus
---

## Adjust the subtitle style from a menu in the portrait player

### What are we building?
A new "Aa" button right next to the subtitles button in the portrait player. It opens a sheet with the style controls: three font chips, Bold, smaller and larger text, four arrows that move the line, Reset to default, and Done. Each tap changes the line on the video straight away, and the video stays visible above the sheet. The choice is remembered across launches.

### Why?
Brent can make the line easier to read, or move it off burnt-in text, without changing the iPhone's text size for every app.

### Done when
- AC-1 `player.subtitleStyle` is a `Button` (not a `Menu`) with the `textformat` icon in `DeckIconButtonStyle`. It is aqua when the style isn't the default, sits directly after `player.subtitlesMenu` in `transportButtons`, and has the label "Subtitle style". (Landscape shows it too. T-016 wires its card; until then it may open nothing in landscape, but must not break the bar.)
- AC-2 The sheet holds the spec's controls, each with its `subtitleStyle.*` identifier:
  - one row per font preset: the name, and the sample "Aa あア漢字" drawn in that font (so both scripts can be judged), aqua when selected. Leave room below the presets for T-017's "More fonts…" row;
  - `bold`, `textformat.size.smaller`, `textformat.size.larger`;
  - `arrow.up|down|left|right` and `arrow.counterclockwise`;
  - Done.
  The values show: "130%", and position like "Up 20% · Left 10%" or "Default place". The icons are distinct from each other, and the colours come only from the Theme tokens: idle Shell/Ink, on or selected Accent with white, values InkSoft. `DeckIconButtonStyle` gains a 0.45-opacity disabled look.
- AC-3 Each control changes the line live through T-014's mutators:
  - a button at its limit is disabled (size at 60%/200%, down at the default bottom, up at 18, left and right at ±8);
  - Reset is disabled while the style is the default;
  - playback is not paused.
- AC-4 VoiceOver hears a label and value on every control, for example:
  - "Larger text", "130 percent";
  - "Move subtitles up", "20 percent up";
  - "Bold", "On";
  - the selected font chip has the `.isSelected` trait.
- AC-5 Layout: the sheet uses `presentationBackground(Theme.panel)` and a fixed-height detent plus `.large`. At the default text size on iPhone 17 Pro, every control's minY is at or below `player.video`'s maxY. The content scrolls, so at an accessibility text size Reset can be reached.
- AC-6 `SubtitleStyleUITests` (portrait) checks:
  - opening the sheet; size up ×3 makes the `player.subtitle` frame taller and shows "130%";
  - up ×2 lowers its maxY; Serif and Bold off are selected or off;
  - relaunch with `-uiTestingKeepSubtitleStyle` keeps the style;
  - Reset brings back the default frame (±2 pt) and disables Reset;
  - size-up is disabled after reaching 200%;
  - a run with `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` scrolls to Reset;
  - attachments `style-01-sheet` and `style-02-large-text`.
- AC-7 DESIGN.md (player controls row and the new sheet: icons, colours, motion, accessibility) and PRODUCT_SPEC.md (core feature) are updated. Every existing test still passes.

### How to check
CI only:
1. `git push origin loop/subtitle-style`, then `gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=all`.
2. `gh run watch <id> --exit-status`. On failure, `gh run view <id> --log-failed`.
3. `./scripts/test-ios.sh` and `./scripts/build-ipa.sh` pass.
4. Download `simulator-results` and read the `style-01`/`style-02` screenshots: distinct icons, app colours, the video uncovered, the line changed.

Unverified for Brent: the feel on a real iPhone, and dark mode (unless a screenshot covers it).

### Agent notes
- Carried over from T-014's review (Could fix): C2: the subtitle line overlay is now drawn above RecordingBadge (PlayerView.swift:436), so a line moved up and left can cover the badge. Keep the badge on top, or keep the line clear of it. C3: SubtitleStyle step mutators (SubtitleStyle.swift:86-103) can overflow if a field is set to Int.max in code; clamp before adding.
- Depends on: T-014 (`SubtitleStyle`, its mutators, the seed and keep flags). Source: the spec's "Menu" section, and D-5, D-8.
- Learned: on iOS 26, a gesture on a `Menu` doesn't fire, so the opener is a Button with `@State` presentation.
- Call it "position", never "offset". `player.offset` is the timing offset.
- If `textformat.size.smaller`/`.larger` aren't available on iOS 17, draw a small and a large "A" instead.

### Out of scope
- "More fonts…" and the system font picker (T-017).
- The landscape card, landscape keep-up, and the 50% bar fit (T-016).
- Changes to the timing offset sheet.

## Implementation notes (round 1) · sonnet
_by loop-frontend · 
- Changed (nothing compiled here, CI only):
  - New `Features/Player/SubtitleStyleSheet.swift`: `SubtitleStyleSheet` (the portrait sheet) and a `nonisolated extension SubtitleStyle` with the menu texts (`sizeText` "130%", `positionText`, spoken values). The sheet owns its own `@AppStorage(SubtitleStyle.storageKey)`, so each tap writes the JSON the player already observes and the line changes live. The playback model is never touched, so it isn't paused.
  - `PlayerView`: `showStyleSheet` state, the sheet, and the `player.subtitleStyle` Button (`textformat`, label "Subtitle style", value Default/Changed, aqua when not default) placed after `player.subtitlesMenu` in `transportButtons`, so it is in portrait and in all three landscape rows. In landscape it opens the same sheet for now (T-016 replaces that with the card); rotating closes it, and it holds the landscape controls up (`keepsControlsUp`).
  - `DeckIconButtonStyle`: now a small View-backed style with the 0.45-opacity disabled look; the press-scale is skipped under Reduce Motion.
  - C2: the `RecordingBadge` moved from the ZStack into an `.overlay` after the line overlay, so it is drawn above the line.
  - C3: new `SubtitleStyle.clampedSum` (clamp, then `addingReportingOverflow`, then clamp) used by the three step mutators.
  - Docs: DESIGN.md (new "Subtitle style menu" section, components, motion, accessibility, player row), PRODUCT_SPEC.md.
- Sheet: header (title + Done pinned), then a ScrollView: Font rows (name + "Aa あア漢字" in that font, aqua+white when selected; stacked at accessibility sizes), Bold, Size ([smaller] value [larger]), Position (left, up, down, right + value line), full-width Reset. Detents `.height(520)` + `.large`, `presentationBackground(Theme.panel)`, background interaction on at the first detent so the video isn't dimmed. The "More fonts…" row goes where the comment says (under the presets, before Bold).
- Icons (all distinct): textformat, bold, textformat.size.smaller/larger, arrow.left/up/down/right, arrow.counterclockwise, checkmark. Colours only Theme tokens.
- Identifiers: `subtitleStyle.font.sans|rounded|serif`, `.bold`, `.sizeDown`, `.sizeUp`, `.left`, `.up`, `.down`, `.right`, `.reset`, `.done`, plus `.sizeValue`, `.positionValue`, `.title`.
- Tests: SubtitleStyleTests (+3: overflow, texts, limits); SubtitleStyleUITests (+5: sheet live + video uncovered + font/bold/size/position, keep flag relaunch, reset, 200% limit, XXXL scroll to Reset; attachments `style-01-sheet`, `style-02-large-text`).
- Gotchas: the sheet's frame checks use `player.video` read before opening; the line is measured after Done (an open sheet may hide the player from the accessibility tree). The tests use `reveal()` (swipe up until hittable) for controls under the first detent. Landscape bar fit at 50%: the third `ViewThatFits` row (icon Make a Card, no skips) gains one 44 pt button plus 8 pt, about 280 of about 320 pt; T-016 must prove it.
- Tester, look at: `style-01-sheet` screenshot (icons distinct, aqua only on selected/on, line changed, video uncovered); that background interaction doesn't let a tap on the video misbehave; the landscape bottom bar with the extra button at a 50% panel; the three Could-fix items above; XXXL (`style-02-large-text`).

## Test report (round 1)
_by loop-tester · 2026-11-21 02:38_

CI run 44878628011 (08f286b, scope=all). The `ipa` job is green, so the app compiles. The `simulator` job ran 316 tests: 315 pass and 1 fails. The failure is `EpisodeImporterTests/copiesAnMP4AndItsSubtitleIntoTheShowFolders()`, "Caught error: .timedOut". The diff doesn't touch it, and it also failed once on main (44838534920), so I count it as a pre-existing flake (added to CONTEXT Learned). The xcresult has no build warnings. All 5 new UI tests and all 3 new unit tests pass. All 14 landscape UI tests pass, including the known flakes.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `player.subtitleStyle` Button, `textformat`, `DeckIconButtonStyle`, aqua when not default, right after `player.subtitlesMenu`, label "Subtitle style"; landscape bar not broken | Pass | `testPortraitSheetChangesTheLineLiveAndLeavesTheVideoUncovered` checks the label, the value Default→Changed, and that it sits after `player.subtitlesMenu` in the same row. The `portrait-default` screenshot shows "Aa" after the captions button. In landscape at the 50% panel (`landscape-05-panel-max-frames`), the style button is at x 246–290 and Make a Card at 338.7–393, clear of the handle at 405. All 14 PlayerLandscape* tests pass. |
| AC-2 sheet controls, identifiers, sample "Aa あア漢字" per font, values, distinct icons, Theme colours only, 0.45 disabled look | Pass | `style-01-sheet`: three font rows each show the sample in their own font (Serif is aqua with white text), plus Bold `B`, smaller/larger `A`, four arrows, "130%", "Default place", Reset, and Done ✓. The disabled down arrow is visibly dimmed. The only literal colour in the diff is `.white`, on the selected or active state. The "More fonts…" slot is marked in `fontSection`. |
| AC-3 live changes through the mutators; each limit disables its button; Reset disabled at the default; playback not paused | Partly: Pass for live changes, 200%, down at the bottom and Reset. Unverified for 60%, up at 18, ±8 and "not paused" | The builder tests prove the line gets taller (130%) and higher (Up 10%), and that 200%, down-at-bottom and Reset disable. The other limits are wired only by reading the code, plus unit `can*` tests. No test plays the video: the builder tests run paused. New tester tests `testEveryLimitDisablesItsOwnButton` and `testUsingTheSheetDoesNotPausePlayback` haven't run yet. |
| AC-4 label and value on every control; the selected chip has `.isSelected` | Partly: Pass for values and isSelected. Unverified for labels | Builder test: sizeUp "130 percent", up "10 percent up", Bold On/Off, Sans/Serif `isSelected`. No test checks the labels ("Larger text", "Move subtitles up", "Serif font"), so tester test `testEveryControlStartsBelowTheVideoAndIsLabelled` checks every one. Font chips, Done and Reset have no value (chips use the selected trait as the AC allows). |
| AC-5 `presentationBackground(Theme.panel)`, fixed detent + `.large`, every control's minY ≥ video maxY, scrolls to Reset at XXXL | Pass as written; see S1 for the spec's "video uncovered" | SubtitleStyleSheet.swift:79-82. The builder's frame check (7 controls) and the XXXL test pass. `style-02-large-text` shows Reset reachable after scrolling. But the sheet itself covers the bottom 8 pt of the video (S1). |
| AC-6 SubtitleStyleUITests: open, size×3 taller + "130%", up×2 lowers maxY, Serif + Bold off, keep-flag relaunch, Reset frame ±2 + disabled, 200% limit, XXXL scroll, attachments | Pass | All 5 pass in 44878628011 (29.3 s, 35.3 s, 36.4 s, 14.4 s, 16.9 s). Both attachments are present. |
| AC-7 DESIGN.md + PRODUCT_SPEC.md updated; every existing test passes | Pass for docs. Existing tests: pass except a pre-existing flake | DESIGN.md has the new "Subtitle style menu" section, components, motion, accessibility and the Player row. PRODUCT_SPEC.md has the core feature and the assumption. 315/316 pass; the one failure is the EpisodeImporter timeout flake. |

### Findings

Should fix S1
Where: ios/ClipDeck/Features/Player/SubtitleStyleSheet.swift:47 (`detentHeight = 520`), :79-80
Problem: The first detent covers the bottom of the video, so the spec's "a fixed-height detent that leaves the video uncovered on iPhone 17 Pro" (and J-1 "the video and its line stay visible above it") is not met. On screen, the sheet starts about 20 pt higher than 874 − 520 = 354. The default line's frame (maxY = video maxY − 12 = 330) is then only 4 pt from the sheet. On any iPhone shorter than the 17 Pro, a fixed 520 pt detent covers more of the video, and then the line itself.
Proof: Ran it. In `style-01-sheet` (run 44878628011, 1206×2622 px, 3×), the video ends at y = 342 pt (x = 10 pt). The sheet's white starts at y = 334 pt at x = 201 pt and at y = 335 pt at x = 80 pt. Rows 335–341 at x = 80 are (255,255,255), while 302 is the video's (95,92,209). The builder's test passed because it checks only the controls' minY (Done ≈ 350 pt), not the sheet's top.
Trigger: Open the style sheet in portrait.
Fix: Size the first detent from the room under the video rather than a constant. For example, measure the video's maxY in PlayerView (`onGeometryChange` in global space) and pass `screen height − videoMaxY` minus the sheet's own top offset. Or lower the constant until the pixel check passes on iPhone 17 Pro, and set a floor that still shows the header and fonts. Keep `presentationBackgroundInteraction(upThrough:)` on the same detent. The deciding test is `SubtitleStyleSheetTesterUITests/testEveryControlStartsBelowTheVideoAndIsLabelled`: its last assertion compares the screenshot pixel at (video.minX + 20% width, video.maxY − 3) with the one 40 pt higher. On this build it fails (white against purple).

Could fix C1
Where: ios/ClipDeck/DesignSystem/Components.swift:61 (`DeckPrimaryButtonStyle`), used by Reset at SubtitleStyleSheet.swift:233
Problem: Reset still press-scales (0.96) under Reduce Motion. `DeckIconButtonStyle` now skips its press-scale, but the primary style doesn't.
Proof: Read it.
Fix: Read `accessibilityReduceMotion` in `DeckPrimaryButtonStyle.StyledLabel` the same way.

Could fix C2
Where: ios/ClipDeck/Features/Player/SubtitleStyleSheet.swift:80
Problem: Background interaction is on at the first detent, so the navigation back button (top-left, above the sheet) can be tapped while the sheet is open, and the player is then popped with the sheet still presented. A tap on the video toggles play or pause. That matches portrait without the sheet, and I count it as fine.
Proof: Read it (not driven).
Fix: Hide or disable the back button while `showStyleSheet` is true, or check by hand that popping with the sheet open leaves no stale sheet.

Notes (no finding):
- T-014 carry-overs: C3 is done, and `clampedSum` is covered by `stepsDoNotOverflowWhenAFieldIsSetToTheExtremesInCode` (pass). C2: the badge overlay is now after the line overlay (PlayerView.swift:444-452), so it draws on top. That is from reading the code only; no test records while the line is raised and moved left.
- The size icons `textformat.size.smaller`/`.larger` render as a small and a large "A". They are distinct, but only by size.
- The XXXL sheet works: the header wraps to two lines and stays pinned, and Reset is reached by scrolling.
- Builder assumptions: the 520 pt detent is wrong by about 8 pt (S1). Whether the player stays in the accessibility tree while the sheet is open is still unknown; the tester test attaches `app.debugDescription` with the sheet open (`tester-sheet-open-frames`). Landscape opens the same sheet (detent taller than 402 pt, so it covers the video), which AC-1 allows until T-016.
- Mutation check: CI-only, so I couldn't revert locally. The pixel assertion is already shown to fail on this build by the measured pixels above. The other three tester tests check behaviour that the code appears to have.

Tests added: ios/ClipDeckUITests/SubtitleStyleSheetTesterUITests.swift
- `testEveryControlStartsBelowTheVideoAndIsLabelled`: all 12 controls are below the video and have labels and values; isSelected; Reset disabled; the sheet leaves the video's bottom uncovered (pixel check, expected to fail until S1 is fixed).
- `testEveryLimitDisablesItsOwnButton`: seeded at 60%/up 18/right 8, then left −8; the values "Up 90% · Right 40%" and "Left 40%".
- `testUsingTheSheetDoesNotPausePlayback`: play, open, size up, Done, still "Pause" (the sample is 6 s long, so the test is quick).

```text
VERDICT: Fail
SPEC: AC-1, AC-2, AC-6, AC-7 met; AC-5 met as written but the spec's "video uncovered" is not (S1); AC-3 and AC-4 partly proven (tester tests added, not yet run)
CHECKS_RUN: CI 44878628011 ipa green (build-ipa.sh); simulator test-ios.sh 315/316, the one failure is the pre-existing EpisodeImporterTests timeout flake; screenshots style-01-sheet, style-02-large-text, portrait-default and landscape-05-panel-max frames read; pixel measurements of style-01
UNVERIFIED: feel on a real iPhone, dark mode (no dark screenshot), VoiceOver speech on a device, Reduce Motion on a device, popping the player with the sheet open (C2)
REVIEWED_AT: 08f286b64c24f10c4f6243ec20b6390d99541fc1
```

## Fix round 2
_orchestrator · 2026-11-21 · round 1 failed on Sonnet; Brent chose to retry on Sonnet. Sent S1 (the 520 pt detent covers the bottom of the video) and Could fix C1/C2 to the same loop-frontend. The tester's new SubtitleStyleSheetTesterUITests.swift is uncommitted and must be kept._

## Implementation notes (round 2) · sonnet
_by loop-frontend · 
- S1: the fixed 520 pt detent is gone. `PlayerView` measures the portrait video's global maxY (`videoMaxY`, a background GeometryReader with `onChange(initial:)`) and passes `SubtitleStyleSheet(firstDetent:)` the height `SubtitleStyleSheet.firstDetentHeight(windowHeight:videoMaxY:)` = window height - videoMaxY - 8 pt gap - 20 pt system rise (the tester measured the sheet sitting about 20 pt higher than window - detent), floored at 120 pt. On iPhone 17 Pro that is 874 - 342 - 28 = 504, so the sheet top is at about 350, 8 pt under the video. The detents are `[.height(first), .large]`, and `presentationBackgroundInteraction(.enabled(upThrough:))` uses the same computed detent. Small room: the first detent shrinks to the floor and the content scrolls, with `.large` as the second. Landscape, or before the video is measured: `.large` only, no background interaction. Window height comes from the key scene's `screen.bounds`.
- C1: `DeckPrimaryButtonStyle` now skips its press-scale and animation under Reduce Motion.
- C2: chose to hide the back button while the sheet is open (`.navigationBarBackButtonHidden(showStyleSheet)`), so the player can't be popped with the sheet presented. Cost: the swipe-back gesture is off while it is open.
- Tests: unit `firstDetentStaysUnderTheVideo`. The tester's SubtitleStyleSheetTesterUITests.swift is untouched.
- Tester, look at: the pixel check in testEveryControlStartsBelowTheVideoAndIsLabelled (the 20 pt rise is a measured constant; if the sheet still covers or leaves a bigger gap, adjust `systemSheetRise`); that the nav bar doesn't jump when the back button hides.

## Test report (round 2)
_by loop-tester · 2026-11-21 04:57_

CI run 44888942981 (89ae32f, scope=all). The `ipa` job is green. The `simulator` job ran 320 tests: 319 pass and 1 fails, with no build issues in the xcresult. The one failure is my own round-1 test `SubtitleStyleSheetTesterUITests/testUsingTheSheetDoesNotPausePlayback`, and the fault is in the test, not the app. It tapped Play at 209.4 s and read the label after Done at 216.5 s, about 7 s later, but the sample is 0:06.0 long (its duration label in `tester-sheet-open-frames`). The clip had ended, and an ended clip shows "Play". I rewrote it to read `player.playPause` while the sheet is still open, about 3 and 5 s after Play. All four known UI flakes and `EpisodeImporterTests/copiesAnMP4…` pass in this run.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `player.subtitleStyle` Button, `textformat`, aqua when changed, right after `player.subtitlesMenu`, "Subtitle style"; landscape bar not broken | Pass | Unchanged since round 1. `testPortraitSheetChangesTheLineLiveAndLeavesTheVideoUncovered` passes. In `tester-sheet-open-frames`, subtitlesMenu is at x 236 and subtitleStyle at x 288 in the same row. All PlayerLandscape* tests pass. |
| AC-2 sheet controls, identifiers, sample per font, values, distinct icons, Theme colours, 0.45 disabled look | Pass | `style-01-sheet` and `tester-sheet-open-screenshot`: the three font rows show "Aa あア漢字" in their own font, Bold, smaller and larger A, four arrows, "130%" / "100%", "Default place", Reset (dimmed at the default), and Done ✓. `testEveryControlStartsBelowTheVideoAndIsLabelled` passes (all 12 identifiers exist as buttons). |
| AC-3 live changes; each limit disables its own button; Reset disabled at the default; playback not paused | Pass except "not paused": Unverified | `testEveryLimitDisablesItsOwnButton` passes (60%, up 18, right +8, left −8, "Up 90% · Right 40%", "Left 40%"). The builder tests cover live changes, 200%, down and Reset. "Not paused" isn't proven yet: the round-1 test was flawed (see above), and the rewritten test hasn't run. |
| AC-4 label and value on every control; selected chip `.isSelected` | Pass | `testEveryControlStartsBelowTheVideoAndIsLabelled` passes: "Larger text"/"Smaller text" "100 percent", "Move subtitles up/down/left/right" with values, Bold "On", "Serif font"/"Rounded font", Sans `isSelected` and Serif not, Done, and Reset disabled. |
| AC-5 `presentationBackground(Theme.panel)`, fixed detent + `.large`, every control's minY ≥ video maxY on iPhone 17 Pro, scrolls to Reset at XXXL | Pass on iPhone 17 Pro / iOS 26.5; see S2 for other devices | The pixel check in `testEveryControlStartsBelowTheVideoAndIsLabelled` passes. I sampled `tester-sheet-open-screenshot` myself: the video is (42,172,210) down to y 341, the Shell gap runs 342–349 with the shadow at 347–349, and the sheet's white starts at y 350 at x 80 and 201. In the tree, the sheet container is {{8, 349.4}, {386, 516.6}} and the Sheet Grabber is at y 344.6, so the gap is 7.4 pt (target 8). The old 520 pt detent covered that same pixel (round 1: white at y 335–341 at x 80), so this test fails on 08f286b and passes here. The unit test `firstDetentStaysUnderTheVideo` passes. `testPortraitSheetScrollsToResetAtAnAccessibilityTextSize` passes. |
| AC-6 SubtitleStyleUITests (open, ×3 taller + 130%, up ×2, Serif/Bold, keep-flag relaunch, Reset ±2 + disabled, 200%, XXXL, attachments) | Pass | All builder SubtitleStyleUITests pass (26.8, 35.9, 14.3, 30.4, 16.6 s). `style-01-sheet` and `style-02-large-text` are present. |
| AC-7 DESIGN.md + PRODUCT_SPEC.md updated; every existing test passes | Pass | DESIGN.md now describes the computed detent and the hidden back button. 319/320 pass; the only failure is the tester test flaw, and every earlier suite is green. |

Round-1 findings:
- S1 fixed on iPhone 17 Pro / iOS 26.5, proven by a run: the pixel check passes, and the sheet top is at 349.4–350 against the video's maxY of 342.
- C1 fixed, by reading: in `Components.swift:62-63`, `DeckPrimaryButtonStyle` skips the scale and the animation under `accessibilityReduceMotion`. Not driven, since CI has no Reduce Motion run.
- C2 fixed, proven by a run. In `tester-sheet-open-frames`, the NavigationBar holds only the "Episode 1" title, with no `BackButton`. With the sheet closed (`portrait-default-frames`), it has `BackButton` at {{16, 62}, {44, 44}}. The bar's frame {{0, 62}, {402, 54}} and the title's {{163, 73.7}} are identical in both, and the video's frame is unchanged ({{0, 116}, {402, 226}} before and while open), so nothing jumps. I added assertions for this, and for back returning after Done (not run yet).
- Builder assumption answered: the player stays in the accessibility tree while the sheet is open. Its whole subtree (video, the slider with 0:00.0 and 0:06.0, playPause, the row, Make a Card and the cue list) is in `tester-sheet-open-frames`.

### Findings

Should fix S2
Where: ios/ClipDeck/Features/Player/SubtitleStyleSheet.swift:50 (`systemSheetRise = 20`), :57-59; PlayerView.swift:182-187
Problem: The first detent subtracts a fixed 20 pt "system rise". That value was measured once, on iPhone 17 Pro with iOS 26.5, and it reflects how that OS draws the sheet, not the app's layout. In this run, iOS 26 draws a floating sheet inset 8 pt on every side, {{8, 349.4}, {386, 516.6}}, for a 504 pt detent. So the rise is 8 pt of bottom inset plus 12.6 pt of extra height, about 20.6. Neither part is guaranteed elsewhere. iOS 17 and 18, which the app supports (deployment target 17.0), draw edge-to-edge sheets, and a `.height` detent there is, as far as I know, sized above the bottom safe area (34 pt on Face ID iPhones). That would put the sheet about 14 pt higher than the formula expects and cover about 6 pt of the video, the same defect as round-1 S1. Home-button iPhones (SE, 0 pt bottom inset, no display corners) likely don't float the sheet either. If the real rise is smaller than 20, the gap only grows, which is harmless. If it is larger, the sheet covers the video.
Proof: Traced it, not run. The iOS 26.5 numbers come from `tester-sheet-open-frames` (CI 44888942981). The iOS 17/18 behaviour is inferred; CI only has the iPhone 17 Pro iOS 26.5 simulator.
Trigger: Open the style sheet in portrait on iOS 17 or 18, or on another iPhone class.
Fix: Measure the sheet instead of assuming its offset. In `SubtitleStyleSheet`, report its own top in global coordinates. These match the window's in this run: the sheet's elements are at y 349.4 in window space. Use `onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY }` (iOS 16+) or the background GeometryReader + `onChange` pattern already used for the video, on the root VStack, while `detent` is the first one. Compute `rise = (windowHeight − firstDetent) − measuredTop`, and correct the detent once: `firstDetent = max(120, windowHeight − videoMaxY − 8 − rise)`. Set the `detents` set and the `detent` selection to the new `.height` together, because `@State detent` keeps its initial value and would otherwise point at a detent that's no longer in the set. A `.height` detent's offset doesn't depend on its height, so one correction converges. Cache the measured rise (for example in PlayerView `@State` or a static), so later opens are exact from the start, and keep 20 only as the first guess. The deciding test is `testEveryControlStartsBelowTheVideoAndIsLabelled` (the pixel check), plus an assertion that the sheet's top gap is no more than about 16 pt, if the builder wants to catch overshoot. If Brent decides only iOS 26 matters, this drops to Could fix.

Could fix C3
Where: ios/ClipDeck/Features/Player/SubtitleStyleSheet.swift:127-130 (Done)
Problem: XCUITest reports `subtitleStyle.done` as Selected (`tester-sheet-open-frames` line 62), so VoiceOver may say "Done, selected". The source adds no `.isSelected` to Done; only the font chips get it (:185). The cause is unknown, possibly the system's initial focus in a sheet.
Proof: Ran it (tree only; VoiceOver speech not heard).
Fix: Check with VoiceOver on a device. If it is spoken, add `.accessibilityRemoveTraits(.isSelected)` to Done.

Notes (no finding):
- PlayerLandscapeBehaviourUITests/testOpenSubtitlesMenuKeepsControlsUpWhilePlaying passed but took 441 s (usually tens of seconds). It is a known flake, and the diff doesn't touch it.
- `styleSheetFirstDetent` reads `connectedScenes.first.screen.bounds`. That is right on an iPhone-only target (TARGETED_DEVICE_FAMILY 1), and the floor of 120 pt covers the video on very short screens, as the builder documented.

Tests changed: ios/ClipDeckUITests/SubtitleStyleSheetTesterUITests.swift
- `testUsingTheSheetDoesNotPausePlayback`: reads "Pause" with the sheet open (after it opens and after a size tap), then checks that Done closes the sheet and back returns. The old version checked after the 6 s clip had already ended.
- `testEveryControlStartsBelowTheVideoAndIsLabelled`: adds checks that back is shown before, hidden while open, and that the nav bar and video frames are unchanged.

```text
VERDICT: Fail
SPEC: AC-1, AC-2, AC-4, AC-6, AC-7 met; AC-5 met on iPhone 17 Pro / iOS 26.5 (S2: fragile constant for other OS/devices); AC-3 met except "playback not paused" (test was flawed, rewritten, not yet run)
CHECKS_RUN: CI 44888942981 ipa green (build-ipa.sh); simulator test-ios.sh 319/320, 0 build issues, the 1 failure is a tester test flaw (clip ended); screenshots style-01-sheet and tester-sheet-open-screenshot read and pixel-sampled; tester-sheet-open-frames and portrait-default-frames compared
UNVERIFIED: "playback not paused" (rewritten test not run); back returning after Done (new assertion not run); the sheet on iOS 17/18 and on other iPhone classes (S2); Reduce Motion on Reset (read only); VoiceOver speech, dark mode, feel on a real iPhone
REVIEWED_AT: 89ae32fb9c9c8abef5cc074ed814ad9f2322724a
```

## Fix round 3
_orchestrator · 2026-11-21 · round 2 failed on Sonnet (S2: the hard-coded systemSheetRise of 20 pt is iOS 26 only). Brent chose: measure it, on Opus. A fresh loop-frontend (opus) gets the round-2 Test report. The tester's edited SubtitleStyleSheetTesterUITests.swift is uncommitted and must be kept. This is the last normal round._

## Implementation notes (round 3) · opus
_by loop-frontend · 2026-11-21 05:16_
- S2 (nothing compiled here, CI only): the fixed `systemSheetRise` is gone. The sheet now measures where the system really drew it and corrects the first detent once.
  - New pure math in `SubtitleStyleSheet.swift`: `SheetClearance` (window height, video maxY), `SheetFit.detentHeight(for:rise:)` = max(120, window - videoMaxY - 8 - rise), `SheetFit.rise(windowHeight:detentHeight:sheetTop:)` = (window - detent) - top, nil when the top isn't finite, isn't inside the window, or the rise is outside -24...96 (mid-animation, dragged, or at `.large`), and `SheetFit.correction(for:detentHeight:sheetTop:)` (keeps the current height when the fix is under 1 pt, so nothing shuffles by fractions).
  - What the round-2 tree showed (CI 44888942981 `tester-sheet-open-frames`): on iOS 26.5 the lower-detent sheet is drawn scaled by about 0.96 (44 pt buttons are 42.2 pt, the 402 pt layout is 386 pt wide), so its top is 874 - 8 - (504 + 34) x 0.96 = 349.4. That also fits round 1's 520 pt detent at 334. So the rise is the OS's and even changes a little with the height (about -0.04 pt per pt, so one correction converges).
  - Because of that scale, the sheet's top is read from UIKit, not from SwiftUI's global frame: `SheetTopProbe` holds a hidden, untouchable `UIView` laid behind the whole sheet (`.ignoresSafeArea()`), and `convert(bounds, to: window).minY` includes the system's transforms. This differs from the "GeometryReader + onChange" suggestion on purpose; SwiftUI geometry may leave out a transform UIKit applies above the hosting view.
  - `SubtitleStyleSheet(clearance:)` owns `@State firstHeight` and `@State detent`. `init` sizes the first detent from the cached rise. `.task(id: SheetFitKey(clearance, dynamicTypeSize))` runs on appear and again only when the geometry or text size really changes: it refits from the cache if needed, waits 0.45 s, then samples the probe every 0.1 s (up to 12 times) while the selection is the first detent; on two equal readings it caches the rise and, if needed, sets `firstHeight` and `detent` together (`useFirstDetent`; a sheet at `.large` stays at `.large`). Then it returns, so the correction can't feed back into a loop.
  - The rise is cached in `UserDefaults` `player.styleSheetRise` (ignored if implausible), so later opens and relaunches are right first time. `-uiTesting` doesn't clear it (it is a device property, like a real phone keeps it).
  - Kept: `presentationBackgroundInteraction(.enabled(upThrough:))` on the same (corrected) detent, landscape `.large` only (no clearance; the task also clears a stale first detent), the hidden back button. `PlayerView.styleSheetClearance` replaces `styleSheetFirstDetent` (key window height, foreground scene first).
  - The sheet's root is now an accessibility container `subtitleStyle.sheet` (`.contain`, so every control stays its own element) so UI tests can read the sheet's top.
- C3: Done was the only Selected element besides the Sans chip, while Bold (same `DeckIconButtonStyle(isActive: true)`, other symbol, and a value) was not. The style adds no traits, so the likely cause is the `checkmark` symbol label being read as a selection mark (not proven; I can't run VoiceOver here). Added `.accessibilityRemoveTraits(.isSelected)` to Done; Done is never a selection.
- Tests:
  - Unit (SubtitleStyleTests): `firstDetentStaysUnderTheVideo` rewritten on the new API (504 at the guess, 490 at a 34 pt rise, floor), plus `riseComesFromTheMeasuredSheetTop` (20.6 from the round-2 numbers, 20 from round 1's), `nonsensicalMeasurementsAreIgnored` (at `.large`, off screen, 0, negative, NaN, infinity, mid-animation, no window), `oneCorrectionPutsTheSheetJustUnderTheVideo` (34 pt true rise: 504 -> 490, top lands at video + 8, a second measurement changes nothing), `aSheetSittingTooLowIsRaised` (rise 0: 504 -> 524), `aSubPointDifferenceIsLeftAlone` (iOS 26.5: stays 504), `theFloorHoldsAfterACorrection`.
  - UI: the tester's `testEveryControlStartsBelowTheVideoAndIsLabelled` now also checks, last, that `subtitleStyle.sheet`'s minY - video maxY is >= -0.5 and <= 16 pt (nothing removed or loosened). `testPortraitSheetChangesTheLineLiveAndLeavesTheVideoUncovered` checks Done isn't Selected.
- Docs: DESIGN.md (the measured rise, the floor, the cache key).
- Checked: nothing can compile here (ci_only). I re-read every change for Swift 6 isolation (the math types are `nonisolated`, the probe and view are MainActor), names that shadow (`measured` instead of `rise` inside `SheetFit`), and that the selection always names a detent in the set.
- Tester, look at:
  - `testEveryControlStartsBelowTheVideoAndIsLabelled`: the new gap assertion, and that `subtitleStyle.sheet` exists as an element (if SwiftUI doesn't expose the container, the test fails at "The sheet's container is in the tree"; that is a test-hook problem, not the layout). On iOS 26.5 I expect a gap of about 7.4 to 8 pt and no visible correction (the fix there is 0.6 pt, under the 1 pt threshold).
  - The round-3 `tester-sheet-open-frames`: the sheet container frame, and Done without Selected.
  - That the detent doesn't jump on open on iOS 26 (nothing should move), and that every builder SubtitleStyleUITests test (reveal by swiping, XXXL) still passes with the new container.
  - Not provable on CI: iOS 17/18 and Home-button iPhones (CI has only iOS 26.5). There the sheet may open at the guess and slide to the corrected height about half a second later, once per install.

## Test report (round 3)
_by loop-tester · 2026-11-21 05:55_

CI run 44893660834 (24a676d, scope=all). The `ipa` job is green. The `simulator` job ran 326 tests: 325 pass and 1 fails, with no build issues in the xcresult. The one failure is `SubtitleStyleSheetTesterUITests/testEveryControlStartsBelowTheVideoAndIsLabelled`, at the gap assertion the builder added last: "XCTAssertLessThanOrEqual failed: (22.776) is greater than (16.0): top 364.776, video 342.0". The fault is in that test hook, not in the layout. In `tester-sheet-open-frames`, the sheet itself is `{{8.0, 349.4}, {386.0, 516.6}}` (grabber at 344.6), a 7.4 pt gap, the same as round 2. The `subtitleStyle.sheet` element reports `{{8.0, 364.8}, …}`, which is Done's top (`{{336.4, 364.8}, {42.2, 42.2}}`). XCUITest reports a `.contain` container's frame as the union of its children, so it starts below the header's 16 pt top padding (15.4 pt at the 0.96 scale). Every assertion before it passed (continueAfterFailure is false): the pixel check, all 12 controls below the video with their labels and values, back hidden while the sheet is open, and the bar and video frames unchanged. All known flakes and `EpisodeImporterTests/copiesAnMP4…` pass in this run.

Evidence that the measurement works on iOS 26.5, independent of the failed hook: this was the first sheet opened on a fresh simulator (the tester class runs before `SubtitleStyleUITests`), so it used the 20 pt guess, a 504 pt detent. In `tester-sheet-open-screenshot`, the sheet's white starts at pixel row 1048 (349.33 pt) at x 80, 120, 201 and 300. In `style-01-sheet`, from a later test and launch, it starts at row 1050 (350.0 pt) at the same columns. The pixel above is (230,233,236) in both. That 0.67 pt shift is what a cached rise of about 20.6 predicts: a 503.4 pt detent, top ≈ 866 − 537.4 × 0.96 = 350.1. So on that first open the probe read the real, scaled top (a rise of about 20.6, a fix of 0.6 pt left alone as under 1 pt), saved it in `player.styleSheetRise`, and the next launch's `init` used it. If the probe had read nothing or something wrong, the second sheet would sit at 349.4 or would have moved by more.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `player.subtitleStyle` Button, `textformat`, aqua when changed, right after `player.subtitlesMenu`, "Subtitle style"; landscape bar not broken | Pass | Unchanged code. `testPortraitSheetChangesTheLineLiveAndLeavesTheVideoUncovered` and all 8 PlayerLandscapeBehaviourUITests pass in 44893660834. |
| AC-2 sheet controls, identifiers, sample per font, values, distinct icons, Theme colours, 0.45 disabled look | Pass | `style-01-sheet` (this run): three font rows with "Aa あア漢字" in their own font, Serif aqua, Bold, smaller and larger A, four arrows, "130%", "Default place", Reset, Done. In the failing tester test, all 12 identifiers exist as buttons before the failing line. |
| AC-3 live changes; each limit disables its own button; Reset disabled at the default; playback not paused | Pass | `testEveryLimitDisablesItsOwnButton` passes. `testUsingTheSheetDoesNotPausePlayback` passes on its first run (21.1 s). Its activities show "Find the player.playPause Button" after the sheet opened and again after the sizeUp tap, both before Done, and both read "Pause". Back returns after Done. |
| AC-4 label and value on every control; selected chip `.isSelected` | Pass | The tester test's label and value checks pass before the failing line. C3 is fixed: Done has no `Selected` in `tester-sheet-open-frames` (line 64), while Sans keeps it. The builder's new `XCTAssertFalse(done.isSelected)` passes. |
| AC-5 `presentationBackground(Theme.panel)`, fixed detent + `.large`, every control's minY ≥ video maxY on iPhone 17 Pro, scrolls to Reset at XXXL | Pass on iPhone 17 Pro / iOS 26.5. Other OS versions and devices: by reasoning, plus a deciding test that hasn't run | Pixel check passes. The sheet is at 349.4 against the video's maxY of 342 (7.4 pt gap). The XXXL test passes. S2: the measurement is shown to work by the cache shift above. The end-to-end correction test (below) hasn't run yet. |
| AC-6 SubtitleStyleUITests | Pass | All 9 SubtitleStyleUITests pass, including the 5 for this task. Attachments `style-01-sheet` and `style-02-large-text` are present. |
| AC-7 DESIGN.md + PRODUCT_SPEC.md; every existing test passes | Pass for docs. Tests: 325/326, and the only failure is the test-hook flaw above | DESIGN.md describes the measured rise, the floor and the cache key. All 7 new SheetFit unit tests pass (`firstDetentStaysUnderTheVideo`, `riseComesFromTheMeasuredSheetTop`, `nonsensicalMeasurementsAreIgnored`, `oneCorrectionPutsTheSheetJustUnderTheVideo`, `aSheetSittingTooLowIsRaised`, `aSubPointDifferenceIsLeftAlone`, `theFloorHoldsAfterACorrection`). |

Round-2 findings:
- S2: the fixed rise is gone. The rise is measured, cached and corrected once. On iOS 26.5 this is proven by a run (cache shift above). The case where the guess is wrong, which is the iOS 17/18 case, is proven by the arithmetic in unit tests, and end to end by the new tester test, which hasn't run yet.
- C3: fixed, proven by a run (tree and the builder's assertion).

Review of the approach (reasoning, CI has only iOS 26.5):
- Layout loops: none. `fitFirstDetent` runs only when `SheetFitKey` changes (clearance or Dynamic Type), corrects at most once, and returns. Changing the detent doesn't change `videoMaxY`, which is SwiftUI's global frame of the presenting view. Nothing measures on geometry change.
- Stale selection: `useFirstDetent` sets `firstHeight` and `detent` in the same update, and keeps `.large` if the sheet is there, so the selection is always in the set. The `PresentationDetent.height(x) == .height(x)` comparison uses the same stored CGFloat, so it is exact.
- Rotation: rotating sets `showStyleSheet = false`, and the clearance turns nil in the same update, so the dismissing sheet may switch to `.large` only. The round-2 code did the same, so this isn't new. Dynamic Type while open: the task restarts, finds no refit needed, and measures again. Harmless.
- iOS 17/18: a `.height` detent there is drawn edge to edge, above the bottom safe area, so the rise should be about 34 pt on Face ID iPhones and 0 on Home-button iPhones. Both are inside the plausible −24…96 range, the transform is identity, and the sheet lives in the same window, so `convert(_:to: window)` gives the real top. One correction is exact there. Cost: the very first open per install shows the sheet about 14 pt too high (over the video) for about 0.5 s before it slides down. Brent should check this on a device.
- iOS 26: the rise depends on the height (about −0.04 pt per pt, because of the 0.96 scale), so one correction from a far-off cache leaves about 4% of the error, for example 0.8 pt from a 20 pt miss. The 8 pt gap absorbs that.
- Accessibility: the probe is `accessibilityElementsHidden`, `isAccessibilityElement = false`, `.accessibilityHidden(true)` and non-interactive, and it doesn't appear in the tree. The `.contain` container has no label, so VoiceOver doesn't stop on it, and every control is still its own element (all identifiers were found).
- Security, paths, network: not touched. The new UserDefaults key holds one Double, and it is checked for plausibility on read.

### Findings

Could fix C1
Where: ios/ClipDeck/Features/Player/SubtitleStyleSheet.swift:262-272
Problem: The "settled" check is two equal readings 0.1 s apart while the selection is the first detent. If the user holds the sheet still mid-drag within the first ~1.65 s, the rise is measured from the dragged position (anything within −24…96 is accepted), cached, and the detent is "corrected" to match. The next open re-measures and fixes it, so it heals itself.
Proof: Read it.
Fix: Optionally require the reading to sit within, say, 30 pt of the expected top, or skip the sample while a drag is in progress.

Could fix C2
Where: ios/ClipDeckUITests/SubtitleStyleSheetTesterUITests.swift (the builder's gap check, now fixed by the tester)
Problem: The builder's gap assertion read the `subtitleStyle.sheet` container, whose XCUITest frame is the union of its children. I replaced it with `sheetTop(_:)`, the innermost element that contains the container. This is test code only, recorded so the next builder knows. CONTEXT Learned has a line about it.

Tests changed: ios/ClipDeckUITests/SubtitleStyleSheetTesterUITests.swift
- `testEveryControlStartsBelowTheVideoAndIsLabelled`: the gap is now measured from the sheet's own top (`sheetTop`), not the container's union frame. The −0.5…16 limits are unchanged.
- New `testAWrongSavedRiseIsCorrectedOnceTheSheetHasSettled`: launches with `-player.styleSheetRise` set to an XML plist real 0 (argument domain, this launch only). The first detent opens 20 pt too tall and covers the video. It asserts that the settled sheet is −0.5…16 pt under the video and that the pixel check passes. It attaches `tester-wrong-rise-frames` with about 3 s of early samples ("covered early: true" shows the wrong position was caught before the correction). Mutation (reasoned, CI only): without the correction in `fitFirstDetent`, the sheet stays at 524 pt, top ≈ 330, gap ≈ −12, and the test fails. If the log says "covered early: false" for every sample, the seed may not have taken effect; the cache shift above is then the evidence for the measurement.

```text
VERDICT: Blocked
NEEDED: verify-only pass: gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=tests -f only_testing=ClipDeckUITests/SubtitleStyleSheetTesterUITests (deciding: testEveryControlStartsBelowTheVideoAndIsLabelled with the fixed sheetTop gap check, and testAWrongSavedRiseIsCorrectedOnceTheSheetHasSettled)
SPEC: AC-1, AC-2, AC-3, AC-4, AC-6 met; AC-5 met on iPhone 17 Pro / iOS 26.5 (7.4 pt gap, pixel check passes; S2's measurement proven by the cache shift; the wrong-rise correction is pending the verify-only run); AC-7 docs met, 325/326 pass (the 1 failure is a test-hook flaw)
CHECKS_RUN: CI 44893660834 ipa green (build-ipa.sh); simulator test-ios.sh 325/326, 0 build issues; tree tester-sheet-open-frames; pixel rows of tester-sheet-open-screenshot vs style-01-sheet; playback test activities
UNVERIFIED: iOS 17/18 and Home-button iPhones (the first open per install may show the sheet over the video for about 0.5 s before it corrects); VoiceOver speech; dark mode; Reduce Motion; feel on a real iPhone
REVIEWED_AT: 24a676dc2804a4a809ef11166c38cb91d9c59c2d
```
