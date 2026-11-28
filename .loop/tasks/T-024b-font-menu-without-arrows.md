---
id: T-024b
title: Font menu without arrows, with its own Reset
lane: frontend
depends_on: [T-024a]
status: done
round: 2
base_sha: 38b2491a68ed0117ece98e0095ca55637328adad
issue: 27
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Keep only font, bold and size in the Font menu, with a Reset that leaves the position alone

### What are we building?
After T-024a the position has its own menu, but the Font menu still shows arrows, and its Reset undoes everything. After this task the Font sheet and card have no arrows and no Position section, the card fits in one tidy row (or two), and the Font Reset only resets font, bold and size.

### Why?
Each menu does one job, and resetting a font never throws away a carefully chosen position.

### Done when
- AC-1 The portrait Font sheet has no Position section and no gap where it was: Size and Reset move up. Reset (`subtitleStyle.reset`) calls `resetFont()`. It's disabled when the font group is at its default, and its value reads "Default" or "Changed" for the font group only.
- AC-2 The landscape Font card shows one row: Sans, Rounded, Serif, More, Bold, size−, size+, Reset, Done. Its fallback is two rows: [Sans, Rounded, Serif, More, Bold] / [size−, size+, Reset, Done], with Reset just left of Done as listed. The three-row layout and the arrows are gone; nothing else in the card changes.
- AC-3 The Aa button (`player.subtitleStyle`) is aqua and reads "Changed" only when the font group isn't at its default. A moved line alone doesn't light it; ✥A shows that.
- AC-4 The Font card's Up-dim and Down-jump wiring goes away with its arrows. Where the line sits while the Font card is open doesn't change: it's still lifted above the card as today.
- AC-5 Tests, in both orientations:
  - with a seeded `{"font":"serif","sizeStep":3,"up":0.30,"right":-0.20}`, Font Reset restores Sans at 100 % and leaves `player.subtitle` at its moved place (±1 pt), and Move-Text Reset leaves the serif font and the size alone;
  - the card shows 9 controls in one row with the panel closed and 5 + 4 at a 50 % panel, all inside the column and the safe area;
  - no `subtitleStyle.up|down|left|right` element exists in the sheet or the card.
- AC-6 The old tests that drive the Font menu's arrows (in SubtitleStyleCardTesterUITests, SubtitleUpLimitTesterUITests, SubtitleStyleSheetTesterUITests, SubtitleStyleCardUITests, SubtitleStyleUITests and SubtitleStyleTesterUITests) are moved to the Move-Text controls (`moveText.*`) where they still prove something T-024a's tests don't. Where they duplicate T-024a's tests, they're deleted. List which in your notes. Every remaining test passes, and DESIGN.md "Subtitle style menu" is updated.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check the edited SubtitleStyle* suites, SubtitleStyleSheetTesterUITests (the sheet still clears the video after the Position section is removed), and the new reset tests.

### Agent notes
- Depends on: T-024a (positions must already be movable from Move-Text). Source: spec T-024, the "Font menu" part.
- Code: the controls and layouts are at SubtitleStyleCard.swift:26-44, and the arrow and Reset cases around 114-140. PlayerView.swift:239-247 and 272-278 pass `canStepUp`/`highestUp` to the card (renamed from `highestUpStep` in T-023). In SubtitleStyleSheet.swift, the sections are at 283-286 and Position/Reset at 580-622.
- The sheet's first detent is fitted to its content by SheetFit (Learned). After removing the section, check that it still sits under the video.
- The card has a background, so XCUITest reports its real frame (Learned).
- C5 from T-023's tester: `SubtitleStyleSheetTesterUITests/testUsingTheSheetDoesNotPausePlayback` reads the button 4–5 s after Play on the 6 s clip and flaked in 45168178904. Since this task reworks that class, launch it with `-uiTestingSampleSeconds 20`.
- **AC-7 (Brent, 2026-11-23, from T-022's tester):** in portrait, tapping the video while the Aa sheet is open closes the sheet, as if Done were pressed. Landscape already does this with the Aa card. Today the tap silently flips `portraitOverlayVisible`, so after Done the overlay may unexpectedly stay hidden or appear (SubtitleStyleSheet.swift:320, 331-334; PlayerView.swift:188, 540, 635-638). Add a UI test: open the sheet, tap the video, and the sheet must close with the overlay state unchanged.
- Since T-022 the centred overlay hides while either Aa menu is open, in both orientations, so the line shows at its saved place there (DESIGN.md "Style menus"). C2 from T-022's tester: DESIGN.md:95 says "see Style card", but that bullet is now "Style menus"; fix the wording here.

### Out of scope
- Font, size and bold rules; the Move-Text menu itself.

## Implementation notes (round 1) · sonnet
_by loop-frontend · 2026-11-27_
- Changed: Font card is one row of 9, else 5 + 4, no arrows and no Up-dim/Down-jump wiring (`canStepUp`/`highestUp` now reach only `MoveTextCard`); the sheet lost its Position section. Both Resets call `resetFont()` and read "Default"/"Changed" (card: "Already the default"). Aa is aqua on `isFontDefault`. AC-7: `togglePortraitOverlay` closes the Aa sheet and leaves `portraitOverlayVisible` alone.
- Files: SubtitleStyleCard.swift, SubtitleStyleSheet.swift, PlayerView.swift, docs/DESIGN.md (menu text, "see Style card" wording, AC-7 rule), ios-simulator.yml (class removed from SHARD1_UI), CONTEXT.md (stale flake line dropped). Not compiled; every identifier checked by hand.
- AC-6 moved: CardTester `testAfterClosingTheLineRestsAtItsStyledPlace` now taps `moveText.up` (rest-place maths is unique to it) and keeps the Font card for the unchanged case; CardUITests `testUpAndSize...` became size-only; SheetTester/StyleUITests lost their position asserts; the sheet reset test became the AC-5 Font-reset test; AvoidOverlay portrait test steps size, not Up.
- AC-6 deleted (duplicates of MoveTextUITests/MoveTextTesterUITests): CardTester `testUpTapsWithTheCardOpenRecordWhereTheLineIs`, `testUpDisablesWhenTheLineCanNoLongerMoveUp`, `testFirstDownTapMovesTheLineWhenTheStoredPlaceIsAboveTheClamp` (= `testUpDimsAtHighestJustUnder...`, `testFirstDownFromAboveTheReachableTop...`); all of SubtitleUpLimitTesterUITests (panel-width climb: the Move card's height doesn't change with width; past-clamp and portrait-limit cases = `testFirstDown...`, `testArrowsDimAtTheirLimitsPortrait`); SheetTester `testEveryLimitDisablesItsOwnButton` position half (size-down half kept as `testSizeDownDisablesAtSixtyPercent`). SubtitleStyleTesterUITests drives no arrows, unchanged.
- AC-5 tests: `testPortraitFontResetRestoresTheFontAndKeepsThePlace` (SubtitleStyleUITests), `testFontResetRestoresTheFontAndKeepsThePlaceLandscape` and `testMoveTextResetKeepsTheFontAndSizeLandscape` (SubtitleStyleCardUITests; Move-Text portrait twin already in MoveTextUITests); layout 9 / 5 + 4 in the CardTester; no-arrow asserts in the sheet, card and Font-reset tests. The place is compared with a position-only seeded reference launch (±1 pt), so the old font can't skew it.
- AC-7 test: `testATapOnTheVideoClosesTheSheetAndLeavesTheOverlayAsItWas` (SheetTester): hidden overlay stays hidden, shown stays shown. C5: `testUsingTheSheetDoesNotPausePlayback` launches with `-uiTestingSampleSeconds 20`.
- Dropped the 25 % panel-width check (AC-5 lists only closed and 50 %; 9 controls at 25 % is unmeasured).
- Tester, look at: sheet still under the video without the Position section (`testEveryControlStartsBelowTheVideo...`), the two-row card at 50 %, rest-place test through Move-Text, the reference-frame compares (landscape uses the same panel-open state in both launches).
- Targeted CI classes: SubtitleStyleCardTesterUITests, SubtitleStyleCardUITests, SubtitleStyleSheetTesterUITests, SubtitleStyleUITests, SubtitleAvoidOverlayUITests, plus MoveTextUITests/MoveTextTesterUITests as a regression check.

### CI (shared run)
- CI: pending, run 46100218606 (be1ed79, scope=all). It covers T-032 round 2 (e049b9b, unit tests) and T-024b round 1. Dispatched once and not watched.
- Run 46100218606 failed in all 4 test jobs: SubtitleStyleCardUITests.swift:193 had a real line break inside a string literal (T-024b), so the UI test bundle didn't compile. The ipa job was green. The orchestrator replaced it with a `\n` escape (8e727cb).
- Run 46102226923 (8e727cb, scope=all): shards 1, 2, 4 and the ipa green; shard 3 red on two tests.
  - `SubtitleStyleCardUITests/testSizeChangesTheLineLiveAndItStaysAboveTheCard`: "285.3 is not less than 250.3, A bigger line, lifted above the card, moves the top edge up". `before` was read before the card opened, with the overlay up (T-022 pushes the line below it), and was compared with the line above the one-row card. Fixed by the orchestrator: `before` is read after the card opens.
  - `MoveTextTesterUITests/testButtonFollowsAaInEveryLandscapeBarVariantAndTheCardFitsAtHalfWidth`: "reset can be tapped at half width ((298.0, 8.0, 44.0, 44.0))". T-024a code and test, both unchanged since the green run 45230680205 (c7b4e65), and the style is cleared on every launch, so it's treated as a flake. Watch it in the next run.
  - The product comment in `togglePortraitOverlay` was removed (no-comments pass; the test doc comments are why-comments in the house style and stay).

## Test report (round 2)
_by loop-tester · 2026-11-28_

Reviewed `git diff e049b9b..9d3d5d4`. CI run 46112964013 (9d3d5d4, scope=all), per the orchestrator, not re-read: shards 2, 3, 4 and the ipa job green. Shard 1 green except `PlaybackOverlayUITests.testBarPlayPauseValueLandscape`, a pre-existing T-021 test this change doesn't touch (48 s idle stall). Nothing ran locally (no Swift here).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 sheet: no Position section, Reset = `resetFont()`, disabled/"Default"/"Changed" for the font group | Pass | SubtitleStyleSheet.swift:372-376, 588-599. SheetTester `testEveryControlStartsBelowTheVideo...` (no arrows, Reset disabled + "Default", sheet clears the video), `testSizeDownDisablesAtSixtyPercent` ("Changed"), StyleUITests `testPortraitFontResetRestoresTheFontAndKeepsThePlace`; shards 2/3 |
| AC-2 card: 9 in one row, else 5 + 4, Reset left of Done, no arrows | Pass | SubtitleStyleCard.swift:28-34; CardTester checkCard [9] with the panel closed and [5, 4] at 50 %; shard 1 |
| AC-3 Aa is aqua/"Changed" only for the font group; a moved line alone doesn't light it | Unverified (code right, test added, not run yet) | PlayerView.swift:790 `isFontDefault`. The "Changed" half: StyleUITests:150, SubtitleFontTesterUITests:114. The "moved line alone" half had no test; the tester added one |
| AC-4 the Font card's Up-dim/Down-jump wiring is gone; the line is still lifted above the card | Pass | PlayerView.swift:315-320 (MoveTextCard still gets the wiring at :302); CardUITests `testSizeChangesTheLineLiveAndItStaysAboveTheCard`, CardTester tallest-card check; shards 1/3 |
| AC-5 Font Reset keeps the place (±1 pt); Move-Text Reset keeps font and size; both orientations | Pass | `testPortraitFontResetRestoresTheFontAndKeepsThePlace`, `testFontResetRestoresTheFontAndKeepsThePlaceLandscape`, `testMoveTextResetKeepsTheFontAndSizeLandscape`, MoveTextUITests `testResetPutsTheLineBackAndKeepsTheFontPortrait`; shards 2/3 |
| AC-5 9 controls in one row / 5 + 4 at 50 %, inside the column and the safe area | Pass | CardTester; shard 1 |
| AC-5 no `subtitleStyle.up/down/left/right` in the sheet or the card | Pass | `.exists` false asserts in SheetTester:65, StyleUITests:140, CardUITests:173; shards 2/3 |
| AC-6 arrow tests moved or deleted, remaining tests pass, DESIGN.md updated | Partly: 2 unique checks were deleted, not moved. The tester moved them (not run yet) | Audit below. DESIGN.md is updated, and the "see Style card" wording is fixed |
| AC-7 a portrait video tap closes the Aa sheet and leaves the overlay as it was | Pass | PlayerView.swift:695-698; SheetTester `testATapOnTheVideoClosesTheSheetAndLeavesTheOverlayAsItWas` (hidden stays hidden, shown stays shown); shard 3 |
| C5 the sheet playback test uses a 20 s clip | Pass | `testUsingTheSheetDoesNotPausePlayback` with `-uiTestingSampleSeconds 20`; shard 3 |

AC-6 audit (each deleted or moved check compared with the MoveText* tests):
- CardTester `testUpTapsWithTheCardOpen...` and `testUpDisablesWhen...` → MoveTextUITests `testUpDimsAtHighestJustUnderTheCardLandscape`. Covered.
- CardTester `testFirstDownTapMoves...`, plus UpLimit's checks that Down keeps the stored percent, re-enables Up, and the next Up returns to the same top place → MoveTextTester `testFirstDownFromAboveTheReachableTopMovesTheLineLandscape`. Covered.
- UpLimit: Up stays dimmed after the card is closed and reopened at the same place. Not covered. **Moved by the tester** to the end of `testFirstDownFromAboveTheReachableTop...`.
- UpLimit's climbs at 25 % and 50 % panel width tested the Font card's 2 and 3 rows. The Move card has one row, and `testButtonFollowsAaInEveryLandscapeBarVariant...` covers it at half width. Fine to delete.
- SheetTester's Up 90 % and Left 40 % limits, UpLimit's "portrait Up stays enabled until 90 %", and the default values ("At the default height", "Centred") → `testArrowsDimAtTheirLimitsPortrait`. Covered.
- SheetTester: Right is disabled at +40 % with the value "40 percent right". This was the only UI proof that `moveText.right` dims (MoveTextMenu.swift:59). Not covered. **Moved by the tester** as `testRightDimsAtFortyPercentRightPortrait`.
- StyleUITests' Up x2 steps and Down disabled at default, CardUITests' "15 percent up", and AvoidOverlay's portrait Up steps → `testUpAndRightMoveTheLineByFivePercentPortrait` and the MoveText overlay tests. Covered.

Reference launches: both Font-reset tests seed the same `up`/`right` without a font and read the line in the same state (portrait: cue row tapped, overlay hidden; landscape: controls up, panel open, paused). The comparison is like for like.

### Findings
Should fix (the tester has closed it; waiting for CI)
Where: ios/ClipDeckUITests (deleted SubtitleUpLimitTesterUITests; SheetTester `testEveryLimitDisablesItsOwnButton`)
Problem: two checks that T-024a's tests don't make were deleted instead of moved: Right dims at 40 %, and Up stays dimmed after the card reopens.
Proof: Read it: a grep of MoveText* finds no Right-limit check and no reopen check.
Trigger: a break in the `canMoveRight` wiring, or in the Up state when the card opens, would still pass CI.
Fix: done in MoveTextTesterUITests.swift.

Could fix
Where: SubtitleStyleCard.swift:98
Problem: the card's Reset value is still "Already the default", while the sheet's now reads "Default". This is in spec (AC-2: nothing else in the card changes), but the two disagree for VoiceOver.

Tests added (test files only, not run). With no Swift here, the revert-once check wasn't run either. Reverting PlayerView.swift:790 to `isDefault` would make both AC-3 asserts read "Changed".
- SubtitleStyleUITests.swift and SubtitleStyleCardUITests.swift: the position-only reference launch asserts `player.subtitleStyle` reads "Default" (AC-3).
- MoveTextTesterUITests.swift: a reopen tail on `testFirstDownFromAboveTheReachableTopMovesTheLineLandscape`, and the new `testRightDimsAtFortyPercentRightPortrait`.

```text
VERDICT: Blocked
NEEDED: verify-only pass. Commit the tester's test edits and run only_testing SubtitleStyleUITests, SubtitleStyleCardUITests, MoveTextTesterUITests (+ ClipDeckTests). Deciding tests: testPortraitFontResetRestoresTheFontAndKeepsThePlace, testFontResetRestoresTheFontAndKeepsThePlaceLandscape (AC-3), testRightDimsAtFortyPercentRightPortrait, testFirstDownFromAboveTheReachableTopMovesTheLineLandscape (AC-6).
SPEC: AC-1, AC-2, AC-4, AC-5 and AC-7 met; AC-3 and AC-6 wait on the tests above
CHECKS_RUN: CI 46112964013 (9d3d5d4, scope=all), as reported by the orchestrator: green except the pre-existing PlaybackOverlayUITests.testBarPlayPauseValueLandscape (idle stall); no local build
UNVERIFIED: the aqua Aa and how the one-row card looks (screenshots not opened); how it feels with VoiceOver (Brent)
REVIEWED_AT: 9d3d5d4
```

### Verify-only pass (round 2)
- Brent (2026-11-28): land on evidence despite the PlaybackOverlay idle stall; its fix (a 120 s clip) is its own commit, 38b2491.
- History rewritten when T-032 landed: rounds 1-2 plus the tester's tests are one wip commit on base_sha 38b2491. This run also carries T-026 round 1 (scope=all).
- CI: run 46115783465 (1487a6c, scope=all), the 4th and last for this task. Pending, not watched.

### Round 2 addendum (orchestrator)
- CI 46115783465 (1487a6c, scope=all) is green in every job. It ran the tester's deciding tests: the two Font-reset tests with the Aa "Default" check (AC-3), `testRightDimsAtFortyPercentRightPortrait` and the reopen check in `testFirstDownFromAboveTheReachableTopMovesTheLineLandscape` (AC-6). The PlaybackOverlay idle-stall test passed too, on the 120 s clip.
- The tester's only open condition was this evidence, so the verdict is Pass. No fresh tester: reading a green status needs no judgment (policy rule 20).
- Unverified (Brent, on the iPhone): how the aqua Aa and the one-row card look; VoiceOver.
