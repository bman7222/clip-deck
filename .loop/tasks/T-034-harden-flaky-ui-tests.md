---
id: T-034
title: Harden the known flaky tests
lane: backend
depends_on: [T-021]
status: done
round: 2
base_sha: e6a46e14301e33ffc432b83434beebe410e272c5
issue: 39
spec: .loop/specs/player-lookup-timeline.md
model: opus
---

## Make the known flaky tests pass on slow CI runners

### What are we building?
Every full CI run in this goal had a failure from a known flaky test: 6 failures across 4 runs, none caused by the change under test. The causes are lost taps, waits that are too short for a slow runner, and a 6 s sample clip that ends before a check. After this task those tests wait for state instead of time, re-tap when a tap didn't take, and get enough clip and launch time. A full run should then go green without re-runs. No app behaviour changes.

### Why?
Each flaky failure costs a CI re-run and a decision from Brent, and it hides real failures in the noise.

### Done when
- AC-1 Shared helpers in the UI test target (for example `ios/ClipDeckUITests/UITestSupport.swift`): launching with the seeded library (one generous, state-based wait), opening the sample episode, waiting for a label/value/frame, "tap until a state holds" (re-tap only after waiting for the state, and only while the button still exists and is hittable), and the existing settle and evidence helpers. The 15 copies of the 30 s "Seeded show should appear" wait in 11 classes use the shared launch helper.
- AC-2 Each flake listed in CONTEXT "Learned" is hardened, with its cause named in your notes:
  - the seeded library not appearing in time;
  - `EpisodeImporterTests/copiesAnMP4AndItsSubtitleIntoTheShowFolders` (".timedOut") and `ClipExtractorTests/cutsExactAudioAndScreenshot` (timeout);
  - `SubtitleStyleCardTesterUITests/testUpDisablesWhenTheLineCanNoLongerMoveUp` (a lost Up tap);
  - `SubtitleUpLimitTesterUITests/testUpDimsExactlyWhenTheLineReachesTheTopBarWithTwoAndThreeRowCards` (a lost Done tap);
  - `AboutUITests/testAboutShowsVersionAndNoticeTextIntact` (a slow VM) and `testSourceLinksAreShownAndOpenInSafari` (Safari slow to launch);
  - `PlayerLandscapeBehaviourUITests/testControlsStayWhilePausedAndAutoHideWhilePlaying` and `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying` (the 6 s clip ends before the check), plus T-021's new overlay timing tests, which have the same clip problem.
- AC-3 The 60 s "wait for app to idle" stall is investigated. Fix it at its cause if that's in test code or in a `-uiTesting`-only setting. Otherwise record what you ruled out and add a CONTEXT "Learned" line. The stalled tests passed, so the stall costs time, not a red run.
- AC-4 No test loses meaning. Nothing is deleted, skipped or renamed, and no assertion is weakened without saying so in your notes. The run executes the same set of tests as the T-021 landing run (at least 390, plus T-021's), checked by test-name sets from the xcresults of all three shards.
- AC-5 One green `scope=all` run: every shard and the ipa job. A re-run of only the failed job (`gh run rerun <id> --failed`) counts for proof, but if a test hardened here fails in either attempt, that's a Fail. docs/DEVELOPMENT.md (Tests) describes the helpers, and a CONTEXT "Learned" line records what was hardened.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`. Watch it with `gh run watch <id> -i 60 --exit-status` and download with `-p "simulator-results*"`. That gives three shards (`simulator-results-1`, `-2`, `-3`); compare their test-name union with T-021's landing run. Read each hardened test's diff against the cause named in its notes.

### Agent notes
- Depends on: T-021 (it rewrites `testPortraitTapStillTogglesPlay` and adds overlay timing tests). Source: Brent's planning change, 2026-11-22, and CONTEXT "Learned" (the flake lines).
- **Likely root cause** (traced by the planner from the code, not yet proven): `TestMediaFactory.waitUntilReady` (ios/ClipDeck/Services/Media/TestMediaFactory.swift:77-84) gives up after 1,000 × 5 ms, about 5 s, and throws `.timedOut`.
  - The UI-test seeder (`UITestSeeder.seed`, RootView.swift:31-48) then prints "UITestSeeder failed" and seeds nothing, so the library stays empty however long a test waits (the "still empty after 66 s" report).
  - The same factory makes the videos in EpisodeImporterTests.swift:51, MediaAndFileTests.swift:52 and :72, and VideoImportModelTests.swift:41.
  - Confirm it from the app output in the xcresults of 45069006816 and 45083671012 (shard 1). A time-based deadline or `requestMediaDataWhenReady(on:)` fixes it; the seeder may also retry once. Both files are DEBUG-only test support, so this is allowed and changes no app behaviour. Say so in your notes.
- The clip problem: PlayerLandscapeBehaviourUITests.swift:32-57 and 65-91. In 45087727557 the Play tap took about 6 s, the clip ended, and the slider read 6,000. One option is a hook such as `-uiTestingSampleSeconds <n>` for the seeder (Debug, with `-uiTesting`; the default of 6 leaves every other test unchanged), so these tests get a 30 s clip. Document it in CLAUDE.md.
- Lost taps: the Up loop is at SubtitleStyleCardTesterUITests.swift:143-160 (the assertion at :156); the Done taps are at SubtitleUpLimitTesterUITests.swift:160-169. A slow tap can land after the re-tap and apply twice, so detect a double step from the stored value (Down's "N percent up") rather than from the frame alone.
- About: AboutUITests.swift:86-120 and 41-80. In 45083671012 one launch took 19.8 s and one tap 11.6 s, against waits of 10 s and 5 s.
- The idle stall: `testLoadDifferentSubtitlesFromLandscapeDialog` took 517 s (45083671012, shard 2), `SubtitleStyleCardUITests/testPresetChipsSelect…` 442 s (45087727557, shard 3), and `testUpAndSize…` hung (44976839046). All three were in landscape.
- Shards: new UI classes land in shard 3. Don't move classes between shards unless a shard nears 35 min (CONTEXT "Learned").
- From T-021 (orchestrator, 2026-11-23):
  - `-uiTestingSampleSeconds <n>` **already exists**. T-021 added it (Debug, with `-uiTesting`, clamped 1…600, default 6, documented in CLAUDE.md), so reuse it for the PlayerLandscapeBehaviour clip tests instead of adding a new hook.
  - The test-name baseline for AC-4 is the T-021 landing set of 375 names: 45110218499's 375, minus `PlaybackOverlayTesterUITests/testScreenshotsDark` (removed on purpose), plus `PlaybackOverlayUITests/testBarValueIsReadAfterTheBarHidLandscape`.
  - Another flake cause besides the clip end: a check that races the 3 s auto-hide. See `readValue` in PlaybackOverlayUITests, which re-shows the bar with a video tap.
  - Open Could fix from T-021's tester:
    - C1: `readValue` (PlaybackOverlayUITests.swift:269-276) reads exists, value and label as three separate queries; one `try? element.snapshot()` would read them together. After the re-show, `waitForExistence` uses about 1 s of the 3 s window.
    - C2: the class comment at PlaybackOverlayTesterUITests.swift:6-7 still says the sample is 6 s.
  - The cold-start seed/launch flake also hit the first tests of a fresh simulator in 45114494368 ("Failed to get background assertion for target app").

### Out of scope
- xcodebuild `-retry-tests-on-failure` or test iterations in the workflow. That would hide flakes, so it's Brent's call.
- App behaviour changes, deleting or skipping tests, new features.

## Implementation notes (round 1) · sonnet
(Recorded by the orchestrator from the builder's report; the builder didn't write this section.)
- New `ios/ClipDeckUITests/UITestSupport.swift` (`@MainActor enum`, not an XCTestCase): `launchSeeded` (45 s wait, then one relaunch), `openSampleEpisode(sampleSeconds:)`, `launchAndOpenSampleEpisode`, `wait`, `waitForLabel/Value/Frame`, `tap(_:until:)`, `tapStep`, `upText`, `readTogether` (one snapshot), `settle`, `attachText`, `attachScreenshot`. 17 copies of the 30 s seeded-show wait now use `launchSeeded`.
- AC-2 seed root cause: **not confirmed from evidence** (the pruned xcresults have no app stdout). Fixed defensively: `TestMediaFactory.waitUntilReady(_:writer:)` uses a 60 s `ContinuousClock` deadline (`readyTimeout`) and fails at once on writer `.failed`/`.cancelled`; `UITestSeeder.seed` tries twice. DEBUG-only; no app behaviour change. This also covers EpisodeImporterTests `.timedOut` and ClipExtractorTests.
- Lost taps: SubtitleStyleCardTester and SubtitleUpLimitTester Up taps go through `tapStep`, which checks Down's "N percent up". It re-taps only if the value is unchanged, and a double step fails the test. The Done taps use `tap(done) { !card.exists }`.
- About: shared `openAbout`, longer waits (Settings 45 s, About 20 s), retried row taps, and `openInSafari` re-taps only while Clip Deck is in front. Watch `testSourceLinksAreShownAndOpenInSafari`.
- PlayerLandscapeBehaviour: reuses `-uiTestingSampleSeconds`. `testOpenSubtitlesMenuKeepsControlsUp…` uses 30 s; `testControlsStayWhilePausedAndAutoHide…` uses 20 s, with its end-of-clip wait raised from 10 s to 40 s (about 20 s longer).
- T-021 carry-overs: C1 (`readValue` via `readTogether`; re-show poll 0.05 s up to 3 s) and C2 (class comment) are done.
- AC-3 idle stall: **not fixed; cause not found**. Stalls always begin at the first action after `orientation = .landscapeLeft` in the player (taps take 120.6–120.9 s = 2 × 60 s, also on Tear Down), even in tests that never play. The app has no repeatForever/TimelineView/Timer/CADisplayLink; the only periodic observer is AVPlayer's. Recorded in CONTEXT "Learned".
- No tests added, deleted, skipped or renamed; no shard changes. Docs: docs/DEVELOPMENT.md (Tests: helper section).
- Not compiled (CI only). Compile risks: `UITestSupport` closures, `XCUIElement.snapshot()`, `XCUIApplication.state`, and the `for attempt in 1...2 where !seeded` loop in RootView.swift.

## Test report (round 1)
_by loop-tester · 2026-11-23 01:30_

CI 45119953687 (scope=all, 8d036e0, CI run 1 of 4): ipa green (2:03), shard 2 green (26:16), shard 1 red (29:33), shard 3 red (24:22). 410 of 412 runs passed, 0 build issues, so the change compiles. Evidence is in %TEMP%\clip-deck-loop\T-034-r1 (Data/ pruned, 23 MB; filtered app logs `app-idle-log-shard<n>.txt` and `app-log-shard1-pids-16112-17274.txt`). Scripts are in %TEMP%\clip-deck-loop\tools-T-034.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 Shared helpers in the UI test target: launching with the seeded library (one generous, state-based wait), opening the sample episode, waiting for a label/value/frame, "tap until a state holds" (re-tap only after waiting for the state, and only while the button still exists and is hittable), and the existing settle and evidence helpers. The 15 copies of the 30 s "Seeded show should appear" wait in 11 classes use the shared launch helper. | Pass | `UITestSupport.swift` has every helper named and compiled in all 3 shards. Base e6a46e1 had 17 copies in 13 files; HEAD has none outside `launchSeeded` (git grep). `launchSeeded`'s relaunch ran once (testBarPlayPauseValuePortrait: the first wait expired at 46.9 s, then terminate and relaunch, and the show appeared after 3.8 s; test passed). `tap(_:until:)` guards with `exists && isHittable` before each re-tap (UITestSupport.swift:72-79). The re-tap paths did not run in this run (no lost taps). |
| AC-2 seeded library not appearing in time | Pass | Cause confirmed from runs. In 45114494368 both failures' "App UI hierarchy" show "Your library is empty" (the seed finished without a show, so it threw; RootView.swift catch path). In this run, the app stdout (xcresult Diagnostics) shows pid 16112 on "Preparing sample episode…" from 05:56:14 to 05:56:58, and no "UITestSeeder failed" line in any shard: a slow writer now waits instead of throwing, and the relaunch recovered. 84 seeded waits: median 1.3 s, p90 4.2 s, max 46.9 s. |
| AC-2 EpisodeImporterTests/copiesAnMP4… (.timedOut), ClipExtractorTests/cutsExactAudioAndScreenshot (timeout) | Pass | Traced: `.timedOut` exists only in TestMediaFactory.swift:11/:88, so the old 1,000 × 5 ms loop is the only source. Both passed (1.75 s, 1.03 s), as did every other ClipDeckTests test. One run can't show a rare flake gone; the cause is removed in code (60 s `ContinuousClock` deadline, fails at once on `.failed`/`.cancelled`). |
| AC-2 SubtitleStyleCardTesterUITests/testUpDisables… (lost Up tap) | Pass | Passed (47.8 s); 13 Up taps for 13 steps ("up taps before disabling: 13"). `tapStep` adds a stored-value check (Down's "N percent up") on top of the kept frame check. |
| AC-2 SubtitleUpLimitTesterUITests/testUpDims… (lost Done tap) | Pass | Passed (97.1 s); 4 Done taps for 4 closes; 19 Up taps = 10 + 7 climb steps + 2 after Down (tester-t018-climb). |
| AC-2 AboutUITests (slow VM, Safari slow to launch) | Pass | All 3 passed, with launches of up to 89.5 s; Safari came to the front on the first tap both times. S1: every About test now launches twice. |
| AC-2 PlayerLandscapeBehaviourUITests clip tests | Pass | testControlsStay… (20 s clip): the bar came back on its own 21.5 s after Play, so the end-of-clip check still means something. testOpenSubtitlesMenu… (30 s): the menu tap ended 2.0 s after Play. S2: the menu tap still races the 3 s auto-hide. |
| AC-2 T-021's overlay timing tests (same clip problem) | Fail | M1: PlaybackOverlayUITests/testBarValueIsReadAfterTheBarHidLandscape failed at :160 because the idle stall outlasted the 30 s clip. |
| AC-3 The 60 s "wait for app to idle" stall is investigated; fixed at its cause if in test code or a `-uiTesting`-only setting, otherwise ruled-out list and a CONTEXT "Learned" line. | Pass (on its wording) | Investigated; not fixed; ruled-out list and a Learned line (working tree). I checked it against 11 xcresults: stalls start at the first action after the landscape rotation (2 × 60 s per action, Tear Down too). The `-uiTesting` settings (ClipDeckApp.swift:11-42) touch defaults, panel width, style and the store, not animation. New from the app stdout: the main run loop keeps going idle, but the first "animations idle" request about 1.7 s after the rotation (05:57:54.806) is never answered for the rest of the process. The AC's premise ("costs time, not a red run") no longer holds: M1. |
| AC-4 No test loses meaning. Nothing is deleted, skipped or renamed, and no assertion is weakened without saying so in your notes. The run executes the same set of tests as the T-021 landing run, checked by test-name sets from the xcresults of all three shards. | Pass | Name union of the 3 shards = 375, identical to the landing set (45110218499's 375 − testScreenshotsDark + testBarValueIsReadAfterTheBarHidLandscape); 412 runs as in 45110218499. 86 UI test functions identical by name at base and HEAD; 289 `@Test` unchanged; no skip added. Changed assertions are timing-only (About 5→20 s and 15→60 s Safari; end of clip 10→40 s with the clip 6→20 s; the Up frame check now polls up to 6 s instead of reading once after a 0.8 s settle) or stronger (stored-step checks). |
| AC-5 One green `scope=all` run, every shard and the ipa job (if a test hardened here fails in either attempt, that's a Fail); DEVELOPMENT.md (Tests) describes the helpers; a CONTEXT "Learned" line records what was hardened. | Fail | 45119953687 is red: M1 in shard 1, plus a pre-existing launch failure in shard 3. DEVELOPMENT.md:141-155 describes the helpers and matches the code. The CONTEXT Learned line is in the working tree, not committed. |

Shard times: 29:33 / 26:16 / 24:22 for the jobs, all under 35 min. Shard 1 includes 5:33 for the stalled test; shard 2 went from 32:00 in 45110218499 to 26:16 with no stall this time.

Revert check: not done. There is no new test; the hardened paths (re-tap, relaunch) are nondeterministic, and each revert costs a CI run. The relaunch path was seen working in this run.

### Findings

Must fix M1
Where: ios/ClipDeckUITests/PlaybackOverlayUITests.swift:154-164 (testBarValueIsReadAfterTheBarHidLandscape), through the AC-3 idle stall
Problem: CI is red. After the landscape rotation the app stopped answering XCTest's "animations idle" request, so every action waited 2 × 60 s (Tap player.video 120.7 s, Play tap 121.4 s). The Play event went out at 06:00:59 and the test got control back 60.4 s later. By then the 30 s clip had played to its end and paused, the bar came back, and line 160 "Playing: the bar hides on its own" failed. Failure hierarchy: player.currentTime 0:30.0, slider 30,000, player.playPause "Play"/"Paused".
Proof: Ran it. CI 45119953687 shard 1: xcresult Activities, and the app stdout for pid 17274. The request at 05:57:54.806 was never answered, while main-run-loop idle replies went on at 05:58:55, 05:59:57 and 06:00:59.
Trigger: the stall hits any test that checks a 3 s state while playing. A longer clip can't save it: under the stall each `readValue` re-show tap also costs 120 s, far past the bar's 3 s.
Fix: handle the stall itself; a longer clip won't do. Options: (a) a setup-level stall guard in UITestSupport: when the first action after rotating takes more than about 50 s, terminate, relaunch and redo the setup once, with an attachment so it stays visible. This is close to a retry, so it may be Brent's call. (b) Find the animation that never finishes. It starts within about 1 s of the rotation in a paused player; PlayerView.swift:91-118 switches `.toolbar(.hidden)`, `.statusBarHidden`, `.persistentSystemOverlays(.hidden)` and resets animated states on rotation.

Should fix S1
Where: ios/ClipDeckUITests/AboutUITests.swift:8, :36, :78 (with :119)
Problem: every About test launches the app twice. The test body calls `app.launch()`, then `openAbout` launches again, which first terminates the instance just started.
Proof: Ran it. 45119953687 shard 2: the second launches took 70.2 s (57.0 s of it terminating the first instance), 5.5 s and 4.9 s. The same terminate step failed outright in shard 3 ("Failed to terminate dev.brent.clipdeck").
Trigger: every About run. On a slow VM it adds about 70 s per test, plus one more launch/terminate failure point in exactly the tests hardened for slow launches.
Fix: delete the `app.launch()` at :8, :36 and :78; `openAbout` launches.

Should fix S2
Where: ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift:76-79
Problem: testOpenSubtitlesMenuKeepsControlsUpWhilePlaying still races the 3 s auto-hide, the cause T-021 handed over. After Play it must find and tap `player.subtitlesMenu` before the bar hides. With the 30 s clip, a slow Play tap leaves the bar hidden (the clip end no longer brings it back), and `menu.waitForExistence(timeout: 2)` or `menu.tap()` fails.
Proof: Traced it. In the Activities of 10 runs (T-018 rounds 1-2 through 45119953687), the menu tap ends 1.8-3.3 s after the Play tap starts, against 3.0 s; it was 3.25 s in 45070921716. In 45087727557 a Play tap in this class took about 6 s.
Trigger: a Play tap whose idle wait is longer than about 1 s.
Fix: if the menu isn't there after Play, bring the bar back with a video tap (as `readValue` does), then tap the menu. The keep-up check after the dialog opens stays as it is.

Could fix
- C1 PlayerLandscapeBehaviourUITests.swift:151-182: testPanelStaysOpenWhenControlsAutoHide still plays the 6 s clip and checks "controls hide on their own", the same clip-end exposure as testControlsStay… (not in AC-2's list). Use `sampleSeconds: 20`.
- C2 A stalled app's Tear Down costs 60-120 s (orientation reset) plus 60 s in the next test's setUp (45110218499 testSkipRestartsTheCountdownLandscape; this run's Tear Down 60.8 s). Terminating the app at the start of tearDown would save up to 3 min per stall.
- C3 `launchAndOpenSampleEpisode`, `settle`, `attachText` and `attachScreenshot` are unused (15 classes keep private copies), and most classes keep their own 5 s "Episode row" wait instead of `openSampleEpisode` (10 s).

Pre-existing (not caused by this change): ExpiryBannerUITests/testOpenSideStoreWithoutSideStoreKeepsBannerAndExplains failed at launch (ExpiryBannerUITests.swift:15, "Failed to terminate dev.brent.clipdeck:13847"; the launch step's finish time is corrupt). The class and its launch code are not in the diff.

```text
VERDICT: Fail
SPEC: AC-1 met; AC-2 partly (seed, unit-test, Up, Done, About and landscape clip items met; T-021 overlay timing test failed, M1; S1 and S2 open); AC-3 met on its wording (its "not a red run" premise is disproven); AC-4 met (375/375 names, 412 runs); AC-5 not met (run red)
CHECKS_RUN: CI 45119953687 scope=all on 8d036e0: ipa success 2:03; shard 1 failure 29:33 (354/355, testBarValueIsReadAfterTheBarHidLandscape); shard 2 success 26:16 (29/29); shard 3 failure 24:22 (27/28, ExpiryBanner launch, pre-existing); 0 build issues. test-ios.sh and build-ipa.sh ran only in CI (ci_only)
UNVERIFIED: the re-tap paths of tap(_:until:) and tapStep (no lost tap occurred); the seeder's second attempt (no "UITestSeeder failed" line in this run)
REVIEWED_AT: 8d036e047950b6ae2f7eaeb8d1818ef823a3a69a
```

## Fix round 2
Round 1 failed M1: the idle stall after the landscape rotation made testBarValueIsReadAfterTheBarHidLandscape fail. S1 (About launches twice) and S2 (the subtitles-menu test races the auto-hide) are also open. Brent's decisions (2026-11-23):
- **Switch to Opus:** a fresh builder reads this whole file.
- **Find the cause, with a guard as fallback.** First hunt for the animation (or other work) that keeps XCTest's "animations idle" request unanswered after the first rotation. It starts within about 1 s, in a paused player; PlayerView.swift:91-118 are the candidates. Fix it if found. If it's a real app animation loop, fixing it is allowed product code, because it also helps the device. Also add a test-setup stall guard in UITestSupport: if the first action after rotating to landscape takes more than about 50 s, terminate, relaunch once and log it clearly, so the stall shows in the logs and isn't hidden. Record which of the two actually fired in CI.
- Fix S1 and S2. C1–C3 are optional.

## Implementation notes (round 2) · opus
_by loop-backend · 2026-11-23 02:31_

**M1, the idle stall: what I found**
- **The app log (pid 17274, 45119953687 shard 1), lined up with the test's steps:**
  - The rotation's own idle request was answered at 05:57:53.711.
  - XCTest then logged "Unexpectedly received animationDidStop without a matching animationDidStart" twice (53.711, 53.725).
  - The next request (05:57:54.806, before the first video tap) was never answered for the rest of the process. "Main run loop idle" replies kept coming the whole time, so the app was not busy.
- **Mechanism:**
  - XCTest's in-app idle notifier counts `UIViewAnimationState` `animationDidStart`/`animationDidStop` callbacks, that is, UIKit animations. Sources: its own log lines, and public reports of the same 60 s stall (github.com/mhismail3/tron issue 2325; github.com/dennisfriedrichsen/xsky-ios issue 38, where a text caret's blink animation "stranded" on a field was the cause).
  - So a stall is one UIView animation that started but never reported a stop. It is not an animation loop.
- **Across all 25 saved xcresults (T-018 r1 to T-034 r1; script `stallscan.py`):**
  - 375 rotations to landscape, 6 stalls (1.6 %). Every stall begins at a portrait-to-landscape rotation of the player: inside the rotation's own wait (1, T-020 r2) or at the first action after it (5).
  - 2 of the 6 came after portrait actions (testScreenshotsLight, 10.9 s after the episode tap; the second rotation of testPanelClosesAndSurvivesRotation). So the push into the player is not the trigger.
  - The other "stalls" in setUp/Tear Down (testUpAndSize…, testSkipRestartsTheCountdownLandscape) are carry-overs: a stalled process from the previous test.
  - In 45119953687 only pid 17274 really stalled. The single "unanswered" requests in other pids are interleaved log lines (`idlemap.py`).
- **Ruled out as the cause:**
  - an app animation loop: no repeatForever, TimelineView, Timer or CADisplayLink. The stall outlives playback and the clip's end, and the run loop idles throughout;
  - the seed spinner: its removal never stalled a launch;
  - the push timing: see above;
  - every `-uiTesting` setting: they touch defaults, panel width, style and the store.
- **Candidates I could not tell apart from code and logs** (all are UIKit animations started by the rotation in the player, PlayerView.swift:76-118):
  - the GeometryReader swaps the portrait subtree for the landscape one. That removes UIKit-backed views (the `SelectableText` UITextView line, UISlider, the AVPlayerLayer view, the cue scroll view) while the rotation's animations may still be running;
  - the `isLandscape` flip one update later hides the navigation bar (`.toolbar(.hidden)`) and the status bar, and changes `persistentSystemOverlays`, while the rotation animates.
- **Confidence:**
  - high that it is a stranded UIKit animation from the rotation, counted by XCTest's notifier;
  - medium on the notifier's internals, which come from public reports;
  - low on which view.
- **So I did not change product code.** A guess would risk visible behaviour, and at 1.6 % a single CI run could not show it worked (P(no stall | unchanged) is about 0.2 per run).

**M1: what I built**
- `UITestSupport.rotateToLandscape(app, reopen:)` (ios/ClipDeckUITests/UITestSupport.swift) is the test-setup stall guard Brent asked for.
  - It rotates, waits for `player.video`, settles 1 s, then sets the same orientation again as a probe. That step does nothing in the app except XCTest's wait for idle: 0.01 s with one "Wait for idle" in testPanelHandleResizesRemembersAndResets (45119953687 shard 3, +36.10 s), and 60 s on a stalled app.
  - If the rotation or the probe takes more than 50 s: it logs, terminates the app, sets portrait, runs `reopen` (default `launchAndOpenSampleEpisode`, same launch arguments), and rotates and probes once more. If the rotation itself stalled, it skips the probe, which saves 60 s.
  - It relaunches only once. A second stall is logged and the test goes on.
  - Why a probe and not each test's own first action: the first action differs per test, and a relaunch after it would redo test steps. The probe sits at the same point (about 1-2 s after the rotation) where all 6 observed stalls had already started, and costs about 1-1.5 s per guarded setup (about 50 per full run, roughly 1 min across the shards).
- **Used in every setup rotation of the player:**
  - PlaybackOverlayUITests.openSample, PlaybackOverlayTesterUITests.openSample;
  - PlayerLandscapeBehaviourUITests (7 tests);
  - PlayerLandscapeUITests (2 tests + launchWithPanelOpen; on its keep-width relaunch the device is already landscape, so only the probe runs);
  - the launchLandscape helpers of SubtitleStyleCardTester, SubtitleStyleCard and SubtitleUpLimitTester;
  - SubtitleStyleTesterUITests:36, SubtitleStyleUITests.landscapeFrames.
- **Left as plain rotations** (the state before them matters, so a relaunch would change the test): PlaybackOverlayUITests:191, PlaybackOverlayTesterUITests:201 and :250, PlayerLandscapeBehaviourUITests:208 and :222, SubtitleStyleCardUITests:158, and the library rotation PlayerLandscapeUITests:250. A stall there still costs time; none of these checks a 3 s state after the rotation, except testScreenshotsLight's playing screenshot, which asserts nothing.
- **Logging when the guard fires:**
  - an activity "Idle stall guard fired: … (rotation X s, probe Y s (limit 50.0 s)); terminating and relaunching it once";
  - then "Idle stall guard: no stall after the relaunch (…)" or "…stalled again after the relaunch…";
  - each with an attachment `idle-stall-guard` (the summary, then `app.debugDescription`) and a "UITestSupport: …" line on the runner's stdout.
- **scripts/test-ios.sh** reads the exported attachments' manifest.json and prints `::warning title=UI test idle stall::<test>: <summary>` for each one, so it shows on the run page. It is wrapped in `|| true`, so the exit status never changes. Checked locally: `bash -n`; the snippet prints nothing on 45119953687's real manifest, one warning per guard attachment on a synthetic one (with a fallback text when the file is missing), and survives a broken manifest.
- **Diagnostic for the cause:** `UITestAnimationWatch` (new, ios/ClipDeck/App/UITestAnimationWatch.swift, `#if DEBUG`, started in `ClipDeckApp.init` only with `-uiTesting`).
  - Every 2 s it walks all windows' layer trees and prints, once each (at most 40 per process), any animation that has stayed on a layer for 3 s or more.
  - Each line gives the view-class path, layer class, accessibility id, key/keyPath, animation class, duration, repeat, begin time against layer time, effective speed, hidden state and delegate class.
  - It only reads and prints; Release builds don't contain it.

**How the tester can tell from CI what fired**
- **The cause fix:** not applied this round, so nothing to see.
- **The guard:** a "UI test idle stall" warning on the run page (`gh run view <id>` lists annotations), and in the xcresult an "Idle stall guard" activity (`steps.py <db> . "Idle stall guard"`). A healthy run has none.
- **A stall the guard didn't cover** (mid-test rotation, or one that started after the probe): `stallscan.py %TEMP%\clip-deck-loop` lists "App animations complete notification not received" steps per test with the 4 steps before.
- **The watch:**
  - In the app stdout (`appstdout.mjs`), every `-uiTesting` launch prints "UITestAnimationWatch: started". A slow seed adds one spinner line, which proves the watch runs.
  - Near a stall, a line with `delegate UIViewAnimationState` names the stuck animation.
  - No line means the stranded animation's layer has left every window, which supports the view-swap theory. In that case the next step is to keep PlayerView's video subtree identity stable across the rotation, or to defer the `isLandscape` changes until the rotation ends.

**S1:** removed the three `app.launch()` calls (AboutUITests :8, :36, :78); `openAbout` is the only launch, and its comment says so.

**S2:** testOpenSubtitlesMenuKeepsControlsUpWhilePlaying now opens the dialog through `openSubtitlesDialogWhilePlaying`.
- If `player.subtitlesMenu` is gone (the bar auto-hid during a slow Play tap), a video tap brings it back (the 30 s clip keeps playing), polled every 0.05 s for up to 3 s.
- The menu is tapped at the frame just read from one snapshot. A bar that hides between the read and the tap costs one try (that tap lands on the video and shows the bar again) instead of failing on a missing element. At most 3 tries.
- Each try first checks whether the dialog is already open, so a dialog that a lagging snapshot missed is never tapped away.
- Removed assertion: `XCTAssertTrue(menu.waitForExistence(timeout: 2))`, a precondition the helper now handles. The checks the test is for are unchanged: the dialog opens ("Menu opens and stays open while playing"), the bar is up, the bar stays 3.5 s, and the dialog stays. I reworded the comment on why the 3.5 s check still catches a broken keep-up rule: the countdown last restarted before the dialog opened, at Play or at the re-show.

**C1:** testPanelStaysOpenWhenControlsAutoHide uses `sampleSeconds: 20`.

**C2, C3:** not done. C2 matters less now that setup stalls relaunch. `settle` and `launchAndOpenSampleEpisode` now have a user (the guard); `attachText`/`attachScreenshot` are still unused.

**Files**
- ios/ClipDeckUITests/UITestSupport.swift, AboutUITests.swift, PlayerLandscapeBehaviourUITests.swift, PlaybackOverlayUITests.swift, PlaybackOverlayTesterUITests.swift, PlayerLandscapeUITests.swift, SubtitleStyleCardTesterUITests.swift, SubtitleStyleCardUITests.swift, SubtitleStyleTesterUITests.swift, SubtitleStyleUITests.swift, SubtitleUpLimitTesterUITests.swift;
- ios/ClipDeck/App/UITestAnimationWatch.swift (new), ios/ClipDeck/App/ClipDeckApp.swift;
- scripts/test-ios.sh, docs/DEVELOPMENT.md (Tests), CLAUDE.md;
- .loop/CONTEXT.md (+1 Learned).
- The new app file is under `ios/ClipDeck`, which XcodeGen picks up (project.yml `sources: ClipDeck`).

**Checks**
- Local: `bash -n scripts/test-ios.sh` passes, and the warning snippet behaved as above.
- AC-4: the UI test function names at HEAD and in the working tree are the same 86, the 289 `@Test` are unchanged, ClipDeckTests is untouched, and there are still 3 XCTSkip, as before.
- Swift was not compiled (CI only).

**Tester, look at:**
- **Compile risks:**
  - `XCTContext.runActivity { activity in activity.add(...) }` in `@MainActor` code;
  - the `(@MainActor () -> Void)?` reopen parameter;
  - `try? menu.snapshot().frame`;
  - UITestAnimationWatch's `Task` loop, `for case let scene as UIWindowScene`, `animation.delegate.map { type(of: $0) }`, and `ContinuousClock.Instant` arithmetic under MainActor default isolation.
- **Timing:** every guarded landscape setup now has one extra "Setting device orientation to Landscape Left" step of about 0.01-0.5 s after a 1 s settle. Shard times should rise by about 0.5 min each at most.
- **If the guard fires:** check that the relaunched test passed on sound state (fresh process, paused at 0:00), and read the UITestAnimationWatch lines around the stall.

## Test report (round 2)
_by loop-tester · 2026-11-23 03:11_

CI 45132085072 (scope=all, 04ceed0, CI run 2 of 4) is **green**: ipa 2:11, shard 1 23:23 (355/355), shard 2 28:07 (29/29), shard 3 21:30 (28/28), 0 test issues, 0 build issues. Evidence is in %TEMP%\clip-deck-loop\T-034-r2: Data/ pruned, 29 MB. It holds the filtered app logs `app-watch-idle-shard<n>.txt` and `app-watch-only-shard<n>.txt`, the gzipped full app stdout, the job logs and the IPA. New script: `probes.py` in tools-T-034.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 Shared helpers in the UI test target (for example `ios/ClipDeckUITests/UITestSupport.swift`): launching with the seeded library (one generous, state-based wait), opening the sample episode, waiting for a label/value/frame, "tap until a state holds" (re-tap only after waiting for the state, and only while the button still exists and is hittable), and the existing settle and evidence helpers. The 15 copies of the 30 s "Seeded show should appear" wait in 11 classes use the shared launch helper. | Pass | Same as round 1, recompiled and run in all 3 shards. 83 seeded waits: median 1.2 s, p90 3.4 s, max 17.0 s, so `launchSeeded`'s relaunch was not needed. Tests that wait 2–3 times relaunch by design (keep-flag tests, two frames). `rotateToLandscape` is added (see AC-3). |
| AC-2 the seeded library not appearing in time | Pass | 83/83 seeds appeared (max 17.0 s); no "UITestSeeder failed" line in any shard's app stdout. Cause confirmed in round 1. |
| AC-2 `EpisodeImporterTests/copiesAnMP4AndItsSubtitleIntoTheShowFolders` (".timedOut") and `ClipExtractorTests/cutsExactAudioAndScreenshot` (timeout) | Pass | Both passed (1.7 s, 0.7 s). The cause was removed in code in round 1 (60 s deadline). |
| AC-2 `SubtitleStyleCardTesterUITests/testUpDisablesWhenTheLineCanNoLongerMoveUp` (a lost Up tap) | Pass | Passed (48.4 s). Up taps equal steps (13 + 19 = 32 across the two lost-tap tests), so no re-tap was needed. |
| AC-2 `SubtitleUpLimitTesterUITests/testUpDimsExactlyWhenTheLineReachesTheTopBarWithTwoAndThreeRowCards` (a lost Done tap) | Pass | Passed (86.6 s); 4 Done taps for 4 closes. |
| AC-2 `AboutUITests/testAboutShowsVersionAndNoticeTextIntact` (a slow VM) and `testSourceLinksAreShownAndOpenInSafari` (Safari slow to launch) | Pass | All 3 About tests passed (74.1 / 101.5 / 116.1 s) on a slow VM (one launch took 30.5 s). S1 is fixed: each test has exactly one "Open dev.brent.clipdeck" at the start. The Safari test's second Open is its own `app.activate()`. |
| AC-2 `PlayerLandscapeBehaviourUITests/testControlsStayWhilePausedAndAutoHideWhilePlaying` and `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying` (the 6 s clip ends before the check), plus T-021's new overlay timing tests, which have the same clip problem. | Pass | Both passed (49.5 s, 27.7 s). On the 20 s clip the bar came back on its own 20.9 s after Play, so the end-of-clip check still means something. S2: the menu was tapped by coordinate 1.0 s after Play started and the dialog appeared 1.2 s later. The bar was still up, so the re-show branch did not run. All 7 PlaybackOverlayUITests landscape tests passed, including round 1's failure testBarValueIsReadAfterTheBarHidLandscape (23.7 s), plus the 3 Tester countdown/skip tests. No stall happened in this run, so these passes do not exercise the guard. |
| AC-3 The 60 s "wait for app to idle" stall is investigated. Fix it at its cause if that's in test code or in a `-uiTesting`-only setting. Otherwise record what you ruled out and add a CONTEXT "Learned" line. The stalled tests passed, so the stall costs time, not a red run. | Pass (on its wording) | Investigated and narrowed: XCTest's UIViewAnimationState ledger, one UIKit animation from the portrait-to-landscape player rotation that never reports a stop. I reproduced the survey: stallscan gives 375 rotations and 6 stalls. The cause is in UIKit/app view code, not in test code or a `-uiTesting` setting, so the AC's "otherwise" branch applies. The ruled-out list is in the notes and the Learned lines are in CONTEXT (working tree). Not met: Brent's first preference (find and fix the cause). His fallback, the guard, is built. **Neither fired in this run:** no stall occurred (0 "App animations complete notification not received" steps, 0 "Idle stall guard" activities, 0 `idle-stall-guard` attachments, 0 "UITestSupport:" lines, no "UI test idle stall" annotation). Guard checked by trace and run: all 40 probes took 0.01–0.38 s (limit 50 s), so there were no false positives. Each probe has the child "Wait for dev.brent.clipdeck to idle", the same child that held the 60 s timeout in stalled orientation steps (round 1 Tear Down, T-020 r3 setUp). The probe sends a real animations-idle request 2.1 s after the rotation's reply (app log 07:55:29.866 vs 27.739). The terminate/relaunch branch has never run. The AC's premise "costs time, not a red run" was disproven in round 1; the guard is what should make it true again. |
| AC-4 No test loses meaning. Nothing is deleted, skipped or renamed, and no assertion is weakened without saying so in your notes. The run executes the same set of tests as the T-021 landing run (at least 390, plus T-021's), checked by test-name sets from the xcresults of all three shards. | Pass | The name union of the 3 shards is 375 and **identical** to the landing set. I rebuilt the baseline independently from 45110218499's three databases (375), minus testScreenshotsDark, plus testBarValueIsReadAfterTheBarHidLandscape. It also equals round 1's expected file. Runs: 355 + 29 + 28 = 412. XCTSkip 3, test functions and @Test 289 are the same at base and HEAD. The only assertion removed this round is `XCTAssertTrue(menu.waitForExistence(timeout: 2))` (S2), and the notes declare it. |
| AC-5 One green `scope=all` run: every shard and the ipa job. A re-run of only the failed job (`gh run rerun <id> --failed`) counts for proof, but if a test hardened here fails in either attempt, that's a Fail. docs/DEVELOPMENT.md (Tests) describes the helpers, and a CONTEXT "Learned" line records what was hardened. | Pass | 45132085072: all 5 jobs succeeded on the first attempt, no re-run. DEVELOPMENT.md:141-170 describes the helpers and the guard (but see C1 on the watch wording). The CONTEXT Learned lines (hardening, stall) are in the working tree; the orchestrator commits them. |

**Release and DEBUG:** the ipa job is green. ClipDeck.ipa's Release binary (1,817,816 bytes) contains 0 occurrences of "UITestAnimationWatch" and of its message text ("on its layer for at least"), and 0 of UITestSeeder/TestMediaFactory. Control strings are present. In DEBUG, every `-uiTesting` app process printed "UITestAnimationWatch: started" (30/33/34 per shard).

**UITestAnimationWatch output:** 442 lines. 436 are iOS 26 Liquid Glass "match" animations (CAMatchPropertyAnimation/CAMatchMoveAnimation, duration inf, delegate none) on the glass bar elements "Clip Deck", "Episode 1", "Anki settings", "About and licences", "Sync to Anki" and `library.tabs`. 4 are spinner animations. 2 are `delegate UIViewAnimationState`: a navigation push (UINavigationTransitionView > UIViewControllerWrapperView > UIView, keys `UIPacingAnimationForAnimatorsKey` and `position`, duration 0.35 s) still on its layer 3.5 s after it began. That was in PlaybackOverlayUITests/testBarHasNoSkipButtonsLandscape during a 20 s main-thread block ("is blocking its subgraph for 20.11 seconds"; the episode tap took 23.7 s). It cleared, and XCTest got its animations-idle reply at 07:40:30.6, so this was a slow-VM freeze, not the stall. It shows the watch can name an overdue animation of the kind XCTest counts. The stuck animation itself has not been seen yet. Also seen: "Unexpectedly received animationDidStop without a matching animationDidStart" follows every rotation in every process (278–367 lines per shard), healthy ones included, so it is not a stall signature.

**Shard times:** jobs 23:23 / 28:07 / 21:30, all under 35 min (shard 2 has the least headroom, 6.9 min). The sums of test time are 16.2 / 19.9 / 14.8 min against 21.1 / 19.5 / 14.9 in round 1, whose shard 1 included the 5.5 min stalled test. The guard costs a median 2.08 s per guarded setup (40 setups, 84 s per run), more than the 1–1.5 s in the notes, because the guard's own wait for `player.video` and the caller's own wait each take about 1.05 s.

**Round 1 findings:**
- M1: addressed by the guard in all 17 setup rotations. The failing test passed, but there was no stall to test the guard against (see AC-3).
- S1: fixed (Ran it).
- S2: fixed. The new path ran; its re-show branch did not.
- C1: done.
- C2: not done (optional). It still applies to stalls at unguarded rotations.
- C3: partly. `settle` and `launchAndOpenSampleEpisode` are used now; `attachText`/`attachScreenshot` are still unused.
- Round 1's pre-existing ExpiryBanner launch failure passed this time.

Revert check: not done. No test was added. The guard's fire path depends on a stall that a test file can't cause, and the guard has no seam to inject a slow probe without changing the code under test.

### Findings

Could fix C1
Where: ios/ClipDeck/App/UITestAnimationWatch.swift:65-80, docs/DEVELOPMENT.md:167-170, CONTEXT "Learned" (T-034 round 2 line)
Problem: the watch reports the permanent iOS 26 Liquid Glass match animations (duration inf, no delegate). They are 436 of its 442 lines, up to 29 of the 40-line budget per process, and the loop stops at 40. The docs say "No line near a stall means the animation XCTest waits for is no longer on a layer", but glass lines appear in every process that has gone past the library, so that reading no longer works.
Proof: Ran it. 45132085072 app stdout, counted in app-watch-only-shard<n>.txt.
Trigger: a stall in a process that already used most of its 40 lines, or a reader following the doc.
Fix: skip animations with an infinite duration and no delegate (or report only those past `beginTime + duration × repeat`), and reword the doc and Learned line to "no `delegate UIViewAnimationState` line".

Could fix C2
Where: PlaybackOverlayTesterUITests.swift:201 and :250, PlayerLandscapeBehaviourUITests.swift:208 and :222, SubtitleStyleCardUITests.swift:158, PlaybackOverlayUITests.swift:191, PlayerLandscapeUITests.swift:250
Problem: 2 of the 6 historical stalls hit rotations the guard leaves plain: T-019 r1 testPanelClosesAndSurvivesRotation's second rotation, and T-021 r2 testScreenshotsLight at 401 s. I read each spot. None checks a 3 s playing state after the rotation (the checks are paused-state or existence checks; testScreenshotsLight's playing shot asserts nothing), so a stall there costs 2–7 min, not a red run.
Proof: Traced it (stallscan over 25 xcresults, plus the code above).
Trigger: a stall at a mid-test rotation.
Fix: round 1's C2 (terminate the app at the start of tearDown) caps the carry-over. A guarded variant that only logs (no relaunch) would at least make these stalls visible.

```text
VERDICT: Pass
SPEC: AC-1 met; AC-2 met (every listed flake passed, round 1's failing overlay test included); AC-3 met on its wording (cause narrowed to a UIKit UIView animation from the rotation, not in test code or a -uiTesting setting; ruled-out list and Learned lines; not fixed at its cause; the guard and the watch are built, and neither the cause fix nor the guard fired because no stall occurred); AC-4 met (375/375 names, 412 runs); AC-5 met (45132085072 green first attempt; docs describe the helpers)
CHECKS_RUN: CI 45132085072 scope=all on 04ceed0 (CI run 2 of 4): ipa success 2:11 (build-ipa.sh); shard 1 success 23:23 (test-ios.sh 355/355, run-ios.sh launch screenshot OK); shard 2 success 28:07 (29/29); shard 3 success 21:30 (28/28); 0 test issues, 0 build issues. Locally: bash -n scripts/test-ios.sh OK; its warning snippet run on synthetic manifests (one warning per guard attachment, fallback text for a missing file, non-zero on a broken manifest, masked by `|| true`). No other local build (ci_only)
UNVERIFIED: the guard's terminate/relaunch branch and its GitHub warning (no stall in this run; ~1.6 % of rotations stall, so a later full run will likely exercise it: look for a "UI test idle stall" annotation); whether a stall can start after the probe (~2 s after the rotation; round 1's started within 1.1 s); the re-tap branches of tap(_:until:)/tapStep and S2's re-show branch (no lost tap or slow Play tap occurred)
REVIEWED_AT: 04ceed087b8be5c6a2449d08adb13a129f144a38
```
