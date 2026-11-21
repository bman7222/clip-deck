---
id: T-015
title: Adjust the subtitle style from a menu in the portrait player
lane: frontend
depends_on: [T-014]
status: testing
round: 2
base_sha: 29491a8a99698de0de6b9141cd3e1ee961b711ca
issue: 16
spec: .loop/specs/subtitle-style.md
model:
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
