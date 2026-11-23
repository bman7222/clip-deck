---
id: T-034
title: Harden the known flaky tests
lane: backend
depends_on: [T-021]
status: todo
round: 0
base_sha:
issue: 39
spec: .loop/specs/player-lookup-timeline.md
model:
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
