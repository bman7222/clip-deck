---
id: T-022
title: Subtitles avoid the overlay
lane: frontend
depends_on: [T-021]
status: done
round: 2
base_sha: 5f8f212d01daa4452f3c9f231628e7158f3ae1c6
issue: 24
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Keep the subtitle line clear of the centre play buttons

### What are we building?
With T-021's overlay, a line moved up to the middle of the video sits under the play buttons. After this task, while the overlay shows, a line that would touch it moves just above or just below it, and goes back when the overlay hides. The saved position never changes.

### Why?
The subtitle stays readable and the buttons stay tappable.

### Done when
- AC-1 `SubtitlePlacement.frame` gains an optional `avoid: CGRect?` band in video-local coordinates, with a default of nil. It stays a pure, `nonisolated` function, and nil gives exactly today's result.
- AC-2 The rule: if the placed frame meets the band, the line moves just above it (bottom = band.minY) or just below it (top = band.maxY). It takes whichever needs the smaller move and still fits inside the active region. If neither fits, it goes below, and the usual clamps keep it inside the region. If there's no overlap, nothing changes.
- AC-3 The band covers the three overlay buttons, from back5's minX to forward5's maxX and 52 pt tall, plus 8 pt of padding on every side. It's computed from T-021's layout rule (25/50/75 %, 52/44 pt), not from measured views. PlayerView passes it only while the overlay is visible, in both orientations. The move uses the existing 0.2 s ease; when the overlay hides, the line goes back. `player.subtitleStyle` is never written.
- AC-4 New unit tests: an overlap where moving above is smaller, an overlap where moving below is smaller, no overlap (unchanged), neither fits (below, clamped), and a nil band reproducing today's frames for a few existing cases. One case combines the band with the landscape top and bottom bar obstructions.
- AC-5 A UI test in portrait and landscape:
  - seed `-uiTestingSubtitleStyle '{"upSteps":9}'` (45 %, mid-video), tap cue row 2 while paused, and show the overlay;
  - `player.subtitle`'s frame doesn't meet any `player.overlay.*` button's frame grown by 8 pt;
  - after the overlay hides, the line is back at the place it had before the overlay showed (within 1 pt).
  Attach `app.debugDescription` as evidence. Every existing test passes, and DESIGN.md describes the rule.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`. Watch it (`gh run watch <id> -i 60 --exit-status`), then download `-p 'simulator-results*'`. Check the new unit tests, the new avoidance UI test and its frames, and the SubtitleStyle* suites, whose placement must be unchanged.

### Agent notes
- Depends on: T-021 (the overlay). Source: spec T-022.
- The spec's UI test seeds "upFraction 0.45", but fractions only arrive in T-023. T-023 keeps the old keys working, so seed `upSteps: 9`, which is the same place.
- Code: `SubtitlePlacement.frame` is at SubtitlePlacement.swift:35-64. `SubtitleLineLayout` (124-155) must pass the band through. `subtitleLine` is at PlayerView.swift:540-562.
- The menu helpers (`canStepUpWithCardOpen`, `highestReachableUpStep`, `upStepAfterDownWithCardOpen`) don't take the band, because menus judge steps without the overlay.
- Learned: in landscape, use element screenshots and `app.debugDescription`. Don't put a mutating call inside `#expect`.
- From T-021/T-034 (orchestrator, 2026-11-23):
  - The overlay hides while the Aa style card is open (T-021 AC-7), and PlayerView.swift:258 is `showsOverlay: shown && !styleMenuOpen`. Avoid the overlay only while it's actually shown.
  - Build new UI tests on `ios/ClipDeckUITests/UITestSupport.swift`: `launchAndOpenSampleEpisode(sampleSeconds:)`, `rotateToLandscape` (the idle-stall guard), `readTogether`, `tapStep` and so on. For anything checked while playing, use `-uiTestingSampleSeconds 30`. Put a new UI class in `SHARD1_UI`, since shard 2 is the tightest at about 28 min.
  - Optional Could fix carried over from T-034's tester:
    - C1: `UITestAnimationWatch` (ios/ClipDeck/App/UITestAnimationWatch.swift:65-80) logs iOS 26 Liquid Glass animations with infinite duration and no delegate, which is noise. Skip those, and reword docs/DEVELOPMENT.md:167-170 to say "no `delegate UIViewAnimationState` line".
    - C2: the 6 mid-test landscape rotations aren't guarded. A stall there costs time, not a red run.

### Out of scope
- Hiding the overlay while the Move-Text menu is open (T-024a; Q3, decided by Brent on 2026-11-22).
- Step sizes and limits.

## Implementation notes (round 1) · sonnet
_by loop-frontend · 2026-11-23_
- Changed: `SubtitlePlacement.frame` gains `avoid: CGRect? = nil` (nil gives today's result). If the line fits the active region and its placed frame meets the band (positive overlap in x and y), it moves to bottom = band.minY or top = band.maxY, whichever is the smaller move and fits between the active top and bottom; if neither fits it goes below, clamped into the region. New pure `SubtitlePlacement.overlayBand(videoSize:)`: x from 0.25w-22 to 0.75w+22, 52 pt tall centred, plus 8 pt padding on every side. `SubtitleLineLayout` has `avoidsOverlay` (builds the band from its bounds). PlayerView `subtitleLine` gets `avoidsOverlay: showsOverlay` (so false while the style card hides the overlay) and a 0.2 s ease on it. The saved style is never written.
- Files: ios/ClipDeck/Features/Player/SubtitlePlacement.swift, ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckTests/SubtitleStyleTests.swift (7 new tests in SubtitlePlacementTests), ios/ClipDeckUITests/SubtitleAvoidOverlayUITests.swift (new; 2 tests), .github/workflows/ios-simulator.yml (class added to SHARD1_UI), docs/DESIGN.md (rule added under Playback overlay).
- Checked: nothing compiled (CI only). Hand-computed the unit-test frames for the 400x225 video.
- Not done: Could fix C1 and C2 (kept out to avoid unverified changes to the test-support code).
- Gotchas: `UITestSupport.launchAndOpenSampleEpisode` has no `sampleSeconds:` parameter, so the UI test passes `-uiTestingSampleSeconds 30` through `launchArguments`. "Cue row 2" is `cue.row.1` (zero-based). The line is not avoided when it is taller than the active region (it is pinned to the bottom, as before). In the UI test the overlay is hidden/shown by a tap at (6 %, 50 %) of `player.video`, which is clear of every button and the centred line.
- Tester, look at: the two new UI tests' frames in the attached `avoid-overlay-*` debugDescription; landscape baseline (controls hidden) vs. return frame within 1 pt; the SubtitleStyle* suites unchanged; that a long (wrapped) line near the band behaves.

## Test report (round 1)
_by loop-tester · 2026-11-23 03:49_

CI 45137420681 (cf006ee, scope=all, CI run 1 of 4):
- `ipa` passed in 2:20 (the Release build compiles). Shard 2 passed in 29:56 and shard 3 in 29:48. Shard 1 **failed** in 17:32 on one test.
- 421 runs: 420 passed, 1 failed, and the 375 existing names all passed. The name union is 384: the T-034 landing set of 375 (rebuilt from 45132085072) plus the 7 new unit tests and the 2 new UI tests. No names were lost.
- **The idle-stall guard did not fire.** There were 0 "Idle stall guard" activities and 0 "App animations complete notification not received" steps. The jobs had no "UI test idle stall" annotations, only GitHub's capacity notice and shard 1's exit 65. The 48 landscape rotations took at most 1.17 s and the 41 probes at most 0.07 s.
- All three shards finished under 35 min. Shard 2's 29:56 includes an AboutUITests launch that took 119.7 s ("Open dev.brent.clipdeck"). That is runner slowness, and the diff doesn't touch About.

Evidence is in %TEMP%\clip-deck-loop\T-022-r1 (Data/ pruned, 30 MB). The landscape failure's recording frames are in `rec-landscape/`.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `SubtitlePlacement.frame` gains an optional `avoid: CGRect?` band in video-local coordinates, with a default of nil. It stays a pure, `nonisolated` function, and nil gives exactly today's result. | Pass | It compiles in all jobs. It is a static member of `nonisolated enum SubtitlePlacement`, with `avoid: CGRect? = nil`. `aNilBandReproducesTodaysFrames` passed. All 32 earlier SubtitlePlacementTests passed. All 60 frame logs and trees from the SubtitleStyle*, SubtitleUpLimit*, SubtitleFont* and PlayerLandscape UI tests match 45132085072 (`cmpattach.py`: logs line by line, trees by every `player.subtitle` frame). The 3 that differ are timing logs and an About tree. |
| AC-2 The rule: if the placed frame meets the band, the line moves just above it (bottom = band.minY) or just below it (top = band.maxY). It takes whichever needs the smaller move and still fits inside the active region. If neither fits, it goes below, and the usual clamps keep it inside the region. If there's no overlap, nothing changes. | Pass | Four unit tests passed: above, below, clear (including a sideways-only miss) and neither-fits. I re-derived their numbers by hand. Real frames, portrait (`avoid-overlay-shown-portrait`): the line's maxY 195.0 = band.minY 195.0 exactly; the above move is 42.3 and the below move 49.7, so above was right. Landscape (failure hierarchy, panel 25 %): maxY 167.0 = 201 − 26 − 8; from the seeded bottom of 206.6 (with the 21 pt bottom inset), the above move is 39.6 and the below move 52.5, and both fit. |
| AC-3 The band covers the three overlay buttons, from back5's minX to forward5's maxX and 52 pt tall, plus 8 pt of padding on every side. It's computed from T-021's layout rule (25/50/75 %, 52/44 pt), not from measured views. PlayerView passes it only while the overlay is visible, in both orientations. The move uses the existing 0.2 s ease; when the overlay hides, the line goes back. `player.subtitleStyle` is never written. | Partly | **Band:** the rule's band matches the real buttons + 8: portrait 70.5–331.5 × 195–263 against measured 70.7–331.7 × 195–263 (1/3 pt pixel snap); landscape at 624.7 wide gives back5 134.2 and forward5 490.5 against measured 134.0 and 490.3. **Only while visible:** in portrait the hidden line is at the seeded place and the shown line is moved. **Card open, not pushed aside:** the line is not moved. With the card open the tree has no `player.overlay.*`, and SubtitleUpLimitTester's card-open climb log is byte-identical to 45132085072. Its Up steps 1–5 at panel 25 % (y 220…147.7, 24 tall) all meet the band (y 167–235, x 126–499; line x 279–376), so any avoidance would have changed them. **Saved style:** the diff never writes `storedSubtitleStyle`, and the portrait line comes back to y 213.3 = 116 + 214 − 9 × 0.05 × 206 − 24, exactly the seeded upSteps 9 place. **Not proven:** the landscape return (blocked by M1). The 0.2 s ease was only read (`.animation(..., value: avoidsOverlay)`); no recording caught the move, because the line appears only after the cue tap, when the overlay was already up. |
| AC-4 New unit tests: an overlap where moving above is smaller, an overlap where moving below is smaller, no overlap (unchanged), neither fits (below, clamped), and a nil band reproducing today's frames for a few existing cases. One case combines the band with the landscape top and bottom bar obstructions. | Pass | All 7 new tests ran and passed in shard 1. The bars case doesn't change the outcome (see C2). |
| AC-5 A UI test in portrait and landscape: seed upSteps 9, tap cue row 2 while paused, and show the overlay; the line doesn't meet any button grown by 8 pt; after the overlay hides, the line is back within 1 pt. Attach `app.debugDescription`. Every existing test passes, and DESIGN.md describes the rule. | **Fail** | `testLineAvoidsTheOverlayPortrait` passed (24.9 s). The seed really is in the path: the baseline line (y 213.3–237.3, x 152.7–249.7) overlaps playPause + 8 by 68 × 24 pt. The shown line clears all three buttons + 8 (0 overlap with playPause + 8). It returned within 1 pt. **`testLineAvoidsTheOverlayLandscape` failed** at SubtitleAvoidOverlayUITests.swift:51, "A tap hides the overlay" (M1). Every existing test passed (375/375). DESIGN.md:99 states the rule. |

I did not revert-check the main test. This is CI only, so it would need a dispatch. The portrait test still discriminates, though. Its hidden state runs the nil-band path, and that line meets playPause + 8, so without the avoidance, `meetsNoButton` stays false and the test fails.

### Findings

**Must fix**
- M1
  - Where: ios/ClipDeckUITests/SubtitleAvoidOverlayUITests.swift:81-82 (`tapVideo`, `dx: 0.06`), which fails at :51.
  - Problem: in landscape with the side panel open, the video column is 624.7 pt wide, so the tap lands at x 37.5 pt. That is on the simulator's Dynamic Island. The tap never reaches the app, the overlay stays, and the test fails before the baseline, show and return checks run. The landscape half of AC-5 (and AC-3's "goes back") is therefore unproven.
  - Proof: ran it in CI 45137420681, shard 1.
    - The synthesized event is at device point (201, 37.48). The island covers about y 13–50 pt and x 136–259 pt.
    - The first video tap, at 6 % of the full 874 pt width (device y 52.4), was just past the island and worked.
    - In the recording, the island pulses at 20.2 s and the controls stay (rec-landscape/frame-0020.4.png).
    - At failure the hierarchy shows the overlay still up, with the line correctly avoided at y 143–167.
  - Trigger: any landscape tap at x below about 50 pt at mid-height.
  - Fix: tap clear of the leading safe area and still left of the band, for example `CGVector(dx: 0.15, dy: 0.5)`. That gives portrait 60.3 (band from 70.5), landscape 131 (band from 188.5), panel 25 % 93.7 (band from 126.2) and panel 50 % 65.6 (band from 79.3). Alternatively, tap at x = back5.minX − 30 once the button exists. Re-prove with `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=tests -f only_testing=ClipDeckUITests/SubtitleAvoidOverlayUITests`. If only this test file changes, 45137420681 (420/421) still covers the product code.

**Should fix:** none.

**Could fix**
- C1 (a question for Brent)
  - Where: ios/ClipDeck/Features/Player/PlayerView.swift:187 and :547.
  - Problem: in portrait, the overlay stays up while the Aa style sheet is open. A real pause shows it, and `keepsControlsUp` includes `showStyleSheet`. So the line is pushed aside while the user steps the position in the sheet. With the sample's 24 pt line on the 402 × 226 video:
    - Up 5 to 8 all sit at the same place under the band;
    - 8 to 9 jumps 92 pt;
    - 9 to 13 all sit at the same place above the band.
    Landscape avoids this, because the card hides the overlay (T-021 AC-7). This follows T-022's wording (the overlay is visible), but the sheet's preview doesn't show the stored place.
  - Proof: Traced it with `SubtitlePlacement` arithmetic on the CI frames above.
  - Fix: pass `avoidsOverlay: showsOverlay && !showStyleSheet`, or hide the portrait overlay while the sheet is open, or leave it to T-024a's Q3 rule.
- C2
  - Where: ios/ClipDeckTests/SubtitleStyleTests.swift:294-299.
  - Problem: `theBandCombinesWithTheLandscapeBars` picks "above", which was already the smaller move, so the bars don't change the result.
  - Fix: add a case where a bar rules out the smaller move. For example, `place(SubtitleStyle(upSteps: 9), top: 50, avoid: band)` should give y 146.5 (below), because above would start at 38.5, which is under 50.
- C3: T-034's carried-over C1 (Liquid Glass noise in UITestAnimationWatch) and C2 (unguarded mid-test rotations) are still open, as the builder noted.

```text
VERDICT: Fail
SPEC: AC-1 met, AC-2 met, AC-3 partly (landscape return unproven; 0.2 s ease read only), AC-4 met, AC-5 not met (landscape UI test fails: M1)
CHECKS_RUN: CI 45137420681 scope=all: ipa pass 2:20; shard 1 FAIL 17:32 (1 of 364, the new landscape test); shard 2 pass 29:56; shard 3 pass 29:48; 420/421 runs, 384 names = 375 + 9 new; idle-stall guard never fired, no "UI test idle stall" annotation
UNVERIFIED: feel of the 0.2 s line move with the overlay fade (Brent, device); landscape return (after M1); a wrapped multi-row line near the band on a real episode (unit-tested only)
REVIEWED_AT: cf006eec0b211ca55638936e484db9278965aa3e
```

## Fix round 2
Round 1 failed M1: the landscape test's tap at dx 0.06 landed on the Dynamic Island. Brent's decisions (2026-11-23):
- Sonnet retry. Fix M1 with the tester's dx: 0.15.
- **New AC-6:** in portrait, the centred overlay hides while the Aa style sheet is open and comes back when the sheet closes. This is the same rule as the landscape Aa card (T-021 AC-7) and Move-Text. The line then shows at its true saved place while the user steps it. It answers round 1's C1. Add a UI test, and update DESIGN.md (Playback overlay) so it states one rule for both orientations.
- C2 (a unit case where the bars change the choice to below) is cheap, so add it. C3 (T-034's carry-overs) stays optional.

## Implementation notes (round 2) · sonnet
_by loop-frontend · 2026-11-23_
- M1: `tapVideo` in SubtitleAvoidOverlayUITests now taps at dx 0.15 (clear of the landscape Dynamic Island, left of the band in every layout).
- AC-6 (Brent's decision): PlayerView portrait passes `showsOverlay: overlayShown && !showStyleSheet`, so the overlay hides while the Aa sheet is open and returns on Done; `avoidsOverlay` follows it, so the line shows at its saved place. `keepsControlsUp` is unchanged. New UI test `testOverlayGivesWayToTheStyleSheetPortrait` (seed upSteps 8; show overlay, open sheet, overlay gone, three Up taps each move the line up by more than 1 pt, Done brings the overlay back). DESIGN.md now states one rule for both orientations.
- C2: new unit test `aTopBarRulesOutTheSmallerMoveAndTheLineGoesBelow` (upSteps 9, top 50: above would start at 38.5 < 50, so below, y 146.5; without the bar y 38.5).
- C3: not done. Nothing compiled (CI only).
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckUITests/SubtitleAvoidOverlayUITests.swift, ios/ClipDeckTests/SubtitleStyleTests.swift, docs/DESIGN.md.
- Tester, look at: that the portrait sheet tests in SubtitleStyleUITests still pass; the new test's Up steps (the sheet may need scrolling to reach Up); the landscape test now past the tap.

## Test report (round 2)
_by loop-tester · 2026-11-23 06:20_

CI 45158384614 (4079a44, scope=all, CI run 2 of 4):
- `ipa` passed in 2:14. Shard 2 passed in 19:54 (29/29) and shard 3 in 23:45 (28/28). Shard 1 **failed** in 30:45 (365/366). Every job finished under 35 min. Shard 1 has about 4 min of headroom left.
- 423 runs: 422 passed and 1 failed. The failure is `PlaybackOverlayUITests/testBarValueIsReadAfterTheBarHidLandscape`, which is pre-existing (see below). Every T-022 test passed.
- The name union is 386: the T-034 landing set of 375 (`T-022-r1/baseline-names.txt`) plus 8 SubtitlePlacementTests and 3 SubtitleAvoidOverlayUITests. No names were lost.
- **The idle-stall guard fired, once.** This is the first time its relaunch branch has run in CI.
  - In `PlaybackOverlayUITests/testOverlayIsCentredLandscape` the setup rotation took 60.4 s ("App animations complete notification not received").
  - The guard terminated and relaunched the app. After that, the rotation took 0.4 s and the probe 0.0 s, and the test passed (101.4 s).
  - Shard 1 shows two "UI test idle stall" annotations.
  - The stalled process (pid 20361) printed only the `UITestAnimationWatch: started` line, so no animation stayed on a layer for 3 s or more. Saved as `T-022-r2/stalled-pid20361-stdout.txt`.
  - The other 48 landscape rotations took at most 1.26 s, and the 41 probes at most 0.05 s.
- Why shard 1 took 30:45 (17:32 in round 1):
  - The VM was slow: the 31 UI tests both runs share ran ×1.26 slower.
  - The seed flake hit `testBarHasNoSkipButtonsLandscape`. The library was empty after 47 s, and `launchSeeded`'s relaunch rescued it, at a cost of 127 s instead of 17 s.
  - The guard's relaunch above added 86 s.

**Pre-existing failure.** `PlaybackOverlayUITests.swift:162`, "A video tap brings the bar back, still playing": the value was "Paused".
- Neither the test nor `UITestSupport` changed after d3c4fa2 (T-034). The product diff since round 1 is one portrait-only line (`portrait(_:)`), and this test runs in landscape without the style menu. It passed in round 1 (45137420681) and in 45132085072.
- What happened, from its activities and recording (`T-022-r2/rec-barvalue/`):
  - The Play tap took 11.5 s on a slow VM (event synthesis alone 7.2 s). The clip read 0:09.5 at 31 s.
  - The bar hid on time. `readTogether`'s snapshot of the hidden button then failed ("Find" plus 2 retries, done by +36.0 s).
  - XCTest logged nothing until the re-show tap at +55.9 s, a 20 s gap.
  - By then the 30 s clip had played to its end (0:30.0 at 58 s and 64.5 s; the video kept changing colour, so the app wasn't frozen). The end pauses the player.
- This is the clip-ends-during-a-slow-wait failure in CONTEXT "Learned" (T-034 round 1), this time without a stall.

Evidence is in %TEMP%\clip-deck-loop\T-022-r2 (Data/ pruned, 29 MB).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `SubtitlePlacement.frame` gains an optional `avoid: CGRect?` band in video-local coordinates, with a default of nil. It stays a pure, `nonisolated` function, and nil gives exactly today's result. | Pass | Unchanged since round 1, and it compiles in every job. `aNilBandReproducesTodaysFrames` passed, along with all the earlier SubtitlePlacementTests. Every SubtitleStyle*, SubtitleStyleSheetTester, SubtitleUpLimitTester, SubtitleFont* and PlayerLandscape frame log and `player.subtitle` tree frame matches 45132085072 (`cmpattach.py`: 61 the same, 2 timing-only logs differ) and round 1 (62 the same). |
| AC-2 The rule: if the placed frame meets the band, the line moves just above it (bottom = band.minY) or just below it (top = band.maxY). It takes whichever needs the smaller move and still fits inside the active region. If neither fits, it goes below, and the usual clamps keep it inside the region. If there's no overlap, nothing changes. | Pass | The above, below, clear and neither-fits unit tests passed. The new `aTopBarRulesOutTheSmallerMoveAndTheLineGoesBelow` passed, and I re-derived it: up 9 gives bottom 120.75; above would start at 38.5 < 50, so the line goes below to y 146.5 (without the bar, above at y 38.5). In real frames (`overlayframes.py`), the shown line's maxY equals band.minY exactly in both orientations. Portrait: the above move is 42.3 and the below move 49.7. Landscape (panel 25 %): the above move is 40.0 and the below move 52.0. |
| AC-3 The band covers the three overlay buttons, from back5's minX to forward5's maxX and 52 pt tall, plus 8 pt of padding on every side. It's computed from T-021's layout rule (25/50/75 %, 52/44 pt), not from measured views. PlayerView passes it only while the overlay is visible, in both orientations. The move uses the existing 0.2 s ease; when the overlay hides, the line goes back. `player.subtitleStyle` is never written. | Pass (ease Unverified) | **Band:** portrait rule 70.5–331.5 × 195–263 against buttons + 8 at 70.7–331.7 × 195–263; landscape 126.2–498.5 × 167–235 against 126.0–498.3 × 167–235. **Goes back, now proven in landscape:** `testLineAvoidsTheOverlayLandscape` passed (30.0 s). Shown, the line is at y 143–167; hidden again, it is at y 183.0–207.0 (x unchanged at 278.7). The seeded upSteps 9 place is bottom 369 − 9 × 0.05 × 361 = 206.55 (margins 8/33 on the 402 pt video), within 0.45 pt. The test's own 1 pt check against the settled baseline passed. Portrait hidden: y 213.3, exactly the seeded place, as in round 1. **Only while visible:** both hidden trees have no `player.overlay.*`, and the line is at the seeded place. With the portrait sheet open, see AC-6. **Saved style:** the diff writes no `storedSubtitleStyle`, and both orientations return to the seeded place. **0.2 s ease:** read only (`.animation(.easeInOut(duration: 0.2), value: avoidsOverlay)`, PlayerView.swift:601). No recording is kept for a passing test, and XCUITest waits for animations to finish before it reads a frame. |
| AC-4 New unit tests: an overlap where moving above is smaller, an overlap where moving below is smaller, no overlap (unchanged), neither fits (below, clamped), and a nil band reproducing today's frames for a few existing cases. One case combines the band with the landscape top and bottom bar obstructions. | Pass | All 8 ran and passed in shard 1. The bars now change the outcome in `aTopBarRulesOutTheSmallerMoveAndTheLineGoesBelow` (round 1's C2). |
| AC-5 A UI test in portrait and landscape: seed upSteps 9, tap cue row 2 while paused, and show the overlay; the line doesn't meet any button grown by 8 pt; after the overlay hides, the line is back within 1 pt. Attach `app.debugDescription`. Every existing test passes, and DESIGN.md describes the rule. | Pass, except "every existing test passes" (pending a re-run) | Portrait passed (23.2 s) and landscape passed (30.0 s). M1 is fixed: the dx 0.15 tap hid and showed the overlay. In both orientations the seeded line overlaps playPause + 8 (68 × 24 and 67.6 × 24 pt). The shown line has 0 overlap with all three buttons + 8, and it returns within 1 pt. All four `avoid-overlay-*` debugDescriptions are attached. Existing tests: 374 of 375 passed. The one failure is pre-existing (above). DESIGN.md:97-98 states the rule. |
| AC-6 (Fix round 2) In portrait, the centred overlay hides while the Aa style sheet is open and comes back when the sheet closes. The line then shows at its true saved place while the user steps it. Add a UI test, and update DESIGN.md (Playback overlay) so it states one rule for both orientations. | Pass | `testOverlayGivesWayToTheStyleSheetPortrait` passed (30.6 s). The sequence: the overlay showed (+16.4 s); the sheet opened; the overlay was gone (+20.4 s); back5 and forward5 were absent; Up was hittable at the first detent with no swipes; then 3 Up taps. Each step's `minY < previous − 1` check passed, at +22.6, +24.0 and +25.2 s. Done brought the overlay back (+29.2 s). The attached tree with the sheet open still lists `player.video` and `player.subtitle` but no `player.overlay.*`, so the overlay is really gone, not hidden from accessibility by the sheet. The line is at y 192.7–216.7: that is upSteps 11 (306 − 11 × 10.3, "Up 55%"), the true saved place. Avoided, it would sit at 171–195. **Discrimination (traced):** without `&& !showStyleSheet` the test fails at :102. Even past that, Up 9→10 would leave the line pinned at 171–195, so step 2 would fail too. DESIGN.md:97 states one rule for both orientations. The existing portrait sheet tests all passed: SubtitleStyleUITests ×7 portrait, SubtitleStyleSheetTesterUITests ×4, SubtitleFont* ×3, and the UpLimit portrait-sheet test. Their logs and trees are unchanged against 45132085072 and round 1. |

I did not revert-check the new tests in CI. That would need a dispatch, so discrimination was shown by tracing. Round 1's findings:
- M1 is fixed.
- Round 1's C1 is answered by AC-6.
- Round 1's C2 is done.
- Round 1's C3 (T-034's C1 and C2) is still open. Here, the guard fired only in a setup rotation, which it covers.

### Findings

**Must fix:** none.

**Should fix:** none.

**Could fix**
- C1 (a question for Brent)
  - Where: ios/ClipDeck/Features/Player/PlayerView.swift:188, :540 and :635-638, with SubtitleStyleSheet.swift:320 and :331-334.
  - Problem: the portrait sheet leaves the video interactive up to its first detent, and a video tap still runs `togglePortraitOverlay`. With the sheet open, that tap flips `portraitOverlayVisible`, but nothing shows (`showsOverlay` is false), and `keepsControlsUp` stops the hide timer. After Done, the overlay then stays hidden when it was up before the sheet opened, or appears when it wasn't. AC-6's "comes back when the sheet closes" then doesn't hold.
  - Proof: traced it; not run.
  - Trigger: open Aa in portrait, tap the video (for example, to dismiss the sheet), then tap Done.
  - Fix: Brent's call. Either ignore the tap while `showStyleSheet` is true, or close the sheet, as the landscape card does on a video tap (`toggleControls`).
- C2
  - Where: docs/DESIGN.md:95.
  - Problem: "see Style card" points to a bullet that is now called "Style menus (one rule, both orientations)".
  - Fix: rename the reference.
- C3 (pre-existing, outside T-022)
  - Where: `UITestSupport.readTogether` (ios/ClipDeckUITests/UITestSupport.swift:184-187), as used by `PlaybackOverlayUITests.readValue`.
  - Problem: on a slow VM, a failed snapshot of a hidden element was followed by 20 s with no activity, which let the 30 s clip end.
  - Fix: check `element.exists` before `snapshot()`, or give `testBarValueIsReadAfterTheBarHidLandscape` a 60 s clip.
- C4: T-034's carried-over C1 (Liquid Glass noise) and C2 (unguarded mid-test rotations) are still open, as before.

```text
VERDICT: Blocked
SPEC: AC-1 met, AC-2 met, AC-3 met (0.2 s ease read only, Unverified), AC-4 met, AC-5 met except "every existing test passes" (1 pre-existing flake, re-run needed), AC-6 met
CHECKS_RUN: CI 45158384614 scope=all on 4079a44: ipa pass 2:14; shard 1 FAIL 30:45 (365/366; only PlaybackOverlayUITests/testBarValueIsReadAfterTheBarHidLandscape, pre-existing); shard 2 pass 19:54; shard 3 pass 23:45; 423 runs, 422 passed; 386 names = 375 + 8 unit + 3 UI; idle-stall guard fired once (testOverlayIsCentredLandscape, 60.4 s, relaunched, passed); all 11 T-022 tests passed
NEEDED: re-run CI for the pre-existing flake PlaybackOverlayUITests/testBarValueIsReadAfterTheBarHidLandscape: `gh run rerun 45158384614 --failed` (shard 1 again, about 31 min; no code change needed)
UNVERIFIED: feel of the 0.2 s line move with the overlay fade (Brent, device); a wrapped multi-row line near the band on a real episode (unit-tested only); C1's video tap with the sheet open (traced only)
REVIEWED_AT: 4079a44b30255b27a3c7ee06c807595b1cd4d8f3
```

### Round 2 addendum
_by loop-tester · 2026-11-23 06:45_

CI 45158384614, attempt 2 (`gh run rerun --failed`, shard 1 only, same SHA 4079a44, CI run 3 of 4): shard 1 passed in 18:32, and the run now concludes **success**. ipa and shards 2/3 are green from attempt 1. I downloaded the new `simulator-results-1` by artifact ID (14815530542). Evidence is in %TEMP%\clip-deck-loop\T-022-r2\attempt2 (Data/ pruned).
- 366/366 runs passed, with 0 issues. With shards 2 and 3 from attempt 1, the name union is again 386 (the 375 T-034 set + 8 unit + 3 UI), identical to attempt 1.
- `PlaybackOverlayUITests/testBarValueIsReadAfterTheBarHidLandscape` passed (22.7 s) on the same fallback path: the bar hid, `readTogether` missed, a re-show tap followed, and it read "Playing". There was no silent gap this time, which confirms the attempt-1 failure was runner slowness, not this change.
- All 11 T-022 tests passed again: the 8 unit tests and the 3 UI tests (landscape 28.1 s, portrait 20.5 s, style sheet 32.8 s). Their frames are identical to attempt 1:
  - landscape: shown y 143–167 (maxY = band.minY 167), hidden y 183–207;
  - portrait: shown y 171–195, hidden y 213.3;
  - sheet: y 192.7, "Up 55%", no `player.overlay.*`.
- Shard 1's frame logs (SubtitleFontTester, SubtitleStyleCardTester, SubtitleUpLimitTester) match 45132085072: 23 the same, 0 different.
- The idle-stall guard did not fire in attempt 2: 0 guard activities, 0 stalled steps. 16 rotations took at most 0.15 s and 15 probes at most 0.02 s.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-5 ... Every existing test passes, and DESIGN.md describes the rule. | Pass | 45158384614 is green across both attempts. All 375 existing names passed: shard 1 in attempt 2 (366/366), shards 2 and 3 in attempt 1 (29/29, 28/28). The two UI tests and their frames are as in round 2 above. |

All the other criteria stand as in round 2: AC-1, AC-2, AC-4 and AC-6 pass, and AC-3 passes with only the 0.2 s ease unverified. The Could fix items C1–C4 stand and don't block.

```text
VERDICT: Pass
SPEC: AC-1 met, AC-2 met, AC-3 met (0.2 s ease read only, Unverified), AC-4 met, AC-5 met, AC-6 met
CHECKS_RUN: CI 45158384614 (4079a44) conclusion success: attempt 1 ipa 2:14, shard 2 19:54 (29/29), shard 3 23:45 (28/28); attempt 2 shard 1 18:32 (366/366, 0 issues); 386 names = 375 + 8 unit + 3 UI; idle-stall guard fired once in attempt 1 (relaunched, passed), not in attempt 2
UNVERIFIED: feel of the 0.2 s line move with the overlay fade (Brent, device); a wrapped multi-row line near the band on a real episode (unit-tested only); Could fix C1, a video tap with the portrait sheet open (traced only)
REVIEWED_AT: 4079a44b30255b27a3c7ee06c807595b1cd4d8f3
```
