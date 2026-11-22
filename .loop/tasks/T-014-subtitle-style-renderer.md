---
id: T-014
title: Draw the on-video subtitle line in a saved style that always stays inside the video
lane: frontend
depends_on: []
status: done
round: 1
base_sha: f906fd8782db0464387c6175de9e99d05a50dc06
issue: 15
spec: .loop/specs/subtitle-style.md
model:
---

## Draw the on-video subtitle line in a saved style that always stays inside the video

### What are we building?
Today the line on the video has one fixed look and one fixed place. After this task the player draws it from a saved style: font (Sans, Rounded or Serif), bold on or off, a size from 60% to 200%, and a position moved up or sideways. The line stays inside the video and the safe area in both orientations, also while the landscape bars show. There is no menu yet: a style can be set only through a Debug test flag. The default style looks exactly like today.

### Why?
This is the base the style menu (T-015, T-016) builds on. With the "always on screen" rule settled and tested here first, the menu tasks only have to change the style.

### Done when
- AC-1 `SubtitleStyle` and `SubtitleFont` exist as the contract in the spec ("Style value"): Int steps, ranges, `default`, `isDefault`, clamping mutators that report whether another step is possible, and JSON under `player.subtitleStyle` that is decoded per field and clamped on read.
- AC-2 The line uses the style's font, with Japanese cascades. Weight is bold or regular. The size is Dynamic Type `.title3` × scale, capped at a quarter of the region height. The white fill and black outline are unchanged. Only `player.subtitle` changes; the cue list and side panel don't.
- AC-3 The line is placed by a pure placement function that follows the spec's "Placement" section. The text view's frame hugs the text, which today it doesn't (`sizeThatFits` returns the full width). With the default style, the frame is bottom-centre, where it is today, with the landscape controls hidden and shown.
- AC-4 Unit tests (`ios/ClipDeckTests/SubtitleStyleTests.swift`) cover:
  - clamping and steps at both ends;
  - garbage, partial and out-of-range JSON;
  - a JSON round trip;
  - the fonts' weight and cascade;
  - placement: default; moved up and left; a bar that pushes the line; a line already clear of the bar that doesn't move; extreme steps clamped inside; a line taller than the region pinned to the bottom; landscape insets and the open panel's handle clearance.
- AC-5 `-uiTesting` launches clear the key unless `-uiTestingKeepSubtitleStyle` is passed, and `-uiTestingSubtitleStyle <json>` seeds a style. Both are documented in CLAUDE.md.
- AC-6 A new `SubtitleStyleUITests` seeks via a cue row while paused and compares the `player.subtitle` frame with the `player.video` frame:
  - portrait: default vs seeded {size +5, up 4, right −4, serif, bold off}. The seeded line is taller, higher and further left, and stays inside the video;
  - landscape (`-uiTesting`): the same, with the controls hidden and shown. While shown, the line is below the top bar's maxY and above the bottom bar's minY. Add `player.topBar` and `player.bottomBar` identifiers (`.accessibilityElement(children: .contain)`);
  - an extreme style {size +10, up 18, right 8} stays inside the video and the window's safe frame in both orientations;
  - evidence: `app.debugDescription` attached as text, and in landscape `XCUIElement.screenshot()` of `player.video` (see Learned).
- AC-7 ARCHITECTURE.md (key and placement rule) and PRODUCT_SPEC.md (global style assumption) are updated. Every existing test still passes.

### How to check
CI only (`ci_only: true`):
1. `git push origin loop/subtitle-style`, then `gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=all`.
2. `gh run list --branch loop/subtitle-style --workflow ios-simulator.yml --limit 3`, then `gh run watch <id> --exit-status`. On failure, `gh run view <id> --log-failed`.
3. `./scripts/test-ios.sh` (simulator job) and `./scripts/build-ipa.sh` (ipa job) pass.
4. `gh run download <id> -n simulator-results -D <scratch>`, then read the SubtitleStyleUITests attachments: the frames text and the landscape element screenshots (serif, regular weight, larger, moved).

Unverified for Brent: how the fonts look on his iPhone.

### Agent notes
- Depends on: none. Source: `.loop/specs/subtitle-style.md` ("Style value", "Placement", "Launch flags", "ASS files").
- Brent accepted D-1..D-8 on 2026-11-20. D-1 also adds "More fonts…", but that is T-017's job: keep the JSON decoding tolerant of unknown fields, so T-017's additive `pickedFontName` field fits in. Keep the font builder a single function (style → `UIFont`), so T-017 can extend it with the cascade.
- Code: `PlayerView.videoScreen` (subtitle at :413, the `subtitleBottomPadding` and `edgeInsets` callers at :173-178), `SelectableText` in `DesignSystem/Components.swift`, `ClipDeckApp.init` (the panelFraction reset is the pattern for the key reset).
- Don't make the style both `RawRepresentable` and `Codable` (infinite recursion).
- ASS needs nothing: the parser already drops every style and tag.
- The new files sit under `ios/ClipDeck` and `ios/ClipDeckTests`, which XcodeGen picks up. Regenerate the project.
- The sample cues are short (0.5–2 s, 2–4 s, 4–5.5 s). Tap a cue row while paused so the line stays put.

### Out of scope
- The style button and menu (T-015, T-016). Picked fonts (T-017).
- Colours, outline, background box. ASS file styles.

## Implementation notes (round 1) · sonnet
_by loop-frontend · 2026-11-20_
- Changed:
  - AC-1: `SubtitleFont` and `SubtitleStyle` (nonisolated, Codable, Equatable, Sendable). Int steps, ranges, `default`, `isDefault`, clamping mutators `stepSize/stepUp/stepRight` that return whether another step is possible, plus `canSizeUp/...` properties. JSON under `player.subtitleStyle`, decoded per field (try? per field), unknown fields ignored, clamped on read. Not RawRepresentable. `uiFont(pointSize:)` is the single style-to-UIFont function (T-017 extends it); `japaneseFallbackName` names the Hiragino face.
  - AC-2: `PlayerView.subtitleLine` draws the line with the style font; point size is today's Dynamic Type size x scale, capped at a quarter of the region height (floor 12). White fill and black outline unchanged. Cue list and panel untouched.
  - AC-3: pure `SubtitlePlacement.frame` (video-local coordinates, margins, top/bottom obstruction, line size, style). `SubtitleLineLayout` (a SwiftUI `Layout`) measures the child at the resting region width and places it. `SelectableText` got `font` and `hugsWidth` (width = widest line via `boundingRect`, +1 pt, stable when proposed back), so `player.subtitle`'s frame is the visible text. The line is now an `.overlay` of the video ZStack, so the video layout is unchanged. Landscape margins/obstructions reproduce today's paddings exactly (hidden: Spacing.m + bottom inset; shown: bottomBarHeight + Spacing.s).
  - AC-5: `ClipDeckApp.init` clears the key on `-uiTesting` unless `-uiTestingKeepSubtitleStyle`, then writes the normalised `-uiTestingSubtitleStyle <json>`. Documented in CLAUDE.md.
  - AC-6: `player.topBar` / `player.bottomBar` identifiers (`.accessibilityElement(children: .contain)`).
  - AC-7: ARCHITECTURE.md (key, placement rule), PRODUCT_SPEC.md (feature, global style assumption), CLAUDE.md (flags).
- Files: ios/ClipDeck/Features/Player/SubtitleStyle.swift (new), SubtitlePlacement.swift (new), PlayerView.swift, DesignSystem/Components.swift, App/ClipDeckApp.swift, ios/ClipDeckTests/SubtitleStyleTests.swift (new, includes placement tests), ios/ClipDeckUITests/SubtitleStyleUITests.swift (new), CLAUDE.md, docs/ARCHITECTURE.md, docs/PRODUCT_SPEC.md.
- Checked: nothing compiled (Windows, ci_only). Re-read every Swift change for syntax and for line breaks inside strings/comments. XcodeGen picks up the new files; run `xcodegen generate` in CI as usual.
- Gotchas:
  - Today's code scaled the font twice (preferredFont size, then `scaledFont`). I kept that (`UIFontMetrics.scaledValue(for: preferred.pointSize)`) so the default is identical at every text size, not just the default one.
  - `DeckIconButtonStyle` disabled look is T-015's; not touched.
  - Landscape UI test opens the side panel to reach a cue row, so both the default and seeded runs have the 32 pt handle clearance on the right.
  - While the bars show, a moved-up line is pushed to the bar's edge, so "higher" is asserted by minY (a taller line), not by maxY.
- Tester, look at: (1) default portrait and landscape screenshots against earlier runs (line position, wrapping, outline); (2) the `hugsWidth` size when proposed back (text not re-wrapping or clipped, esp. two-line cues and 200%); (3) UITextView height at the hugged width; (4) font weights/cascade assertions in SubtitleStyleTests (`designedFontsCarryAJapaneseCascade` reads `.cascadeList` back from the UIFont; if CoreText drops it, relax that test, the name test is the real contract); (5) the new UI tests' frames text and `video.screenshot()` attachments; (6) the existing player and landscape tests unchanged.

## Test report (round 1)
_by loop-tester · 2026-11-20 22:53_

CI run 44860511457 (6fc17c1, scope=all). The ipa job passes. The simulator job ran 298 test cases: 295 pass, 3 fail, 0 skipped, and there are no Swift warnings. All 4 SubtitleStyleUITests pass, and every SubtitleStyleTests case passes. The 3 failures:
1. `SubtitlePlacementTests.landscapeInsetsAndThePanelHandleClearance`: the test's arithmetic is wrong. The product follows the spec, so I corrected the test (see below).
2. `PlayerLandscapeBehaviourUITests.testControlsStayWhilePausedAndAutoHideWhilePlaying`: a known flake ("Playing: controls hide on their own").
3. `AboutUITests.testSourceLinksAreShownAndOpenInSafari`: Safari never launched on the runner ("com.apple.mobilesafari ... does not exist"). The diff doesn't touch About.

Pixel baseline: the latest green run on main (42740988540, 2026-11-10) predates the landscape player. Main's only later run (44838534920, fa881cd) failed in `EpisodeImporterTests.copiesAnMP4AndItsSubtitleIntoTheShowFolders`, which passes here. So the baseline is 44836733690, which ran on 5c7fb83, the same tree as main (fa881cd^2, empty diff).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `SubtitleStyle` and `SubtitleFont` exist as the contract in the spec ("Style value"): Int steps, ranges, `default`, `isDefault`, clamping mutators that report whether another step is possible, and JSON under `player.subtitleStyle` that is decoded per field and clamped on read. | Pass | 44860511457: all 30 SubtitleStyleTests cases pass (clamping at both ends, the step return values, 8 garbage inputs, partial, wrong types, an unknown `pickedFontName`, out-of-range, round trip for every font). |
| AC-2 The line uses the style's font, with Japanese cascades. Weight is bold or regular. The size is Dynamic Type `.title3` × scale, capped at a quarter of the region height. The white fill and black outline are unchanged. Only `player.subtitle` changes; the cue list and side panel don't. | Pass | Font, weight, cascade (`designedFontsCarryAJapaneseCascade` passes, so CoreText keeps `.cascadeList`), cap and scale tests pass. `portrait-seeded-screenshot` shows Hiragino Mincho, regular, with the white fill inside a black outline, at 150%. Cue list and panel are pixel-identical to the baseline: the portrait list in 03-player, plus landscape-03-panel-element, 05-panel-max and 05-panel-resized. |
| AC-3 The line is placed by a pure placement function that follows the spec's "Placement" section. The text view's frame hugs the text, which today it doesn't (`sizeThatFits` returns the full width). With the default style, the frame is bottom-centre, where it is today, with the landscape controls hidden and shown. | Pass (one hugging risk open) | Default frames: portrait (152.7, 306, 97×24), so midX 201.2 against the video's 201 and maxY = video maxY − 12. Landscape hidden: maxY 370 = 402 − 12 − 20. Landscape shown: maxY 274.3 = bottom bar minY 282.3 − 8. **Pixels against 44836733690:** in 03-player, mkv-01-player and mkv-03-embedded the only changed pixels are the status-bar clock, so the line is pixel-identical. In landscape-03-list, 03-panel and 04-recording the line's pixels are identical but sit 1 px (⅓ pt) further along the line (zero residual after that shift; C1). landscape-01, 02, 06 and 08 are identical. The 04-panel-card diff is the card sheet's presentation timing; no line is visible in it. Multi-line re-wrapping under `hugsWidth` is not exercised by any CI cue (all are one short line), so I added `SubtitleStyleTesterTests.huggedLineKeepsTheSameLinesAndIsStable`. |
| AC-4 Unit tests (`ios/ClipDeckTests/SubtitleStyleTests.swift`) cover clamping and steps at both ends; garbage, partial and out-of-range JSON; a JSON round trip; the fonts' weight and cascade; placement (default, moved up and left, a bar that pushes, a line clear of the bar, extreme steps, a too-tall line, landscape insets and the handle clearance). | Pass once verified | 12 of 13 placement tests pass. `landscapeInsetsAndThePanelHandleClearance` failed: "abs(farRight.maxX - 752) → 17.7", and the same for farLeft. By the spec formula, right 8 on a 100 pt line puts maxX at 413.5 + 270.8 + 50 = 734.3, not 752. Corrected in the test: 734.3 and 92.7, plus a 300 pt line that is clamped to 752 and 75. Not yet run. |
| AC-5 `-uiTesting` launches clear the key unless `-uiTestingKeepSubtitleStyle` is passed, and `-uiTestingSubtitleStyle <json>` seeds a style. Both are documented in CLAUDE.md. | Pass (keep flag not yet run) | Seed: every seeded UI test passes. Clear: `testLandscapeSeeded…`'s plain launch runs right after `testLandscapeExtreme…`'s seeded one and shows the default 97×24 line. CLAUDE.md documents both flags. Nothing exercised the keep flag or relaunch persistence, so I added `SubtitleStyleTesterUITests.testStyleIsKeptAcrossRelaunchOnlyWithTheKeepFlag`. |
| AC-6 A new `SubtitleStyleUITests` compares the `player.subtitle` frame with the `player.video` frame (portrait default vs seeded; landscape hidden and shown with bar ids; extreme style in both orientations; evidence attached). | Pass (leading safe inset not yet run) | All 4 pass. Frames: portrait seeded (51.7, 253, 151×36), so 20% up of 206 and 20% left of 370, as computed. Portrait extreme (196, 124, 190×48) sits at video top + 8 and right edge − 16. Landscape seeded is pushed to bar − 8 while shown. Landscape extreme shown has minY 68 = top bar 60 + 8. `player.topBar` and `player.bottomBar` frames are present. Element screenshots show the seeded and extreme lines. The builder's tests check the window frame but never move the line toward the leading (Dynamic Island) inset, so I added `testLandscapeExtremeLeftStaysClearOfTheLeadingSafeArea` (line.minX ≥ player.back minX). |
| AC-7 ARCHITECTURE.md (key and placement rule) and PRODUCT_SPEC.md (global style assumption) are updated. Every existing test still passes. | Pass for the docs; existing tests need a re-run | Docs read in the diff. Every existing player, landscape, MKV, expiry and mining-flow test passes, and so does ClipExtractor, except the known flake above and the About Safari launch. Neither failure is in code this diff touches. |

### Findings
No Must fix or Should fix in product code.

Could fix C1
Where: ios/ClipDeck/Features/Player/SubtitlePlacement.swift:49 (`x` = centre − width / 2 of the hugged box)
Problem: in landscape the default line is ⅓ pt (1 px) off its old place along its length. The hugged box (ceil(width) + 1) gets pixel-rounded differently from text centred inside the old full-width box. You can't see it, but it isn't pixel-identical.
Proof: Ran it. Shift search on landscape-03-list and 04-recording against 44836733690 gives a best match at 1 px with 0 residual. Portrait is exact.
Trigger: any landscape default line.
Fix: optional. Round `x` to the display scale like the old centring, or accept it.

Could fix C2
Where: ios/ClipDeck/Features/Player/PlayerView.swift:436 (`.overlay` above the ZStack)
Problem: the line is now drawn above `RecordingBadge` (before, it was below it in the ZStack). A line moved up and left can cover the recording badge while mining.
Proof: Read it.
Trigger: upSteps near 18 with rightSteps < 0 while recording.
Fix: T-015/T-016 can treat the badge as a top obstruction, or draw the badge above the overlay.

Could fix C3
Where: ios/ClipDeck/Features/Player/SubtitleStyle.swift:86-103 (`stepSize/stepUp/stepRight`)
Problem: the fields are settable `var`s, and `sizeStep + delta` traps on overflow if a caller first sets a field to Int.max. Only possible from code, not from saved data.
Proof: Read it.
Trigger: `style.sizeStep = .max; style.stepSize(1)`.
Fix: clamp before adding, or make the setters `private(set)`.

Builder's test bug (fixed by the tester, test file only): ios/ClipDeckTests/SubtitleStyleTests.swift `landscapeInsetsAndThePanelHandleClearance` expected 752/75 for a 100 pt line, which goes against the spec formula.

Tests added or changed (not yet run, deciding):
- ios/ClipDeckTests/SubtitleStyleTests.swift: corrected expectation plus a wide-line clamp.
- ios/ClipDeckTests/SubtitleStyleTesterTests.swift:
  - the default style gives the same font as before styles (name, size, traits, lineHeight) at the portrait and landscape region heights;
  - `huggedLineKeepsTheSameLinesAndIsStable`: through the real `SelectableText` sizing in a UIHostingController, the hugged height equals the full-width height for long EN, JA and mixed text, with an explicit newline, at 3 fonts × 3 widths. It must also not be wider than the proposal and must be stable when its width is proposed back.
- ios/ClipDeckUITests/SubtitleStyleTesterUITests.swift: kept across relaunch only with the keep flag; landscape extreme-left line clear of the leading safe inset in both bar states.
- Revert check: not possible locally (ci_only, no Swift on Windows). The builder's placement test already failed against real code in CI. The new tests' first CI run decides them.

```text
VERDICT: Blocked
NEEDED: verify-only pass. Product code is unchanged, so no ipa is needed: gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=tests (no only_testing: the deciding tests span both targets and only_testing takes one value). Deciding: ClipDeckTests/SubtitlePlacementTests/landscapeInsetsAndThePanelHandleClearance, ClipDeckTests/SubtitleStyleTesterTests (esp. huggedLineKeepsTheSameLinesAndIsStable), ClipDeckUITests/SubtitleStyleTesterUITests, plus re-checks of PlayerLandscapeBehaviourUITests/testControlsStayWhilePausedAndAutoHideWhilePlaying (known flake) and AboutUITests/testSourceLinksAreShownAndOpenInSafari (Safari didn't launch).
SPEC: AC-1, AC-2, AC-3 (default pixel-identical in portrait, 1 px in landscape), AC-5 (seed/clear) and AC-6 met; AC-4 met after the test fix (not yet run); AC-7 docs met, existing suite green except a known flake and the Safari launch
CHECKS_RUN: CI 44860511457 (ipa pass; simulator 295/298, 0 warnings); pixel diff against 44836733690 (portrait identical except the clock; landscape 1 px shift); xcresult issues and frames attachments read
UNVERIFIED: how Serif/Rounded and the outline on thin Mincho look on Brent's iPhone; accessibility text sizes (font equivalence tested only at the simulator default size)
REVIEWED_AT: 6fc17c17d39ffa2e912159eec68b2ac33d13538a
```

### Round 1 addendum
_by loop-tester · 2026-11-20 23:32_

Verify-only run 44863556968 (b289a5b, scope=tests, the full suite) is green: 308/308 pass, 0 skipped, and the only issue is an internal QoS notice. b289a5b changes only test files and this task file, so the product code is the same as 6fc17c1, and the ipa result from 44860511457 still stands.

- Deciding tests, all pass:
  - `SubtitlePlacementTests/landscapeInsetsAndThePanelHandleClearance` (corrected expectation);
  - `SubtitleStyleTesterTests`: the default font equals the old font at both region heights, and `huggedLineKeepsTheSameLinesAndIsStable` passes for all 5 texts × 3 fonts × 3 widths. So the hugged width never re-wraps or clips, and it is stable when proposed back;
  - `SubtitleStyleTesterUITests/testStyleIsKeptAcrossRelaunchOnlyWithTheKeepFlag`: the frames are seeded (51.7, 253, 151×36), then kept (51.7, 253, 151×36), then cleared (152.7, 306, 97×24);
  - `SubtitleStyleTesterUITests/testLandscapeExtremeLeftStaysClearOfTheLeadingSafeArea`: the line's minX is 78, against `player.back` minX 74 and a leading inset of 62. The line stays at the same x with the bars shown (minY 68) and hidden (minY 8).
- Re-checks, both pass on unchanged app code:
  - `PlayerLandscapeBehaviourUITests/testControlsStayWhilePausedAndAutoHideWhilePlaying` (known flake);
  - `AboutUITests/testSourceLinksAreShownAndOpenInSafari`. Its round-1 failure was a runner-environment flake (Safari never launched); added to CONTEXT.md Learned.
- All 4 SubtitleStyleUITests and every existing test pass again.

Criteria: AC-1..AC-7 pass. C1 (1 px landscape rounding) stays an open Could fix. C2 and C3 go to T-015's Agent notes.

```text
VERDICT: Pass
SPEC: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7 met
CHECKS_RUN: CI 44860511457 (6fc17c1: ipa pass; simulator 295/298, failures = test arithmetic + 2 flakes); CI 44863556968 (b289a5b, scope=tests: 308/308, 0 skipped); pixel diff against 44836733690 (portrait identical except the clock, landscape 1 px shift)
UNVERIFIED: how Serif/Rounded and the outline on thin Mincho look on Brent's iPhone; accessibility text sizes
REVIEWED_AT: b289a5b949b945828c23e384b3c4c58419fa7551
```
