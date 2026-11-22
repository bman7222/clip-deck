---
id: T-018
title: Stop Up when the line can't go higher, and trust a font's weight over its name
lane: frontend
depends_on: [T-016]
status: done
round: 2
base_sha: 0747bcd9dea4ba425f6f007235bf7638f4bf7fdf
issue: 19
spec: .loop/specs/subtitle-style.md
model:
---

## Stop Up when the line can't go higher, and trust a font's weight over its name

### What are we building?
Two small fixes from T-016's review. With the landscape style card open, the line stops below the top bar after about 12, 9 or 6 Up taps (for a 1-, 2- or 3-row card), but Up stays enabled, so later taps change the saved value without showing anything. And a font whose name contains "Black", "Heavy" or "Bold" counts as bold even when the font reports a light weight.

### Why?
Brent chose to fix both in a follow-up: every enabled tap should show its effect, and a light font named "â€¦Black" shouldn't disable Bold or say "This font is always bold."

### Done when
- AC-1 While the landscape card is open, Up is disabled (dimmed, with VoiceOver value "Highest") as soon as one more step would no longer move the line. That is, the placement for step n+1 is clamped to the same place as step n (SubtitlePlacement.swift:55-61). Closing the card and the portrait sheet keep their existing rule: Up disables only at the stored limit (90%). The value text keeps showing the stored percent.
- AC-2 A unit test for the new "can the line still move up with the card open" function covers 1-, 2- and 3-row card heights and the top-bar clamp. A UI test taps Up with the card open until it disables and asserts that every tap before that moved the line by more than 1 pt.
- AC-3 (revised by Brent after round 1, 2026-11-22: on iOS 26.5 ArialRoundedMTBold reports weight exactly 0.0) `SubtitleStyle.isBoldFace` trusts the weight trait only when it exists and is non-zero: then the rule is weight >= 0.3 or the bold symbolic trait. When the weight trait is missing or exactly 0.0, the name ("bold", "heavy", "black") decides (or the bold symbolic trait). ArialRoundedMTBold must still count as bold (by its name, since its weight is 0.0). Unit tests: a light face (negative weight) whose name contains "Black" is not bold; weight 0.0 with a "Bold" name is bold; a non-zero weight >= 0.3 with a plain name is bold.
- AC-4 Every existing test still passes. Update docs/DESIGN.md (the landscape card note and the bold sentence) to match.
- AC-5 (added by Brent after round 1, 2026-11-22) While the landscape card is open, every enabled Down tap visibly moves the line. If the stored place is above the highest place the line can reach with the card open (it is pinned under the top bar), the first Down tap sets the stored step to one step below that highest reachable step, so the line moves down at once. Below that, Down steps as before. The closed card and the portrait sheet keep their existing Down behaviour. A unit test covers the jump (stored step above the clamp â†’ one below the highest reachable), and a UI test seeds a high place (for example upSteps 17), opens the card and asserts the first Down tap moves the line by more than 1 pt.

### How to check
- CI: `gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=all`.
- The new unit tests in SubtitleStyleTests / SubtitleFontTests, and the new card UI test.

### Agent notes
- Depends on: T-016
- Source: T-016 Test report round 2, Could fix C3 and C4; Brent's decision, 2026-11-22 ("small follow-up task after").
- Keep T-014's placement for the closed card and portrait unchanged. Only the "can step up" decision, used while the card is open, is new.
- Read .loop/CONTEXT.md "Learned": a `.contain` container frame is a union; don't put a mutating call inside `#expect`; `.traitBold` misses ArialRoundedMTBold.

### Out of scope
- Changing step sizes or limits; ASS file styles.

## Implementation notes (round 1)
_by loop-frontend Â· 2026-11-22_
- Changed: `SubtitlePlacement.canStepUpWithCardOpen` (pure; compares placement at step n and n+1 with steps counted from the card; enabled only if the line moves > 1 pt; true when the video isn't measured yet). PlayerView measures the video and line size (`measuredSize`) and passes `canStepUp` to `SubtitleStyleCard`, whose Up is disabled with value "Highest" when false. Portrait sheet and closed card untouched. `SubtitleStyle.isBoldFace`: weight trait present -> weight >= 0.3 or bold symbolic trait; name only when no weight trait (plain-value overload for tests).
- Files: Features/Player/SubtitlePlacement.swift, SubtitleStyleCard.swift, SubtitleStyle.swift, PlayerView.swift; ClipDeckTests/SubtitleStyleTests.swift, SubtitleFontTests.swift; ClipDeckUITests/SubtitleStyleCardTesterUITests.swift; docs/DESIGN.md
- Checked: nothing compiled (Windows); scanned edited files for stray line breaks in strings.
- Tester, look at: unit counts 14/11/9 taps for 1/2/3-row cards (hand-computed with an 800x360 video); UI test testUpDisablesWhenTheLineCanNoLongerMoveUp; Up when no cue is showing stays enabled.

## Test report (round 1)
_by loop-tester Â· 2026-11-22 03:14_

CI run 44997338718 (ios-simulator.yml, scope=all, 45f32d4): ipa job green (the app compiles); simulator job failed after 36 min with 374/377 tests passing, 0 build issues. All three failures come from one cause (M1). The known flakes all passed this time (AboutUITests Ã—3, PlayerLandscapeBehaviourUITests Ã—2, EpisodeImporterTests/copiesAnMP4â€¦). Artifacts are in C:\Users\Brent\AppData\Local\Temp\clip-deck-loop\T-018-r1.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 While the landscape card is open, Up is disabled (dimmed, with VoiceOver value "Highest") as soon as one more step would no longer move the line. That is, the placement for step n+1 is clamped to the same place as step n (SubtitlePlacement.swift:55-61). Closing the card and the portrait sheet keep their existing rule: Up disables only at the stored limit (90%). The value text keeps showing the stored percent. | Partly verified | One-row card: CI 44997338718 `SubtitleStyleCardTesterUITests/testUpDisablesWhenTheLineCanNoLongerMoveUp` passed. Up dimmed after 13 taps (attachment "up taps before disabling: 13"), every tap moved the line by more than 1 pt, and the value was "Highest". Portrait 90 % rule: `SubtitleStyleSheetTesterUITests/testEveryLimitDisablesItsOwnButton` passed, and SubtitleStyleSheet.swift isn't in the diff. **Not yet run:** the 2- and 3-row cards on device, Down's value staying on the stored percent, Up not dimming early (the line at the top-bar clamp), and portrait Up staying enabled past the landscape clamp. All of these are in the new tester file `ios/ClipDeckUITests/SubtitleUpLimitTesterUITests.swift` (2 tests, not yet run). |
| AC-2 A unit test for the new "can the line still move up with the card open" function covers 1-, 2- and 3-row card heights and the top-bar clamp. A UI test taps Up with the card open until it disables and asserts that every tap before that moved the line by more than 1 pt. | Pass | CI 44997338718: `SubtitlePlacementTests/oneRowCardAllowsFourteenUpTaps`, `twoRowCardAllowsElevenUpTaps`, `threeRowCardAllowsNineUpTaps` and `theStoredLimitStillStopsUpAndAnUnmeasuredVideoDoesNot` passed, and the UI test above passed. Mutation (traced, not run in Swift, because only CI can build): a Python port of `frame`/`canStepUpWithCardOpen` gives 14/11/9 taps. With the old stored-limit-only rule it gives 18 taps, of which 4/7/9 don't move the line, so the unit tests catch a revert. |
| AC-3 `SubtitleStyle.isBoldFace` (SubtitleStyle.swift:244-252) uses the name ("bold", "heavy", "black") only when the font has no weight trait. When a weight trait exists, the rule is weight >= 0.3 or the bold symbolic trait. ArialRoundedMTBold must still count as bold, by its weight trait: prove it with a test that fails if the name rule were the only path. Add a unit test for a light face whose name contains "Black". | **Fail** | CI 44997338718 `SubtitleFontTests/arialRoundedCountsAsBoldByItsWeightTraitAlone`: "Expectation failed: SubtitleStyle.isBoldFace(rounded â†’ <UICTFont â€¦> font-family: "Arial Rounded MT Bold"; font-weight: normal â€¦)" and "(weight â†’ 0.0) >= 0.3". ArialRoundedMTBold reports a weight trait of **0.0** and no `.traitBold` on iOS 26.5. In T-016 it counted as bold only through its name, so the AC's premise ("by its weight trait") is false on this OS. The light "Black" tests (`aLightFaceNamedBlackIsNotBold`, `theNameCountsOnlyWhenThereIsNoWeightTrait`) pass. |
| AC-4 Every existing test still passes. Update docs/DESIGN.md (the landscape card note) to match. | **Fail** | Existing tests now fail: `SubtitleFontTests/aBoldOnlyFamilyIsAlwaysBoldAndSaysSo` (`pickedFontIsAlwaysBold â†’ false`; boldSpoken "This font has no bold weight") and `SubtitleStyleCardUITests/testABoldOnlyFontSaysItIsAlwaysBold` ("The always-bold note shows"). Both passed in T-016 (44982440176). DESIGN.md is updated (card note and bold rule), but its bold sentence documents the rule that breaks. |

### Findings

**Must fix M1: the new bold rule makes Arial Rounded MT Bold "not bold" (3 tests fail)**
Where: ios/ClipDeck/Features/Player/SubtitleStyle.swift:255-256 (`if let weight { return weight >= 0.3 || hasBoldTrait }`); test ios/ClipDeckTests/SubtitleFontTests.swift:233-241
Problem: On iOS 26.5, ArialRoundedMTBold's descriptor has a weight trait of exactly 0.0 and no `.traitBold`, so the "weight present â†’ trust it" branch returns false. Then `pickedFontIsAlwaysBold` is false and `boldSpoken` says "This font has no bold weight." This is the T-016 M1 bug back again. The builder's new test asserts `weight >= 0.3`, which is false for this font, so the test can't pass with any rule.
Proof: Ran it. CI 44997338718, xcresult TestIssues: "(weight â†’ 0.0) >= 0.3", "pickedFontIsAlwaysBold â†’ false", "The always-bold note shows".
Trigger: pick Arial Rounded MT Bold in More fonts (portrait sheet or landscape card).
Fix: AC-3's premise needs a decision (planner or Brent), because this font has no weight trait to trust. Two options that keep the "light face named â€¦Black isn't bold" goal:
(a) Treat weight 0.0 like "no weight". Use the name when the weight trait is missing or exactly 0, and trust the weight only when it is non-zero. A light face reports a negative weight, so "â€¦BlackLight" at âˆ’0.4 stays not bold. A regular-weight face named "â€¦Black" that reports 0.0 would count as bold.
(b) Read the real design weight: the OS/2 table `usWeightClass` (`CTFontCopyTable(â€¦, kCTFontTableOS2, â€¦)`, bold if â‰¥ 600), or `CTFontCopyTraits`. Check in CI which of these returns a non-zero value for ArialRoundedMTBold before relying on it.
With either option, rewrite `arialRoundedCountsAsBoldByItsWeightTraitAlone` so it states the real path. It must still fail if the name rule were the only path: for (a), assert that a light weight (âˆ’0.4) with a "Bold" name is not bold, and that weight 0.0 with a "Bold" name is bold. Update the DESIGN.md sentence too.

**Could fix C1: Down taps from a stored place past the clamp don't move the line**
Where: ios/ClipDeck/Features/Player/SubtitleStyleCard.swift:114-118
Problem: The task's "Why" says every enabled tap should show its effect, but AC-1 covers only Up. If the stored place is above the clamp (set in portrait, for example), the card opens with Up dimmed (correct). The first Down taps change the saved value but don't move the line.
Proof: Traced it with the Python port. With the 800Ã—360 one-row geometry, Down from 18, 17, 16 and 15 moves the line â‰¤ 1 pt; with the real 13-tap clamp, about 5 Down taps from 90 % would show nothing.
Fix: Brent's call. Either accept it (Down is "closer to default" and the value is spoken), or snap the stored value to the highest visible step when the card opens or on the first Down.

**Could fix C2: the sizes used for the decision are only measured while a line shows**
Where: ios/ClipDeck/Features/Player/PlayerView.swift:241-243 and 550-553
Problem: `subtitleVideoSize` and `subtitleLineSize` are measured inside `if let cue`. With no cue, the decision uses `.zero` for the line and the last measured video size, which can be the portrait video's size after a rotation, or stale after a panel resize. So Up can dim at the wrong step while no line is shown, until the next cue appears. The builder's note "Up when no cue is showing stays enabled" isn't accurate: with a 0-high line Up still dims at the clamp.
Proof: Read it, PlayerView.swift:512-517 (the overlay exists only with a cue) and :550-553 (the measurements live inside it).
Fix: Measure the video size on `videoScreen` itself (outside the cue `if`), and correct the comment or note.

**Could fix C3: the builder's UI test can't tell the top bar from the stored limit**
Where: ios/ClipDeckUITests/SubtitleStyleCardTesterUITests.swift:160 (`XCTAssertLessThan(taps, 20, â€¦)`)
Problem: Up stopping at 18 taps (the stored limit) would also pass. The per-tap move assertion is what really catches it. SubtitleUpLimitTesterUITests asserts `< 18`, and that the line sits within 2 pt of the top bar + 8 when Up dims.

Tests added by the tester (uncommitted, not yet run):
- ios/ClipDeckTests/SubtitleUpLimitTesterTests.swift: 5 unit tests (a partial last step of 2.65 pt still counts, then Up dims; a move â‰¤ 1 pt doesn't count; a stored place past the clamp dims Up; a line taller than the room dims Up at once; with no top bar the clamp is the resting top, 16 taps). The values were checked with the Python port.
- ios/ClipDeckUITests/SubtitleUpLimitTesterUITests.swift: 2 UI tests. The first climbs with the 2-row (panel 25 %) and 3-row (panel 50 %) cards: each tap moves more than 1 pt, Down's value is "N percent up", Up dims at "Highest" fewer than 18 taps in, the line sits at the top-bar clamp, one Down re-enables Up, and Up stays dimmed after close and reopen. The second seeds `upSteps 17`: the card opens with Up dimmed and Down reading "85 percent up"; after a rotation the portrait sheet's Up is enabled at 85 % and disables at 90 %.

```text
VERDICT: Fail
SPEC: AC-1 partly (one-row card verified on CI; 2/3-row, value text, portrait past the clamp pending the tester tests), AC-2 met, AC-3 not met (ArialRoundedMTBold reports weight 0.0, so the AC premise is false), AC-4 not met (2 existing bold-only tests fail)
CHECKS_RUN: CI 44997338718 scope=all: ipa success; simulator 374/377, 3 failures all M1, 0 build issues; Python port of SubtitlePlacement (14/11/9 taps; the old rule gives 18 with 4/7/9 dead taps)
UNVERIFIED: Brent: on a real iPhone, open the card and tap Up until it dims (one-row, then with the panel open); the line should stop just under the top bar with no dead tap. Pick Arial Rounded MT Bold after the fix: Bold should say "This font is always bold".
REVIEWED_AT: 45f32d4793e8f69fc18f98246d71ebf492d054d5
```

## Fix round 2
Brent, 2026-11-22: retry on Sonnet. Fix M1 with the revised AC-3 (weight 0.0 = use the name). Also build the new AC-5 (Down from above the clamp jumps to one below the highest reachable step). Commit the tester's two files with this round.

## Implementation notes (round 2)
_by loop-frontend · 2026-11-22_
- M1/AC-3: `isBoldFace` trusts a weight only when non-nil and non-zero (>= 0.3 or bold trait); otherwise the bold trait or the name decides. Arial Rounded test rewritten (weight 0.0 + its name is bold; weight -0.4 + same name is not). Added tests for weight 0 + "Bold", non-zero >= 0.3 plain name. Removed the old assertion that weight 0 with "Heavy-Regular" is not bold (contradicts the revised AC-3).
- AC-5: `SubtitlePlacement.highestReachableUpStep` and `upStepAfterDownWithCardOpen`; PlayerView passes `highestUpStep` to the card; card Down uses the jump rule. Unit tests (14/11/9, jump, jump moves > 1 pt) and UI test `testFirstDownTapMovesTheLineWhenTheStoredPlaceIsAboveTheClamp` (upSteps 17).
- C3: UI test bound tightened to `< 18`. C2 not done (AC-5 doesn't depend on it).
- Checked: nothing compiled; scanned for stray line breaks.

## Test report (round 2)
_by loop-tester · 2026-11-22 04:10_

CI run 45002423211 (ios-simulator.yml, scope=all, headSha b698119 = the pushed SHA): both jobs passed. The ipa job took 2 min. The simulator job took 46 min (limit 60) and ran **390/390 tests, 0 failures, 0 issues** (377 from round 1 plus 13 new: 5 builder unit, 5 tester unit, 1 builder UI, 2 tester UI). Every step passed, including "Launch in simulator and screenshot". Every known flake passed: AboutUITests ×3, PlayerLandscapeBehaviourUITests ×2, EpisodeImporterTests/copiesAnMP4…, ClipExtractorTests/cutsExactAudioAndScreenshot, ExpiryBannerUITests ×5 and SubtitleStyleSheetTesterUITests/testEveryLimitDisablesItsOwnButton. Artifacts: C:\Users\Brent\AppData\Local\Temp\clip-deck-loop\T-018-r2. Geometry was checked with a Python port of `SubtitlePlacement` (frame, canStepUpWithCardOpen, highestReachableUpStep, upStepAfterDownWithCardOpen). With this run's real sizes (874×402, top bar 60, card 80/132/184, line 24 pt), it reproduces every measured line position to within 0.15 pt.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 While the landscape card is open, Up is disabled (dimmed, with VoiceOver value "Highest") as soon as one more step would no longer move the line. That is, the placement for step n+1 is clamped to the same place as step n (SubtitlePlacement.swift:55-61). Closing the card and the portrait sheet keep their existing rule: Up disables only at the stored limit (90%). The value text keeps showing the stored percent. | Pass | CI 45002423211. **1 row:** `SubtitleStyleCardTesterUITests/testUpDisablesWhenTheLineCanNoLongerMoveUp`: Up dims after 13 taps, every tap moves the line by more than 1 pt, value "Highest". **2 and 3 rows:** `SubtitleUpLimitTesterUITests/testUpDimsExactlyWhenTheLineReachesTheTopBarWithTwoAndThreeRowCards` (attachment tester-t018-climb). Panel 25 %, 2 rows: 238.0 → 220.0 → … → 75.0 → 68.0. That is 10 taps of about 18 pt, the last one 7 pt, then "Highest". Panel 50 %, 3 rows: 186.0 → … → 77.33 → 68.0, 7 taps. Both stop at the clamp, 68.0 = top bar 60 + 8, so Up never dims early. After every tap Down's value read "N percent up" (the stored percent). One Down re-enabled Up, and the next Up returned to 68.0 and dimmed it again. Closing and reopening kept Up dimmed. **Stored 85 %:** `…/testAStoredPlacePastTheClampDimsUpInTheCardButNotInThePortraitSheet`: the card opens with Up dimmed, "Highest", Down "85 percent up", line at 68.0. After a rotation the portrait sheet's Up is enabled at "85 percent up" and disables at "90 percent up", with "Up 90%" in the value text. Screenshots 13D05E37… (stored 17, Up dimmed) and 54F1758F… (3 rows, line under the top bar, Up dimmed). SubtitleStyleSheet.swift is not in the diff. |
| AC-2 A unit test for the new "can the line still move up with the card open" function covers 1-, 2- and 3-row card heights and the top-bar clamp. A UI test taps Up with the card open until it disables and asserts that every tap before that moved the line by more than 1 pt. | Pass | CI 45002423211: `SubtitlePlacementTests/oneRowCardAllowsFourteenUpTaps`, `twoRowCardAllowsElevenUpTaps`, `threeRowCardAllowsNineUpTaps`, `theStoredLimitStillStopsUpAndAnUnmeasuredVideoDoesNot`, `theHighestReachableStepMatchesTheUpTaps`. `SubtitleUpLimitTesterTests` ×5 cover the top-bar clamp: a partial last step, a move of 1 pt or less, a stored place past the clamp, a line taller than the room, and no top bar. The UI test is the one in AC-1. Mutation (traced in the port, round 1): the old stored-limit-only rule gives 18 taps with dead taps, so these tests fail. |
| AC-3 (revised by Brent after round 1, 2026-11-22: on iOS 26.5 ArialRoundedMTBold reports weight exactly 0.0) `SubtitleStyle.isBoldFace` trusts the weight trait only when it exists and is non-zero: then the rule is weight >= 0.3 or the bold symbolic trait. When the weight trait is missing or exactly 0.0, the name ("bold", "heavy", "black") decides (or the bold symbolic trait). ArialRoundedMTBold must still count as bold (by its name, since its weight is 0.0). Unit tests: a light face (negative weight) whose name contains "Black" is not bold; weight 0.0 with a "Bold" name is bold; a non-zero weight >= 0.3 with a plain name is bold. | Pass | SubtitleStyle.swift:255-260 matches the rule word for word. CI 45002423211: `SubtitleFontTests/arialRoundedCountsAsBold` (the real face is bold; weight 0 with its name is bold; −0.4 with its name is not), `aLightFaceNamedBlackIsNotBold`, `weightZeroWithABoldNameIsBold`, `aNonZeroWeightOfSemiboldOrMoreIsBoldWithAPlainName` and `theNameCountsWhenThereIsNoWeightInformation` all pass. Mutation (ported rule against the 15 expectations): the shipped rule passes 15/15. The round-1 rule fails 3 (the Arial Rounded lines and weight 0 with "Bold"); that rule also really failed on CI 44997338718. The T-016 rule fails 3 (light "…Black", light Arial Rounded name, 0.1 "Heavy"). |
| AC-4 Every existing test still passes. Update docs/DESIGN.md (the landscape card note and the bold sentence) to match. | Pass | CI 45002423211: 390/390, including both bold-only tests that failed in round 1 (`SubtitleFontTests/aBoldOnlyFamilyIsAlwaysBoldAndSaysSo`, `SubtitleStyleCardUITests/testABoldOnlyFontSaysItIsAlwaysBold`). DESIGN.md:79 (the bold rule with the 0.0 case) and :89 (Up dims with "Highest", Down's jump, closed card and portrait unchanged) match the code. |
| AC-5 (added by Brent after round 1, 2026-11-22) While the landscape card is open, every enabled Down tap visibly moves the line. If the stored place is above the highest place the line can reach with the card open (it is pinned under the top bar), the first Down tap sets the stored step to one step below that highest reachable step, so the line moves down at once. Below that, Down steps as before. The closed card and the portrait sheet keep their existing Down behaviour. A unit test covers the jump (stored step above the clamp → one below the highest reachable), and a UI test seeds a high place (for example upSteps 17), opens the card and asserts the first Down tap moves the line by more than 1 pt. | Pass | CI 45002423211. Unit: `SubtitlePlacementTests/aStoredStepAboveTheHighestReachableJumpsToOneBelowItOnTheFirstDown` and `theJumpedStepMovesTheLineByMoreThanOnePoint`. UI: `SubtitleStyleCardTesterUITests/testFirstDownTapMovesTheLineWhenTheStoredPlaceIsAboveTheClamp`, attachment "pinned (388.67, 68.0, 97, 24), after first Down (388.67, 72.67, 97, 24)". That is exactly step 12 (the port gives 72.8, step 11 would be 90.9). In the same run Up dims at step 13, so the jump landed one below the highest reachable step. Below the clamp: the climb test's Down from the top moved the line by more than 1 pt, and the port's sweep (20,000 random geometries × stored 1…18) found **0** dead Down taps whenever the line can move at all. A plain one-step Down mutant gives 110,589 dead taps and fails both unit tests (16 ≠ 13; 0 pt move). `upStepAfterDownWithCardOpen` has one caller (SubtitleStyleCard.swift:123). The sheet's Down (SubtitleStyleSheet.swift:596-597) is untouched, and its UI suites pass. |

### Findings

**Could fix C1: the stale video size (round-1 C2) now also drives the Down jump**
Where: ios/ClipDeck/Features/Player/PlayerView.swift:239-247 (decision), :517 and :555-558 (sizes measured only inside `if let cue`)
Problem: With no line on screen, `subtitleVideoSize` keeps the last size measured, which can be the portrait video's (about 402×226) after a rotation. Round 1 only dimmed Up at the wrong step. Now `highestUpStep` comes from that size too, so one Down tap can drop the stored place by several steps.
Proof: Traced it with the port on CI geometry (one-row card, no line). Highest reachable is 8 with the stale size and 14 with the real one. Stored 12 → Down sets 7 (35 %) instead of 11, and Up dims at 40 % instead of 70 %.
Trigger: watch in portrait with subtitles, rotate during a gap between lines, open the card before a line shows, then tap Down with the stored place above 40 %. The next line shows lower than expected.
Fix: measure the video size on `videoScreen` itself, outside the cue `if`.

**Could fix C2: when the line can't move at all, the first Down drops the stored place to 0**
Where: ios/ClipDeck/Features/Player/SubtitlePlacement.swift:115-119
Problem: When the line is taller than the room between the top bar and the card, `highestReachableUpStep` is 0. Then Down from 85 % sets 0 % in one tap and the line doesn't move. This follows AC-5's wording (one below 0 clamps to 0), but the stored place is lost with nothing to see.
Proof: Traced it: 3-row card (room 142 pt), 150 pt line → highest 0, Down from 17 → 0, the line moves 0 pt.
Trigger: a three-line cue at 200 % with the panel at 50 % and a high place set in portrait.
Fix: Brent's call. For example, use plain one-step Down when the highest reachable step is 0.

No Must fix or Should fix. Round-1 M1 is fixed; round-1 C1 is now AC-5 (met); C3 is fixed (`< 18`); C2 is still open (C1 above).

```text
VERDICT: Pass
SPEC: AC-1 met, AC-2 met, AC-3 met, AC-4 met, AC-5 met
CHECKS_RUN: CI 45002423211 scope=all on b698119: ipa success; simulator success, 390/390 tests, 0 issues, launch-and-screenshot step green (covers commands test/run/build, which are macOS-only; lint is ""). Python port of SubtitlePlacement + the Down jump (CI frames reproduced; 0 dead Down taps in a 360,000-case sweep; mutants fail) and of isBoldFace (15/15; both earlier rules fail 3)
UNVERIFIED: Brent, on a real iPhone: (1) set Up to 85 % in portrait, rotate, open the card: Up should be dimmed and the first Down should move the line, but only by the partial last step (about 4.7 pt with a one-row card, 7 to 9 pt with the panel open), not a full 18 pt step. Judge whether that is visible enough. (2) Tap Up until it dims (one row, then with the panel open): the line should stop just under the top bar with no dead tap. (3) Pick Arial Rounded MT Bold: Bold should say "This font is always bold".
REVIEWED_AT: b6981191da020aad9b97b3ba4138ee0563fc0e73
```
