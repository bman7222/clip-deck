---
id: T-023
title: Continuous position plus separate resets
lane: backend
depends_on: [T-022]
status: todo
round: 0
base_sha:
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
