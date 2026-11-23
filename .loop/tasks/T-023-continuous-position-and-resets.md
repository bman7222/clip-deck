---
id: T-023
title: Continuous position plus separate resets
lane: backend
depends_on: [T-022]
status: done
round: 1
base_sha: c1122c9e111c1225ea426e564bdc17287982a494
issue: 25
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Save the subtitle position as a smooth value, and reset font and position separately

### What are we building?
Today the position is saved in whole 5 % steps, so a drag (T-025) couldn't stop between two steps, and Reset puts everything back at once. After this task the position is saved as a continuous fraction, and the arrows still move it 5 % per tap. Saved styles carry over, and the model gets two separate resets: one for the font group and one for the position. The menus don't change yet.

### Why?
The Move-Text menu and dragging build on this, and Brent wants a font reset that leaves the position alone (and the reverse).

### Done when
- AC-1 `SubtitleStyle` has `up: Double` (0…0.90) and `right: Double` (−0.40…0.40) in place of `upSteps`/`rightSteps`, saved under the JSON keys `up` and `right`. Values are rounded to 4 decimals on every write, so taps never drift: 18 Up taps from 0 give exactly 0.90, and `canMoveUp` is then false.
- AC-2 Decoding stays tolerant. It uses `up`/`right` when present, otherwise `upSteps`/`rightSteps` × 0.05. Invalid or missing values give the default, and everything is clamped. Encoding writes only the new keys. `-uiTestingSubtitleStyle` accepts either form, so existing UI tests that seed `upSteps` keep working unchanged.
- AC-3 The step mutators move ±0.05 × n from the current value (not onto a grid), clamp, and still report whether another step is possible. The display texts round to whole percents ("Up 20% · Left 10%", "20 percent up"), so they read the same for values on the grid.
- AC-4 `resetFont()` restores font, pickedFontName, bold and size. `resetPosition()` restores up and right. Neither touches the other group. `isFontDefault` and `isPositionDefault` exist, and `isDefault` means both. Today's Reset buttons keep resetting everything; T-024a and T-024b wire the new resets.
- AC-5 `SubtitlePlacement.frame` and the T-018 helpers (`canStepUpWithCardOpen`, `highestReachableUpStep`, `upStepAfterDownWithCardOpen`) work in fractions: the highest reachable `up`, and the `up` after a Down. They gain a `stepsFromObstruction` parameter that defaults to true (today's behaviour), so T-024a can use them with a menu at the top. The landscape card's Up dimming and Down jump behave exactly as now: the unit tests still count 14/11/9 taps, the UI tests 13/10/7, and the T-018 jump still holds.
- AC-6 Unit tests:
  - migration from the old keys (4 → 0.20, −4 → −0.20, out-of-range values clamped);
  - new keys win over old ones, and garbage gives the default;
  - clamps at both ends, and 18 taps reach exactly 0.90;
  - a value between steps (0.37) steps to 0.42;
  - the two resets stay apart.
  Rewrite the existing unit tests to fractions with the same meaning (upSteps 4 becomes up 0.20). Every existing test passes, and ARCHITECTURE.md describes the `player.subtitleStyle` key.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check SubtitleStyleTests, SubtitleUpLimitTesterTests, SubtitleFontTests and SubtitleStyleTesterTests. Every UI suite that seeds `upSteps` must pass untouched: that proves the migration.

### Agent notes
- Depends on: T-022 (it changes `SubtitlePlacement.frame` first). Source: spec T-023, and section G defaults 3 (arrows step from wherever a drag left the line) and "5 % arrow steps".
- Code: SubtitleStyle.swift:25-181 (fields, init, CodingKeys, decode, clamp, mutators, json, seeded). The display texts (`upPercent`, `positionText`, `verticalSpoken`, `horizontalSpoken`) are at SubtitleStyleSheet.swift:9-57, and the frame and helpers at SubtitlePlacement.swift:35-119. Adapt the callers (PlayerView.swift:239-247, and `highestUpStep: Int` in SubtitleStyleCard.swift:19) so the app builds with no visible change.
- Pure types are `nonisolated`, because the app's default isolation is MainActor. Don't make the style both RawRepresentable and Codable.
- Learned: no mutating call inside `#expect`. Read results into a `let` first.

### Out of scope
- Any menu change (T-024a/T-024b), dragging (T-025).

## Implementation notes (round 1)
_by loop-backend (sonnet) · 2026-11-23_
- Changed: `SubtitleStyle` now has `up: Double` (0...0.90) and `right: Double` (-0.40...0.40), saved under `up`/`right` only. Every write goes through `clampPosition` (clamp, then round to 4 decimals; NaN gives 0), so 18 Up taps give exactly 0.90. Decoding: valid new key wins, else old `upSteps`/`rightSteps` x 0.05, else default (a wrong-typed new key falls through to a valid old key). `stepUp`/`stepRight` add delta x 0.05 from the current value via `positionSum`. Added `resetFont()`, `resetPosition()`, `isFontDefault`, `isPositionDefault`; `isDefault` is still the whole style. The card's and sheet's Reset buttons still reset everything.
- Placement: `frame` uses `style.up * height` and `style.right * width` (T-022 `avoid:` untouched). `canStepUpWithCardOpen` and the new `highestReachableUp` take `stepsFromObstruction` (default true). Renamed `highestReachableUpStep` to `highestReachableUp` (returns Double, searched in 0.05 steps from 0) and `upStepAfterDownWithCardOpen` to `upAfterDownWithCardOpen`. `SubtitleStyleCard.highestUpStep` is now `highestUp`; PlayerView passes it. No visible change.
- Display texts round to whole percents. CLAUDE.md shows both seed forms; ARCHITECTURE.md describes the keys, migration and resets.
- Files: ios/ClipDeck/Features/Player/{SubtitleStyle,SubtitlePlacement,SubtitleStyleSheet,SubtitleStyleCard,PlayerView}.swift; ios/ClipDeckTests/{SubtitleStyleTests,SubtitleFontTests,SubtitleUpLimitTesterTests}.swift; docs/ARCHITECTURE.md; CLAUDE.md. UI tests untouched on purpose (they seed `upSteps`).
- Tests added (SubtitleStyleTests): eighteenUpTapsFromZeroReachExactlyNinetyPercent, aValueBetweenStepsStepsFromWhereItIs (0.37 to 0.42), nonFinitePositionsFallBackOrClamp, resetFontLeavesThePositionAlone, resetPositionLeavesTheFontAlone, oldStepKeysMigrateToFractions, newKeysWinOverOldOnes, garbagePositionValuesGiveTheDefault, encodingWritesOnlyTheNewKeys, aBetweenStepsValueSurvivesTheSavedJSON, aMenuAtTheTopCanCountUpFromTheBottomInstead, plus extra menuTexts cases. Existing tests were rewritten to fractions (upSteps 4 = up 0.20); the 14/11/9 tap counts and the jump test are kept.
- Checked: nothing compiled (Windows, CI only). Read-through of every identifier; `grep` shows no remaining `upSteps`/`rightSteps` in app code outside the legacy decoder.
- Gotchas: floating-point is controlled by the 4-decimal rounding, tests compare with `==` on rounded values. `up` on a hand-set unclamped property is clamped in `canMove*`, `clamped()` and the placement.
- Tester, look at: the 4 unit classes (SubtitleStyleTests incl. SubtitlePlacementTests, SubtitleFontTests, SubtitleUpLimitTesterTests, SubtitleStyleTesterTests) and the UI classes that seed `upSteps` and open the landscape card.

## Test report (round 1)
_by loop-tester · 2026-11-23 07:11_

CI 45168178904 (0a075c6, scope=tests, targeted: ClipDeckTests + the 6 UI classes that seed `upSteps`, one job, CI run 1 of 4). It built, and 369 of 370 test runs passed (333 names). The one failure is a pre-existing timing flake in a test the diff doesn't touch (C5). Evidence: %TEMP%\clip-deck-loop\T-023-r1 (Data/ pruned, 8.4 MB).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `up` 0…0.90 / `right` −0.40…0.40 under keys `up`/`right`, 4-decimal rounding, 18 taps = exactly 0.90 and `canMoveUp` false | Pass | 45168178904: SubtitleStyleTests/eighteenUpTapsFromZeroReachExactlyNinetyPercent, initClampsEveryField, aValueBetweenStepsStepsFromWhereItIs (0.123456 → 0.1235), encodingWritesOnlyTheNewKeys and nonFinitePositionsFallBackOrClamp all pass |
| AC-2 tolerant decode (new keys win, old × 0.05, garbage → default, clamped), only new keys encoded, seed accepts either form | Pass | 45168178904: oldStepKeysMigrateToFractions (4 → 0.20, −4 → −0.20, 99/−99/−3 clamped), newKeysWinOverOldOnes, garbagePositionValuesGiveTheDefault, outOfRangeJSONIsClamped, encodingWritesOnlyTheNewKeys and aBetweenStepsValueSurvivesTheSavedJSON pass. Seed: `git diff c1122c9 0a075c6 -- ios/ClipDeckUITests` is empty, and all 6 suites that seed `upSteps`/`rightSteps` pass. `cmpattach.py` against T-022's landing run 45158384614 (same app code: `git diff 4079a44 c1122c9 -- ios/` is empty) gives **40 of 40 text attachments identical, 0 different, none missing**: SubtitleAvoidOverlay 5, SubtitleStyleCardTester 14, SubtitleStyleSheetTester 2, SubtitleStyleTester 5, SubtitleStyle 9, SubtitleUpLimitTester 5. The new-key seed goes through the same `decoded(from:)`, which the unit tests above cover |
| AC-3 mutators ±0.05 × n from the current value, clamp, report the next step; texts round to whole percents | Pass | 45168178904: aValueBetweenStepsStepsFromWhereItIs (0.37 → 0.42 → 0.32; −0.12 → −0.07), positionStepsStopAtBothEnds, stepsDoNotOverflowWhenAFieldIsSetToTheExtremesInCode (positionSum with Int.max/Int.min), menuTextsShowSizeAndPosition ("Up 20% · Left 10%", "37 percent up", "Up 38% · Right 4%"). The UI values are unchanged: "Up 90% · Right 40%", "Left 40%", "85 percent up", "Up 10%", climb log "5…50 percent up" |
| AC-4 `resetFont()` / `resetPosition()` kept apart; `isFontDefault`, `isPositionDefault`, `isDefault` = both; today's Reset still resets everything | Pass | 45168178904: resetFontLeavesThePositionAlone, resetPositionLeavesTheFontAlone, defaultStyleIsToday (all three flags). Reset buttons: SubtitleStyleCard.swift:137 is unchanged (`stored = SubtitleStyle.default.json`); SubtitleStyleUITests/testPortraitResetBringsBackTheDefaultLineAndDisablesItself and the climb's card Reset pass |
| AC-5 frame and T-018 helpers in fractions, `stepsFromObstruction` defaults to true; unit 14/11/9, UI 13/10/7, T-018 jump | Pass | 45168178904: theHighestReachableUpMatchesTheUpTaps (0.70/0.55/0.45 = 14/11/9, called without the argument, so the default is true); attachment `up-disables-card-open` "up taps before disabling: 13"; `tester-t018-climb` panel-25 taps 10, panel-50 taps 7; `down-from-above-clamp` pinned y 68.0 → 72.67 after the first Down. All are identical to 45158384614. `false` is passed through in both helpers (SubtitlePlacement.swift:123,127,147), but the builder's test of it can't detect that, so I added one (Tests added). It hasn't run yet |
| AC-6 unit tests listed, existing tests rewritten with the same meaning, every existing test passes, ARCHITECTURE.md describes `player.subtitleStyle` | Partly: pending the re-run | Every listed unit test passes. Each rewrite maps n steps → n × 0.05 (I read every hunk). Names: the reference's 322 names in the same classes → 333 (2 renamed, 11 added, 0 lost). docs/ARCHITECTURE.md:60 describes the keys, migration and resets. "Every existing test passes": 1 UI run is red, a pre-existing flake (C5) |

Mutation check: not run. This is CI-only and I may not dispatch. The equivalent evidence is the untouched old-key UI seeds: without the legacy decode, the `{"upSteps":17}` line would sit at the default place and "85 percent up" would fail, as would "Up 90% · Right 40%". Both passed with identical frames.

### Tests added
- `ios/ClipDeckTests/SubtitleUpLimitTesterTests.swift`: `stepsFromObstructionFalseCountsFromTheRegionBottom`. The builder's `aMenuAtTheTopCanCountUpFromTheBottomInstead` uses `bottomObstruction: 0`, where `activeBottom == resting.maxY`, so it passes even if `false` were ignored. With a 40 pt bottom obstruction the two modes differ: the highest is 0.75 counted from the obstruction and 0.80 from the bottom, and at 0.75 Up is possible only with `false`. I checked the numbers by emulating the same double arithmetic in Python, which also reproduced 0.70/0.55/0.45. **Not run yet.**

### Findings
None at Must fix or Should fix.

Could fix C1 (contract note for T-024a)
Where: ios/ClipDeck/Features/Player/SubtitlePlacement.swift:133-151
Problem: with `stepsFromObstruction: false` and a bottom obstruction that pins the line at small `up` values, `highestReachableUp` returns 0. The first value from which Up doesn't move the line is then the bottom-pinned start, not the top. `upAfterDownWithCardOpen(stored: 0.5, highestReachable: 0)` then jumps to 0.
Proof: Traced it. I emulated the frame arithmetic for 800×360, margins 8/75/33/48, top 52, bottom 68, line 30, with `false`: highest 0.0, and Down from 0.5 → 0.0. Today no caller passes `false`.
Trigger: T-024a calling the helpers with `false` while still passing a bottom obstruction.
Fix: T-024a should pass `bottomObstruction: 0`, since its AC-3 hides the bottom bar; then `false` and `true` give the same frames anyway. Or search for the first value whose line sits at the top clamp.

Could fix C2
Where: ios/ClipDeck/Features/Player/SubtitleStyle.swift:81-90, CLAUDE.md:48
Problem: an invalid new key falls through to a valid old key (`{"up":"x","upSteps":4}` gives 0.20). AC-2 says "uses up/right when present … invalid values give the default", and CLAUDE.md says "invalid fields take the default". It only happens with hand-written JSON that has both keys.
Proof: Read it. The builder's notes state it too.
Fix: pick one rule and say it in CLAUDE.md.

Could fix C3 (loop docs, orchestrator)
Where: .loop/specs/player-lookup-timeline.md:28; .loop/tasks/T-024b-font-menu-without-arrows.md:38
Problem: these still name `highestReachableUpStep`, `upStepAfterDownWithCardOpen` and `highestUpStep`. The new names are `highestReachableUp(…, stepsFromObstruction:) -> Double`, `upAfterDownWithCardOpen(stored:highestReachable:) -> Double` and `SubtitleStyleCard(highestUp:)`.
Fix: update both notes before T-024a/b start.

Could fix C4 (coverage for the landing run)
Where: ios/ClipDeckUITests/SubtitleStyleCardUITests.swift:71-86
Problem: it drives the card's Up arrows and asserts "15 percent up", but it wasn't in this targeted run.
Fix: the full landing run must include it (it does by default).

Could fix C5 (pre-existing flake, not caused by the diff)
Where: ios/ClipDeckUITests/SubtitleStyleSheetTesterUITests.swift:172-181 (untouched; portrait playback plus the Aa sheet)
Problem: the test plays the 6 s sample without `-uiTestingSampleSeconds` and reads "Pause" 4–5 s after Play, so it has only 1–2 s of slack. In 45168178904 it failed at :179 ("Play" is not equal to "Pause").
Proof: Ran it (CI). The Play tap's idle wait took 3.45 s (11:58:51.604 → 55.052; earlier runs took 0.40–0.60 s), so the read came 6.85 s after Play. The app log shows the main thread blocked in that window: "fopen failed for data file" ×2, "building pipeline path_exterior-… took 0.911026 seconds", "System gesture gate timed out" (freeze-excerpt-app-stdout.txt). In the recording frames (rec-pause/), the video layer kept playing (green → purple) while the UI stayed at 0:00.0 with a Play icon. At rec 15.5 s it showed 0:04.6 and Pause, and by the read the clip had ended. This is the slow-runner freeze in Learned (T-021). The run as a whole was not slower than 45158384614 (median duration ×0.96, median tap 0.39 s against 0.54 s), and the idle-stall guard never fired.
Fix: re-run it. Later, in T-024b (which reworks this class), launch it with `-uiTestingSampleSeconds 20` like the T-034 hardening.

```text
VERDICT: Blocked
SPEC: AC-1 to AC-5 met; AC-6 met except "every existing test passes" (1 pre-existing flaky UI failure, C5)
CHECKS_RUN: CI 45168178904 (0a075c6, targeted) → build ok, 369/370 runs, 333 names; the failure is SubtitleStyleSheetTesterUITests/testUsingTheSheetDoesNotPausePlayback (pre-existing flake). cmpattach vs 45158384614 → 40/40 identical
NEEDED: commit ios/ClipDeckTests/SubtitleUpLimitTesterTests.swift (tester test), then `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=tests -f only_testing="ClipDeckTests ClipDeckUITests/SubtitleStyleSheetTesterUITests"`. That one run decides both the flake and stepsFromObstructionFalseCountsFromTheRegionBottom. Without the commit: `gh run rerun 45168178904 --failed`
UNVERIFIED: none for Brent (no visible change). SubtitleStyleCardUITests is left for the landing run (C4)
REVIEWED_AT: 0a075c6fff3acb7c0ba728996809416df08b5657
```

### Round 1 addendum
_by loop-tester · 2026-11-23 07:26_

The verify-only pass is CI 45172400098 on 7036038 (the tester test only: `git diff 0a075c6 7036038` touches only SubtitleUpLimitTesterTests.swift, +23 lines), scope=tests, only_testing "ClipDeckTests ClipDeckUITests/SubtitleStyleSheetTesterUITests", one job, CI run 2 of 4. It is green: shard 1 passed, with **350 of 350 runs and 0 test issues** (313 names = round 1's 312 in the same classes + 1 new, none lost). Evidence: %TEMP%\clip-deck-loop\T-023-r1\verify (Data/ pruned).
- SubtitleUpLimitTesterTests/stepsFromObstructionFalseCountsFromTheRegionBottom passes, so `stepsFromObstruction: false` reaches both helpers (0.75 vs 0.80 with a 40 pt bottom obstruction). That closes the open part of AC-5.
- SubtitleStyleSheetTesterUITests/testUsingTheSheetDoesNotPausePlayback passes (28.1 s). Its Play tap took 1.75 s, and the read came 5.2 s after Play, still close to the 6 s clip's end, so C5 stands for T-024b. The class's other 3 tests pass, and its 2 text attachments are identical to 45158384614.
- Every other unit test passes again: SubtitleStyleTests 42, SubtitlePlacementTests 41, SubtitleFontTests 25, SubtitleStyleTesterTests 8, SubtitleUpLimitTesterTests 6.
- With round 1's evidence, every T-023 test has now passed: round 1 had 369 of 370 green, and its one failure (the flake) passed here. AC-6 "every existing test passes" is met. Before landing, the orchestrator's full run must still show SubtitleStyleCardUITests (C4) and the classes outside these targeted runs.

```text
VERDICT: Pass
SPEC: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6 met
CHECKS_RUN: CI 45168178904 (0a075c6, targeted) → 369/370, the failure is the pre-existing flake (C5); CI 45172400098 (7036038, verify) → 350/350, 0 issues; cmpattach vs 45158384614 → 40/40 identical (round 1) and 2/2 identical (verify)
UNVERIFIED: none for Brent (no visible change). SubtitleStyleCardUITests and the rest are left for the orchestrator's full landing run (C4)
REVIEWED_AT: 7036038c6892a6bb18747000d36520e5eb976f40
```
