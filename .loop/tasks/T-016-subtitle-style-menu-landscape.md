---
id: T-016
title: Adjust the subtitle style in landscape from a card in the bottom bar
lane: frontend
depends_on: [T-015, T-017]
status: done
round: 2
base_sha: 10fb1b8f044894ff9b3dc35d4c88c7e2f47c06a1
issue: 17
spec: .loop/specs/subtitle-style.md
model:
---

## Adjust the subtitle style in landscape from a card in the bottom bar

### What are we building?
In landscape, the new "Aa" button in the bottom bar opens a style card. The card pops up from the bottom of the video, in place of the bottom bar, and holds the same controls as the portrait sheet. The line stays visible just above the card, so every tap shows its effect. The controls don't fade while the card is open. Done, a tap on the video, or a rotation closes it.

### Why?
Most watching happens in landscape full screen, where a sheet would cover the whole video. Brent needs to adjust the line there and see the result.

### Done when
- AC-1 `player.subtitleStyle` fits next to `player.subtitlesMenu` in all three `bottomRow` variants. With the panel dragged to 50% on iPhone 17 Pro, it is hittable, and its frame lies inside the video column (maxX ≤ `player.sidePanel` minX).
- AC-2 The card `subtitleStyle.card`:
  - replaces the bottom bar while open, and the top bar stays;
  - reuses the controls and identifiers from T-015 and T-017, icon only, with the bars' look (`Color.black.opacity(0.55)`, `.dark` colour scheme, Theme tokens only). The three preset chips each show "Aあ" in their font, and `subtitleStyle.font.more` (`ellipsis.circle`) opens T-017's font picker. VoiceOver reads its value as the picked font's name;
  - lays out the 13 controls with `ViewThatFits` as one row, otherwise rows of 7 and 6, otherwise rows of 5, 4 and 4;
  - always stays inside the video column and the safe area.
- AC-3 The card appears with move-from-bottom + opacity, or opacity only when `accessibilityReduceMotion` is on, and leaves the same way.
- AC-4 `styleMenuOpen` and the font picker's presented state are both part of `keepsControlsUp`. The card stays open when the picker closes. The card closes:
  - on Done;
  - on a tap on the video (that tap only closes the card; it doesn't also hide the controls);
  - on a rotation (cleared with `subtitleDialogOpen`).
  Closing restarts the 3 s hide timer.
- AC-5 While the card shows, the line is pushed above it, through T-014's placement with the card's height as the bottom obstruction: `player.subtitle` maxY ≤ `subtitleStyle.card` minY. After closing, with the controls hidden, the line rests at its styled place.
- AC-6 `SubtitleStyleUITests` (landscape) checks:
  - (a) Keep-up, following the "stays visible" rule: play from the first cue, open the card, and check `player.back` and the card repeatedly for 3.5 s. The window ends before the 6 s sample ends, so the end of playback can't bring the controls back. Copy the timing notes in `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying`.
  - (b) Up ×3 and size up ×2 change the line's frame live, and the line stays above the card.
  - (c) The panel at 50% (drag the handle far left): the card's frame is inside the video column, and all 13 controls are hittable.
  - (d) Done, a video tap and a rotation each close the card.
  - (e) More fonts opens the picker. Cancelling it returns to the open card, with the controls still up.
  - Evidence per state: `app.debugDescription` text, plus `XCUIElement.screenshot()` of the window or `player.video` (`landscape-style-01-card`, `landscape-style-02-panel-50`). Not `app.screenshot()` (see Learned).
- AC-7 DESIGN.md's landscape paragraph and "Interaction and motion" cover the card. The existing landscape tests still pass, including the panel-width and keep-up ones.

### How to check
CI only:
1. `git push origin loop/subtitle-style`, then `gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=all`.
2. `gh run watch <id> --exit-status`. On failure, `gh run view <id> --log-failed`. Check Learned for the known flakes before counting a failure.
3. `./scripts/test-ios.sh` and `./scripts/build-ipa.sh` pass.
4. From `simulator-results`, read the landscape-style element screenshots and the frames text: the card sits in the column, the line sits above it, and the fonts and arrows look distinct.

Unverified for Brent: how it feels on his iPhone, and the iPhone SE / mini widths.

### Agent notes
- Carried over from T-017 (31bc513): SystemFontPicker is private in SubtitleStyleSheet.swift, so make it internal to reuse it. Could fix C1: a family whose only face is bold (e.g. ArialRoundedMTBold) draws bold even with Bold off, with no note (SubtitleStyle.swift:245/255); show the no-bold note there too, or say 'This font is always bold'. Re-check ExpiryBannerUITests/testOpenSideStoreWithoutSideStoreKeepsBannerAndExplains (failed in 44960788495 on the sample-episode timing flake) in this task's CI run.
- Depends on: T-015 (button, controls view, identifiers) and T-017 (the picker wrapper, `pickedFontName`, the More fonts control). Source: the spec's "Menu" and "Picked font" sections, and D-1 and D-6 (accepted 2026-11-20).
- `PlayerView.landscape` overlay (:184-199), `bottomBar`/`bottomRow` (:369-398), `keepsControlsUp` (:437), the rotation reset (:70-78), `toggleControls` (`onTap`).
- The tightest row today is about 245 of about 320 pt at 50%, and the new button adds about 52 pt. Measure it, don't assume.
- iOS 26: Menu gestures don't fire. The card's state is plain `@State`.

### Out of scope
- Portrait changes. New style options.

## Implementation notes (round 1) · sonnet
_by loop-frontend · 2026-11-21 20:30_
- Changed:
  - New `SubtitleStyleCard` (`subtitleStyle.card`): 13 icon controls laid out by `ViewThatFits` as 1 row, 7+6, or 5+4+4, with the bars' look (black 0.55, `.dark` scheme set by the player, the bars' insets, Theme tokens only). The preset chips show "Aあ" in their font and the current weight. More fonts (`ellipsis.circle`) is aqua while a font is picked, value = picked name or "None".
  - Shared with the sheet: new `StyleIconButton` (the sheet's `iconButton` now builds it), `SubtitleStyle.pickFont(_:)` and `boldSpoken`, and `SystemFontPicker` is now internal. The card owns no state beyond its own `@AppStorage` of the same style key.
  - `PlayerView`: `styleMenuOpen` and `showCardFontPicker` (both in `keepsControlsUp`), `styleCardHeight`. In the landscape overlay the card replaces the bottom bar (top bar stays) with move-from-bottom + opacity, or opacity only under Reduce Motion. The line's bottom obstruction is the card's measured height + `Spacing.s` while it is open. `toggleControls` only closes the card when it is open (no control hiding). Done calls `closeStyleMenu`; a rotation clears `styleMenuOpen` and the picker next to `subtitleDialogOpen`. The picker is a root `.sheet`, so the card stays open under it.
  - Removed the landscape "open the sheet at .large" fallback: the opener now sets `styleMenuOpen` in landscape and `showStyleSheet` in portrait only.
  - T-017 C1: `SubtitleStyle.pickedFontIsAlwaysBold` (a bold picked face and no non-bold face in its family). The sheet shows "This font is always bold." (`subtitleStyle.font.alwaysBold`), and Bold's spoken value says so (and "This font has no bold weight" for no-bold families) in the sheet and the card.
- Files: Features/Player/SubtitleStyleCard.swift (new), PlayerView.swift, SubtitleStyleSheet.swift, SubtitleStyle.swift, ClipDeckTests/SubtitleFontTests.swift (4 new tests), ClipDeckUITests/SubtitleStyleCardUITests.swift (new, 7 tests), docs/DESIGN.md, docs/PRODUCT_SPEC.md.
- Checked: nothing compiled (Windows, no Mac); scanned for literal line breaks in strings and for syntax by reading. Existing tests are untouched. None of them opened the sheet in landscape.
- NOT run: everything (CI only). The ExpiryBannerUITests/testOpenSideStoreWithoutSideStoreKeepsBannerAndExplains re-check (T-017 flake) needs this task's CI run.
- Tester, look at:
  - The card's frame is the union of its controls (children: .contain), so its minY is the top of the first row, not of the card's black background; `player.subtitle` maxY <= card minY is therefore a weaker check than the real one. The 50 % test checks each control's own frame instead. Judge the real top from the `landscape-style-01-card` / `-02-panel-50` video screenshots.
  - Which `ViewThatFits` level shows at 25 % and 50 % (frames text), and the card's height at three rows against the line's room (video height about 402 pt: top bar + 3-row card leaves little).
  - `.accessibilityAddTraits(.isSelected)` on `StyleIconButton` (More fonts) and `.accessibilityRemoveTraits` on Done are modifiers on a wrapper view; if `isSelected` isn't reported on More fonts, move the trait inside `StyleIconButton`.
  - The press-then-open timing in `testCardKeepsTheControlsUpWhilePlaying` copies the existing keep-up test; it is on the known-flake list.
- Gotchas: tests tap the video at x 0.3, not 0.5, because at a 50 % panel x 0.5 is the panel handle. The card's own state is plain `@State` (no Menu). `Reset` in the card is icon only, disabled at the default, so the 50 % test seeds `{"sizeStep":1}` to make it enabled.

## Test report (round 1)
_by loop-tester · 2026-11-21 20:39_

CI 44971851033 (ecc866e, scope=all, iPhone 17 Pro / iOS 26.5, Xcode 26.6). The **ipa job is green**: the app compiles in Release, and the IPA notice check passes. The **simulator job failed at build time**, so **no unit or UI test ran** (the xcresult has 0 test cases and 3 build issues). The only compile errors are in a test file the builder wrote:
- `ios/ClipDeckTests/SubtitleFontTests.swift:219:9: error: cannot use mutating member on immutable value: '$0' is immutable` (in the expansion of `#expect(style.pickFont("Georgia"))`)
- `ios/ClipDeckTests/SubtitleFontTests.swift:222:9: error: cannot use mutating member on immutable value: '$0' is immutable` (in the expansion of `#expect(!style.pickFont("NoSuchFont-Regular"))`)
- Follow-on: "Testing cancelled because the build failed." Nothing else was reported. The other primary files in the same compile batch (SubtitleParserTests, SubtitleStyleTesterTests, SubtitleStyleTests, VideoImportModelTests) had no errors, and the Debug app module built, because the test target compiled against it. It isn't known whether ClipDeckUITests was compiled before the cancel. I read SubtitleStyleCardUITests.swift for compile problems and found none: every pattern it uses already compiles in other UI test files.
- Cause: Swift Testing's `#expect` macro passes the receiver of a method call as an immutable `$0`, so a `mutating` call can't sit inside `#expect`. I fixed it in the test file: the results are read into `let`s first (test code only).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `player.subtitleStyle` fits next to `player.subtitlesMenu` in all three `bottomRow` variants. With the panel at 50% on iPhone 17 Pro, it is hittable, and its frame lies inside the video column (maxX ≤ `player.sidePanel` minX) | Unverified (no test ran) | Read: the button is in `transportButtons`, so it is in all three rows (PlayerView.swift:646-657). Deciding: SubtitleStyleCardUITests/testEveryControlIsHittableInsideTheVideoColumnWithThePanelAt50Percent |
| AC-2 The card replaces the bottom bar while open, and the top bar stays | Unverified | Read: PlayerView.swift:255-267. Deciding: testCardKeepsTheControlsUpWhilePlaying (makeCard absent), and the tester's checkCard (play absent, back present) at 3 widths |
| AC-2 It reuses the controls and identifiers, icon only, with the bars' look (`Color.black.opacity(0.55)`, `.dark`, Theme tokens only). Each chip shows "Aあ" in its font. `subtitleStyle.font.more` (`ellipsis.circle`) opens the picker, and VoiceOver reads the picked name | Unverified | Read: SubtitleStyleCard.swift uses only `DeckIconButtonStyle` (Shell/Ink/Accent) and black 0.55. The icons are distinct (13 different symbols plus 3 text chips). Deciding: testPresetChipsSelectAndAPickedFontShowsItsNameOnMoreFonts and testMoreFonts…; the chip close-ups `tester-chip-*` and `landscape-style-01-card` / `-02-panel-50` decide legibility |
| AC-2 It lays out the 13 controls with `ViewThatFits` as one row, otherwise 7 + 6, otherwise 5 + 4 + 4 | Unverified | Expected from the geometry (874 × 402, 62 pt side insets): closed 726 pt for 668 → 1 row; 25% about 507 pt → 7 + 6; 50% about 319 pt → 5 + 4 + 4. Deciding: the tester's testTheCardKeepsToTheSafeAreaAndTheLineToItsRealTopAtEveryPanelWidth (row counts asserted per width) |
| AC-2 It always stays inside the video column and the safe area | Unverified | The builder's 50% test checks against the window only. The tester's test checks every control against the bars' own edges (back minX, panel toggle maxX, play maxY), which use the same paddings, at all 3 widths |
| AC-3 Move-from-bottom + opacity, or opacity only under Reduce Motion, leaving the same way | Unverified (Brent) | Read: PlayerView.swift:553-555 and :262. XCUITest can't switch Reduce Motion on, and snapshots are too slow to see a 0.25 s move. Brent should check on the iPhone with Reduce Motion on and off |
| AC-4 `styleMenuOpen` and the picker state are part of `keepsControlsUp`. The card stays open when the picker closes. It closes on Done, on a video tap (which doesn't also hide the controls) and on a rotation. Closing restarts the 3 s timer | Unverified | Read: PlayerView.swift:545-571 and :92-99. Deciding: testCardKeepsTheControlsUpWhilePlaying, testDoneAVideoTapAndARotationEachCloseTheCard, testMoreFontsOpensThePickerAndCancelReturnsToTheOpenCard. "Closing restarts the timer" has no run test: the 6 s sample leaves no reliable window. It is covered in code twice (`closeStyleMenu` and `.onChange(of: keepsControlsUp)`) |
| AC-5 While the card shows, the line is pushed above it (`player.subtitle` maxY ≤ `subtitleStyle.card` minY). After closing, with the controls hidden, the line rests at its styled place | Unverified | The builder's check uses the union frame, which is 8 pt below the real top (Learned). The tester's tests use the real top (first row minY − 8) at 3 widths and at 200%, plus testAfterClosingTheLineRestsAtItsStyledPlace (rest unchanged after a close; Up ×2 and ×4 rest places are linear) |
| AC-6 (a)-(e) and the evidence `landscape-style-01-card`, `landscape-style-02-panel-50` | Unverified | All 7 SubtitleStyleCardUITests were built but never run |
| AC-7 DESIGN.md's landscape paragraph and "Interaction and motion" cover the card. Existing landscape tests still pass | Docs: Pass (read). Tests: Unverified | DESIGN.md:20, :89-91, :134 and PRODUCT_SPEC.md:107 describe the card, Reduce Motion and the always-bold note. The old "opens the same sheet" text is gone |
| Carry-over: always-bold note (T-017 C1) | Unverified | Deciding: SubtitleFontTests/aBoldOnlyFamilyIsAlwaysBoldAndSaysSo, aFamilyWithARegularFaceIsNotAlwaysBold, aFontWithoutBoldSaysSoWhenSpoken, pickFontTakesThePlaceOfThePresetAndIgnoresAMissingName (the fixed one), and SubtitleStyleCardUITests/testABoldOnlyFontSaysItIsAlwaysBold |
| Carry-over: the landscape sheet fallback is gone, and the portrait sheet still passes | Read: gone. Run: Unverified | The opener sets `styleMenuOpen` in landscape and `showStyleSheet` only in portrait (PlayerView.swift:651). The tester's checkCard asserts that no `subtitleStyle.sheet` appears in landscape. Portrait: SubtitleStyleUITests, SubtitleStyleSheetTesterUITests, SubtitleFontUITests and SubtitleFontTesterUITests must pass again |
| Carry-over: re-check ExpiryBannerUITests/testOpenSideStoreWithoutSideStoreKeepsBannerAndExplains | Unverified | It didn't run |

### Findings
Fixed in test code by the tester (uncommitted): a mutating call inside `#expect`
Where: ios/ClipDeckTests/SubtitleFontTests.swift:219 and :222
Problem: the ClipDeckTests target doesn't compile, so the whole simulator job (unit and UI tests) is cancelled.
Proof: Ran it. CI 44971851033: "cannot use mutating member on immutable value: '$0' is immutable"; xcresult BuildIssues shows these 2 errors plus "Testing cancelled because the build failed."
Fix: done. `let pickedGeorgia = style.pickFont("Georgia"); #expect(pickedGeorgia)`, the same for the missing name, plus a check that `font` stays `.sans`.

Could fix C1 (Brent's call; the verify run decides how often it happens): the first Up taps with the card open may not move the line
Where: SubtitlePlacement.swift:43-56 (T-014's rule), used by PlayerView.swift:238
Problem: the task says "the line stays visible just above the card, so every tap shows its effect". The placement pins the line at `videoHeight − (cardHeight + 8)` until its wanted place is higher than that. By the geometry, a one-row card (about 81 pt) takes about 3 Up taps before the line moves, and a two-row card at 25% (about 133 pt) about 6. Down taps near the bottom show nothing either. Done-when AC-5 asks for exactly this mechanism, so it's a spec tension, not a code bug. The builder's AC-6 (b) test passes on the size taps alone: after Up ×3 at 25%, `minY` falls because the line got taller and the card is taller than the bar.
Proof: Traced it (arithmetic only). The tester's testUpTapsWithTheCardOpenRecordWhereTheLineIs records the line's maxY after each of 8 taps (`tester-up-taps-card-open`) to settle it.
Fix (if Brent wants each tap to show): while the card is open, measure the position steps in the region above the card, or show the value ("Up 15%") on the card. Otherwise accept it as designed and note it in DESIGN.md.

Could fix C2: a stale comment in the keep-up test
Where: ios/ClipDeckUITests/SubtitleStyleCardUITests.swift:28-31
Problem: it says a broken rule hides the bar "about 1.5 s after opening". The opener calls `restartHideTimer()`, so a broken rule hides it 3 s after opening. The 3.5 s window still covers that, before playback ends at about 4.5–5 s, so the test still catches a regression, but with only about 0.5 s of margin.
Proof: Read it (PlayerView.swift:652).

```text
VERDICT: Blocked
SPEC: AC-7 docs met (read); AC-1..AC-6 and the carry-overs not yet proven by any run (the build of the test target failed; app code compiles, ipa green); AC-3 Reduce Motion is Brent's hand check
NEEDED: verify-only pass after committing the tester's test files: gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=tests (full suite; the app code is unchanged and its ipa is already green). Deciding tests: ClipDeckTests/SubtitleFontTests (4 new, incl. the fixed pickFont test); ClipDeckUITests/SubtitleStyleCardUITests (all 7); ClipDeckUITests/SubtitleStyleCardTesterUITests (3: per-width rows, safe area and real card top; rest after close; per-tap Up evidence for C1); portrait SubtitleStyleUITests, SubtitleStyleSheetTesterUITests, SubtitleFontUITests, SubtitleFontTesterUITests; PlayerLandscape*UITests; and the ExpiryBannerUITests/testOpenSideStoreWithoutSideStoreKeepsBannerAndExplains re-check
CHECKS_RUN: CI 44971851033: ipa job green (build-ipa.sh + notice check); simulator job test-ios.sh failed at build (2 compile errors in SubtitleFontTests.swift, 0 tests run)
UNVERIFIED: everything behavioural until the verify run; Reduce Motion (Brent, iPhone); feel on the iPhone; SE/mini widths (Brent). Mutation check of the main new test not done (ci_only, conservative budget)
REVIEWED_AT: ecc866ef5059b7aea11548f453972c971e9ccb3b (plus tester test edits in the working tree)
```

### Round 1 addendum
_by loop-tester · 2026-11-21 21:30_

Verify run 44972664549 (34ca7e6: test files only, on ecc866e's app code; scope=tests, whole suite, iPhone 17 Pro / iOS 26.5). The ipa job was skipped; it was green on ecc866e, and the app code is unchanged. **362/365 tests pass.** The 3 failures:
1. **SubtitleFontTests/aBoldOnlyFamilyIsAlwaysBoldAndSaysSo:** a product bug, M1 below.
2. **SubtitleStyleCardUITests/testABoldOnlyFontSaysItIsAlwaysBold:** the same bug, seen in the UI.
3. **SubtitleStyleCardTesterUITests/testTheCardKeepsToTheSafeAreaAndTheLineToItsRealTopAtEveryPanelWidth:** a flaw in my test, fixed below. It stopped at its first assertion, so its 25%, 50% and 200% parts and the chip close-ups didn't run. The 25% and 50% facts below come from the builder's attachments.

| Deciding test / item | Result | Evidence |
|---|---|---|
| SubtitleFontTests: 3 of the 4 new tests, including the fixed pickFont test | Pass | aFamilyWithARegularFaceIsNotAlwaysBold, aFontWithoutBoldSaysSoWhenSpoken and pickFontTakesThePlaceOfThePresetAndIgnoresAMissingName pass. All 16 earlier SubtitleFontTests pass |
| SubtitleFontTests/aBoldOnlyFamilyIsAlwaysBoldAndSaysSo | **Fail** | `pickedFontIsAlwaysBold → false`; `boldSpoken → "This font has no bold weight"` (M1) |
| SubtitleStyleCardUITests (a) testCardKeepsTheControlsUpWhilePlaying | Pass | `player.back` and the card stayed for 3.5 s while playing; Make a Card is absent |
| (b) testUpAndSizeChangeTheLineLiveAndItStaysAboveTheCard | Pass | At 25% the card is {0, 270, 624.7, 132} and the line {269.7, 233.3, 115, 28.7}, so the line's maxY is 262.0, 8 pt above the card's top. The values read "120 percent" and "15 percent up". Up ×3 didn't move the line here (C1); only the size taps did |
| (c) testEveryControlIsHittableInsideTheVideoColumnWithThePanelAt50Percent | Pass | The panel is at 437 (50%) and the card at {0, 218, 437, 184}. Rows: 5 at y 226 (fonts, More, Bold), 4 at y 278 (smaller, larger, Reset, Done), 4 at y 330 (arrows). x runs from 107.7 to 359.7, inside the column, the 62 pt leading inset and the 405 handle edge; the bottom is 374, clear of the 20 pt bottom inset. All 13 are hittable. AC-1: the opener fits and is hittable next to the subtitles button |
| (d) testDoneAVideoTapAndARotationEachCloseTheCard | Pass | Done, a video tap (the controls stay) and a rotation each close the card, and it doesn't come back |
| (e) testMoreFontsOpensThePickerAndCancelReturnsToTheOpenCard | Pass | The picker opens; `close` returns to the open card with the controls up; the value stays "None" and Sans stays selected |
| testPresetChipsSelectAndAPickedFontShowsItsNameOnMoreFonts | Pass | With Georgia seeded, More fonts reads "Georgia" and is Selected (the trait on the wrapper works). Serif selects and clears the pick |
| testABoldOnlyFontSaysItIsAlwaysBold | **Fail** | In the hierarchy (542D4360), More fonts reads "Arial Rounded MT B…" and is Selected, so the font is installed. The note shown is `subtitleStyle.font.noBold` "This font has no bold weight.", and Bold reads "This font has no b…" |
| Tester: testAfterClosingTheLineRestsAtItsStyledPlace | Pass | The rest place is maxY 370.0. After a close it is 370.0 again, unchanged. Up 2 gives 333.67 and Up 4 gives 297.67: rises of 36.33 and 72.33, linear |
| Tester: testUpTapsWithTheCardOpenRecordWhereTheLineIs | Pass | Per-tap numbers under C1 |
| Tester: …RealTopAtEveryPanelWidth | Fail (test flaw, fixed) | "374.0 is greater than 372.17 – subtitleStyle.font.sans is inside the bottom safe area (closed)". My reference was the play button's maxY. It is centred in a 47.7 pt row (Make a Card is taller), so it sits 1.8 pt above the row's bottom. The card's row bottom (374) equals the bar row's bottom, 8 + 20 pt above the screen edge. Fix: the reference is now max(play, Make a Card) maxY |
| AC-2 ViewThatFits levels | Pass | Closed: 1 row of 13 (y 330, card {0, 322, 874, 80}, x 103–771, inside 62…812). 25%: 7 + 6 (y 278: fonts, More, Bold, smaller, larger; y 330: arrows, Reset, Done). 50%: 5 + 4 + 4 |
| AC-5 Line above the card's real top | Pass | XCUITest reports the card's real frame. It has a background, so its frame is not a union: the reported minY equals the first row − 8. Closed: line maxY 314.0, card top 322. 25%: 262.0 against 270. Screenshot `landscape-style-03-live`: the "元気ですか" baseline is about 258 pt and the card's background starts at 270, with a clear gap |
| Screenshots | Pass | `landscape-style-02-panel-50` (unrotated, 437 × 402): the 3-row card is centred in the column; the handle grip is visible at the right edge. In `-01-card` and `tester-up-taps` (full-width video, rotated 90°), all 13 controls are in one row, and Down and Reset are dimmed at the default. Icons: 3 "Aあ" chips, `ellipsis.circle`, B, small and large A, 4 arrows, the counterclockwise arrow, the checkmark; all distinct. Colours: Shell-dark fill with Ink glyphs; Accent aqua with white for selected Sans, Bold on, and Done; dimmed at 0.45; the card's black 0.55 over the video. Chips: Sans is a bold gothic あ, Rounded a round maru あ, Serif a Mincho あ with a serif A. All three are legible and clearly different at 44 pt |
| Portrait sheet still passes | Pass | SubtitleStyleUITests 9/9, SubtitleStyleSheetTesterUITests 4/4, SubtitleFontUITests 4/4, SubtitleFontTesterUITests 4/4 |
| AC-7 existing landscape tests | Pass | PlayerLandscapeUITests 6/6 and PlayerLandscapeBehaviourUITests 8/8, including both known keep-up flakes |
| Carry-over: ExpiryBannerUITests/testOpenSideStoreWithoutSideStoreKeepsBannerAndExplains | Pass | 9.7 s. The flake didn't recur |
| AC-3 Reduce Motion; AC-4 "closing restarts the 3 s timer" | Unverified | AC-3 is for Brent on the iPhone. The timer restart is checked by reading only (closeStyleMenu plus `onChange(of: keepsControlsUp)`) |

**C1 per-tap evidence, for Brent** (iPhone 17 Pro landscape; each Up step is 5% of the 362 pt region, about 18.1 pt; the line rests at maxY 370 and is held 8 pt above the card):
- **One-row card (panel closed, card 80 pt). Measured:** Up 1, 2 and 3 leave the line at maxY 314.0. Up 4 moves it 16.3 pt (to 297.7), and every later tap moves it 18 pt. **The first 3 taps show nothing.**
- **Two-row card (panel at 25%, card 132 pt). Computed from the measured geometry,** which the one-row numbers and the rest-place test confirm to 0.3 pt: the line is held at maxY 262. Up 1–5 show nothing, Up 6 moves it about 0.5 pt (invisible), and Up 7 is the first visible move, about 18 pt. **6 taps show nothing.** The builder's (b) test confirms Up 3 at 25% leaves the line held at 262.0.
- **Three-row card (panel at 50%, card 184 pt). Computed:** the line is held at 210. Up 1–8 show nothing and Up 9 moves it about 3 pt. **About 8–9 taps show nothing.**
- **Down:** taps show nothing while the line's wanted place is below the held place.

This is T-014's rule working as specified (AC-5), so it stays Could fix. It is Brent's call whether that's acceptable.

### Findings (round 1 addendum)
Must fix M1: a bold-only family is reported as having no bold weight
Where: ios/ClipDeck/Features/Player/SubtitleStyle.swift:262-272 (`pickedFontIsAlwaysBold`); the same test is at :245 (`boldFace`) and :255 (`pickedFontHasBold`)
Problem: the check relies on `fontDescriptor.symbolicTraits.contains(.traitBold)`. ArialRoundedMTBold doesn't carry `.traitBold`, so `pickedFontIsAlwaysBold` is false, `pickedFontHasBold` is false too, and the sheet shows "This font has no bold weight." Bold's spoken value says the same, for a font that is always bold. The new always-bold note never appears, and 2 tests fail.
Proof: Ran it. CI 44972664549: SubtitleFontTests/aBoldOnlyFamilyIsAlwaysBoldAndSaysSo (`pickedFontIsAlwaysBold → false`, `boldSpoken → "This font has no bold weight"`), and SubtitleStyleCardUITests/testABoldOnlyFontSaysItIsAlwaysBold ("The always-bold note shows" failed). The UI hierarchy shows the font is installed and the noBold note is shown.
Trigger: in the portrait sheet, pick "Arial Rounded MT Bold" with More fonts. The line draws bold, but the sheet says the font has no bold weight.
Fix: decide "this face is bold" by its weight, not only by the symbolic trait. Read the weight trait (`fontDescriptor.object(forKey: .traits)` → `[.weight]`, or `CTFontCopyTraits` `kCTFontWeightTrait`, ≥ about 0.3), falling back to the face or style name ("Bold", "Heavy", "Black"). Use the same rule in `boldFace` and `pickedFontIsAlwaysBold`, so the family counts as "has bold" and "always bold" and never gets the noBold note. The UI test also needs the sheet's noBold note to stay hidden. Alternatively, drop the always-bold part (it was a carried-over Could fix) together with its 2 tests.

Fixed in test code by the tester (uncommitted): the bottom reference in my safe-area check
Where: ios/ClipDeckUITests/SubtitleStyleCardTesterUITests.swift (`checkCard`)
Problem: it used the play button's maxY, which is centred in a taller row and sits 1.8 pt above the row's bottom.
Fix: done. It now uses max(play, Make a Card) maxY.

Could fix C1 (Brent's call): numbers above. Could fix C2 (stale timing comment in the keep-up test) stands.

```text
VERDICT: Fail
SPEC: AC-1 met; AC-2 met (rows 13 / 7+6 / 5+4+4, inside column and safe area, distinct icons, Theme colours, legible chips, More fonts value and Selected); AC-3 Unverified (Brent: Reduce Motion); AC-4 met except "closing restarts the timer" (read only); AC-5 met (line 8 pt above the card's real top at 1 and 2 rows; rest place after close exact and linear); AC-6 (a)-(e) met; AC-7 met (docs; all landscape and portrait suites pass). Carry-over always-bold note: NOT met (M1). ExpiryBanner re-check passes
MUST_FIX: M1 SubtitleStyle.swift:262-272 (and :245/:255): bold-only family detected by .traitBold, which ArialRoundedMTBold lacks; it gets "no bold weight"; 2 tests fail
CHECKS_RUN: CI 44971851033 (ecc866e): ipa green, simulator build failed (test-file compile errors, fixed). CI 44972664549 (34ca7e6, scope=tests): 362/365; failures = M1 (2 tests) + tester test flaw (fixed, uncommitted)
UNVERIFIED: Reduce Motion on/off (Brent, iPhone); "closing restarts the 3 s timer" by run; feel on the iPhone; SE/mini widths; my per-width test's 200% and chip close-up parts (they'll run in the next round)
REVIEWED_AT: 34ca7e694d2d1287d6b4389f62949cb9a47e545e
```

## Fix round 2
_orchestrator · 2026-11-21 · round 1 failed on Sonnet; Brent chose to retry on Sonnet. Sent M1 (always-bold detection) and Brent's decision on C1 to the same loop-frontend:_
- **Brent's decision (C1):** while the landscape card is open, every Up/Down tap must visibly move the line (a live preview). Measure the position from the card's top while the card is open, so step n puts the line n × step above its resting place just over the card. After Done, the line rests at the real styled place, exactly as now. Portrait and the closed-card behaviour stay unchanged.
- The tester's edited ios/ClipDeckUITests/SubtitleStyleCardTesterUITests.swift is uncommitted and must be kept.

## Implementation notes (round 2) · sonnet
_by loop-frontend · 2026-11-21 22:10_
- M1: one shared rule `SubtitleStyle.isBoldFace(_:)` (bold symbolic trait, or `.traits[.weight]` >= 0.3, or a name containing bold, heavy or black) now decides "this face is bold" in `boldFace`, its post-check, and `pickedFontIsAlwaysBold` (both the base face and the "has a lighter face" scan). ArialRoundedMTBold is therefore its own bold face (`pickedFontHasBold` true, always bold, no "no bold weight" note). Georgia (regular weight 0, real bold face) and Zapfino (no bold face, weight 0) behave as before; the Hiragino fallback code is untouched.
- C1 (Brent's decision): `SubtitlePlacement.frame(..., stepsFromObstruction:)` (default false). When true, the wanted bottom is `activeBottom - upSteps x 5% x region height` instead of `resting.maxY - ...`, then clamped as before (inside the video, below the top bar). `SubtitleLineLayout` carries the flag, `PlayerView.videoScreen`/`subtitleLine` pass `shown && styleMenuOpen`. Closed card, portrait and the bars use the old rule (flag false). Left/right are unchanged.
- Tests: 4 new pure placement tests in SubtitleStyleTests.swift (n steps = n x 10.25 pt from the card's edge for 0...7, top clamp below the top bar, sideways unchanged, closed-card result equal to the normal rule). The tester's testUpTapsWithTheCardOpenRecordWhereTheLineIs now also asserts every tap lifts maxY by more than 1 pt.
- C2: the keep-up test's comment now says the timer restarts on open, so a broken rule hides the bar 3 s after opening.
- Docs: DESIGN.md card paragraph says the live-preview rule.
- Files: SubtitleStyle.swift, SubtitlePlacement.swift, PlayerView.swift, ClipDeckTests/SubtitleStyleTests.swift, ClipDeckUITests/SubtitleStyleCardUITests.swift, SubtitleStyleCardTesterUITests.swift (only the one added assertion; the tester's other edits kept), docs/DESIGN.md. Nothing compiled.
- Tester, look at: the up-taps log (each tap about 18 pt at one row, so 8 taps at 50 % with a 184 pt card go from maxY 210 up to about 66 and the clamp below the top bar may stop the last taps; if the 8th tap hits the clamp, lower the tap count in that assertion); ArialRoundedMTBold tests; the weight read as an NSNumber from `.traits`.

## Test report (round 2)
_by loop-tester · 2026-11-21 22:47_

CI 44976839046 (472e414, scope=all, iPhone 17 Pro / iOS 26.5). The **ipa job is green**. The **simulator job was cancelled by its 45-minute `timeout-minutes`** (job 02:35:59–03:21:42; the test step was cancelled at 03:21:12). It did not fail on an assertion: **272/272 unit tests pass**, and **44 UI tests pass with 0 failures** before the hang. One test hung, and **15 UI tests never ran**:
- Hung: `SubtitleStyleCardUITests/testUpAndSizeChangeTheLineLiveAndItStaysAboveTheCard` (started 03:06:21, never finished). From its very first tap (`tapVideo` after the rotation, before the card opened, default style), every XCUITest action waited 60 s for "App animations complete notification not received". The app log shows the main run loop going idle, but the "animations idle" reply never came after 03:06:35.7. By the cancel it had got through opening the card, Up ×3 and the first size-up tap, at about 2 min per tap. This happened in no other test (count of idle timeouts per test: 14 in this one, 0 elsewhere). The trigger came before the card opened, with no picked font and the card closed, where round 2's code computes exactly what round 1 did (`stepsFromObstruction` is false, so `wantedBottom = resting.maxY - upDistance`; `isBoldFace` is only reached with a picked font). Round 1's code passed this test in 44972664549. The audio HAL logged "skipping cycle due to overload" 15 times in this process (the runner was overloaded). I judge it an environment hang, not caused by the diff, but it isn't on the Learned flake list.
- Not run: SubtitleStyleSheetTesterUITests (4), SubtitleStyleTesterUITests (2), SubtitleStyleUITests (9). These are the portrait sheet and T-014/T-015 placement UI suites.
- Headroom: the previous full run (44972664549) took 44 min 21 s against the same 45-minute limit. The full suite now has almost no margin even without a hang.
- The upload kept only the unfinalised `Staging` bundle (no xcresult database). Evidence below comes from the session logs and the zstd-decoded attachment blobs.

| Criterion / check | Result | Evidence |
|---|---|---|
| M1 fixed: SubtitleFontTests/aBoldOnlyFamilyIsAlwaysBoldAndSaysSo | Pass | 44976839046 unit log: passed. The other 3 new font tests also pass |
| M1 in the UI: SubtitleStyleCardUITests/testABoldOnlyFontSaysItIsAlwaysBold | Pass | Passed (15.3 s) |
| Georgia / Zapfino / Hiragino W6 still right | Pass | georgiaDrawsLatin…, georgiaBoldUsesItsBoldFaceAndTheHeavierMincho (Georgia-Bold + HiraMinProN-W6), aFamilyWithoutBoldKeepsItsFace (Zapfino), aRoundedPicked…, aSansPicked… (HiraginoSans-W6), realFontsMapToTheirPreset: all pass. All of SubtitleFontTests passes |
| C1: every Up tap with the card open moves the line > 1 pt (testUpTapsWithTheCardOpenRecordWhereTheLineIs) | Pass | Passed (34.6 s). `tester-up-taps-card-open`: card top 322; opened maxY 314.0; Up 1–8: 296.0, 277.67, 259.67, 241.67, 223.67, 205.33, 187.33, 169.33. Every tap moves 18.0–18.33 pt (round 1: taps 1–3 moved 0) |
| C1: 4 new placement unit tests | Pass | withTheCardOpenEachUpStep…, …StillStopsBelowTheTopBar, …SidewaysStepsAreUnchanged, afterTheCardClosesThePlacementIsTheNormalRule: all pass. SubtitlePlacementTests and SubtitleStyleTests (T-014/T-015 unit) pass unchanged |
| C1: after Done the line rests at the real styled place | Pass | testAfterClosingTheLineRestsAtItsStyledPlace passed. `tester-rest-after-close`: rest maxY 370.0; after an unchanged close 370.0; Up 2 = 333.67; Up 4 = 297.67 (rises 36.33 / 72.33). This is identical to round 1, before the live preview existed |
| C1 with 2 and 3 rows, and the top-bar clamp | Pass (unit + computed), no UI per-tap run | No UI test taps Up with a 2- or 3-row card. The unit test covers the clamp (minY = top obstruction at 18 steps). Computed from the measured geometry (line 24 pt, top bar 60 + 8, step 18.1): 1 row, taps 1–12 move and 13 moves about 5 pt; 2 rows (card top 270), taps 1–9 move; 3 rows (card top 218), taps 1–6 move and 7 moves about 9 pt. **Later taps don't move the line** (C3 below) |
| AC-1, AC-2 rows and safe area at every width (tester per-width test, fixed bottom reference) | Pass, all parts ran | testTheCardKeepsToTheSafeArea…EveryPanelWidth passed (64 s). Closed: rows [13], bottom 374, card {0,322,874,80}, line maxY 314.0. 25%: rows [7,6], card top 270, line maxY 262.0. 50%: rows [5,4,4], card {0,218,437,184}, line maxY 210.0. Every control is inside leading 74 / trailing edge / bottom 374. 200% (3 rows): line {138.7,162,190,48}, maxY 210 < card top 218, minY 162 ≥ top bar 60 |
| Screenshots | Pass | 200% at 50% (unrotated, 1206×1310 px): the big "元気ですか" ends just above the card's dark band and is well clear of the top bar; Size up is dimmed at its limit, Down is dimmed at 0. 50% card at 100%: same layout, smaller line. Chip close-ups (132 px = 44 pt): Sans "Aあ" selected in aqua; Rounded and Serif (serif A, Mincho あ) are distinct; More fonts `ellipsis.circle`; Bold "B" on in aqua. All legible |
| AC-6 (a), (c), (d), (e), chips | Pass | testCardKeepsTheControlsUpWhilePlaying, testEveryControlIsHittable…50Percent, testDoneAVideoTapAndARotationEachCloseTheCard, testMoreFontsOpensThePicker…, testPresetChips…: all pass |
| AC-6 (b) testUpAndSizeChangeTheLineLiveAndItStaysAboveTheCard | **Not run (hung)** | See above. The C1 change touches the path this test checks |
| AC-7 landscape suites | Pass | PlayerLandscapeUITests 6/6 and PlayerLandscapeBehaviourUITests 8/8, including both known keep-up flakes |
| Earlier suites | Partly | Pass: About 3/3, ExpiryBanner 5/5, Launch, MKVImport 3/3, MiningFlow, SubtitleFontUITests 4/4, SubtitleFontTesterUITests 4/4, all 272 unit tests. **Not run:** SubtitleStyleUITests (9), SubtitleStyleSheetTesterUITests (4), SubtitleStyleTesterUITests (2) |
| AC-3 Reduce Motion; "closing restarts the timer" | Unverified | Unchanged from round 1 (Brent on the iPhone; timer by reading) |

### Findings
Could fix C3 (Brent's call): the live preview stops at the top-bar clamp, and the Up button stays enabled
Where: ios/ClipDeck/Features/Player/SubtitlePlacement.swift:55-61
Problem: with the card open, steps now start just above the card, but the range is still 0…18 steps of 5% of the full region. The line stops below the top bar after about 12 taps (one-row card), 9 (two rows) or 6 (three rows, panel at 50%). Further Up taps change the saved value (the line rises after Done) but show nothing, and Down taps from there show nothing until the value is back in range. Brent's "every Up/Down tap visibly moves the line" holds only for the first taps. The opposite effect also follows: at Up 13+ the preview sits lower than the real place it gets after Done.
Proof: Traced it with measured geometry (CI 44976839046: card tops 322/270/218, line 24 pt, top bar maxY 60, step 18.0–18.33 per tap). The unit test withTheCardOpenTheLineStillStopsBelowTheTopBar confirms the clamp.
Fix (if Brent wants it): while the card is open, scale the step to the room above the card (room / 18), or accept the clamp and note it in DESIGN.md.

Could fix C4: the name fallback in `isBoldFace` overrides a light weight trait
Where: ios/ClipDeck/Features/Player/SubtitleStyle.swift:244-252
Problem: the name test ("bold", "heavy", "black") runs even when the font reports a weight below 0.3. A user-installed family whose regular face has one of those words in its PostScript name (for example a "Black…" display or blackletter family) would count as bold. Bold would then do nothing (`boldFace` returns the base), and if every face matches, "This font is always bold." would show. The built-in families are fine: the picker is family-level (`includeFaces = false`, SubtitleStyleSheet.swift:165), so only each family's default face is picked, and the bold-named defaults (ArialRoundedMTBold, BradleyHandITCTT-Bold) really are bold. The 0.3 threshold equals `UIFont.Weight.semibold`. Medium (0.23) stays regular, which is right. "Arial Black" isn't an iOS family, and "Avenir Black" can't be picked as a face.
Proof: Read it. The ArialRoundedMTBold tests pass, but they would pass on the name rule alone, so no run shows the weight read working.
Fix: use the name only when the descriptor has no weight trait.

Infra (for the orchestrator, not code): the simulator job's `timeout-minutes: 45` (.github/workflows/ios-simulator.yml:31) leaves under a minute of margin for the full suite (44:21 in 44972664549). One stuck XCUITest action costs 60 s per action, so a single never-idle app uses up the rest of the budget.

```text
VERDICT: Blocked
SPEC: M1 fixed (both tests pass; Georgia/Zapfino/Hiragino tests pass). C1 live preview met (8/8 taps move 18.0–18.33 pt; rest after Done unchanged at 370/333.67/297.67; 4 unit tests pass). AC-1, AC-2, AC-5 at 1/2/3 rows and 200% met; AC-6 (a)(c)(d)(e) met; AC-7 landscape suites pass. AC-6 (b) and 3 portrait UI suites (15 tests) not run: the job hit its 45-minute timeout while (b) hung on "animations idle". AC-3 for Brent
NEEDED: re-run CI: gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=tests -f only_testing=ClipDeckUITests (the unit target is already 272/272 green and the ipa is green; the UI target alone fits in 45 min). Deciding: SubtitleStyleCardUITests/testUpAndSizeChangeTheLineLiveAndItStaysAboveTheCard, SubtitleStyleUITests, SubtitleStyleSheetTesterUITests, SubtitleStyleTesterUITests. Pass if they are green and nothing else regresses
CHECKS_RUN: CI 44976839046 (472e414, scope=all): ipa job green (build-ipa.sh + notice check); simulator test-ios.sh cancelled at the 45-min job timeout: 272/272 unit pass, 44/44 completed UI tests pass, 1 hung, 15 not run
UNVERIFIED: Reduce Motion on/off and feel on the iPhone, SE/mini widths (Brent); "closing restarts the 3 s timer" (read only); per-tap UI numbers for 2- and 3-row cards (computed, not run)
REVIEWED_AT: 472e41497f39d0290e234b2c1dfb89d5f5155bf8
```

_orchestrator · 2026-11-22 · Brent approved: raise the simulator timeout to 60 min (commit separate from T-016) and a UI-only re-run (dispatch 4 of 4). C3 (the preview stops below the top bar) and C4 (the bold-name rule) go to a follow-up task after T-016._

### Round 2 addendum
_by loop-tester · 2026-11-21 23:29_

Verify run 44982440176 (f71a426, scope=tests, only_testing=ClipDeckUITests, iPhone 17 Pro / iOS 26.5): **success**, simulator job 03:50:44–04:28:12 (37.5 min, inside the new 60-minute limit). The ipa job was skipped. The app code is the same as 472e414 (`git diff 472e414..f71a426` touches only the workflow timeout, 45 → 60, and the task file), where the ipa was green and 272/272 unit tests passed in 44976839046. From the xcresult database: **60/60 UI tests Success, 0 TestIssues**. The "animations idle" hang didn't recur.

| Deciding test | Result | Evidence |
|---|---|---|
| SubtitleStyleCardUITests/testUpAndSizeChangeTheLineLiveAndItStaysAboveTheCard (AC-6 b) | Pass (26.9 s) | `landscape-style-03-live-frames`, panel at 25%: card {0, 270, 624.7, 132} (7 + 6 rows); line {269.7, 179.0, 115, 28.7}, maxY 207.7 < card top 270, minY 179 > top bar 60; values "120 percent" and "15 percent up". In round 1 the line was held at maxY 262.0, so Up ×3 now moves it 54.3 pt (3 × 18.1): the live preview at 2 rows, measured. Screenshot `landscape-style-03-live`: the line sits mid-video, well above the card and below the top bar, and Down is enabled now |
| SubtitleStyleUITests (T-014/T-015 placement, portrait sheet, landscape seeded/extreme) | 9/9 Pass | Including testLandscapeSeededStyleWithControlsHiddenAndShown and testLandscapeExtremeStyleStaysInsideTheVideoAndWindow (the closed-card rule is unchanged) |
| SubtitleStyleSheetTesterUITests | 4/4 Pass | Including testAWrongSavedRiseIsCorrectedOnceTheSheetHasSettled and testEveryLimitDisablesItsOwnButton (a sample-episode flake in T-015; didn't recur) |
| SubtitleStyleTesterUITests | 2/2 Pass | testLandscapeExtremeLeftStaysClearOfTheLeadingSafeArea, testStyleIsKeptAcrossRelaunchOnlyWithTheKeepFlag |
| Everything else in ClipDeckUITests | Pass, no regressions | About 3, ExpiryBanner 5, Launch 1, MKVImport 3, MiningFlow 1, PlayerLandscapeBehaviour 8, PlayerLandscape 6, SubtitleFont 4, SubtitleFontTester 4, SubtitleStyleCard 7, SubtitleStyleCardTester 3 |

Final state of the criteria: AC-1, AC-2, AC-4 (except the timer restart, read only), AC-5, AC-6 (a)–(e), AC-7 and the carry-overs (always-bold note, the landscape sheet fallback removed, the ExpiryBanner re-check) are met by runs. Brent's C1 decision is met: every tap moves the line while the card is open (8/8 at 1 row, 3/3 at 2 rows measured), and after Done the line rests at its styled place. C3 and C4 stay open as Could fix for the follow-up task (Brent's decision). They don't block.

```text
VERDICT: Pass
SPEC: AC-1, AC-2, AC-4, AC-5, AC-6 (a)-(e), AC-7 met by runs; M1 fixed; C1 (live preview, then the real place after Done) met; AC-3 Reduce Motion and the timer restart are Unverified (Brent / read only). Could fix C3, C4 deferred to a follow-up task by Brent
CHECKS_RUN: CI 44976839046 (472e414, scope=all): ipa green, 272/272 unit, 44 UI pass then timeout (environment hang). CI 44982440176 (f71a426, scope=tests, only_testing=ClipDeckUITests): success, 60/60 UI tests, 0 issues
UNVERIFIED: Reduce Motion on/off, feel on the iPhone, SE/mini widths (Brent); "closing restarts the 3 s timer" (read only); per-tap UI numbers for a 3-row card (computed)
REVIEWED_AT: f71a426
```
