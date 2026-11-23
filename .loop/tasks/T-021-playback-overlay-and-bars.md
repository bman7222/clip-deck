---
id: T-021
title: Centred playback overlay, plain bottom pause button, new bar layout
lane: frontend
depends_on: []
status: done
round: 3
base_sha: b651c15883946629b25b9e395968426c22dcbf79
issue: 23
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Control playback from big buttons in the middle of the video, like a normal video player

### What are we building?
Today a tap on the portrait video plays or pauses, and ±5 s are small buttons in the bar. After this task both orientations show a centred ⟲5 ⏯ 5⟳ overlay that appears on a tap and fades like the landscape controls. The ±5 s buttons leave the bar, and the bar's play/pause button is plain while playing and aqua only while paused.

### Why?
It works like every other video app, and it frees room in the bar for the Move-Text and Lookup buttons that come next.

### Done when
- AC-1 Overlay: three white glyphs (`gobackward.5`, play/pause, `goforward.5`), each on a translucent black circle: 52 pt for the centre one, 44 pt for the skips. Their centres sit at 25 %, 50 % and 75 % of the video container's width, vertically centred. The container is the 16:9 video in portrait and the video column in landscape, so the overlay re-centres when the panel opens or is resized. Ids `player.overlay.back5`, `player.overlay.playPause` and `player.overlay.forward5`. Labels "Back 5 seconds", "Play"/"Pause" and "Forward 5 seconds". The play/pause value is "Playing"/"Paused".
- AC-2 Timing. In landscape the overlay shows and hides with the existing controls (`controlsShown`). In portrait it follows the same rules with its own state: it starts hidden, a tap on the video shows or hides it (and no longer toggles play), and a real pause (playing → paused) shows it. In both: a 0.2 s fade, auto-hide after 3 s while playing, it stays while paused, opacity only under Reduce Motion, always shown under VoiceOver, and hidden after a rotation. A skip tap restarts the countdown.
- AC-3 ±5 s is gone from the portrait row and from every landscape bar variant, and the `skips:` parameter is removed.
- AC-4 The bar's `player.playPause` (both orientations) uses `DeckIconButtonStyle(isActive: !model.isPlaying)`: Shell/Ink while playing, aqua while paused. Its accessibility value is "Playing"/"Paused"; its id and labels don't change.
- AC-5 Bar order for the later buttons. Portrait: the row `⏯ ±0.0s Subs Aa`, then Make a Card on its own row. Landscape: `⏯ ±0.0s Subs Aa … Make a Card`, with these ViewThatFits variants: (1) one row with the full Make a Card label; (2) one row with an icon-only Make a Card; (3) two rows, `⏯ ±0.0s Subs Aa` above Make a Card (icon) on the trailing side. In each variant a comment marks where ✥A (after Aa, T-024a), ↺📄 (after ✥A, T-029b) and 📄🔍 (just left of each Make a Card, T-030a) will go.
- AC-6 `testPortraitTapStillTogglesPlay` becomes a test that a portrait tap shows the overlay and leaves the play state alone. New UI tests in both orientations:
  - the overlay centres are within 2 pt of 25/50/75 % of `player.video`'s width and of its vertical centre;
  - while paused mid-video, back5 and forward5 move the time by about 5 s, and the overlay play/pause toggles playback;
  - the overlay is gone 3 s after playing starts and stays while paused;
  - `player.bottomBar` and the portrait controls hold no 5-second skip button;
  - `player.playPause` reads "Paused", then "Playing".
  Every existing test passes, and DESIGN.md documents the overlay and the play-button colour rule.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`. Watch it with `gh run watch <id> -i 60 --exit-status`, and on failure read `gh run view <id> --log-failed`. Then `gh run download <id> -p 'simulator-results*' -D <scratch>`. Check the new overlay tests, all of PlayerLandscapeBehaviourUITests, SubtitleStyleCardTesterUITests, and the frames in the `app.debugDescription` attachments.
- Unverified for Brent: how the overlay and its fades feel, and how readable it is on bright scenes.

### Agent notes
- Depends on: none. Order it after T-020 so the extra UI tests have CI room. Source: spec T-021, section G defaults 5 (white glyphs on dark circles).
- Code in PlayerView.swift: the portrait tap `videoScreen(model, onTap: { model.togglePlay() })` is at line 181. The landscape overlay stack and `controlsShown` are at 219-295, `keepsControlsUp` at 569, and `restartHideTimer` at 597; it returns early unless `isLandscape`, so portrait needs its own path. `transportButtons(_:landscape:skips:)` is at 626-682 and the bottom-bar ViewThatFits at 471-475. `DeckIconButtonStyle` is in Components.swift:69-98.
- Z-order: line, then overlay, then bars. The recording badge stays visible. A tap on an overlay button must not also toggle the overlay.
- Tests use `app.buttons["player.playPause"]` with the labels "Play"/"Pause" (PlayerLandscapeBehaviourUITests.swift:42-55, 227-228), so keep the bar button's id and labels. The overlay button has its own id.
- The sample video is 6 s long, with cues at 0.5–2.0, 2.0–4.0 and 4.0–5.5 s. Test the skips from about 3 s while paused.
- Learned: landscape `app.screenshot()` comes out rotated, so use `XCUIElement.screenshot()` and attach `app.debugDescription`. A `.contain` container's frame is the union of its children. Known flakes are in PlayerLandscapeBehaviourUITests.

### Out of scope
- The subtitle line avoiding the overlay (T-022).
- The ✥A, ↺📄 and 📄🔍 buttons themselves.
- Double-tap-to-skip gestures, scrubber changes.

## Implementation notes (round 1)
_by loop-frontend · 2026-11-23_
- Changed: new private `PlaybackOverlay` + `OverlayButtonStyle` in PlayerView.swift (white glyphs on 50 % black circles, 52 pt centre, 44 pt skips, `.position` at 25/50/75 % of the video container, ids `player.overlay.back5|playPause|forward5`). It is an overlay inside `videoScreen` (z-order: video, line, overlay, recording badge; landscape bars above), rendered only while shown with a 0.2 s opacity transition. Landscape passes `controlsShown`; portrait has its own `portraitOverlayVisible` (starts hidden, a video tap toggles it and no longer plays, a real pause shows it, rotation hides it, `overlayShown` = it or VoiceOver). `restartHideTimer` now works in both orientations (hides `controlsVisible` in landscape, `portraitOverlayVisible` in portrait; same `keepsControlsUp` rule). Skips call `restartHideTimer`.
- Bars: `skips:` removed from `transportButtons` and `bottomRow`; the bar's `player.playPause` uses `DeckIconButtonStyle(isActive: !model.isPlaying)` with value "Playing"/"Paused" (id and labels unchanged). Landscape ViewThatFits is now (1) full Make a Card, (2) icon-only, (3) new `bottomStackedRows` (transport row above an icon-only Make a Card on the trailing side). Comments mark where T-024a (Move-Text), T-029b (popup reset) and T-030a (Lookup toggle) go, in portrait and in each variant.
- Added `player.currentTime` id on the scrubber's elapsed-time text (tests read the time from it).
- Tests: `testPortraitTapStillTogglesPlay` became `testPortraitTapShowsOverlayWithoutTogglingPlay` (PlayerLandscapeBehaviourUITests). New `ios/ClipDeckUITests/PlaybackOverlayUITests.swift`, 9 tests (both orientations): overlay centres within 2 pt of 25/50/75 % of `player.video` and its vertical centre; skips move the time by 5 s (tested from 0:00, so neither skip is clamped by the 6 s clip) and the overlay play/pause toggles playback; overlay stays while paused and is gone after playing starts; no 5-second skip in `player.bottomBar` or the portrait controls (and exactly one of each in the whole screen); `player.playPause` reads Paused then Playing; rotation hides the overlay. They wait on state (element existence, value predicates, polling the elapsed time), not on fixed sleeps; the only fixed wait is the 3.5 s "still there while paused" check.
- CI: `PlaybackOverlayUITests` added to `SHARD1_UI` in .github/workflows/ios-simulator.yml (shard 1 has the most room).
- Docs: DESIGN.md has a "Playback overlay" section (incl. the play-button colour rule and bar order), updated landscape paragraph, screen sketch and motion list.
- Checked: nothing compiled (no Mac). Read every use of `skips:`/`transportButtons`; grepped the other UI tests: none look for the ±5 buttons, and the taps they make on the video (x 0.3/0.35/0.5, y 0.35) clear the overlay buttons (centre button spans y 175-227 of a 402 pt landscape height; with the panel open the centre moves left of x 0.5).
- Tester, look at: (1) Swift 6 compile of `PlaybackOverlay`/`OverlayButtonStyle` and `videoScreen`'s new `showsOverlay:` argument; (2) the overlay's GeometryReader must not swallow taps meant for the video (a tap at 37 %/15 % has to toggle it); (3) the autohide test's "gone" wait starts right after the Play tap, and the 6 s clip pausing at its end brings the overlay back, so a very slow VM can still flake it; (4) landscape ViewThatFits variant 3 only appears at a very narrow bar (panel near 50 %): check the frames in `app.debugDescription`; (5) every existing test in PlayerLandscapeBehaviourUITests, SubtitleStyleCardTesterUITests, SubtitleStyleUITests.
- Gotchas: the subtitle line still doesn't avoid the overlay (T-022). A tap on the portrait video while paused with the overlay up hides it (paused overlays can be dismissed, they just don't auto-hide).

## Test report (round 1)
_by loop-tester · 2026-11-22 20:58_

CI 45094204439 (scope=all, 7034c69): ipa green (2:26), shard 2 green (21:16), shard 3 green (21:31), **shard 1 red** (23:24): 3 of the 11 new PlaybackOverlayUITests failed. Every pre-existing test passed: 398 of 401 test runs succeeded, 364 test names. The name set equals T-020's final run 45087727557 plus the 11 new tests and the renamed portrait test, minus `testPortraitTapStillTogglesPlay`. Evidence is in `%TEMP%\clip-deck-loop\T-021-r1` (xcresult databases, attachments, recording frames; Data/ pruned).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 Overlay: three white glyphs (`gobackward.5`, play/pause, `goforward.5`), each on a translucent black circle: 52 pt for the centre one, 44 pt for the skips. Their centres sit at 25 %, 50 % and 75 % of the video container's width, vertically centred. The container is the 16:9 video in portrait and the video column in landscape, so the overlay re-centres when the panel opens or is resized. Ids `player.overlay.back5`, `player.overlay.playPause` and `player.overlay.forward5`. Labels "Back 5 seconds", "Play"/"Pause" and "Forward 5 seconds". The play/pause value is "Playing"/"Paused". | Pass (the "Pause" label is unobserved) | `testOverlayIsCentredPortrait/Landscape` passed (ids, 44/52 pt, ±2 pt, labels, "Play"/"Paused"). `testSkipsAndPlayPauseWork*` passed and read the overlay value "Playing". Re-centring: frames in run attachments put all three centres within 0.2 pt of 25/50/75 % and at the exact vertical centre, with the column at 874 (card-closed frames), 624.7 (panel 25 %), 504.7 (41 %, `landscape-05-panel-resized-frames`) and 437 pt (50 %, `landscape-05-panel-max-frames`). Portrait (402 pt video): mids 100.7 / 201 / 301.7. Pixels: glyph max (255,255,255), and each circle is video × 0.50–0.51 per channel, in landscape (card-closed element shot) and portrait (recording frame at 18 s). |
| AC-2 Timing. In landscape the overlay shows and hides with the existing controls (`controlsShown`). In portrait it follows the same rules with its own state: it starts hidden, a tap on the video shows or hides it (and no longer toggles play), and a real pause (playing → paused) shows it. In both: a 0.2 s fade, auto-hide after 3 s while playing, it stays while paused, opacity only under Reduce Motion, always shown under VoiceOver, and hidden after a rotation. A skip tap restarts the countdown. | Partly / Unverified | Proven by the run: landscape shows with the controls (`testOverlayIsCentredLandscape`) and hides with them while playing (`testControlsStayWhilePaused…` and `testPanelStaysOpen…` passed, and `landscape-05-autohidden` has no overlay). It stays while paused in both orientations: the 3.5 s check passed in both `testOverlayHides…` tests. Portrait starts hidden and a tap shows it without playing (`testPortraitTapShowsOverlayWithoutTogglingPlay` passed). Portrait auto-hides while playing (`testOverlayHides…Portrait` passed). The clip's end, a real pause, showed the portrait overlay with no tap (UI tree in the failed `testBarPlayPauseValuePortrait`, plus recording frame 18 s). Rotation hides it (`testRotationHidesTheOverlay`), and an overlay-button tap doesn't toggle it (skips test). **Not yet proven:** a second portrait tap hides it, and a skip restarts the countdown (tester tests added, see below). The 0.2 s fade, Reduce Motion and VoiceOver are code-read only. `testOverlayHides…Landscape` failed (M1). |
| AC-3 ±5 s is gone from the portrait row and from every landscape bar variant, and the `skips:` parameter is removed. | Pass | `testBarHasNoSkipButtonsPortrait/Landscape` passed. `grep skips\|gobackward\|goforward ios/ClipDeck`: only PlaybackOverlay (PlayerView.swift:845, :858). |
| AC-4 The bar's `player.playPause` (both orientations) uses `DeckIconButtonStyle(isActive: !model.isPlaying)`: Shell/Ink while playing, aqua while paused. Its accessibility value is "Playing"/"Paused"; its id and labels don't change. | Fail (its test failed) / Unverified | Paused: aqua (26,139,195) in portrait and landscape recording frames, value "Paused", label "Play", id unchanged (frames). "Playing" was never observed in run 1, because both `testBarPlayPauseValue*` failed (M1). The only playing frame (landscape, 24 s) was rendered mid-transition during a UI freeze ((29,46,58) against the chips' (23,25,29)). Settled playing-state shots come from the tester's `testScreenshotsLight/Dark`. |
| AC-5 Bar order for the later buttons. Portrait: the row `⏯ ±0.0s Subs Aa`, then Make a Card on its own row. Landscape: `⏯ ±0.0s Subs Aa … Make a Card`, with these ViewThatFits variants: (1) one row with the full Make a Card label; (2) one row with an icon-only Make a Card; (3) two rows, `⏯ ±0.0s Subs Aa` above Make a Card (icon) on the trailing side. In each variant a comment marks where ✥A, ↺📄 and 📄🔍 will go. | Pass (variant 3 Unverified) | Portrait frames: playPause x12, offset 72, subs 132, Aa 184 at y401, and Make a Card at y453, full width 378. Landscape: 74/134/194/246, then Make a Card. Variant 1 at 25 % (162 pt label). Variant 2 at 41 % and 50 % (54 pt icon on the same row; maxX 393 < handle 405). Variant 3 is unreachable on an iPhone 17 Pro, because the one-row icon variant fits at 50 %: code-read only. The comments are at PlayerView.swift:500, :514, :662, :720-722. |
| AC-6 `testPortraitTapStillTogglesPlay` becomes a test that a portrait tap shows the overlay and leaves the play state alone. New UI tests in both orientations (centres within 2 pt; paused mid-video skips move ~5 s and overlay play/pause toggles; gone 3 s after playing, stays while paused; no 5-second skip in `player.bottomBar` or the portrait controls; `player.playPause` reads "Paused", then "Playing"). Every existing test passes, and DESIGN.md documents the overlay and the play-button colour rule. | **Fail** | The renamed test passed (shard 2). New tests: 8 of 11 pass. `testBarPlayPauseValuePortrait`, `testBarPlayPauseValueLandscape` (both :142) and `testOverlayHidesWhilePlayingAndStaysWhilePausedLandscape` (:92) failed (M1). Every existing test passed. DESIGN.md has a "Playback overlay" section, the colour rule, the bar order, the sketch and motion. The skips test runs 0:00 → 0:05 → 0:00, so it can't tell back 5 s from a jump to the start, and it isn't "mid-video". The tester test `testSkipsMoveFiveSecondsMidVideo*` covers that. |

### Findings

**Must fix: three new tests fail on CI when the app's UI freezes during playback of the 6 s clip**
Where: ios/ClipDeckUITests/PlaybackOverlayUITests.swift:141-142 (`checkBarValue`) and :91-94 (`checkTiming`)
Problem: `testBarPlayPauseValuePortrait`, `testBarPlayPauseValueLandscape` and `testOverlayHidesWhilePlayingAndStaysWhilePausedLandscape` are red in 45094204439 shard 1, so the check fails.
Proof: I traced it from the xcresult activities and the screen recordings. After the bar Play event, XCUITest's "Wait for app to idle" took 6.43 s (portrait) and 15.01 s (landscape). In the landscape timing test, each existence check took 4.2–4.5 s. The recordings show the app's UI frozen from the Play tap: the elapsed label stuck at 0:00.0 or 0:02.4, no subtitle line drawn, and the bar still aqua, while the video layer played to its last frame. The UI caught up only after the clip ended (0:06.0, "Paused", overlay back). This is the same signature as the known flake in CONTEXT "Learned" (Play tap ≈ clip length, 45087727557 on pre-T-021 code). In the same run, the 6 pre-existing bar-Play taps in shards 2 and 3 took 0.41–2.58 s, and the 4 overlay Play/Pause taps took 0.39–1.28 s. The same VM ran the other overlay playback tests normally just before and after (01:30:03–01:31:50 was the bad window). I found no app defect behind it, but these tests are new in this task.
Trigger: a slow or stalled runner during playback. The test then sees "Paused" (the clip ended) where it expects "Playing", or the overlay back where it expects it gone.
Fix: make the playing-state checks tolerate a tap or snapshot that outlasts the clip. Detect it (the bar value back to "Paused" with the elapsed time at the end, or the tap's wall time ≥ 6 s), retry from 0:00 a bounded number of times, then `XCTSkip` with the reason rather than fail. Or pull T-034's planned Debug-only `-uiTestingSampleSeconds` hook forward so these tests get a longer clip. The tester tests already follow the first pattern.

**Could fix: with the 3-row style card at panel 50 %, the card cuts into the overlay row**
Where: ios/ClipDeck/Features/Player/PlayerView.swift:254-300 (the overlay stays up while the card is open)
Problem: the card top is y 218, and the overlay row spans y 175–227, so the card's top edge covers the bottom 5–9 pt of the circles. The subtitle line (y 183.7–210) also sits on the centre button, but avoiding the line is T-022's job.
Proof: Ran it: `tester-card-panel-50` frames F932D503 and the screenshot (CI 45094204439 shard 1).
Trigger: landscape, panel at 50 %, Aa card open.
Fix: Brent's call. One option is to hide the overlay while the style card is open, as spec Q3 does for Move-Text.

**Could fix: no T-030a marker at the side panel's Make a Card**
Where: ios/ClipDeck/Features/Player/PlayerView.swift:421-427
Problem: T-030a AC-1 puts the Lookup toggle "immediately left of all three Make a Card buttons … at T-021's markers". The portrait and bar copies have a marker, but the side panel copy doesn't. This is comment-only, and AC-5's bar wording is met.
Proof: Read it.
Fix: add the same `// T-030a:` comment above the panel's `ViewThatFits`.

### Tests added (test files only)
`ios/ClipDeckUITests/PlaybackOverlayTesterUITests.swift` (10 tests; it lands in shard 3 unless the workflow lists it). Nothing in it has run yet.
- `testPortraitSecondTapHidesTheOverlay`: AC-2 tap hides. It also proves the overlay layer doesn't swallow video taps in portrait. Landscape is already shown by the passing "second tap hides the controls" tests.
- `testPortraitRealPauseShowsTheOverlay`: AC-2, a bar Pause shows the overlay. Guarded for a tap that outlasts the clip.
- `testSkipsMoveFiveSecondsMidVideoPortrait/Landscape`: AC-6 "mid-video". Paused, forward ×2 to the clamped end, back → end − 5 (≈0:01), forward → end. No playback.
- `testSkipRestartsTheCountdownPortrait/Landscape`: AC-2. Back 5 s about once a second while playing; the overlay must still show 4.5 s after Play, then hide ≥ 2.9 s after the last skip. It `XCTSkip`s, rather than fails, when the runner is too slow to decide.
- `testOverlayRecentresWhenThePanelOpensAndResizes`: AC-1 and AC-5 at panel closed, 25 % and 50 %, as assertions.
- `testRotationResetsThePortraitOverlay`: AC-2, portrait → landscape → portrait.
- `testScreenshotsLight/Dark`: AC-1/AC-4 visuals, paused and playing, portrait and landscape, plus a playing-state label/value attachment. Dark mode is set through KVC on `XCUIDevice.appearance` (compile-safe; it skips if the setter is missing) and reset to light in tearDown.
- Revert check: not done (ci_only, no product edits allowed). On base b651c15 every PlaybackOverlay test fails by construction, because `player.overlay.*` doesn't exist there.

```text
VERDICT: Fail
SPEC: AC-1 met; AC-2 partly (tap-hides and skip-restart unproven, fade/Reduce Motion/VoiceOver read only); AC-3 met; AC-4 partly (Paused/aqua shown, Playing unobserved); AC-5 met (variant 3 unreachable on 17 Pro); AC-6 not met (3 new tests red)
CHECKS_RUN: CI 45094204439 scope=all on 7034c69: ipa success; shard 1 failure (3 new tests), shard 2 success, shard 3 success; 398/401 runs pass; test/run/build are macOS-only and ran in CI (lint is "")
UNVERIFIED: overlay fade feel and readability on bright scenes (Brent, iPhone); VoiceOver always-shown; Reduce Motion; landscape variant 3 (needs a narrower phone such as an SE); dark-mode portrait shots (tester test pending)
REVIEWED_AT: 7034c6925a8aa9ea14f4708d9e50f28608d0ee8c
```

## Fix round 2
Round 1 failed M1: 3 new tests went red because the UI froze on a slow runner until the 6 s clip had ended. Brent's decisions (2026-11-23):
- Sonnet retry.
- **Longer test clip flag:** add a Debug-only -uiTestingSampleSeconds <n> launch argument (with -uiTesting; default 6, so every other test is unchanged). Only the overlay tests pass a longer clip, for example 30 s. Document it in CLAUDE.md next to the other -uiTesting flags. T-034 reuses it later.
- **New AC-7:** in landscape the centred overlay hides while the subtitle style card (Aa) is open, and comes back on Done. This is the same rule as Move-Text (T-024a). It fixes the 3-row card cutting through the overlay (round 1 C1). Add a test.
- Commit the tester's PlaybackOverlayTesterUITests.swift with this round. Put it in SHARD2_UI (shard 2 had the most room after shard 1 took the 11 new tests); the overlay tests in it should use the longer clip too.
- C2: add the // T-030a: marker comment at the side panel's Make a Card.

## Implementation notes (round 2)
_by loop-frontend · 2026-11-23_
- M1 -> new Debug-only launch argument `-uiTestingSampleSeconds <n>` (`LaunchFlags.sampleSeconds` in ClipDeckApp.swift, clamped 1...600, default 6; `UITestSeeder` passes it to `TestMediaFactory.makeVideo(seconds:)`). Documented in CLAUDE.md. `PlaybackOverlayUITests.openSample` now launches with 30 s, so none of its playing tests can reach the clip's end; checks are unchanged (state waits). In `PlaybackOverlayTesterUITests` `openSample(landscape:sampleSeconds:)` (default 6): testPortraitRealPauseShowsTheOverlay, the two skip-restart tests and the screenshot tests use 30 s; the paused skip tests keep the 6 s clip (they rely on its end as the clamp). No check weakened.
- AC-7: landscape overlay hides while the style card is open (`showsOverlay: shown && !styleMenuOpen`) and returns on Done. New test `testOverlayGivesWayToTheStyleCardLandscape` in PlaybackOverlayUITests.
- C2: `// T-030a:` marker added above the side panel's Make a Card ViewThatFits.
- CI shards: PlaybackOverlayTesterUITests added to `SHARD2_UI`; PlaybackOverlayUITests stays in `SHARD1_UI`.
- DESIGN.md notes the style-card rule. Nothing compiled (no Mac).
- Tester, look at: Swift 6 compile of `LaunchFlags.sampleSeconds`; a 30 s clip generates in the seeder (300 frames, same code path as 6 s); the card/overlay test; the tester file with the longer clip.

## Test report (round 2)
_by loop-tester · 2026-11-22 23:47_

CI 45110218499 (scope=all, c1b6f0d, CI run 2 of 4): every job is green. ipa 1:55, shard 1 21:47 (354 test runs), shard 2 32:00 (30), shard 3 20:59 (28). All 412 test runs pass, with 0 test issues. That is 375 test names: round 1's 364 plus `testOverlayGivesWayToTheStyleCardLandscape` and the 10 PlaybackOverlayTesterUITests. None was lost, and every known flake in CONTEXT "Learned" passed. Evidence is in `%TEMP%\clip-deck-loop\T-021-r2` (xcresult databases and exported attachments; Data/ pruned, 16 MB).

Round 1 findings:
- M1 (3 new tests red when the 6 s clip ended during a slow tap): fixed for the clip end. All three pass with the 30 s clip. The duration label reads "0:30.0" in the 30 s launches and "0:06.0" in default ones (frames attachments in shard 2), so the flag works and the default is unchanged. One related race is left in `testBarPlayPauseValueLandscape` (S2).
- C1 (the 3-row style card cut into the overlay at 50 %): fixed by AC-7, see below.
- C2 (no T-030a marker at the side panel's Make a Card): fixed, PlayerView.swift:423.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 Overlay: three white glyphs (`gobackward.5`, play/pause, `goforward.5`), each on a translucent black circle: 52 pt for the centre one, 44 pt for the skips. Their centres sit at 25 %, 50 % and 75 % of the video container's width, vertically centred. The container is the 16:9 video in portrait and the video column in landscape, so the overlay re-centres when the panel opens or is resized. Ids `player.overlay.back5`, `player.overlay.playPause` and `player.overlay.forward5`. Labels "Back 5 seconds", "Play"/"Pause" and "Forward 5 seconds". The play/pause value is "Playing"/"Paused". | Pass | `testOverlayIsCentredPortrait/Landscape` pass (shard 1). `testOverlayRecentresWhenThePanelOpensAndResizes` (shard 2) asserts at column widths of 874, 624.7 and 437 pt. Every centre is within 0.17 pt of 25/50/75 % and exactly at the vertical centre (y 201), and the diameters are 44/52/44 (`tester-centres-panel-closed/-25/-50`). The "Pause" label, unobserved in round 1, is now seen: `tester-portrait-playing-light/dark-state` reads "overlay label Pause value Optional(Playing)". Screenshots in portrait and landscape show white glyphs on dark translucent circles; round 1 measured the circles at 50 % black. |
| AC-2 Timing. In landscape the overlay shows and hides with the existing controls (`controlsShown`). In portrait it follows the same rules with its own state: it starts hidden, a tap on the video shows or hides it (and no longer toggles play), and a real pause (playing → paused) shows it. In both: a 0.2 s fade, auto-hide after 3 s while playing, it stays while paused, opacity only under Reduce Motion, always shown under VoiceOver, and hidden after a rotation. A skip tap restarts the countdown. | Pass (fade timing, Reduce Motion and VoiceOver Unverified) | Landscape follows the controls: `testOverlayIsCentredLandscape` and `testOverlayHidesWhilePlayingAndStaysWhilePausedLandscape`, now green. Portrait starts hidden, and a tap shows it without playing (`testPortraitTapShowsOverlayWithoutTogglingPlay`). A second tap hides it, and a third shows it again, still paused (`testPortraitSecondTapHidesTheOverlay`). A real pause shows it: `testPortraitRealPauseShowsTheOverlay` took its decisive path ("Playing", bar Pause, then the overlay appeared and stayed 3.5 s). It auto-hides while playing and stays while paused, in both orientations (`testOverlayHides…Portrait/Landscape`). A rotation hides it (`testRotationHidesTheOverlay`, `testRotationResetsThePortraitOverlay`). A skip restarts the countdown (`testSkipRestartsTheCountdownPortrait/Landscape`, run, not skipped): with a back-5 tap about once a second, the overlay still showed 3.9–5.0 s after Play and hid 4.1 s after the last tap (`tester-skip-restart-*`). The 0.2 s fade, opacity-only under Reduce Motion and always-shown under VoiceOver are code-read only (PlayerView.swift:553-561, :604-607). |
| AC-3 ±5 s is gone from the portrait row and from every landscape bar variant, and the `skips:` parameter is removed. | Pass | `testBarHasNoSkipButtonsPortrait/Landscape` pass. `git grep` on c1b6f0d finds `gobackward`/`goforward` only in PlaybackOverlay (PlayerView.swift:847, :860), and no `skips:`. |
| AC-4 The bar's `player.playPause` (both orientations) uses `DeckIconButtonStyle(isActive: !model.isPlaying)`: Shell/Ink while playing, aqua while paused. Its accessibility value is "Playing"/"Paused"; its id and labels don't change. | Pass | Pixels of the bar button: paused is (26,139,196) = aqua #1A8BC4, in portrait and landscape. Playing is Shell (238,241,244) in portrait, and (22,25,30) in the dark-scheme landscape bar, the same fill as the offset, Subs and Aa chips (`tester-*-barPlay`, `tester-landscape-playing-dark-video`). The value is "Paused" (`testOverlayIsCentred…`, `testBarPlayPauseValue…`) and "Playing": both `testBarPlayPauseValue…` tests are now green, and `tester-portrait-playing-*-state` reads "bar label Pause value Optional(Playing)". The id and labels are unchanged. |
| AC-5 Bar order for the later buttons. Portrait: the row `⏯ ±0.0s Subs Aa`, then Make a Card on its own row. Landscape: `⏯ ±0.0s Subs Aa … Make a Card`, with these ViewThatFits variants: (1) one row with the full Make a Card label; (2) one row with an icon-only Make a Card; (3) two rows, `⏯ ±0.0s Subs Aa` above Make a Card (icon) on the trailing side. In each variant a comment marks where ✥A (after Aa, T-024a), ↺📄 (after ✥A, T-029b) and 📄🔍 (just left of each Make a Card, T-030a) will go. | Pass (variant 3 Unverified) | `testOverlayRecentres…` asserts the left-to-right order ⏯ < ±0.0s < Subs < Aa < Make a Card. With the panel closed and at 25 %, Make a Card is 162 pt (variant 1); at 50 % it is a 54 pt icon (variant 2). Variant 3 can't be reached on an iPhone 17 Pro (code-read). The portrait order is shown in the screenshots. Markers are at PlayerView.swift:423, :502, :516, :664 and :723-724. |
| AC-6 `testPortraitTapStillTogglesPlay` becomes a test that a portrait tap shows the overlay and leaves the play state alone. New UI tests in both orientations (centres within 2 pt; paused mid-video skips move ~5 s and overlay play/pause toggles; gone 3 s after playing, stays while paused; no 5-second skip in `player.bottomBar` or the portrait controls; `player.playPause` reads "Paused", then "Playing"). Every existing test passes, and DESIGN.md documents the overlay and the play-button colour rule. | Pass | The renamed test passes (shard 2). All 12 PlaybackOverlayUITests and all 10 PlaybackOverlayTesterUITests pass. The mid-video skips are proven by `testSkipsMoveFiveSecondsMidVideoPortrait/Landscape`, which use the end clamp of the 6 s clip. Every existing test passes (412/412 runs). DESIGN.md has the overlay section and the colour rule, but its style-card wording is now stale (S1). |
| AC-7 (Fix round 2) In landscape the centred overlay hides while the subtitle style card (Aa) is open, and comes back on Done. This is the same rule as Move-Text (T-024a). It fixes the 3-row card cutting through the overlay (round 1 C1). Add a test. | Pass | `testOverlayGivesWayToTheStyleCardLandscape` passes: the card opens at 16.6 s, the overlay is gone at 18.7 s, Done closes the card at 20.1 s, and the overlay is back at 21.2 s. In this run's frames, all 12 with `subtitleStyle.card` lack the overlay, and all 12 with `player.bottomBar` have it. Revert check: round 1's 7034c69 is this code without `!styleMenuOpen`, and 5 of its frames show the card and the overlay together (at 50 %: card top y 218, overlay y 175–227). The new test's "hides while the card is open" step would fail on that code. |

Brent's other round 2 decisions:
- The flag is Debug-only in effect: only `UITestSeeder` reads it, and the seeder is `#if DEBUG`. It is clamped to 1…600, and a missing value, a non-number or "30.5" falls back to 6 (read, ClipDeckApp.swift:76-82). CLAUDE.md documents it.
- Seed time: with the 30 s clip, the "Seeded show should appear" wait took 1.2–7.2 s against its 30 s timeout (the longest was `testScreenshotsDark`). Launches with the 6 s clip took 1.1–1.6 s, except one slow 5.9 s, and round 1's worst 6 s wait was 21.7 s. There is no timeout risk on these VMs.
- PlaybackOverlayTesterUITests is in SHARD2_UI: shard 2 ran 30 tests (20 + 10), and the class ran nowhere else.

### Findings

**Should fix (S1): DESIGN.md still says the landscape overlay stays up while the style card is open**
Where: docs/DESIGN.md:95 and :98
Problem: Line 95 says the landscape overlay "shows and hides with the controls (… always up while paused or with a sheet, dialog or style card open)", and line 98 says it is "always shown under VoiceOver". Since round 2, the code hides it while the card is open, also with VoiceOver on (`showsOverlay: shown && !styleMenuOpen`, PlayerView.swift:258). Line 97 states the new rule, so the section contradicts itself, and T-022 and T-024a build on this section.
Proof: Read it. Ran it: the AC-7 test passes, and 12 card frames have no overlay.
Trigger: anyone reading the overlay rules.
Fix: line 95: "always up while paused or with a sheet or dialog open (see Style card)". Line 98: "always shown under VoiceOver, except while the style card is open". Brent decides if VoiceOver users should keep the overlay with the card open.

**Should fix (S2): `testBarPlayPauseValueLandscape` reads the bar only 0.6 s before it auto-hides**
Where: ios/ClipDeckUITests/PlaybackOverlayUITests.swift:141-143 (the same pattern is at :66-70 for the overlay)
Problem: After the landscape Play tap, the bar hides 3 s later, because the controls auto-hide while playing. `waitForValue` makes its first check about 1.0 s after it starts (1.03–1.10 s for every wait in this run), and only then is the label read. In 45110218499 the Play event ended at 18.53 s and the label read ended at 20.89 s: 2.36 s after the event and 0.64 s before the hide. If the post-tap "wait for app to idle" runs about 0.7 s longer than this run's 0.89 s, the bar is gone before the read and the test fails. The 30 s clip doesn't help, because the cause is the auto-hide, not the clip's end. In `checkSkipsAndPlayPause`, the overlay's "Playing" check and its re-tap race the same 3 s hide (about 1.9 s of margin in this run).
Proof: Traced it from the xcresult activities. I measured the post-event idle waits after a landscape Play tap with the controls up across 45070921716, 45083671012, 45087727557 (both attempts), 45094204439 and 45110218499: 1.70, 1.32, 5.64, 0.69, 0.86, 15.01, 0.89, 2.20, 0.13, 0.10, 0.02 and 0.01 s, plus 2.09, 1.46, 1.43, 1.02 and 0.06 s with the card open. 5 of these 17 are over 1.6 s, and 3 of 15 without the two frozen VMs.
Trigger: a moderately slow runner, about 1 run in 5 on these numbers. The test goes red with nothing wrong in the app, the same kind of failure as round 1's M1.
Fix: In landscape, read the bar's value and label with a direct property read right after the tap, in a short bounded loop, instead of XCTNSPredicateExpectation and its 1 s first poll. If the bar has already hidden, tap the video at (0.37, 0.15) to bring the controls back (the 30 s clip is still playing) and read again. Do the same for the overlay's "Playing" check in `checkSkipsAndPlayPause`. If Brent sends this to T-034 instead, add this cause there, because T-034's AC-2 names only the clip-end problem.

**Could fix (C1): "6 s" comments left over after the switch to 30 s, and a doc comment on the wrong property**
Where: PlaybackOverlayUITests.swift:4, :52-53, :79-81; PlaybackOverlayTesterUITests.swift:6-7, :55, :59, :110, :240; ClipDeckApp.swift:71-83
Problem: The class and helper comments still describe a 6 s clip for tests that now launch with 30 s. In LaunchFlags, the new `sampleSeconds` doc lines were added after the `-uiTestingMKV` doc block, so that block now documents `sampleSeconds`, and `shouldSeedMKV` (:83) has no doc comment.
Proof: Read it.
Fix: Update the comments, and move the MKV doc lines down to `shouldSeedMKV`.

**Could fix (C2): `testScreenshotsDark` takes light-mode screenshots on CI**
Where: ios/ClipDeckUITests/PlaybackOverlayTesterUITests.swift:386-395 (the round 1 tester's file)
Problem: The KVC appearance setter ran ("Setting appearance mode to Dark", 2.04 s) and the test passed, but the simulator stayed light. The status-bar text is black, and the playing bar button is Shell (238,241,244), the same pixels as the light run. The "dark" evidence isn't dark mode.
Proof: Ran it: `tester-portrait-paused-dark-screen` and `tester-portrait-playing-dark-barPlay` in shard 2 of 45110218499.
Fix: Set dark mode from the workflow before that class (`xcrun simctl ui <udid> appearance dark`), or check a status-bar pixel and `XCTSkip` when the switch didn't take. Dark mode stays Unverified.

**Could fix (C3): shard 2 took 32:00 of its 35-minute target**
Where: .github/workflows/ios-simulator.yml:52
Problem: Shard 2 took 32:00, against 21:47 for shard 1 and 20:59 for shard 3. 6:40 of it was one test: `testScreenshotsLight` hit the known 60 s "wait for app to idle" stall six times in landscape (401 s). The first stall began right after the rotation, before any tap. The stall is pre-existing (T-034 AC-3), and the 30 s clip played to its end during it (the shot reads 0:30.0, the paused state), but it leaves shard 2 close to the limit.
Fix: If shard 2 nears 35 min again, drop PlaybackOverlayTesterUITests from SHARD2_UI so it runs in shard 3. Brent chose shard 2, so it's his call.

### Tests added (test files only)
None this round. The round 1 tester's PlaybackOverlayTesterUITests ran for the first time: 10/10 pass, and none was skipped. C2 is a gap in it.

```text
VERDICT: Fail
SPEC: AC-1 met; AC-2 met (fade timing, Reduce Motion and VoiceOver code-read only); AC-3 met; AC-4 met; AC-5 met (variant 3 unreachable on 17 Pro); AC-6 met; AC-7 met. Fails on S1 (stale DESIGN.md lines 95/98) and S2 (landscape bar-value test races the 3 s auto-hide)
CHECKS_RUN: CI 45110218499 scope=all on c1b6f0d: plan success; ipa (build-ipa.sh) success 1:55; shards 1/2/3 (test-ios.sh) success 21:47/32:00/20:59; 412/412 runs, 375 names (364 + 11 new), 0 issues; run-ios.sh launch screenshot (shard 1) shows the library; lint is ""
UNVERIFIED: overlay fade feel and readability on bright scenes (Brent, iPhone); 0.2 s fade, Reduce Motion and VoiceOver always-shown (code-read); landscape variant 3 (needs a narrower phone); dark mode (C2)
REVIEWED_AT: c1b6f0d51bbd8628f33c95abe568cd7ddb9e8a79
```

## Fix round 3
Round 2 passed every AC with all 412 tests green (CI 45110218499) and failed only on S1 and S2. Brent's decisions (2026-11-23):
- Sonnet retry.
- **VoiceOver:** the overlay hides for everyone while the Aa card is open, VoiceOver included (the code as built). Fix S1 so DESIGN.md says this consistently.
- Fix S2 (the bar-value race against the 3 s auto-hide) in this round. Fold in the cheap Could fixes C1 (stale comments) and C2 (dark screenshots not dark on CI: fix it or rename/drop the claim).
- No product code should change. Then the green scope=all run 45110218499 stays the landing run, and the proof is a targeted run: -f scope=tests -f only_testing=ClipDeckUITests/PlaybackOverlayUITests (CI run 3 of 4). If C2 changes PlaybackOverlayTesterUITests, include it in that run.

## Implementation notes (round 3)
_by loop-frontend · 2026-11-23_
- S1: DESIGN.md "Playback overlay" now says consistently that the landscape overlay hides for everyone while the Aa card is open, VoiceOver included ("always up while paused or with a sheet or dialog open; see Style card"; "always shown under VoiceOver, except while the style card is open").
- S2: new `readValue(_:id:expecting:)` in PlaybackOverlayUITests: direct property reads right after the tap, polling while the element exists with another value, and up to 3 video taps to bring the controls back when the bar or overlay has hidden (state-based, bounded). `checkBarValue` and the overlay "Playing" check in `checkSkipsAndPlayPause` use it. Assertions unchanged (value "Playing", label "Pause").
- C1: stale 6 s comments fixed in both test files; in ClipDeckApp.swift the MKV doc block moved back onto `shouldSeedMKV` and `sampleSeconds` has its own doc (comments only, no behaviour change).
- C2: chose the safer option, dropping the dark claim: `testScreenshotsDark` and `setAppearance` (KVC) are removed, `testScreenshotsLight` stays. Reason: on CI the KVC setter ran but the simulator stayed light, and I can't verify a workflow `simctl ui appearance` change without a Mac. Dark mode stays Unverified for Brent. Test name set: minus `testScreenshotsDark` (T-034's name comparison should expect that).
- Nothing compiled (no Mac). No product behaviour changed.

## Test report (round 3)
_by loop-tester · 2026-11-23 00:20_

Round 3 is ec96444 (c1b6f0d..ec96444). It changed docs/DESIGN.md, the two overlay UI test files and ios/ClipDeck/App/ClipDeckApp.swift. The ClipDeckApp.swift change is comments only: I diffed both versions with every `//`/`///` line removed and they are identical; the MKV doc block moved back onto `shouldSeedMKV`. No other file under ios/ClipDeck, ios/project.yml, .github or scripts changed. So the green scope=all run 45110218499 on c1b6f0d (412/412 runs, ipa green) still covers the product code, the ipa and every other test class.

Targeted CI 45114494368 (scope=tests, only_testing "ClipDeckUITests/PlaybackOverlayUITests ClipDeckUITests/PlaybackOverlayTesterUITests", ec96444, CI run 3 of 4) is **red**: 18 of 21 tests passed, in one job that took 21:03. It compiled, with 0 build issues. All 12 PlaybackOverlayUITests passed, and so did 6 of the 9 PlaybackOverlayTesterUITests. The 3 that failed were the first 3 tests of the run, on a cold, slow VM (launches took 4.4–54.6 s, against 1.1–1.6 s in round 2):
- `testOverlayRecentresWhenThePanelOpensAndResizes` (default 6 s clip): "Seeded show should appear". At the end of the 30 s wait, the UI tree shows "Your library is empty".
- `testPortraitRealPauseShowsTheOverlay` (30 s clip): "Seeded show should appear". The library was still empty after the wait (111 s, because the snapshots were slow).
- `testPortraitSecondTapHidesTheOverlay` (6 s clip): "Failed to get background assertion for target app with pid 9427". The launch itself failed.
Round 3 didn't touch any of these three tests (it changed one comment in the second), and all three passed in 45110218499 (54.2, 29.2 and 19.7 s). From the fourth test on, every seed worked (1.1–9.5 s). The first two failures are the known "Seeded show should appear" flake in CONTEXT "Learned". The third is a simulator launch failure. They are pre-existing, not caused by this change. Evidence is in `%TEMP%\clip-deck-loop\T-021-r3` (database.sqlite3 and exported attachments; Data/ pruned, 12 MB).

Round 2 findings:
- S1 (stale DESIGN.md): fixed. docs/DESIGN.md:95 now reads "always up while paused or with a sheet or dialog open; see Style card". :97 reads "hides for everyone while the subtitle style card (Aa) is open, VoiceOver included". :98 reads "always shown under VoiceOver, except while the style card is open". That matches the code, where `showsOverlay: shown && !styleMenuOpen` and `shown` includes `voiceOverOn` (PlayerView.swift:258, :604). No other DESIGN.md line describes the overlay differently (:146 is the fade).
- S2 (the landscape bar read raced the 3 s auto-hide): fixed for the trigger it named, a moderately slow tap. In 45114494368, `readValue` read the value and label 0.08–0.27 s after the Play event in all four tests that use it (bar landscape/portrait, overlay landscape/portrait). In round 2 the read came 2.36 s after the event, which left 0.64 s of margin; now about 2.7 s remain, plus whatever the tap's own idle wait takes. `testSkipsAndPlayPauseWork*` re-tapped the overlay 0.30–0.33 s after Play. The fallback for a tap that outlasts the hide (re-show with a video tap) hasn't run, because no tap was that slow. I added `testBarValueIsReadAfterTheBarHidLandscape` to exercise it (see below). Its leftover narrow windows are C1 below.
- C1 (round 2: stale comments): fixed in ClipDeckApp.swift and PlaybackOverlayUITests. One leftover is in the tester file (C2 below).
- C2 (round 2: testScreenshotsDark): dropped. That's acceptable against the ACs. None of them names dark mode. AC-1 and AC-4's visual evidence comes from the light shots, and the landscape bar is always drawn dark. testScreenshotsLight passed again here, and the shots show the same thing as round 2: paused, the landscape bar ⏯ is aqua with three dark circles; playing, the portrait bar ⏯ is plain Shell and the overlay shows Pause; `tester-portrait-playing-light-state` reads "bar label Pause value Optional(Playing); overlay label Pause value Optional(Playing)". Dark mode stays Unverified for Brent. Overlay test names: 21, the same as round 2's 22 minus `testScreenshotsDark` and nothing else.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 Overlay: three white glyphs (`gobackward.5`, play/pause, `goforward.5`), each on a translucent black circle: 52 pt for the centre one, 44 pt for the skips. Their centres sit at 25 %, 50 % and 75 % of the video container's width, vertically centred. The container is the 16:9 video in portrait and the video column in landscape, so the overlay re-centres when the panel opens or is resized. Ids `player.overlay.back5`, `player.overlay.playPause` and `player.overlay.forward5`. Labels "Back 5 seconds", "Play"/"Pause" and "Forward 5 seconds". The play/pause value is "Playing"/"Paused". | Pass | The product is unchanged since 45110218499, where every AC-1 test passed (round 2 report). In 45114494368, `testOverlayIsCentredPortrait/Landscape` passed again, and testScreenshotsLight shows the overlay in both orientations. `testOverlayRecentresWhenThePanelOpensAndResizes` didn't reach its checks this time (seed flake). It passed in 45110218499. |
| AC-2 Timing. In landscape the overlay shows and hides with the existing controls (`controlsShown`). In portrait it follows the same rules with its own state: it starts hidden, a tap on the video shows or hides it (and no longer toggles play), and a real pause (playing → paused) shows it. In both: a 0.2 s fade, auto-hide after 3 s while playing, it stays while paused, opacity only under Reduce Motion, always shown under VoiceOver, and hidden after a rotation. A skip tap restarts the countdown. | Pass (0.2 s fade, Reduce Motion and VoiceOver Unverified) | 45110218499 (all green). In 45114494368, `testOverlayHides…Portrait/Landscape`, `testRotationHidesTheOverlay`, `testRotationResetsThePortraitOverlay` and `testSkipRestartsTheCountdownPortrait/Landscape` passed again, and the skip-restart tests ran without skipping (the overlay was still up 4.6–4.9 s after Play, then hid 4.1–4.4 s after the last skip). `testPortraitSecondTapHidesTheOverlay` and `testPortraitRealPauseShowsTheOverlay` failed at launch (pre-existing flakes). Both passed in 45110218499. The 0.2 s fade, Reduce Motion and VoiceOver are code-read only (PlayerView.swift:553-561, :604-607). |
| AC-3 ±5 s is gone from the portrait row and from every landscape bar variant, and the `skips:` parameter is removed. | Pass | `testBarHasNoSkipButtonsPortrait/Landscape` passed in both runs. The product is unchanged. |
| AC-4 The bar's `player.playPause` (both orientations) uses `DeckIconButtonStyle(isActive: !model.isPlaying)`: Shell/Ink while playing, aqua while paused. Its accessibility value is "Playing"/"Paused"; its id and labels don't change. | Pass | `testBarPlayPauseValuePortrait/Landscape` passed with the new direct read (value "Playing", label "Pause", 0.27 s after the event). The playing portrait shot shows a Shell ⏯, and the paused landscape shot shows an aqua one. The pixels were measured in round 2, and the product is unchanged. |
| AC-5 Bar order for the later buttons. Portrait: the row `⏯ ±0.0s Subs Aa`, then Make a Card on its own row. Landscape: `⏯ ±0.0s Subs Aa … Make a Card`, with these ViewThatFits variants: (1) one row with the full Make a Card label; (2) one row with an icon-only Make a Card; (3) two rows, `⏯ ±0.0s Subs Aa` above Make a Card (icon) on the trailing side. In each variant a comment marks where ✥A (after Aa, T-024a), ↺📄 (after ✥A, T-029b) and 📄🔍 (just left of each Make a Card, T-030a) will go. | Pass (variant 3 Unverified) | Unchanged since round 2 (45110218499). The round 3 shots show the same portrait and landscape order. Variant 3 can't be reached on an iPhone 17 Pro. |
| AC-6 `testPortraitTapStillTogglesPlay` becomes a test that a portrait tap shows the overlay and leaves the play state alone. New UI tests in both orientations: the overlay centres are within 2 pt of 25/50/75 % of `player.video`'s width and of its vertical centre; while paused mid-video, back5 and forward5 move the time by about 5 s, and the overlay play/pause toggles playback; the overlay is gone 3 s after playing starts and stays while paused; `player.bottomBar` and the portrait controls hold no 5-second skip button; `player.playPause` reads "Paused", then "Playing". Every existing test passes, and DESIGN.md documents the overlay and the play-button colour rule. | Pass on 45110218499; the check on ec96444 is red on 3 pre-existing flakes | All 12 PlaybackOverlayUITests pass on ec96444. `testSkipsMoveFiveSecondsMidVideoPortrait/Landscape` pass too. Every existing test passed in 45110218499, and round 3 touched no other test class. DESIGN.md is now consistent (S1). The one removed test is `testScreenshotsDark`, the tester's own evidence test and not an AC test. |
| AC-7 (Fix round 2) In landscape the centred overlay hides while the subtitle style card (Aa) is open, and comes back on Done. This is the same rule as Move-Text (T-024a). It fixes the 3-row card cutting through the overlay (round 1 C1). Add a test. | Pass | `testOverlayGivesWayToTheStyleCardLandscape` passed in both runs. Brent's round 3 rule (hidden for everyone, VoiceOver included) is what the code does: `shown && !styleMenuOpen` (PlayerView.swift:258). The VoiceOver case itself is code-read. |

### Findings

**Could fix (C1): `readValue` still has two narrow windows on a slow runner**
Where: ios/ClipDeckUITests/PlaybackOverlayUITests.swift:252-259 (now :269-276 with the tester test above it)
Problem: (a) `element.exists`, `element.value` and `element.label` are three separate queries, 0.06–0.2 s apart in this run. If the bar hides between them, the `.value` or `.label` read records "No matches found" and fails the test. That only happens when the Play tap's idle wait lands in roughly 2.7–3.0 s. None of the 17 earlier samples did. (b) After a re-show tap, `waitForExistence(timeout: 3)` makes its first check about 1.0 s later (CONTEXT "Learned"). So the fallback only works when the re-show tap's own idle wait is under about 1.7 s.
Proof: Traced it. Activity timings are from 45114494368 (`readvalue.py`), and the 1.0 s first poll is from 45110218499.
Trigger: a slow runner whose Play-tap idle lands near 3 s, or whose taps all take about 2 s or more.
Fix: read once with `if let s = try? element.snapshot() { last = (s.value as? String, s.label) }`. It's atomic and doesn't record a failure. After the re-show tap, poll `exists` directly in a short loop instead of `waitForExistence`. This fits T-034 if Brent prefers to put it there.

**Could fix (C2): the tester class comment still says "a 6 s video"**
Where: ios/ClipDeckUITests/PlaybackOverlayTesterUITests.swift:6-7, and :238
Problem: four of its nine tests launch with 30 s. Line 238 says a slow runner "can't" play the 30 s clip to its end, but round 2's 60 s idle stalls did exactly that (CONTEXT "Learned"). Comments only.
Proof: Read it.
Fix: change it to "a 6 s video (30 s where a test plays it)". On :238, say "rarely".

Note for the orchestrator (not a finding): T-034 AC-4 compares test names with "the T-021 landing run". The landed commit's set is 45110218499's 375 names minus `testScreenshotsDark`, plus `testBarValueIsReadAfterTheBarHidLandscape` if it is committed. Record that set when T-021 lands.

### Tests added (test files only)
- `ios/ClipDeckUITests/PlaybackOverlayUITests.swift`: `testBarValueIsReadAfterTheBarHidLandscape`. It exercises S2's fallback: landscape, Play from the bar, wait for the bar to hide on its own, then `readValue` must re-show the controls with a video tap and read "Playing" / "Pause". It is in the same class because `readValue` is private. It hasn't run yet. Revert check: not run (ci_only). With round 2's `waitForValue(barPlay, "Playing", timeout: 5)` in its place, the bar is hidden at that point, so the predicate can never match and the test fails. Without the re-show branch, `readValue` returns (nil, nil), and the test fails.

```text
VERDICT: Blocked
SPEC: AC-1 to AC-7 met on 45110218499 (product code unchanged since; round 3 = docs, test files, comments). S1 fixed, S2 fixed for its trigger (reads 0.08-0.27 s after Play, was 2.36 s), C1/C2 folded in. Check on ec96444 red only on 3 pre-existing launch/seed flakes in unchanged tests
NEEDED: one targeted run that includes the tester's new test (CI run 4 of 4): commit ios/ClipDeckUITests/PlaybackOverlayUITests.swift, push, then `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=tests -f only_testing="ClipDeckUITests/PlaybackOverlayUITests ClipDeckUITests/PlaybackOverlayTesterUITests"`. It decides testOverlayRecentresWhenThePanelOpensAndResizes, testPortraitRealPauseShowsTheOverlay, testPortraitSecondTapHidesTheOverlay and testBarValueIsReadAfterTheBarHidLandscape. Without the new test: `gh run rerun 45114494368 --failed`
CHECKS_RUN: CI 45114494368 (scope=tests, the two overlay classes, ec96444): build ok, 0 build issues; 18/21 pass; failures are "Seeded show should appear" x2 and "Failed to get background assertion" x1, the first 3 tests on a cold VM; ipa and the other classes rest on 45110218499 (scope=all, c1b6f0d, 412/412, ipa green), valid because c1b6f0d..ec96444 changes no product line (comment-only diff checked); lint is ""
UNVERIFIED: overlay fade feel and readability on bright scenes (Brent, iPhone); 0.2 s fade, Reduce Motion, VoiceOver always-shown and VoiceOver hidden-with-card (code-read); landscape variant 3 (needs a narrower phone); dark mode (no CI evidence; testScreenshotsDark removed)
REVIEWED_AT: ec96444a69635bd35d85e4591f980b2cba56aa29
```

### Round 3 addendum
_by loop-tester · 2026-11-23 00:45_

The verify-only run is CI 45117390680, on c971174 ("wip(T-021): round 3 verify"). It used scope=tests and only_testing "ClipDeckUITests/PlaybackOverlayUITests ClipDeckUITests/PlaybackOverlayTesterUITests", and it was CI run 4 of 4. It is **green**: 22 of 22 tests passed in one job (16:39), with 0 build issues and no test skipped. c971174 is ec96444 plus only the tester's 17-line test (`git diff ec96444 c971174`), so the product code is still c1b6f0d's and 45110218499 still covers it.

- **The three tests that flaked in 45114494368 now pass, and each ran to its checks:**
  - `testOverlayRecentresWhenThePanelOpensAndResizes` passed in 91.6 s. It again went first on a slow, cold simulator (the launch and the first rotation took about 55 s), but the seed was ready in 3.3 s. Its assertions and attachments ran at panel closed, 25 % and 50 %.
  - `testPortraitRealPauseShowsTheOverlay` passed and took its decisive path: "Playing", then a bar Pause, then the overlay appeared and stayed 3.5 s.
  - `testPortraitSecondTapHidesTheOverlay` passed all three taps: show, hide, show, still paused.
  - This confirms the 45114494368 failures were the pre-existing cold-start launch and seed flake.
- **`testBarValueIsReadAfterTheBarHidLandscape` passed and ran the S2 fallback path:**
  - The Play event ended at 15.53 s. The bar was gone at the 18.55 s check (3.02 s later).
  - `readValue` found no bar at 18.58 s, tapped the video at (0.37, 0.15), and the event ended at 19.09 s.
  - `waitForExistence` first checked at 20.14 s (1.05 s later, as C1 says).
  - The value and label were read at 20.20–20.26 s: "Playing" / "Pause". That is 1.1 s after the re-show event, about 1.9 s before the next hide.
- **All 12 of the implementer's PlaybackOverlayUITests** and the other 6 tester tests passed again.
- **Test names in the two overlay classes:** 22 (round 2's 22, minus `testScreenshotsDark`, plus `testBarValueIsReadAfterTheBarHidLandscape`). The full landed set for T-034 AC-4 is 375 names: 45110218499's 375, minus `testScreenshotsDark`, plus `testBarValueIsReadAfterTheBarHidLandscape`.
- Evidence is in `%TEMP%\clip-deck-loop\T-021-r3\verify` (Data/ pruned).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 | Pass | 45110218499. In 45117390680, `testOverlayIsCentred*` and `testOverlayRecentresWhenThePanelOpensAndResizes` passed |
| AC-2 | Pass (0.2 s fade, Reduce Motion and VoiceOver Unverified) | 45110218499. In 45117390680, `testPortraitSecondTapHidesTheOverlay`, `testPortraitRealPauseShowsTheOverlay`, `testOverlayHides*`, `testRotation*` and `testSkipRestartsTheCountdown*` passed |
| AC-3 | Pass | `testBarHasNoSkipButtons*` passed in both runs |
| AC-4 | Pass | `testBarPlayPauseValue*` and `testBarValueIsReadAfterTheBarHidLandscape` passed ("Playing"/"Pause"). The colours are from round 2's pixels and the round 3 shots |
| AC-5 | Pass (variant 3 Unverified) | Unchanged since 45110218499 |
| AC-6 | Pass | All 13 PlaybackOverlayUITests and all 9 PlaybackOverlayTesterUITests are green on c971174. Every other test is green on 45110218499 (same product code). DESIGN.md is consistent (S1) |
| AC-7 | Pass | `testOverlayGivesWayToTheStyleCardLandscape` passed in all three runs since round 2 |

Findings: no Must fix or Should fix is open. C1 (`readValue`: three separate queries, and the 1 s first poll after a re-show) and C2 (the tester class comment) from the round 3 report stay Could fix. T-034 can take C1.

```text
VERDICT: Pass
SPEC: AC-1 to AC-7 met. S1 and S2 fixed; the S2 fallback proven by testBarValueIsReadAfterTheBarHidLandscape. Round 2's C1/C2 folded in (dark screenshots dropped; dark mode Unverified)
CHECKS_RUN: CI 45117390680 (scope=tests, overlay classes, c971174): success, 22/22, 0 build issues, 16:39. CI 45114494368 (ec96444): 18/21, 3 pre-existing cold-start launch/seed flakes, all passing in 45117390680. CI 45110218499 (scope=all, c1b6f0d, same product code): 412/412, ipa green. lint is ""
UNVERIFIED: overlay fade feel and readability on bright scenes (Brent, iPhone); 0.2 s fade, Reduce Motion, VoiceOver always-shown and VoiceOver hidden-with-card (code-read); landscape variant 3 (needs a narrower phone); dark mode
REVIEWED_AT: c97117432fb11379b9a5c2815493047c35f6cdb0
```
