---
id: T-001
title: Watch in landscape full screen, with controls that appear on tap
lane: frontend
depends_on: []
status: done
round: 4
base_sha: 7f768862e265fbdb3a849622757994972120fb49
issue: 1
spec:
model: opus
---

## Watch in landscape full screen, with controls that appear on tap

### What are we building?
Today, turning the phone sideways shows the video above a controls bar with the navigation bar still visible. After this task, landscape fills the whole screen with the video. Tapping the video brings up the controls on top of it, and they fade away again on their own while the video plays. Portrait stays exactly as it is.

### Why?
On a phone in landscape, every point of screen matters. Brent wants the episode to fill the screen like any video app, with controls only when he asks for them.

### Done when
- AC-1 In landscape the video fills the screen edge to edge (letterboxed only by its own aspect ratio). The navigation bar, status bar and controls are hidden until the user taps. The home indicator auto-hides (`persistentSystemOverlays(.hidden)`).
- AC-2 Tapping the video shows the overlay controls and tapping again hides them. While playing, they hide after 3 s without a touch. They stay visible while paused, while scrubbing, while a sheet or menu is open, and while VoiceOver is running.
- AC-3 The overlay has a top bar (back button `player.back` that returns to the episode list, episode title, and an empty trailing slot that T-002 fills) and a bottom bar with the same controls as portrait: scrubber, back 5 s, play/pause, forward 5 s, offset, subtitles menu, and Make a Card, all with their existing identifiers. Controls stay inside the safe area (clear of the notch / Dynamic Island).
- AC-4 The current subtitle line stays on the video. It moves up above the bottom bar while the controls are showing, and Look Up still works on it. Make a Card works from landscape (recording chip shows, the editor opens).
- AC-5 Until T-002 lands, the subtitles menu's "Show subtitle list" still opens the existing side list next to the video, so the list is reachable in landscape.
- AC-6 Portrait is unchanged: tapping the video still toggles play, and `MiningFlowUITests` passes without edits.
- AC-7 A new UI test file `ios/ClipDeckUITests/PlayerLandscapeUITests.swift` opens the seeded sample episode, sets `XCUIDevice.shared.orientation = .landscapeLeft`, attaches screenshots `landscape-01-fullscreen` (no controls) and `landscape-02-controls` (after a tap), asserts `player.back` and `player.makeCard` appear after the tap and disappear after tapping again, and resets the orientation to portrait in `tearDown`.

### How to check
CI only (Windows, no Mac):
1. `git push origin loop/mkv-landscape-sideload`
2. `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload`
3. `gh run list --branch loop/mkv-landscape-sideload --workflow ios-simulator.yml --limit 3`, then `gh run watch <id> --exit-status` (check `headSha` matches the pushed commit). On failure: `gh run view <id> --log-failed`.
4. The `simulator` job runs `./scripts/test-ios.sh` (all unit + UI tests) and `./scripts/run-ios.sh`; the `ipa` job runs `./scripts/build-ipa.sh`. Both must be green.
5. `gh run download <id> -n simulator-results -D <scratch>/ci` and read `screenshots/ui-tests/*landscape-01*`, `*landscape-02*` and the existing portrait `03-player` shot. Landscape: video fills the screen, controls only in the second shot. Portrait: same layout as before.
Unverified for Brent: real iPhone feel of the auto-hide timing.

### Agent notes
- Depends on: None
- Source: Brent's goal item 2; `docs/DESIGN.md` (Player, Interaction and motion).
- Code: `ios/ClipDeck/Features/Player/PlayerView.swift` (`landscape(_:)`, `videoScreen(_:)`, `controls(_:)`). Landscape is detected with `GeometryReader` width > height; keep that.
- Navigation: hide the bar with `.toolbar(.hidden, for: .navigationBar)` in landscape only; the swipe-back gesture may stop working, so `player.back` must call `dismiss()`.
- Tap behaviour differs by orientation on purpose: portrait = play/pause, landscape = show/hide controls.
- Use `accessibilityVoiceOverEnabled` from the environment to keep controls up for VoiceOver.
- Give the video surface `accessibilityIdentifier("player.video")` (T-002's test measures it).
- Use `.animation` that respects Reduce Motion (SwiftUI springs already do). Overlay bars use a dark translucent background so white text stays readable on any frame.
- Update `docs/DESIGN.md` Player section and the DEVELOPMENT.md identifier list (`player.back`, `player.video`).
- New test file is picked up by XcodeGen through the `ClipDeckUITests` source folder.

### Out of scope
- The top-right panel button and the 75/25 split (T-002).
- Changing portrait in any way.
- Double-tap-to-seek or gesture scrubbing.

## Implementation notes (round 1) · sonnet
_by loop-frontend · 2026-11-19_
- Changed: landscape is now full screen. Video ignores safe areas; nav bar hidden (`.toolbar(.hidden)`), status bar hidden while controls are hidden, `persistentSystemOverlays(.hidden)`. Tap on video toggles controls in landscape, play/pause in portrait (`videoScreen(onTap:)`). Overlay = top bar (`player.back` calling `dismiss()`, title, empty 44 pt trailing slot) + bottom bar (scrubber, transport, inline Make a Card), dark translucent, forced dark colour scheme. Overlay stays in the hierarchy (opacity 0, no hit testing, `accessibilityHidden`) so an open Menu is not torn down by the auto-hide. 3 s auto-hide only while playing and not scrubbing / in a sheet / VoiceOver; pausing shows controls; entering or leaving landscape resets to hidden. Subtitle moves above the bottom bar (measured heights + safe area); recording chip moves below the top bar. Side list still opens via the subtitles menu. `player.video` identifier added. Controls split into `transportButtons` / `makeCardButton`, shared by portrait and landscape (portrait output unchanged).
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckUITests/PlayerLandscapeUITests.swift (new), docs/DESIGN.md, docs/DEVELOPMENT.md
- Checked: nothing compiled (Windows, no Mac). Read through for Swift 6 / iOS 17 API use only.
- Tester, look at: CI compile; `landscape-01/02` screenshots (bar insets, subtitle position, chip); `MiningFlowUITests` unchanged; whether `waitForNonExistence` on hidden buttons holds (relies on `accessibilityHidden`); whether tapping coordinate (0.5, 0.35) hits the video in the test.
- Gotchas: sample video is paused at start so the second tap hides controls; the empty trailing slot is a 44 pt spacer for T-002. Subtitle line text is white outlined and unaffected by the dark scheme override.

## Test report (round 1)
_by loop-tester · 2026-11-19 18:20_

CI run 44635551739 (headSha 135af0e matches the pushed SHA), iPhone 17 Pro simulator, Xcode 26.6. `ipa` job: green. `simulator` job: red. 1 failing test (`PlayerLandscapeUITests.testControlsAppearOnTapInLandscape`). All unit tests and `MiningFlowUITests` passed. The `run-ios.sh` step was skipped because the earlier step failed. No `landscape-01/02` screenshots exist because the test failed before the first attach. I checked landscape visually from the xcresult screen recording (frames at 11 s and 14 s, rendered locally) and from the failure's UI hierarchy dump.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 In landscape the video fills the screen edge to edge (letterboxed only by its own aspect ratio). The navigation bar, status bar and controls are hidden until the user taps. The home indicator auto-hides (`persistentSystemOverlays(.hidden)`). | Pass (visual) | Screen recording `6C857C0E….mp4` in run 44635551739: at 11 s and 14 s (after rotation, before any tap) the video fills the screen, black bars come only from the aspect ratio, and there is no nav bar, status bar or visible controls. The home indicator shows at 11 s and is gone by 14 s. The failure's UI hierarchy has no NavigationBar element. The automated assert for "controls hidden" fails (see AC-7). |
| AC-2 Tapping the video shows the overlay controls and tapping again hides them. While playing, they hide after 3 s without a touch. They stay visible while paused, while scrubbing, while a sheet or menu is open, and while VoiceOver is running. | Fail | Not exercised: the AC-7 test stopped before its first tap. Menu-open is not handled (finding 2). New test `testControlsStayWhilePausedAndAutoHideWhilePlaying` added for the next run. |
| AC-3 The overlay has a top bar (back button `player.back` that returns to the episode list, episode title, and an empty trailing slot that T-002 fills) and a bottom bar with the same controls as portrait: scrubber, back 5 s, play/pause, forward 5 s, offset, subtitles menu, and Make a Card, all with their existing identifiers. Controls stay inside the safe area (clear of the notch / Dynamic Island). | Unverified (layout OK) | Failure hierarchy (874×402): `player.back` at x 74, title, 44 pt trailing slot at x 756, slider, `player.playPause`, `player.offset`, `player.subtitlesMenu`, `player.makeCard`. Everything sits within x 74–800 and y 8–374, inside the 62 pt side and 20 pt bottom insets. Back → episode list was not exercised. New test `testNavigationBarHiddenAndBackReturnsToEpisodes` covers it. |
| AC-4 The current subtitle line stays on the video. It moves up above the bottom bar while the controls are showing, and Look Up still works on it. Make a Card works from landscape (recording chip shows, the editor opens). | Unverified | Not reached in CI. New test `testSubtitleListAndMakeACardInLandscape` (screenshots `landscape-03-list`, `landscape-04-recording`). Chip placement issue: finding 4. Look Up is for Brent to check on a device. |
| AC-5 Until T-002 lands, the subtitles menu's "Show subtitle list" still opens the existing side list next to the video, so the list is reachable in landscape. | Unverified | Not reached in CI. Covered by the same new test. |
| AC-6 Portrait is unchanged: tapping the video still toggles play, and `MiningFlowUITests` passes without edits. | Fail (minor) | `MiningFlowUITests` passed, unedited. `03-player` and `04-card-editor` are pixel-identical to main run 42740988540 except the status-bar clock (diff bbox 165,79–281,117). But the portrait recording chip moved 8 pt down (finding 3). Portrait tap → play is covered by new test `testPortraitTapStillTogglesPlay`. |
| AC-7 A new UI test file `ios/ClipDeckUITests/PlayerLandscapeUITests.swift` opens the seeded sample episode, sets `XCUIDevice.shared.orientation = .landscapeLeft`, attaches screenshots `landscape-01-fullscreen` (no controls) and `landscape-02-controls` (after a tap), asserts `player.back` and `player.makeCard` appear after the tap and disappear after tapping again, and resets the orientation to portrait in `tearDown`. | Fail | Run 44635551739: fails at `PlayerLandscapeUITests.swift:30` "Controls start hidden". `player.back` stays in the XCUITest tree for the full 5 s, although the screen shows no controls (finding 1). |

### Findings

Must fix
Where: ios/ClipDeck/Features/Player/PlayerView.swift:143-154 (overlay kept in the hierarchy with `.opacity(0)` + `.accessibilityHidden(!shown)`)
Problem: hidden controls are still visible to XCUITest, so `PlayerLandscapeUITests` cannot pass and AC-7 ("disappear after tapping again") cannot be met. On screen the controls are hidden. In the accessibility tree that XCUITest queries, they are not.
Proof: Ran it. CI run 44635551739 failed at PlayerLandscapeUITests.swift:30. The attached UI hierarchy lists `player.back`, `player.makeCard`, the slider, etc. while the screen recording shows no controls. It also lists the trailing 44 pt spacer (`Color.clear … .accessibilityHidden(true)`, PlayerView.swift:184-185) as `Other {{756,8},{44,44}}`, so `accessibilityHidden` does not remove elements from XCUITest's view here.
Trigger: rotate to landscape on the player, then query any overlay control.
Fix: render the overlay only while shown (`if shown { overlay.transition(.opacity) }`), so the tree matches the screen. Keep the controls up while the subtitles menu is open (finding 2), so removing the overlay never tears down an open Menu.

Should fix
Where: ios/ClipDeck/Features/Player/PlayerView.swift:245-248 (`keepsControlsUp`)
Problem: AC-2 says the controls stay visible "while a sheet or menu is open". The subtitles `Menu` is not tracked. While playing, opening the menu does not stop the 3 s timer, so the controls fade out under the open menu. Once finding 1 is fixed by removing the overlay, the Menu would be torn down mid-use.
Proof: Traced it. `keepsControlsUp` checks only `showOffset`, `showSubtitlePicker`, `draft`, playing and scrubbing state. The `simultaneousGesture` taps on the bars (lines 190, 209) only restart the 3 s timer.
Trigger: landscape, play, tap to show controls, open the subtitles menu, wait 3 s.
Fix: track menu state and add it to `keepsControlsUp`. Either replace the `Menu` with a button + `confirmationDialog(isPresented:)` (trackable), or set a `menuOpen` flag on the label tap and clear it in each menu action and on the next video tap.

Should fix
Where: ios/ClipDeck/Features/Player/PlayerView.swift:216 and 232
Problem: portrait changed, which AC-6 and "Out of scope" forbid. `badgeTopPadding` defaults to `Spacing.s` and is applied before the existing `.padding(Spacing.s)`. In portrait the recording chip now sits 16 pt from the top instead of 8 pt.
Proof: Read it. Before the change: `.frame(…topLeading).padding(Spacing.s)`. After: `.padding(.top, Spacing.s).padding(Spacing.s)` with the default argument.
Trigger: Make a Card in portrait.
Fix: default `badgeTopPadding` to `0`, and add `Spacing.s` only in the landscape caller if wanted.

Should fix
Where: ios/ClipDeck/Features/Player/PlayerView.swift:137-141, 229-233
Problem: the video ignores all safe areas. Its recording chip and subtitle line use offsets from the physical screen edge, not the safe area. With controls hidden, the chip sits 8 pt from the physical leading edge and 16 pt from the top, inside the rounded display corner (and next to the sensor housing in `.landscapeLeft`), so it gets clipped. Controls auto-hide 3 s into a Make a Card playback, so the chip moves there during normal use (AC-4 "recording chip shows"). Long subtitle lines also have only 16 pt horizontal padding from the physical edges.
Proof: Traced it. `.ignoresSafeArea(edges: .all)` on `videoScreen`. The badge and subtitle paddings use only `Spacing` constants, and `insets.leading/trailing` are never applied.
Trigger: landscape, Make a Card on a line longer than 3 s, or a long subtitle line.
Fix: add `insets.leading` (and top) to the badge padding, and `max(insets.leading, insets.trailing)` to the subtitle horizontal padding in landscape.

Could fix
Where: ios/ClipDeck/Features/Player/PlayerView.swift:194-210 with the side list open (line 164)
Problem: the bottom bar needs about 470 pt (5 controls + gaps + Make a Card + padding). With the 320 pt side list open on an iPhone 17 Pro, about 430 pt is left, so the Make a Card label may truncate or compress.
Proof: Traced it from the hierarchy frames (controls span x 74–342, Make a Card is 162 pt wide). Screenshot `landscape-03-list` from the new test will show it.
Trigger: landscape, open the subtitle list, show the controls.
Fix: drop the Make a Card text label to an icon when space is tight (`ViewThatFits`). T-002 may make this moot.

Could fix (done in test files by the tester)
Where: ios/ClipDeckUITests/PlayerLandscapeUITests.swift:9-11
Problem: `tearDown` mutated `XCUIDevice.shared` from a nonisolated context (CI log: "main actor-isolated class property 'shared' can not be mutated from a nonisolated context"). The screenshot `landscape-01-fullscreen` was attached after the assert, so the failure left no image.
Fix applied: `override func tearDown() async throws { await MainActor.run { … } }`, and the screenshot is now attached before the hidden-controls asserts.

Tests added (uncommitted): ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift, which covers AC-1 nav bar + AC-3 back, AC-2 paused/auto-hide/return-on-stop, AC-4/AC-5 list + subtitle + Make a Card in landscape, and AC-6 portrait tap toggles play. These have not run yet: they need the next CI run. Their hidden-state asserts use non-existence, like AC-7, so they depend on finding 1's fix. The revert-and-confirm-failure step was not possible (CI only, tester cannot push). The CI failure above already shows the AC-7 test failing against the current code.

```text
VERDICT: Fail
SPEC: AC-1 met (visual), AC-2 not met, AC-3 layout OK / back unverified, AC-4 unverified, AC-5 unverified, AC-6 partly (chip moved), AC-7 not met
CHECKS_RUN: CI run 44635551739: simulator job (scripts/test-ios.sh) FAIL, 1 test (PlayerLandscapeUITests.testControlsAppearOnTapInLandscape), all others pass; scripts/run-ios.sh skipped; ipa job (scripts/build-ipa.sh) PASS. Portrait screenshot diff vs main run 42740988540: identical except clock.
UNVERIFIED: auto-hide timing feel on a real iPhone; Look Up on the landscape subtitle; chip/subtitle clearance of the rounded corners on a real device
REVIEWED_AT: 135af0ef8ea500a7a8ae4ff80625c527df18e168
```

## Fix round 2
_orchestrator · 2026-11-19 · sent the round-1 Test report findings (1 Must fix, 3 Should fix, 1 Could fix) to loop-frontend (sonnet)_

## Implementation notes (round 2) · sonnet
_by loop-frontend · 2026-11-19_
- Must fix, hidden controls visible to XCUITest: the landscape overlay is now rendered only `if shown` (opacity transition), so the accessibility tree matches the screen. The `accessibilityHidden` flags are gone. Bar heights keep their last measured value (initial guess 60 / 100 pt).
- Should fix, menu open: new `subtitleMenuOpen` state is set by a simultaneous tap on the subtitles Menu and counted in `keepsControlsUp`. It clears when a menu action runs, on the next video tap, and on orientation change. Dismissing the menu by tapping outside leaves the controls up until the next video tap (which hides them). Risk: if the simultaneous gesture stops the Menu opening, `testSubtitleListAndMakeACardInLandscape` will show it.
- Should fix, portrait chip: `badgeTopPadding` defaults to 0, so portrait is back to the original 8 pt. Landscape passes `insets.top` (hidden) or bar height + insets.top + 8 (shown).
- Should fix, safe areas: new `edgeInsets` parameter on `videoScreen` adds `insets.leading` to the chip and subtitle, and `insets.trailing` to the subtitle (not when the side list is open, because the list owns that edge). The subtitle's bottom padding includes `insets.bottom` when the controls are hidden.
- Could fix, narrow bottom bar: `ViewThatFits` falls back to an icon-only Make a Card (`MakeCardLabelStyle`, accessibility label kept) when the side list leaves too little room. Portrait still shows the full-width labelled button. The button now has an explicit accessibility label ("Make a Card" / "Recording").
- Tester test files kept as they are. Nothing compiled locally.
- Files: ios/ClipDeck/Features/Player/PlayerView.swift
- Tester, look at: compile of `ViewThatFits` / `LabelStyle`; Menu still opens with the extra gesture; the landscape-03-list screenshot (icon-only Make a Card); `testControlsStayWhilePausedAndAutoHideWhilePlaying`.

## Test report (round 2)
_by loop-tester · 2026-11-19 18:45_

CI run 44637588062 (headSha be4118f matches the pushed SHA), iPhone 17 Pro simulator, iOS 26.5. `ipa` job: green. `simulator` job: red. 53 tests ran: 52 passed and 1 failed (`PlayerLandscapeBehaviourUITests.testControlsStayWhilePausedAndAutoHideWhilePlaying`, "Controls return when playback stops"). `run-ios.sh` was skipped after the failure. All round-1 findings are fixed (see the end of this report). Note: in landscape, XCUITest's `app.screenshot()` comes out rotated and cropped to the leftmost ~400 pt of the screen. That is a test-tool artefact, not a layout bug. Landscape was also checked from the failing test's screen recording (`F86C87B8….mp4`, frames rendered locally).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 In landscape the video fills the screen edge to edge (letterboxed only by its own aspect ratio). The navigation bar, status bar and controls are hidden until the user taps. The home indicator auto-hides (`persistentSystemOverlays(.hidden)`). | Pass | `testNavigationBarHiddenAndBackReturnsToEpisodes` passed (no navigation bar in landscape). `testControlsAppearOnTapInLandscape` passed (no `player.back`/`player.makeCard` before the tap). `landscape-01-fullscreen`: video only, no controls. Recording frame at 21.5 s: full-screen video, no bars, no status bar. Home indicator: seen in round 1, code unchanged. |
| AC-2 Tapping the video shows the overlay controls and tapping again hides them. While playing, they hide after 3 s without a touch. They stay visible while paused, while scrubbing, while a sheet or menu is open, and while VoiceOver is running. | Fail | Tap show/hide: `testControlsAppearOnTapInLandscape` passed. Paused stays up past 3 s and playing auto-hides: the first two asserts of `testControlsStayWhilePausedAndAutoHideWhilePlaying` passed, and recording frames show controls up at 20 s and gone at 21.5 s. Fails when the episode plays to its end: the player stays "playing", controls do not come back (frames 22.5 s, 24 s, 28 s; failure hierarchy holds only `player.video`). See finding 1. Menu open: not exercised yet (new test `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying`). Sheet and scrubbing: read only (`keepsControlsUp`). VoiceOver: read only (`controlsShown`). |
| AC-3 The overlay has a top bar (back button `player.back` that returns to the episode list, episode title, and an empty trailing slot that T-002 fills) and a bottom bar with the same controls as portrait: scrubber, back 5 s, play/pause, forward 5 s, offset, subtitles menu, and Make a Card, all with their existing identifiers. Controls stay inside the safe area (clear of the notch / Dynamic Island). | Pass | `testNavigationBarHiddenAndBackReturnsToEpisodes` passed (`player.back` leads to `episode.row.Episode 1`). The UI hierarchy after the tap (874×402) lists Back (74,8), the title "Episode 1", time labels, slider, Back 5 s, `player.playPause`, Forward 5 s, `player.offset`, `player.subtitlesMenu`, and `player.makeCard` (638–800). All sit within x 74–800 and y 8–374, inside the 62 pt side and 20 pt bottom insets. |
| AC-4 The current subtitle line stays on the video. It moves up above the bottom bar while the controls are showing, and Look Up still works on it. Make a Card works from landscape (recording chip shows, the editor opens). | Pass (Look Up unverified) | Recording: subtitle about 130–150 pt from the bottom with controls (20 s), about 35–50 pt with them hidden (21.5 s). `landscape-03-list` shows the line just above the bottom bar. `testSubtitleListAndMakeACardInLandscape` passed: the editor opens and `card.range` = "0:02.0 – 0:04.0". `landscape-04-recording` shows the red chip below the top bar, about 70 pt from the leading edge (clear of the 62 pt inset). Look Up: Brent, on a device. |
| AC-5 Until T-002 lands, the subtitles menu's "Show subtitle list" still opens the existing side list next to the video, so the list is reachable in landscape. | Pass | `testSubtitleListAndMakeACardInLandscape` passed: menu → "Show subtitle list" → `cue.row.1` exists and the tap seeks to it. The Menu still opens with the new simultaneous gesture. |
| AC-6 Portrait is unchanged: tapping the video still toggles play, and `MiningFlowUITests` passes without edits. | Pass | `MiningFlowUITests` passed and is unchanged since base (`git diff 7f76886 be4118f` on that file is empty). `testPortraitTapStillTogglesPlay` passed. All six portrait screenshots (01–06) are pixel-identical to main run 42740988540 apart from the status-bar clock (bbox 161,79–284,117). Portrait chip padding is back to 8 pt (`badgeTopPadding` 0 + leading 0 + `Spacing.s`). |
| AC-7 A new UI test file `ios/ClipDeckUITests/PlayerLandscapeUITests.swift` opens the seeded sample episode, sets `XCUIDevice.shared.orientation = .landscapeLeft`, attaches screenshots `landscape-01-fullscreen` (no controls) and `landscape-02-controls` (after a tap), asserts `player.back` and `player.makeCard` appear after the tap and disappear after tapping again, and resets the orientation to portrait in `tearDown`. | Pass | Passed in run 44637588062, and both screenshots are attached. Revert check from CI: against round-1 code (overlay kept at opacity 0), the same assertions failed in run 44635551739 at "Controls start hidden". Between the two runs the test changed only in tearDown isolation and screenshot order. |

### Findings

Should fix
Where: ios/ClipDeck/Features/Player/PlayerModel.swift:117-127 (`isPlaying` is only updated in the periodic `tick`), relied on by ios/ClipDeck/Features/Player/PlayerView.swift:66-71 and :263-266
Problem: when the episode plays to its end (`actionAtItemEnd = .pause`), the view still treats it as playing. Landscape controls do not come back. If the user taps to show them, they auto-hide after 3 s even though nothing is playing. AC-2 requires "They stay visible while paused". The round-2 notes and the code comment ("Pausing (or a finished clip) brings the controls back") claim this case works, and it does not. The gap in the model already existed before this change, but T-001's landscape behaviour depends on it, so it is in scope. It probably also leaves the play button showing Pause after the end in both orientations.
Proof: Ran it. Run 44637588062, `testControlsStayWhilePausedAndAutoHideWhilePlaying` failed at "Controls return when playback stops". In the recording, playback starts at about 17 s and the last frame is reached at about 23 s. There are still no controls at 24 s and 28 s, and the failure hierarchy at about 31 s has only `player.video`. If `isPlaying` had turned false, `onChange(of: model?.isPlaying)` would have set `controlsVisible = true` (PlayerView.swift:68), and `keepsControlsUp` would have stopped any hide timer.
Trigger: landscape, play until the video ends.
Fix: in `PlayerModel`, set `isPlaying = false` (and `finishSegment()`) when playback actually stops. Observe `AVPlayerItem.didPlayToEndTimeNotification` for the current item, or KVO `player.timeControlStatus`, instead of relying on a periodic tick that stops firing once the player pauses. The updated test now checks the "Play" label and that the controls stay up after the end.

Could fix
Where: ios/ClipDeck/Features/Player/PlayerView.swift:337-338 with :264
Problem: if the subtitles menu is dismissed by tapping outside it (no action chosen), `subtitleMenuOpen` stays true. While playing, the controls then never auto-hide until the next video tap. The implementer documented this trade-off. It is the safe failure mode, but it does not match AC-2's 3 s rule in that case.
Proof: Traced it. The flag is cleared only in the two menu actions, in `toggleControls`, and on rotation.
Trigger: landscape, play, show controls, open the subtitles menu, tap outside it, and wait.
Fix: clear the flag on any bar tap (the existing `simultaneousGesture` on the bars), or swap the Menu for a button + `confirmationDialog(isPresented:)`, which reports dismissal.

Round-1 findings, all fixed:
- Must fix (hidden controls visible to XCUITest): fixed. The overlay is now rendered only `if shown`, and `testControlsAppearOnTapInLandscape` passes.
- Should fix (menu open not tracked): fixed in code (`subtitleMenuOpen` in `keepsControlsUp`), and the Menu still opens (AC-5 test). The keep-up behaviour itself is not yet proven, so `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying` was added.
- Should fix (portrait chip +8 pt): fixed. `badgeTopPadding` defaults to 0, and portrait screenshots are identical to main.
- Should fix (landscape chip/subtitle ignore horizontal safe area): fixed. `edgeInsets` adds leading and trailing insets, and `landscape-04` shows the chip about 70 pt from the edge.
- Could fix (narrow bottom bar with the list open): `ViewThatFits` fallback added. Not visible in screenshots because the landscape crop cuts the right side off; `player.makeCard` was found and tapped with the list open.

Tests changed (uncommitted, test files only): ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift
- new `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying` (AC-2 menu open while playing; screenshot `landscape-06-menu-open`)
- `testControlsStayWhilePausedAndAutoHideWhilePlaying`: the end-of-video part now asserts the AC-2 wording. When stopped at the end, a tap shows the controls if they did not return on their own, the button offers "Play", and the controls stay past 3 s (screenshot `landscape-07-ended`). It still fails on the current code (the stuck "playing" state).
Neither has run yet. They need the next CI run.

```text
VERDICT: Fail
SPEC: AC-1 met, AC-2 partly (end-of-episode case fails; menu-open unproven), AC-3 met, AC-4 met (Look Up unverified), AC-5 met, AC-6 met, AC-7 met
CHECKS_RUN: CI run 44637588062: ipa job (scripts/build-ipa.sh) PASS; simulator job (scripts/test-ios.sh) FAIL, 52/53 pass, failing PlayerLandscapeBehaviourUITests.testControlsStayWhilePausedAndAutoHideWhilePlaying; scripts/run-ios.sh skipped. Portrait screenshots 01-06 vs main run 42740988540: identical except clock. Revert check for AC-7 test: failed on round-1 code (run 44635551739), passes now.
UNVERIFIED: menu-open keep-up (new test pending CI); icon-only Make a Card with the list open (landscape screenshots are cropped); scrubbing and VoiceOver keep-up (read only); Look Up on the landscape subtitle; auto-hide timing feel and corner clearance on a real iPhone
REVIEWED_AT: be4118f09205d3dcfa10d89cea644530a3f7ef54
```

## Fix round 3
_orchestrator · 2026-11-19 · sent the round-2 Test report findings (1 Should fix: end of video not detected; 1 Could fix) to loop-frontend (sonnet). This is the last round before Blocked._

## Implementation notes (round 3) · sonnet
_by loop-frontend · 2026-11-19_
- Should fix, end of video: `PlayerModel` now observes `AVPlayerItem.didPlayToEndTimeNotification` for the player's item (block observer on the main queue, `MainActor.assumeIsolated`, same pattern as the time observer). It sets `isPlaying = false` and calls `finishSegment()`; the token is removed in `tearDown()`. The landscape controls come back at the end (`onChange(of: model?.isPlaying)`), the hide timer stays off while stopped, and the play button shows Play at the end in both orientations. `play()` already restarts from 0 when at the end.
- Could fix, menu dismissed by tapping outside: left as documented. Clearing on a bar tap is unsafe because the tap that opens the Menu also counts as a bar tap and the order against the menu gesture is undefined. Failure mode is safe: controls stay up until the next video tap.
- Files: ios/ClipDeck/Features/Player/PlayerModel.swift
- Tester, look at: `testControlsStayWhilePausedAndAutoHideWhilePlaying` end-of-video check, `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying`, `MiningFlowUITests` (playSegment still ends via tick; the notification only adds an earlier finish).

## Test report (round 3)
_by loop-tester · 2026-11-19 18:48_

CI run 44639515011 (headSha 11ee5f0 matches the pushed SHA), iPhone 17 Pro simulator, iOS 26.5. `ipa` job: green. `simulator` job: red. 54 tests ran: 53 passed and 1 failed (`PlayerLandscapeBehaviourUITests.testOpenSubtitlesMenuKeepsControlsUpWhilePlaying`, "Menu opens while playing"). `run-ios.sh` was skipped after the failure. This is the first run of the round-2 test edits. The round-2 Should fix (end of video) is fixed. The menu-open rule (round-1 finding 2, reported fixed in round 2) does not work on device: the screen recording shows the controls auto-hiding under the open menu, and the menu then closes. Frames were taken from the failing test's recording `DC2CAA09….mp4` with headless Chrome over CDP.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 In landscape the video fills the screen edge to edge (letterboxed only by its own aspect ratio). The navigation bar, status bar and controls are hidden until the user taps. The home indicator auto-hides (`persistentSystemOverlays(.hidden)`). | Pass | `testNavigationBarHiddenAndBackReturnsToEpisodes` and `testControlsAppearOnTapInLandscape` passed. `landscape-01-fullscreen` shows video only. Recording frame t=10 s (before any tap) shows full-screen video with no bars. The home indicator was checked in round 1, and that code has not changed. |
| AC-2 Tapping the video shows the overlay controls and tapping again hides them. While playing, they hide after 3 s without a touch. They stay visible while paused, while scrubbing, while a sheet or menu is open, and while VoiceOver is running. | Fail | Tap show/hide: `testControlsAppearOnTapInLandscape` passed. Paused, auto-hide while playing, and end of video: `testControlsStayWhilePausedAndAutoHideWhilePlaying` passed. `landscape-07-ended` (2.2 s after `landscape-05-autohidden`, so no tap fallback) shows the controls back at 0:06.0 with the Play icon. **Menu open: fails** (finding 1). Recording: play at about 11.5 s; menu open at 13.2–14.0 s; bars gone at 14.5 s with the menu still floating (3 s after play, so the timer was never stopped); menu gone at 15.0 s. Sheet, scrubbing and VoiceOver: checked by reading `keepsControlsUp` only. |
| AC-3 The overlay has a top bar (back button `player.back` that returns to the episode list, episode title, and an empty trailing slot that T-002 fills) and a bottom bar with the same controls as portrait: scrubber, back 5 s, play/pause, forward 5 s, offset, subtitles menu, and Make a Card, all with their existing identifiers. Controls stay inside the safe area (clear of the notch / Dynamic Island). | Pass | `testNavigationBarHiddenAndBackReturnsToEpisodes` passed (back leads to `episode.row.Episode 1`). `landscape-02-controls` and recording frames 11–14 s show the top bar (back, "Episode 1") and the bottom bar (time, scrubber, back 5 s, play/pause, forward 5 s, offset, subtitles, Make a Card), all clear of the edges. Layout code has not changed since round 2. |
| AC-4 The current subtitle line stays on the video. It moves up above the bottom bar while the controls are showing, and Look Up still works on it. Make a Card works from landscape (recording chip shows, the editor opens). | Pass (Look Up unverified) | `testSubtitleListAndMakeACardInLandscape` passed (the editor opens, range 0:02.0 – 0:04.0). In the recording, the line sits above the bottom bar with controls showing (t=12, 12.6 s) and near the bottom edge when they are hidden (t=15–16.5 s). Look Up needs a check on a device. |
| AC-5 Until T-002 lands, the subtitles menu's "Show subtitle list" still opens the existing side list next to the video, so the list is reachable in landscape. | Pass | `testSubtitleListAndMakeACardInLandscape` passed (menu → "Show subtitle list" → `cue.row.1` → seek). |
| AC-6 Portrait is unchanged: tapping the video still toggles play, and `MiningFlowUITests` passes without edits. | Pass | `MiningFlowUITests` passed, and `git diff 7f76886 11ee5f0` on that file is empty. `testPortraitTapStillTogglesPlay` passed. Portrait screenshots 01–06 are pixel-identical to main run 42740988540 except the status-bar clock (bbox 165,79–276,117 on all six). |
| AC-7 A new UI test file `ios/ClipDeckUITests/PlayerLandscapeUITests.swift` opens the seeded sample episode, sets `XCUIDevice.shared.orientation = .landscapeLeft`, attaches screenshots `landscape-01-fullscreen` (no controls) and `landscape-02-controls` (after a tap), asserts `player.back` and `player.makeCard` appear after the tap and disappear after tapping again, and resets the orientation to portrait in `tearDown`. | Pass | Passed in run 44639515011, with both screenshots attached. Revert evidence from round 2 still holds (failed on round-1 code in run 44635551739). |

### Findings

Should fix
Where: ios/ClipDeck/Features/Player/PlayerView.swift:338 (`.simultaneousGesture(TapGesture().onEnded { subtitleMenuOpen = true })` on the subtitles `Menu`), used by :264 (`keepsControlsUp`)
Problem: opening the subtitles menu while playing does not keep the landscape controls up. The tap gesture attached to the `Menu` never fires on iOS 26: the timer is not stopped, and the bar's own restart gesture at :215 does not fire either. Three seconds after play, the overlay is removed under the open menu, and the menu closes by itself about 0.5 s later. AC-2 ("stay visible while ... a menu is open") fails, and a user who opens the menu during playback loses it before choosing.
Proof: Ran it. Run 44639515011, `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying`. Recording `DC2CAA09-A824-4E9F-91D7-5AD1D2F10908.mp4`: t≈11.5 s play starts (Pause icon at 12 s); t=13.2–14.0 s the menu is open over the bottom bar; t=14.5 s the top and bottom bars are gone and the menu floats alone; t=15.0 s the menu is gone. The failure hierarchy at 23:42:56 holds only `player.video` and `player.subtitle`. The hide came exactly 3 s after play, so neither `subtitleMenuOpen` nor the bar tap restart ran.
Trigger: landscape, tap to show controls, press Play, open the subtitles menu within 3 s, then wait.
Fix: track the menu with something SwiftUI reports reliably, not a gesture on the `Menu`. Option 1: set `subtitleMenuOpen` from `.onAppear` / `.onDisappear` on the menu's content (this also clears it when the menu is dismissed by tapping outside, which fixes the Could fix below). Confirm on CI that these fire for `Menu` content on iOS 26. Option 2 (certain to work): in landscape only, replace the `Menu` with a `Button` (same `player.subtitlesMenu` identifier) that sets `subtitleMenuOpen = true`, and present `.confirmationDialog(isPresented: $subtitleMenuOpen)` with the same two actions, so dismissal is reported. Portrait keeps the `Menu`, so AC-6 holds. `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying` checks this case.

Could fix (still open, from round 2)
Where: ios/ClipDeck/Features/Player/PlayerView.swift:323-327, 269
Problem: if the menu is dismissed without choosing an item, `subtitleMenuOpen` stays true. Option 1 above fixes this too.

Round-2 findings:
- Should fix (end of video leaves `isPlaying` true): fixed. `PlayerModel` observes `didPlayToEndTime` (PlayerModel.swift:39-48), and the token is removed in `tearDown`. The stricter end-of-video asserts passed: the controls came back on their own (no tap fallback), the button says "Play", and the controls stay up past 3 s. The same scenario failed on be4118f in run 44637588062. `MiningFlowUITests` (segment playback) still passes. `finishSegment()` is safe to call twice.
- Could fix (menu flag sticks on outside dismissal): not addressed. The implementer documented this choice.
- Round-1 finding 2 (menu open not tracked): reported fixed in round 2, but now shown by running it **not** to work (finding above).

Test changed (uncommitted, test file only): ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift, `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying`. The menu-appearance wait is now 5 s instead of 2 s. XCUITest snapshots lag while the video plays: the menu was on screen about 1.3 s but was not found within 2 s. With the bug, the test still fails, because the menu is torn down about 1.5 s after it opens. With a fix, the menu stays open and the test passes. This version has not run yet.

```text
VERDICT: Fail
SPEC: AC-1 met, AC-2 not met (menu-open case fails on device; everything else met), AC-3 met, AC-4 met (Look Up unverified), AC-5 met, AC-6 met, AC-7 met
CHECKS_RUN: CI run 44639515011 (headSha 11ee5f0): ipa job (scripts/build-ipa.sh) PASS; simulator job (scripts/test-ios.sh) FAIL, 53/54 pass, failing PlayerLandscapeBehaviourUITests.testOpenSubtitlesMenuKeepsControlsUpWhilePlaying; scripts/run-ios.sh skipped. Portrait screenshots 01-06 vs main run 42740988540: identical except clock. Recording frames 10-16.5 s reviewed.
UNVERIFIED: scrubbing, sheet and VoiceOver keep-up (read only); Look Up on the landscape subtitle; icon-only Make a Card with the list open (landscape screenshots are cropped); auto-hide timing feel and corner clearance on a real iPhone
REVIEWED_AT: 11ee5f09e5229dde80d8c4c9cfb2d171d587f48f
```

## Blocked
_orchestrator · 2026-11-19 · max_fix_rounds (3) reached. Remaining: AC-2 menu-open keep-up (Should fix at PlayerView.swift:338). Waiting for Brent's decision._

## Fix round 4
_orchestrator · 2026-11-19 · Brent approved one extra round past max_fix_rounds, on Opus. A fresh loop-frontend (opus) gets the round-3 Test report._

## Implementation notes (round 4) · opus
_by loop-frontend · 2026-11-19_
- Should fix (menu open not tracked on iOS 26), used the tester's option 2: in landscape only, `player.subtitlesMenu` is now a `Button` (DeckIconButtonStyle, same icon, label "Subtitles", same identifier) that sets `subtitleDialogOpen = true`. A `.confirmationDialog("Subtitles", isPresented: $subtitleDialogOpen, titleVisibility: .hidden)` with "Load different subtitles", "Show/Hide subtitle list" and Cancel is attached to the landscape root (the HStack in `landscape(_:insets:)`). It is not attached inside the bottom bar, because `ViewThatFits` builds both row variants and the overlay is removed when hidden. `subtitleDialogOpen` is in `keepsControlsUp`, so the timer stops while the dialog is open. It is cleared on rotation.
- Could fix (flag sticks after an outside dismissal): fixed by the same change. The dialog binding goes false on any dismissal (action, Cancel, tap outside), and `onChange(of: keepsControlsUp)` then restarts the 3 s countdown.
- Portrait (AC-6): `transportButtons(_:landscape:)` takes an explicit flag. Portrait keeps the `Menu` exactly as on base 7f76886: same items with images, same label, and no extra gesture. The old `subtitleMenuOpen = false` lines in its actions are gone.
- Removed: `subtitleMenuOpen`, the `TapGesture` on the Menu, and the `simultaneousGesture` restart on both bars. The bar gestures were there so that touching a control restarts the 3 s countdown ("without a touch"). Round 3 showed they don't fire reliably on iOS 26, so I replaced them with explicit `restartHideTimer()` calls in the two skip buttons, which is the only control with no state change to hook. Play/pause, scrubbing, the offset sheet, the subtitles dialog and Make a Card's editor sheet already restart or stop the timer through `onChange`. `restartHideTimer()` returns early in portrait. Lost: tapping empty space on a bar no longer restarts the countdown.
- Tests (ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift): kept the tester's uncommitted 5 s wait. Dialog actions are found with `app.buttons[...]`, which searches the whole app, including the action sheet or popover. I did not narrow it to `app.sheets`, because on iOS 26 the dialog may present as a popover. Added one assertion: after "Show subtitle list" is chosen, the dialog closes (`waitForNonExistence`). No assertion weakened.
- Docs: docs/DESIGN.md Player paragraph mentions the dialog and its keep-up rule.
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift, docs/DESIGN.md
- Checked: nothing compiled (Windows, no Mac). Read through for iOS 17 API use (`confirmationDialog(_:isPresented:titleVisibility:actions:)` is iOS 15+) and Swift 6 isolation (all in the MainActor view).
- Tester, look at: `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying` and `testSubtitleListAndMakeACardInLandscape` (the dialog buttons are found, the dialog closes after a choice); screenshot `landscape-06-menu-open` (where iOS 26 places the dialog in landscape); "Load different subtitles" from the landscape dialog opens the picker sheet (not covered by a test); portrait screenshots 01-06 still identical, and `MiningFlowUITests` unchanged.
- Gotchas: the 6 s sample ends before "dismiss the dialog, then auto-hide resumes" can be seen in a test, so that path is checked by reading only.

## Test report (round 4)
_by loop-tester · 2026-11-19 19:14_

CI run 44642425777 (headSha 60e2fed matches the pushed SHA), iPhone 17 Pro simulator, iOS 26.5. Attempt 1: the `ipa` job passed and the `simulator` job failed. 53 of 54 tests passed. The one failure was `ClipExtractorTests.cutsExactAudioAndScreenshot()`, which threw `.timedOut` from `TestMediaFactory.waitUntilReady`. That is a unit-test helper that writes a synthetic video, and this branch has never touched it. It is a CI timing flake and is pre-existing. I re-ran the failed job, and attempt 2 passed in full: 54/54 tests, and `run-ios.sh` (launch + screenshot) passed too. All 8 landscape/portrait UI tests passed in both attempts. Artifacts are in the tester scratchpad (`T-001-r4/ci` for attempt 1, `T-001-r4/ci2` for attempt 2). No screen recordings exist, because XCUITest keeps them only for failing tests.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 In landscape the video fills the screen edge to edge (letterboxed only by its own aspect ratio). The navigation bar, status bar and controls are hidden until the user taps. The home indicator auto-hides (`persistentSystemOverlays(.hidden)`). | Pass | `testNavigationBarHiddenAndBackReturnsToEpisodes` and `testControlsAppearOnTapInLandscape` passed in both attempts. This round left the layout code alone. Evidence from rounds 1 and 3 still holds. |
| AC-2 Tapping the video shows the overlay controls and tapping again hides them. While playing, they hide after 3 s without a touch. They stay visible while paused, while scrubbing, while a sheet or menu is open, and while VoiceOver is running. | Unverified (menu case) | Tap show/hide, paused, auto-hide while playing and end of video: `testControlsAppearOnTapInLandscape` and `testControlsStayWhilePausedAndAutoHideWhilePlaying` passed. **Menu case: the round-3 symptom is gone, but CI has not shown that the controls stay up.** The xcresult timeline for `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying` (attempt 1): play was tapped at 889.87 s and the subtitles button at 891.29 s. The dialog was found at 892.81 s and was still there at 896.36 s, after the 3 s mark (~892.9 s). The dialog opening proves the Button action ran and `subtitleDialogOpen` became true; in round 3 the Menu gesture never fired. But the dialog hangs off the landscape root, so it would stay open even if the overlay were removed. The 6 s sample also ended at about 895.9 s, before the `landscape-06-menu-open` shot at 896.4 s (shot shows 0:06.0 with the Play icon), and the end of playback brings the controls back by itself. So the passing test and the screenshot look the same whether or not the keep-up rule works. I strengthened the test to watch `player.back` while the dialog is open (see below). It has not run yet. Sheet, scrubbing and VoiceOver: checked by reading only, unchanged since round 2. |
| AC-3 The overlay has a top bar (back button `player.back` that returns to the episode list, episode title, and an empty trailing slot that T-002 fills) and a bottom bar with the same controls as portrait: scrubber, back 5 s, play/pause, forward 5 s, offset, subtitles menu, and Make a Card, all with their existing identifiers. Controls stay inside the safe area (clear of the notch / Dynamic Island). | Pass | `testNavigationBarHiddenAndBackReturnsToEpisodes` passed. `landscape-06-menu-open` and `landscape-03-list` show back, "Episode 1", scrubber, back/forward 5 s, play, offset and subtitles. The landscape subtitles button keeps the `player.subtitlesMenu` identifier, and the tests find it. Its style now matches the other bar buttons (dark DeckIconButtonStyle). |
| AC-4 The current subtitle line stays on the video. It moves up above the bottom bar while the controls are showing, and Look Up still works on it. Make a Card works from landscape (recording chip shows, the editor opens). | Pass (Look Up unverified) | `testSubtitleListAndMakeACardInLandscape` passed in both attempts (the editor opens, range 0:02.0 – 0:04.0). `landscape-03-list` shows the line above the bottom bar. |
| AC-5 Until T-002 lands, the subtitles menu's "Show subtitle list" still opens the existing side list next to the video, so the list is reachable in landscape. | Pass | `testSubtitleListAndMakeACardInLandscape`: dialog → "Show subtitle list", the dialog closes (new assert), then `cue.row.1` appears and seeks. |
| AC-6 Portrait is unchanged: tapping the video still toggles play, and `MiningFlowUITests` passes without edits. | Pass | `MiningFlowUITests` and `testPortraitTapStillTogglesPlay` passed. `git diff 7f76886 60e2fed -- ios/ClipDeckUITests/MiningFlowUITests.swift` is empty. Portrait screenshots 01–06 are pixel-identical to main run 42740988540 except the status-bar clock (bbox 158,79–288,117 on all six). The portrait `Menu` block (items, label, modifiers, identifier) is textually identical to base 7f76886 lines 171–182. The new `restartHideTimer()` in the skip buttons returns at `guard isLandscape` in portrait. |
| AC-7 A new UI test file `ios/ClipDeckUITests/PlayerLandscapeUITests.swift` opens the seeded sample episode, sets `XCUIDevice.shared.orientation = .landscapeLeft`, attaches screenshots `landscape-01-fullscreen` (no controls) and `landscape-02-controls` (after a tap), asserts `player.back` and `player.makeCard` appear after the tap and disappear after tapping again, and resets the orientation to portrait in `tearDown`. | Pass | Passed in both attempts, with both screenshots attached. Revert evidence from round 2 still holds. |

### Findings

Round-3 findings:
- Should fix (menu open not tracked, PlayerView.swift:338): the mechanism is replaced. CI shows the new Button action runs: the dialog presents from `$subtitleDialogOpen` while playing and survives the 3 s mark. Whether the overlay stays up is **not yet shown by CI** (see AC-2). From reading: the flag feeds `keepsControlsUp` (:270), and `onChange(of: keepsControlsUp)` (:72) calls `restartHideTimer()`, which cancels `hideTask` and returns early at :282.
- Could fix (flag sticks after an outside dismissal): fixed by design, because the dialog binding clears on any dismissal. Read only.

Removed bar gestures: I checked every control in the bars. Play/pause (`onChange(of: isPlaying)`), scrubber (`isScrubbing`), offset (sheet), subtitles (dialog), skip (explicit call) and back (dismiss) all still restart or stop the countdown. No test or other code referenced the bar gestures (`grep simultaneousGesture` finds nothing in `ios/`). One control lost its restart:

Could fix
Where: ios/ClipDeck/Features/Player/PlayerView.swift:350-361 (`makeCardButton`)
Problem: tapping Make a Card in landscape while playing no longer restarts the 3 s countdown. If the tap comes late in the countdown, the bars fade during recording. The recording chip stays on the video, and the editor sheet then keeps the controls up, so nothing breaks.
Proof: Read it. No state that `keepsControlsUp` reads changes until `draft` is set after `playSegment`.
Trigger: landscape, play, tap Make a Card about 2.5 s after the controls last restarted.
Fix: call `restartHideTimer()` in the button action, or add `miningRange != nil` to `keepsControlsUp`.

Could fix
Where: ios/ClipDeck/Features/Player/PlayerView.swift:181
Problem: "Load different subtitles" from the landscape dialog sets a sheet while the dialog is closing. No test covers it. SwiftUI normally queues this correctly.
Proof: Read it.
Fix: none needed unless Brent sees the picker fail to open. Otherwise add a UI test.

Pre-existing (not caused by this change): `ClipExtractorTests.cutsExactAudioAndScreenshot()` can time out on CI in `TestMediaFactory.waitUntilReady` (5 s budget). It failed in attempt 1 of run 44642425777 and passed in attempt 2.

Test changed (uncommitted, test file only): ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift, `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying`. Once the dialog is open, it asserts that `player.back` exists, that it does not disappear during the next 3.5 s (a broken rule hides it about 1.6 s after the dialog opens, about 3 s before the sample ends), and that the dialog is still open. This has not run. No revert check was possible, because I cannot push. If it fails at "Controls are up when the dialog opens", look at the failure recording first: XCUITest may not expose elements under the dialog, which would be a test problem, not a product bug.

```text
VERDICT: Blocked
SPEC: AC-1 met, AC-2 partly (menu case: round-3 symptom gone, keep-up of the controls not yet shown by CI), AC-3 met, AC-4 met (Look Up unverified), AC-5 met, AC-6 met, AC-7 met
CHECKS_RUN: CI run 44642425777 (headSha 60e2fed). Attempt 1: ipa (scripts/build-ipa.sh) PASS; simulator (scripts/test-ios.sh) FAIL 53/54, only ClipExtractorTests.cutsExactAudioAndScreenshot (.timedOut, pre-existing flake). Attempt 2 (re-run of the failed job): simulator PASS 54/54, run-ios.sh PASS. Portrait 01-06 vs main run 42740988540: identical except clock. xcresult activity timeline for the menu test read.
NEEDED: commit the test-file edit, push, `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload`, and have the tester read the result of testOpenSubtitlesMenuKeepsControlsUpWhilePlaying (no product change needed if it passes)
UNVERIFIED: scrubbing, sheet and VoiceOver keep-up (read only); "Load different subtitles" from the landscape dialog; Look Up on the landscape subtitle; auto-hide timing feel and corner clearance on a real iPhone
REVIEWED_AT: 60e2feddbb7b4ea54f75a072492da92f71f9e79c
```

### Round 4 addendum
_by loop-tester · 2026-11-19 19:23_

CI run 44644572562 (headSha 4e13857 matches; the only change from 60e2fed is the stricter test) passed on the first attempt. Both jobs are green: 54/54 tests passed, and run-ios.sh passed. ClipExtractorTests did not flake this time. Artifacts are in the tester scratchpad (`T-001-r4/ci3`).

`testOpenSubtitlesMenuKeepsControlsUpWhilePlaying` passed. Timeline from the xcresult activities, in seconds since the reference date:
- Play tapped at 821.69–821.98, so the auto-hide would fire at about 825.0 s.
- Subtitles button tapped at 823.12. The dialog was found at 824.64.
- `player.back` was present at 824.68 ("Controls are up when the dialog opens" passed). It was polled again at 825.72, 826.77, 827.72 and 828.21, and present every time, so "Controls stay up while the subtitles dialog is open" passed.
- The dialog was still open at 828.26.

The polls at 825.72–827.72 fall after the 3 s mark and before the sample ends. The video was playing during them: the `landscape-06-menu-open` shot at 828.41 shows 0:06.0, which it can only reach by playing continuously from 0:00 since about 822.0. In round 3, the broken rule hid the bar exactly 3 s after play. This test would have caught that here with three polls. XCUITest does see `player.back` under the dialog. I could not run a revert check, because I cannot push product edits.

AC-2 is now **Pass**. Tap show/hide, paused, auto-hide while playing, end of video and the menu/dialog case are all shown in CI. Sheet, scrubbing and VoiceOver are checked by reading only.

The round-3 Should fix (menu open not tracked) is fixed. The two Could fix items in the round-4 report are still open and do not block: Make a Card does not restart the countdown, and "Load different subtitles" from the dialog has no test.

```text
VERDICT: Pass
SPEC: AC-1 met, AC-2 met, AC-3 met, AC-4 met (Look Up unverified), AC-5 met, AC-6 met, AC-7 met
CHECKS_RUN: CI run 44644572562 (headSha 4e13857): ipa (scripts/build-ipa.sh) PASS; simulator (scripts/test-ios.sh) PASS 54/54; run-ios.sh PASS. Earlier: run 44642425777 (60e2fed), attempt 2 all green (attempt 1 had a pre-existing ClipExtractorTests flake).
UNVERIFIED: scrubbing, sheet and VoiceOver keep-up (read only); "Load different subtitles" from the landscape dialog; Look Up on the landscape subtitle; auto-hide timing feel and corner clearance on a real iPhone
REVIEWED_AT: 4e13857539d1c7ccc18426ffccabf4469d8cee85
```

## Amended after landing
_orchestrator · 2026-11-19 · Brent's decision, built in T-011 (3f38205):_ AC-2 now reads: "Once shown, the controls stay visible while paused …; pausing or reaching the end brings them back. Entering landscape, by rotating or by opening the player already in landscape, always starts hidden."
