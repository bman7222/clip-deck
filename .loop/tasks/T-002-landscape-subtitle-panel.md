---
id: T-002
title: Pop the subtitle list out on the right in landscape
lane: frontend
depends_on: [T-001]
status: done
round: 2
base_sha: 7d88f580d5a63544b4b81c3d8a7794df03ab249b
issue: 2
spec:
model:
---

## Pop the subtitle list out on the right in landscape

### What are we building?
In full-screen landscape (T-001), a button in the top-right corner of the tap-up controls opens the subtitle section. The video shrinks slightly and slides to the left, taking three quarters of the screen, and the subtitle list slides in to fill the right quarter. Pressing the button again closes it and the video goes back to full width.

### Why?
Brent wants to see and tap subtitle lines while watching sideways, without losing the video. Today the list only opens from a menu item and is a fixed 320 pt panel.

### Done when
- AC-1 When the landscape controls are showing, the top-right corner has a button (`player.panelToggle`, SF Symbol `sidebar.right`, spoken "Show subtitle list" / "Hide subtitle list").
- AC-2 Tapping it animates the video area to 75 % of the screen width on the left (the picture keeps its aspect ratio and shrinks a little) and slides in the panel (`player.sidePanel`) on the right with the remaining 25 %, never narrower than 180 pt. The panel holds, top to bottom: the subtitle-problem banner when there is one, a compact Make a Card button (`player.panel.makeCard`), and the cue list (current line highlighted, auto-scrolls, tap to seek).
- AC-3 The panel stays open when the overlay controls auto-hide. The overlay bars and the on-video subtitle line stay inside the video area while the panel is open.
- AC-4 Tapping the button again closes the panel and the video returns to full width. Rotating to portrait shows the normal portrait screen; rotating back restores the panel's open/closed state for that visit.
- AC-5 The "Show subtitle list" item is removed from the subtitles menu (and the old 320 pt panel code goes away); "Load different subtitles" stays.
- AC-6 `PlayerLandscapeUITests` gains a test that opens the panel and asserts `player.sidePanel` width is 25 % ± 2 % of the window width (or 180 pt if larger) and `player.video` width about 75 %; taps `cue.row.1` and sees `player.subtitle`; taps `player.panel.makeCard` and the card editor's `card.save` appears; attaches `landscape-03-panel` and `landscape-04-panel-card`. Orientation is reset in `tearDown`.

### How to check
CI only:
1. `git push origin loop/mkv-landscape-sideload`
2. `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload`
3. `gh run list --branch loop/mkv-landscape-sideload --workflow ios-simulator.yml --limit 3`, then `gh run watch <id> --exit-status`; on failure `gh run view <id> --log-failed`.
4. `./scripts/test-ios.sh` (simulator job) and `./scripts/build-ipa.sh` (ipa job) must be green; `MiningFlowUITests` still passes unchanged.
5. `gh run download <id> -n simulator-results -D <scratch>/ci`; read `screenshots/ui-tests/*landscape-03*` and `*landscape-04*`: video on the left ~3/4, list on the right ~1/4, current line highlighted.
Unverified for Brent: how the split feels on his iPhone; readability of long lines at 25 %.

### Agent notes
- Carried over from T-001 (round-4 Could fix): Make a Card in landscape doesn't restart the 3 s hide countdown, so the bars can fade while a card is recording. Fix it here (call `restartHideTimer()` in the button, or add `miningRange != nil` to `keepsControlsUp`). Also add a UI test for "Load different subtitles" from the landscape subtitles dialog. Note: on iOS 26, tap gestures attached to a SwiftUI Menu never fire; the landscape subtitles control is a Button + confirmationDialog (see T-001 notes).
- Depends on: T-001 (full-screen landscape, overlay controls, `player.video`).
- Source: Brent's goal item 2 ("3/4 or 7/8 of video, last vertical slice for subtitles"). Brent confirmed 2026-11-19: default video 3/4, panel 1/4, panel at least 180 pt. Keep the ratio as one constant; T-011 makes it draggable and remembered.
- Code: `ios/ClipDeck/Features/Player/PlayerView.swift`; reuse `CuePanel` as is. `showSidePanel` already exists.
- Use `GeometryReader` widths, not hard-coded points. Respect the trailing safe area inside the panel; its background may run to the edge.
- Slide in from the trailing edge with the existing `.spring(duration: 0.3)`.
- Two Make a Card buttons can be on screen together (overlay + panel), so the panel one needs its own identifier.
- Update `docs/DESIGN.md` (landscape side panel: 25 %, button top-right) and the DEVELOPMENT.md identifier list.

### Out of scope
- Portrait layout.
- Dragging to resize the panel and remembering its width (T-011); remembering whether the panel was open between app launches.
- iPad layouts.

## Implementation notes (round 1) · sonnet
_by loop-frontend · 2026-11-19_
- Changed: `landscape(_:size:insets:)` now lays out an `HStack` that ignores the safe area and uses the real screen width (`size.width` + side insets): video column `total - panel`, panel `max(total * 0.25, 180)` (constants `panelFraction`, `panelMinWidth`). The bars and panel pad their own content by the safe-area insets instead (so the bar heights now include the insets; the subtitle/chip offsets no longer add `insets` twice). Top bar's trailing slot is now `player.panelToggle` (`sidebar.right`, label "Show/Hide subtitle list", highlighted when open, restarts the hide timer). New `sidePanel`: banner, compact Make a Card (`player.panel.makeCard`; `makeCardButton` gained an `identifier` parameter), `CuePanel`, container id `player.sidePanel`. Panel and video column live outside the overlay, so the panel stays when the controls hide; the overlay and subtitle line are inside the video column. `showSidePanel` is not reset on rotation, so it restores in landscape. Old 320 pt panel removed; "Show subtitle list" removed from the landscape dialog and from the portrait Menu (AC-5; in portrait that item only changed a flag that portrait ignores, so portrait looks the same, but the Menu now has one item).
- T-001 carry-overs: `miningRange != nil` added to `keepsControlsUp` (bars stay up while recording, countdown restarts when it ends). New test `testLoadDifferentSubtitlesFromLandscapeDialog`.
- Tests: `PlayerLandscapeUITests.testSubtitlePanelOpensOnTheRight` (AC-6, screenshots `landscape-03-panel`, `landscape-04-panel-card`). In `PlayerLandscapeBehaviourUITests`: `testSubtitleListAndMakeACardInLandscape` opens the list through `player.panelToggle` instead of the dialog (same assertions on the list, subtitle, Make a Card and card range, minus the dialog-closes assert, which has no equivalent); `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying` uses "Load different subtitles" as the dialog sentinel because "Show subtitle list" no longer exists (the keep-up assertions are unchanged).
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckUITests/PlayerLandscapeUITests.swift, ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift, docs/DESIGN.md, docs/DEVELOPMENT.md
- Checked: nothing compiled (Windows, no Mac); read through only. CI needed.
- Tester, look at: that `ignoresSafeArea()` on the HStack really gives a full-screen width (panel 25 % of window; if the window reports safe-area width the test numbers will be off); bars still clear of the notch/corners; bottom bar `ViewThatFits` icon-only fallback with the panel open; compact Make a Card label at 180-220 pt; `testLoadDifferentSubtitlesFromLandscapeDialog` finds the nav bar title "Subtitles for Episode 1"; portrait unchanged.
- Gotchas: the test measures `player.video` frame width; if XCUITest reports the PlayerLayerView at the column width this is fine. Panel toggle sits at the right edge of the video column, not the screen corner, while the panel is open.

## Test report (round 1)
_by loop-tester · 2026-11-19 19:50_

CI run 44646676783 (headSha afb033a, started by hand): **ipa green, simulator red**. Of 56 test runs, 55 pass and 1 fails: `PlayerLandscapeBehaviourUITests.testLoadDifferentSubtitlesFromLandscapeDialog`, with the issue "XCTAssertFalse failed - The list item moved to the panel button". The results come from the xcresult `database.sqlite3` (TestCaseRuns, TestIssues and Activities). `ClipExtractorTests` passed on the first attempt, so no re-run was needed.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 When the landscape controls are showing, the top-right corner has a button (`player.panelToggle`, SF Symbol `sidebar.right`, spoken "Show subtitle list" / "Hide subtitle list"). | Pass (partly by reading) | Run 44646676783: `testSubtitlePanelOpensOnTheRight` and `testSubtitleListAndMakeACardInLandscape` find and tap `player.panelToggle` after the controls appear. The failing test shows that a button labelled "Show subtitle list" is on screen while the panel is closed. Symbol and trailing slot: PlayerView.swift:227-233 (read). The "Hide subtitle list" label is asserted only by the new tester tests, which have not run. |
| AC-2 Tapping it animates the video area to 75 % … panel (`player.sidePanel`) 25 %, never narrower than 180 pt … banner, `player.panel.makeCard`, cue list (highlighted, auto-scrolls, tap to seek). | Pass | `testSubtitlePanelOpensOnTheRight` passed in run 44646676783. It asserts the panel width is max(25 % of the window, 180) ± 2 % and the video width is 75 % ± 2 %. Tapping `cue.row.1` shows `player.subtitle`, and `player.panel.makeCard` opens the editor with `card.save`. The banner, the aspect ratio (`.resizeAspect`, PlayerLayerView.swift:12) and the highlight/auto-scroll (`CuePanel` unchanged) are checked by reading only. The landscape screenshots are rotated and cropped to the left ~400 pt (known), so they cannot show the panel. |
| AC-3 The panel stays open when the overlay controls auto-hide. The overlay bars and the on-video subtitle line stay inside the video area while the panel is open. | Unverified (no test ran) | Correct by reading: the panel sits outside the `if shown` overlay, and the bars and subtitle are inside the ZStack with `.frame(width: videoWidth).clipped()` (PlayerView.swift:150-179). New tester test `testPanelStaysOpenWhenControlsAutoHide` (uncommitted, not run). |
| AC-4 Tapping the button again closes the panel and the video returns to full width. Rotating to portrait shows the normal portrait screen; rotating back restores the panel's open/closed state for that visit. | Unverified (no test ran) | Correct by reading: `showSidePanel` is never reset on rotation (PlayerView.swift:55-63). New tester test `testPanelClosesAndSurvivesRotation` (uncommitted, not run). |
| AC-5 The "Show subtitle list" item is removed from the subtitles menu (and the old 320 pt panel code goes away); "Load different subtitles" stays. | Fail (its test is red) | Code is correct: the dialog has only Load + Cancel (PlayerView.swift:187-190), the portrait Menu has only Load (:375-377), and a grep finds no `320` panel. In run 44646676783 the dialog's "Load different subtitles" was found, but the test's absence check matched the panel toggle (Must fix below). |
| AC-6 `PlayerLandscapeUITests` gains a test that opens the panel and asserts widths …; taps `cue.row.1` …; taps `player.panel.makeCard` and `card.save` appears; attaches `landscape-03-panel` and `landscape-04-panel-card`. Orientation is reset in `tearDown`. | Pass | Run 44646676783: the test passed in 21.5 s with both attachments (manifest.json). `tearDown` resets to portrait (PlayerLandscapeUITests.swift:9-12). Revert check not run on CI. By tracing: on base 7d88f58 the trailing slot is `Color.clear` with no `player.panelToggle`, so the test's first `waitForExistence` fails. |
| T-001 carry-over: Make a Card holds the controls up | Pass (by reading only) | `miningRange != nil` in `keepsControlsUp` (PlayerView.swift:311). The 6 s sample's ~2 s clips are shorter than the 3 s countdown, so a UI test cannot tell fixed from broken code. |
| T-001 carry-over: test for "Load different subtitles" | Fail | Added, but it fails in CI (Must fix). The sheet-opening half never ran because the assert before it failed. |
| T-001 behaviour still holds (auto-hide, keep-up, end of video, portrait tap, back) | Pass | Run 44646676783: `testControlsStayWhilePausedAndAutoHideWhilePlaying`, `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying`, `testNavigationBarHiddenAndBackReturnsToEpisodes`, `testPortraitTapStillTogglesPlay`, `testControlsAppearOnTapInLandscape` and `MiningFlowUITests` all passed. |

### Findings
Must fix
Where: ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift:134 (at afb033a)
Problem: `XCTAssertFalse(app.buttons["Show subtitle list"].exists)` also matches `player.panelToggle`. Its label is "Show subtitle list" while the panel is closed, and XCUITest sees the top bar behind the confirmationDialog. The simulator job is red.
Proof: Ran it. Run 44646676783, TestIssues: "XCTAssertFalse failed - The list item moved to the panel button". Activities: the step "Checking existence of "Show subtitle list" Button" ran right before Tear Down.
Trigger: Every run of `testLoadDifferentSubtitlesFromLandscapeDialog`.
Fix: Exclude the toggle from the query. The tester applied this in the working tree (test file only, not run): `app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Show subtitle list", "player.panelToggle")).count == 0`. Keep it and re-run CI.

Should fix
Where: ios/ClipDeck/Features/Player/PlayerView.swift:195-212 (with `CueRow`, :597-613)
Problem: The panel is 25 % of 874 = 218.5 pt on the CI iPhone 17 Pro, but it pads its trailing side by the landscape safe-area inset (about 62 pt on this device), which leaves about 156 pt of content. `CueRow` then spends 8+8 (outer), 12+12 (inner), 56 (time) and 12 (spacing) points. That leaves the subtitle text a column of about 48 pt: 2-3 kana per line, or one short English word. The compact Make a Card (16 pt padding on each side) has about 108 pt for icon + "Make a Card", which probably truncates. The Agent notes asked for the trailing safe area to be respected, but the result makes the list hard to read, which defeats the point of the panel.
Proof: Traced it, from the widths in the code and the standard landscape inset. Not measured: the landscape screenshots are cropped and only failing tests keep a screen recording.
Trigger: Open the panel on any iPhone with a notch or Dynamic Island in landscape.
Fix: Keep the 25 % panel, but give the panel a compact row (time above the text, smaller paddings), so the text gets about 120 pt. Or decide with the planner whether the trailing inset should be counted inside the 180 pt minimum. Add a test that asserts a minimum width for the cue text in `cue.row.1`, so the result is measured and not traced.

Could fix
- The `landscape-04-panel-card` screenshot is taken right after the tap, before `card.save` appears, so it shows the recording state and not the editor (PlayerLandscapeUITests.swift:91-92).
- Portrait was not pixel-compared with main run 42740988540 in this round (the tester's scratch folder became unavailable). By reading, the only portrait change is the removed Menu item.

```text
VERDICT: Fail
SPEC: AC-1 met (Hide label not yet run), AC-2 met, AC-3 unverified (test written), AC-4 unverified (test written), AC-5 code met but its test is red, AC-6 met
CHECKS_RUN: CI run 44646676783 (afb033a): ipa success; simulator failure, 55/56 (testLoadDifferentSubtitlesFromLandscapeDialog); MiningFlowUITests pass; ClipExtractorTests pass first try
UNVERIFIED: how the split feels on Brent's iPhone; readability of lines in the panel (see Should fix); portrait pixel diff vs main
REVIEWED_AT: afb033a47effa7d95fdc21ee1535d5a3330ef6a1
```
Tester's uncommitted test changes (ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift): the fix for the line-134 assert, plus the new `testPanelStaysOpenWhenControlsAutoHide` (AC-3), `testPanelClosesAndSurvivesRotation` (AC-4) and the `waitUntilSettled` helper. None of them have run yet.

## Fix round 2
_orchestrator · 2026-11-19 · sent the round-1 Test report findings to loop-frontend (sonnet), with Brent's decision on the panel width:_
- **Brent's decision (panel readability):** BOTH (1) panel rows use a compact layout, with the timestamp above the text instead of a 56 pt time column beside it, and (2) the panel's 25% / 180 pt minimum counts only the usable content area: panel content width = max(25% of the usable width, 180 pt), where usable width = full width − leading inset − trailing inset, and the trailing safe-area inset is added on top as panel padding. The video gets the rest (about 70% of the screen on an iPhone 17 Pro). Make the compact Make a Card fit, with an icon-only fallback if needed. Update AC-6's width test to the new rule.
- The Must fix (test-only, line 134) is already fixed in the working tree by the tester, along with two new tests; keep them.

## Implementation notes (round 2) · sonnet
_by loop-frontend · 2026-11-19_
- Must fix (line-134 assert): already fixed by the tester in the working tree; kept as is, with the two new tests and `waitUntilSettled`.
- Should fix (readability): panel width is now `max(usableWidth * 0.25, 180) + insets.trailing`, where usable width is `size.width` (safe-area width); the video column gets `totalWidth - panelWidth`. `CuePanel` and `CueRow` gained `compact` (default false, so portrait is unchanged): time above the text, `Spacing.s`/`xs` paddings. The panel passes `compact: true`. The panel's Make a Card is in a `ViewThatFits` (full label, then icon-only fallback), both with id `player.panel.makeCard`.
- Tests: `testSubtitlePanelOpensOnTheRight` now asserts, from observed frames, panel >= 180, panel <= 35 % of the window, video + panel = window (2 %), video between 65 % and 75 %. `landscape-04-panel-card` is now taken after `card.save` appears. I did not add a cue-text width test (not asked; could not measure without a Mac).
- Docs: DESIGN.md updated to the new rule.
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckUITests/PlayerLandscapeUITests.swift, docs/DESIGN.md
- Checked: nothing compiled (Windows); read through only. CI needed.
- Tester, look at: the `ViewThatFits` Make a Card (full label vs icon at 180 pt content), cue text width in the panel, and that `size.width` really is the safe-area width (video + panel = window).

## Test report (round 2)
_by loop-tester · 2026-11-19 19:52_

CI run 44648208663 (headSha e615c89, started by hand): **ipa green; simulator red, but only from the known flake.** Of 58 test runs, 57 pass. The one failure is `ClipExtractorTests.cutsExactAudioAndScreenshot()` with "Caught error: .timedOut". It is listed in CONTEXT "Learned", and the diff does not touch it. The tester tried `gh run rerun 44648208663 --failed`, but the permission system denied it, so the simulator job has no green attempt yet. Every UI test passes in attempt 1, including the two round-1 tester tests, which ran here for the first time. The results come from the xcresult `database.sqlite3` (TestCaseRuns, TestIssues and Activities). Downloads are in `C:\Users\Brent\AppData\Local\Temp\clip-deck-loop\T-002-r2`, outside the repo.

Round-1 findings:
- Must fix (line-134 assert): **fixed.** `testLoadDifferentSubtitlesFromLandscapeDialog` passes (16.5 s) and reaches the picker sheet.
- Should fix (readability): **fixed in code; partly measured.** The panel is now `max(size.width * 0.25, 180) + insets.trailing` (PlayerView.swift:144-147), with compact rows (:621-640) and a `ViewThatFits` Make a Card (:204-209). The implementer's width test cannot tell the new rule from a wrong one: if `size.width` were the full 874 pt, the panel would be 280.5 pt and the video 67.9 %, which still passes its 65-75 % bounds. The tester has tightened the test (see AC-6); it has not run yet.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 When the landscape controls are showing, the top-right corner has a button (`player.panelToggle`, SF Symbol `sidebar.right`, spoken "Show subtitle list" / "Hide subtitle list"). | Pass | Run 44648208663: `testPanelClosesAndSurvivesRotation` asserts `toggle.label == "Show subtitle list"` before opening and waits for "Hide subtitle list" after. In `testPanelStaysOpenWhenControlsAutoHide`, the Activities step "Expect predicate label == "Hide subtitle list"" passed. The symbol `sidebar.right` is checked by reading only (PlayerView.swift:230). |
| AC-2 Tapping it animates the video area to 75 % … panel (`player.sidePanel`) …, never narrower than 180 pt … banner, `player.panel.makeCard`, cue list (highlighted, auto-scrolls, tap to seek). Brent's Fix round 2 changes this to: content = max(25 % of usable width, 180) + trailing inset. | Pass for behaviour; the exact rule is pending the verify-only run | Run 44648208663: `testSubtitlePanelOpensOnTheRight` passed (22.6 s): panel ≥ 180 and ≤ 35 %, video + panel = window ± 2 %, video 65-75 %. Tapping `cue.row.1` shows `player.subtitle`, and `player.panel.makeCard` opens `card.save`. Round 1 showed total = size + insets ≈ window, so `size.width` is the safe-area width (traced from both runs). The tester's tightened test asserts the exact rule; it has not run yet. |
| AC-3 The panel stays open when the overlay controls auto-hide. The overlay bars and the on-video subtitle line stay inside the video area while the panel is open. | Pass | Run 44648208663: `testPanelStaysOpenWhenControlsAutoHide` passed (19.4 s). The Activities show each step: video maxX ≤ panel minX; the toggle and `player.makeCard` are ≤ video maxX; after play, `player.back` disappears ("Waiting 5.0s … to not exist"); the panel and `cue.row.1` still exist; `player.subtitle` is found and its maxX is checked against the video column ("Find the "player.subtitle" TextView"). |
| AC-4 Tapping the button again closes the panel and the video returns to full width. Rotating to portrait shows the normal portrait screen; rotating back restores the panel's open/closed state for that visit. | Pass | Run 44648208663: `testPanelClosesAndSurvivesRotation` passed (27.7 s). In portrait the navigation bar shows, there is no panel, and `player.makeCard` is there. Back in landscape the panel is restored. The second tap closes it, and the video width = window ± 2. A closed panel stays closed after a trip to portrait and back. |
| AC-5 The "Show subtitle list" item is removed from the subtitles menu (and the old 320 pt panel code goes away); "Load different subtitles" stays. | Pass | Run 44648208663: `testLoadDifferentSubtitlesFromLandscapeDialog` passed. The dialog has no action labelled "Show subtitle list", and "Load different subtitles" opens "Subtitles for Episode 1". The portrait Menu has not changed since round 1 (read). |
| AC-6 `PlayerLandscapeUITests` gains a test that opens the panel and asserts widths … (updated to the new rule per Fix round 2); taps `cue.row.1` …; `card.save` appears; attaches `landscape-03-panel` and `landscape-04-panel-card`. Orientation is reset in `tearDown`. | Pass; the new-rule assertion is pending the verify-only run | Run 44648208663: the test passed, and both attachments are in manifest.json (`landscape-04-panel-card` is now taken after `card.save`). Its width part did not assert Brent's rule, so the tester added `XCTAssertEqual(panel.width, max((window − 2·inset)·0.25, 180) + inset, accuracy: 2)`, with the inset taken from `player.back` minX − 12. Revert check by tracing: on afb033a the panel is 218.5 pt against the expected 249.5 pt, so the test fails. Without the inset the panel would be 187.5 pt, which also fails. |
| Fix round 2 (Brent): compact panel rows; portrait CueRow unchanged | Pass (portrait measured; compact rows by reading) | Portrait: run 44648208663 screenshots 01-06 were pixel-compared with main run 42740988540. 01, 03 (the player with its cue list), 04, 05 and 06 differ only in the status-bar clock box (x 157-288, y 79-117). 02-show also has a faint shadow difference around the nav back button, which is not on the player screen. The compact layout (time above the text, xs/s paddings) is checked by reading only. |
| Readability: width of the panel's text column | Unverified (measurement pending) | Traced: on the iPhone 17 Pro the content is 187.5 pt, so the compact row's text column is 187.5 − 24 = 163.5 pt (round 1: about 48 pt). The landscape screenshots are still rotated and cropped (`landscape-03-panel` shows only the video column), and this xcresult has no UI hierarchy. The tester's test now attaches `landscape-03-panel-frames` (the key frames plus `app.debugDescription`) and `landscape-03-panel-element` (a screenshot of the panel element), and asserts that `cue.row.1` is ≥ 144 pt wide. |
| T-001 behaviour still holds; MiningFlowUITests unchanged | Pass | Run 44648208663: all 7 `PlayerLandscapeBehaviourUITests` and both `PlayerLandscapeUITests` pass. `MiningFlowUITests.testMakeACardFromSubtitleLine` passes. |

### Findings
Must fix: None. Should fix: None.

Could fix
Where: ios/ClipDeck/Features/Player/PlayerView.swift:204-209
Problem: The accessibility tree cannot show whether the panel's Make a Card shows the full label or falls back to icon-only. Both variants share the same id, label and full-width frame.
Proof: Read it. By tracing, the icon + "Make a Card" + 32 pt padding comes to about 160 pt, which fits in 187.5 pt of content.
Trigger: Any landscape panel.
Fix: No code change needed. Look at `landscape-03-panel-element` after the verify-only run.

Could fix
Where: ios/ClipDeckUITests/PlayerLandscapeUITests.swift (the implementer's round-2 width asserts)
Problem: They also accept the wrong width rule (see above).
Proof: Traced it.
Trigger: n/a
Fix: Done by the tester (test file only). The fix has not run yet.

```text
VERDICT: Blocked
SPEC: AC-1 met, AC-2 met (exact Fix-round-2 rule pending the tightened test), AC-3 met, AC-4 met, AC-5 met, AC-6 met (new-rule assertion pending)
CHECKS_RUN: CI run 44648208663 (e615c89): ipa success; simulator failure, 57/58, the only failure ClipExtractorTests.cutsExactAudioAndScreenshot .timedOut (known flake; the permission system denied the re-run); all 12 UI tests pass incl. testPanelStaysOpenWhenControlsAutoHide, testPanelClosesAndSurvivesRotation, testLoadDifferentSubtitlesFromLandscapeDialog, MiningFlowUITests; portrait pixel diff vs main 42740988540: clock only
UNVERIFIED: how the split feels on Brent's iPhone; readability of long lines at 25 % on a real device; measured text-column width (pending verify-only)
NEEDED: verify-only pass. Commit ios/ClipDeckUITests/PlayerLandscapeUITests.swift and run CI. PlayerLandscapeUITests.testSubtitlePanelOpensOnTheRight decides it: the exact width rule plus cue.row.1 ≥ 144 pt, and its landscape-03-panel-frames / -element attachments give the measured text column. The same run gives the simulator job a clean attempt past the ClipExtractor flake.
REVIEWED_AT: e615c89df4189ba0bea1477bc5c40cee7408856a
```

### Round 2 addendum
_by loop-tester · 2026-11-19 21:12_

CI run 44658198733 (headSha 9455f7f; the only change since e615c89 is the tester's tightened test file): **both jobs green on the first attempt.** All 58 test runs pass, `ClipExtractorTests.cutsExactAudioAndScreenshot` included (2.2 s). `testSubtitlePanelOpensOnTheRight` passed in 23.1 s, so the exact-rule and readability asserts held. The xcresult has no TestIssues.

The measured frames come from the `landscape-03-panel-frames` attachment (`app.debugDescription`, iPhone 17 Pro, iOS 26.5, landscape):

| Element | Frame (x, y, w, h), pt |
|---------|------------------------|
| Window | 0, 0, 874, 402 |
| Side inset (`player.back` minX − 12) | 62 |
| Expected panel, max((874 − 124)·0.25, 180) + 62 | 249.5 |
| `player.sidePanel` | 624.7, 0, **249.3**, 402 |
| `player.video` | 0, 0, 624.7, 402 (71.5 % of the window) |
| `cue.row.1` (panel content width) | 624.7, 111.3, **187.3**, 44.7 |
| `cue.row.1` time "0:02.0" | 636.7, 115.3, 40.3, 14.3 |
| `cue.row.1` text "元気ですか" | 636.7, **131.7** (below the time), 82.3, 20.3 |
| `player.panel.makeCard` | 632.7, 4, 171.3, 48.7, with child StaticText "Make a Card" 132.3 wide |
| `player.panelToggle` | 568.7, 8, 44, 44, label "Hide subtitle list", inside the video column |

- Brent's rule holds. The content is 187.3 pt, which is 25 % of the 750 pt usable width. The panel is 249.3 pt (content plus the 62 pt trailing inset). The content ends at x = 812 = 874 − 62.
- Readability, measured: the text starts at x 636.7 and the row content ends at 812 − 12, so the text column is **163.3 pt**. Round 1 traced it at about 48 pt. "元気ですか" (5 kana) measures 82.3 pt, so a line holds about 9-10 kana or 25-30 Latin characters.
- The panel Make a Card shows the **full label**: the accessibility tree has a "Make a Card" StaticText inside the button, and the element screenshot shows icon + "Make a Card". The round-2 Could fix about telling the two variants apart is resolved.
- The `landscape-03-panel-element` screenshot (the first readable picture of the panel) shows Make a Card at the top, then compact rows with the time above the line text. It was taken before `cue.row.1` was tapped, at 0:00 before the first cue, so no row is highlighted in it. The highlight's background code is shared with portrait and was checked by reading.

AC-2 and AC-6 move from "pending" to Pass. The readability row moves from Unverified to Pass (measured on the simulator). AC-1, AC-3, AC-4 and AC-5 pass again in this run.

```text
VERDICT: Pass
SPEC: AC-1 met, AC-2 met (Fix-round-2 rule measured: panel 249.3 vs 249.5 expected), AC-3 met, AC-4 met, AC-5 met, AC-6 met
CHECKS_RUN: CI run 44658198733 (9455f7f): simulator success 58/58 (first attempt), ipa success; earlier run 44648208663 (e615c89): 57/58, ClipExtractor flake only; portrait pixel diff vs main 42740988540: clock only
UNVERIFIED: how the split feels on Brent's iPhone; readability of long real subtitle lines at 163 pt on a real device
REVIEWED_AT: 9455f7f8c956435c3703f7b60355f412c20c4644
```
