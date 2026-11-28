# Context: clip-deck

Offline iPhone video player for language learners (like asbplayer): watch your own episodes with SRT/ASS
subtitles, turn a subtitle line into an Anki card (audio clip, screenshot, sentence), sync cards to desktop Anki via AnkiConnect.

## Stack
- SwiftUI, iOS 17.0+, Swift 6 (MainActor default isolation), SwiftData, AVFoundation, XcodeGen. No backend.
- Tests: Swift Testing (unit, `ios/ClipDeckTests`), XCUITest (`ios/ClipDeckUITests`).

## Where things live
- `ios/project.yml` — source of truth; `.xcodeproj` is generated (`cd ios && xcodegen generate`). Never edit the .xcodeproj.
- `ios/ClipDeck/Features/<Feature>/` — View + `@Observable` model (Library, Player, CardEditor, Sync, Settings)
- `ios/ClipDeck/Services/` — Subtitles, Media, Anki, `FileStore.swift`; `Models/` — SwiftData (Show, Episode, PendingCard)
- `ios/ClipDeck/DesignSystem/` — colours, type, tiles, buttons
- `scripts/` — bootstrap, run-ios, test-ios, build-ipa; `.github/workflows/ios-simulator.yml` — CI

## Commands (run only on macOS / CI)
- Test: `./scripts/test-ios.sh` · Run + screenshot: `./scripts/run-ios.sh` · Unsigned IPA: `./scripts/build-ipa.sh`

## Conventions that matter
- Every interactive element gets `accessibilityIdentifier` named `feature.element`.
- SwiftData file paths are relative to Documents (`FileStore`); never store absolute paths.
- Card media names fixed per card (`CardMediaNames`) so Sync retries are idempotent.
- `-uiTesting` launch arg: in-memory library + generated "Sample Show"; `-uiTestingNoSeed` skips the sample.
- No secrets in app code or xcconfig. Mock data only in tests or behind a documented switch.
- After adding files: they must be picked up by XcodeGen (check `project.yml` sources).

## How to verify
- Brent is on Windows with no Mac. Nothing Swift can be compiled locally.
- CI: push the loop branch, then `gh workflow run ios-simulator.yml --ref <branch>` (push alone doesn't trigger it on non-main branches).
  Watch with `gh run watch`, read `--log-failed`, download `simulator-results-1`/`-2`/`-3` (screenshots, xcresult) and `ClipDeck-ipa`.
- Only Brent can check: real iPhone install via Sideloadly, real video import from Files, sync with desktop Anki.

## Full docs
- `CLAUDE.md`, `README.md`, `docs/ARCHITECTURE.md`, `docs/DESIGN.md`, `docs/PRODUCT_SPEC.md`, `docs/DEVELOPMENT.md`

## Learned
<!-- Agents append one-line facts here that the next agent needs. -->
- iOS 26: tap gestures attached to a SwiftUI Menu (and simultaneousGesture on bars) don't fire; use Button + confirmationDialog when you need to know a menu is open.
- XCUITest `app.screenshot()` in landscape comes out rotated and cropped to about 400 pt; check layout from the xcresult UI hierarchy and the screen recording.
- `ClipExtractorTests.cutsExactAudioAndScreenshot` can time out on CI (pre-existing flake); `gh run rerun <id> --failed` once before treating it as a failure.
- Landscape UI evidence: `XCUIElement.screenshot()` of a single element comes out unrotated and correct, and attaching `app.debugDescription` as text records every element's frame. Use these instead of `app.screenshot()`.
- Landscape panel width rule (Brent): panel content = max(25% of the usable width, 180 pt) + trailing inset, where usable width = full width − both insets. Panel rows are compact (time above the text).
- CI's "Upload screenshots and test results" step can fail with a GitHub `CreateArtifact ... Request timeout`. That is infrastructure, not code: re-dispatch the workflow (the tests themselves passed if test-ios printed "Tests passed").
- XCUITest on iOS 26: a List row's label and value are one StaticText ("Clip Deck, 0.1.0"). `XCUIElement.screenshot()` of a very tall Text fails with "Rendering screen failed"; use `app.screenshot()` there.
- FFmpeg: use `FFmpegInspector` (Services/Media) as the only libav* entry point. Test fixtures come from `scripts/make-test-media.sh` into build/fixtures (env CLIPDECK_FIXTURES / TEST_RUNNER_CLIPDECK_FIXTURES).
- Known UI-test flakes on CI (lost taps or timing; seen in 44750491956): AboutUITests/testAboutShowsVersionAndNoticeTextIntact, PlayerLandscapeBehaviourUITests/testControlsStayWhilePausedAndAutoHideWhilePlaying, and …/testOpenSubtitlesMenuKeepsControlsUpWhilePlaying. Re-check them in the next needed run before treating one as a failure.
- Runner flake: AboutUITests/testSourceLinksAreShownAndOpenInSafari can fail when Safari never launches on the CI simulator ("Application 'com.apple.mobilesafari' ... does not exist"; seen in 44860511457, passed on unchanged app code in 44863556968). Re-run before treating it as a failure.
- Video import: always go through `EpisodeImporter` (and `VideoImportModel` in the UI). It owns staging, the coordinated read, rollback and the subtitle copy.
- Releases: `git tag vX.Y.Z && git push origin vX.Y.Z` runs release.yml (IPA + SHA-256 + apps.json for the SideStore source). Versions with a suffix are pre-releases and are left out of the source. A release is never overwritten; to redo one, use a new version.
- Unit-test flake: EpisodeImporterTests/copiesAnMP4AndItsSubtitleIntoTheShowFolders() can fail on CI with "Caught error: .timedOut" (main 44838534920; T-015 run 44878628011, where the diff doesn't touch importing). Re-check it in the next needed run before treating it as a failure.
- XCUITest reports an `.accessibilityElement(children: .contain)` container's frame as the union of its children, not its layout frame. To find a sheet's top, use the innermost element that `containing(.any, identifier:)` the container (T-015 round 3, CI 44893660834).
- UI-test flake: a test can fail at "Seeded show should appear" when the generated sample episode isn't ready in time on CI (seen in SubtitleStyleSheetTesterUITests/testEveryLimitDisablesItsOwnButton, 44953847701). Re-check it in the next needed run.
- iOS 26 UIFontPickerViewController ("Choose Font", a remote view) has no "Cancel": its dismiss button is an X labelled `close`; it does have a SearchField "Search" (CI 44957727655).
- Swift Testing: `#expect(value.mutatingCall())` doesn't compile ("'$0' is immutable"); read the result into a `let` first (T-016, CI 44971851033).
- Fonts: `UIFontDescriptor.symbolicTraits.contains(.traitBold)` is false for ArialRoundedMTBold, so test boldness by the weight trait or the face name (T-016, CI 44972664549). The landscape style card has a background, so XCUITest reports its real frame, not a union.
- The portrait style sheet: SubtitleStyleSheet(clearance:) sizes its first detent from the room under the video and self-corrects via SheetFit (rise cached in player.styleSheetRise). T-016/T-017 callers must pass the clearance.
- CI headroom: the full simulator suite took 44:21 against `timeout-minutes: 45` (44972664549). In 44976839046 one UI test hung (the app never reported "animations idle", so every action waited 60 s) and the job was cancelled with 15 tests unrun. Split the UI target into its own run (`only_testing=ClipDeckUITests`) when the unit target is already green.
- Fonts: on iOS 26.5 ArialRoundedMTBold reports weight trait 0.0 and no traitBold ("font-weight: normal"); it is bold only by its name, so a "trust the weight trait" rule breaks it (T-018, CI 44997338718).
- CI headroom (timeout now 60 min): the full simulator suite of 390 tests took 46 min in 45002423211 (T-018 round 2).
- CI headroom: in 45055876049 (T-019, scope=all, same 390 tests) testing took 53 min and the simulator job 57 of its 60 min. Split ClipDeckTests and ClipDeckUITests into separate runs before a full run times out.
- UI-test flake: SubtitleStyleCardTesterUITests/testUpDisablesWhenTheLineCanNoLongerMoveUp can lose an Up tap on CI ("Up tap 7 moves the line", 45055876049). In the recording the line never moved and Up stayed enabled, and the diff was only the icon PNG. Re-check it in the next needed run.
- The "Seeded show should appear" flake also hit SubtitleStyleCardTesterUITests/testFirstDownTapMovesTheLineWhenTheStoredPlaceIsAboveTheClamp in 45069006816. The runner was slow: launches took up to 31 s, and the library was still empty after 66 s. It passed on the same SHA in 45055876049.
- CI (T-020): jobs `plan`, `simulator (shard 1)` (ClipDeckTests + listed UI classes + launch screenshot), `simulator (shard 2)` (listed UI classes), `simulator (shard 3)` (everything else), `ipa`. Artifacts `simulator-results-1`, `-2`, `-3`, `ClipDeck-ipa` (download with `-p "simulator-results*"`). With only_testing there is only shard 1.
- CI runner speed varies a lot: in 45070921716 (T-020) one macOS VM needed 12 min from xcodebuild start to the first UI test (the other 5.8) and ran UI tests ×1.22 slower than 45002423211; 45055876049 ran them ×1.34. Leave headroom when judging job times.
- CI (T-020, three shards, 45083671012): shard 1 20:23, shard 2 28:28 (8.6 min of it was one test's 60 s "wait for idle" stalls), shard 3 27:41. New UI classes land in shard 3; when it nears 35 min, move classes into SHARD1_UI (most headroom).
- Slow-runner freeze (45094204439 shard 1, T-021): on a bad VM the app's UI froze for the whole playback. In the recording the elapsed label stayed put while the video layer kept playing, the post-tap "wait for idle" took 6–15 s and snapshots took 4+ s, and 3 consecutive tests in one 2-minute window failed. Any check that needs the "playing" state of the 6 s clip can hit this.
- Windows triage of an xcresult without xcresulttool: `database.sqlite3` has the failure text and line (TestIssues → TestCaseRuns → TestCases) and every step's start and finish (Activities). Recording frames: Node 26's built-in WebSocket can drive headless Chrome over CDP (seek a `<video>`, draw it to a canvas).
- Flake root cause: PlayerLandscapeBehaviourUITests/testControlsStayWhilePausedAndAutoHideWhilePlaying fails ("Playing: controls hide on their own") when the Play tap takes about 6 s on a slow VM. The 6-s sample plays to its end and stops, and the controls come back (slider 6,000, button "Play"; 45087727557 shard 2). It passed on the same shard filter in 45083671012.
- XCUITest timing: the first check of a `waitForExistence` or XCTNSPredicateExpectation wait comes about 1.0 s after the wait starts (45110218499). A check of something that auto-hides 3 s after Play (the landscape bars, the overlay) only has about 1.6 s of slack for the tap's own "wait for idle".
- Dark mode in UI tests: setting `XCUIDevice.appearance` to dark through KVC logs its step, but the CI simulator stays light (black status bar, light fills; 45110218499). For dark evidence, set it from the workflow with `xcrun simctl ui <udid> appearance dark`.
- `-uiTestingSampleSeconds 30` (T-021) adds 2–6 s to the "Seeded show should appear" wait (at most 7.2 of 30 s in 45110218499). The 60 s idle stall can still outlast a 30 s clip (testScreenshotsLight, 401 s, the clip reached 0:30.0).
- Cold-start flake in targeted runs: with only_testing, the first tests run on a freshly booted simulator. In 45114494368 (T-021) the first 3 tests failed at launch, with launches of 4–55 s: "Seeded show should appear" twice (the library was still empty after the wait, also with the 6 s clip) and "Failed to get background assertion for target app" once. Every seed after them worked (1.1–9.5 s). Treat these as pre-existing (T-034 scope).
- UI-test hardening (T-034): use `UITestSupport` (ios/ClipDeckUITests) for every launch, wait and retried tap (`launchSeeded`, `tap(_:until:)`, `tapStep`, `readTogether`); never add a raw "Seeded show should appear" wait. Tests that play video use `-uiTestingSampleSeconds` 20/30. `TestMediaFactory.waitUntilReady` is now a 60 s deadline (was 1,000 x 5 ms, about 5 s) and the seeder retries once. The earlier flake lines above are addressed; if one returns, check CI first against these helpers.
- The 60 s "wait for idle" stall (T-034, from the xcresults of T-019-r1, T-020-r2/r3, T-021-r2): every stalled test loses 2 x 60 s on each action after `orientation = .landscapeLeft` on the player (Tap Target Application, Tap button, set orientation, Tear Down: 120.6/120.8 s or 60.4 s each), also in tests that never play. Ruled out in the app code: no repeatForever/TimelineView/Timer/CADisplayLink; the 20 Hz time observer only fires during playback. Cause not found; it is not in test code. Costs time, not a red run.
- The xcresult has the app's stdout (Windows, no xcresulttool): one Data blob is a JSON list of Diagnostics files (`StandardOutputAndStandardError-dev.brent.clipdeck.txt`, Session-*.log). Its `refs.0~` file maps each name to a zstd `data.0~` blob (a count byte, then [0x41][0x00][64-byte hash] → base64url); Node 26 `zlib.zstdDecompressSync` reads it (T-034, 45119953687).
- Idle stall, corrected (T-034 round 1, 45119953687): the main run loop keeps reporting idle, but the first "animations idle" request about 1-2 s after `orientation = .landscapeLeft` is never answered for the rest of that app process. It can make a red run: testBarValueIsReadAfterTheBarHidLandscape failed because the 30 s clip ended during the Play tap's 60 s idle wait.
- Idle stall (T-034 round 2): XCTest's in-app notifier counts `UIViewAnimationState` animationDidStart/animationDidStop, so a stall is one UIView animation whose stop never comes (6 of 375 portrait-to-landscape player rotations in 25 xcresults; the view is not known yet). Setup rotations use `UITestSupport.rotateToLandscape`: setting the same orientation again is a pure idle-wait probe (under 1 s, or 60 s when stalled), and it relaunches once. When it fires: GitHub warning "UI test idle stall", activity "Idle stall guard…", attachment `idle-stall-guard`. The app's "UITestAnimationWatch:" stdout lines name any animation stuck on a layer. Scans: `stallscan.py`, `idlemap.py` in %TEMP%\clip-deck-loop\tools-T-034.
- Reading UITestAnimationWatch (T-034 round 2, 45132085072): 436 of its 442 lines were iOS 26 Liquid Glass "match" animations (CAMatchPropertyAnimation/CAMatchMoveAnimation, duration inf, delegate none) on glass bar items. They are permanent noise; search for `delegate UIViewAnimationState` instead. "Unexpectedly received animationDidStop without a matching animationDidStart" follows every rotation, healthy ones too, so it is not a stall sign. idlemap.py flags a few false "unanswered" requests, which have replies 0–0.8 s later; check the raw log.
- Landscape taps in UI tests: on the iPhone 17 Pro simulator, a tap within about 50 pt of the leading edge at mid-height lands on the Dynamic Island and never reaches the app (T-022, 45137420681: 6 % of the 624.7 pt panel-open column = x 37.5). Synthesized-event attachments are bplists with the device point. Tap at x >= 65 pt.
- Idle-stall guard relaunch, first real firing (T-022 round 2, 45158384614): testOverlayIsCentredLandscape rotation 60.4 s, relaunch, then 0.4 s, test passed. The stalled process printed no UITestAnimationWatch line. Same run: on a slow VM a failed `readTogether` snapshot of a hidden button was followed by 20 s of silence, so PlaybackOverlayUITests/testBarValueIsReadAfterTheBarHidLandscape saw its 30 s clip end ("Paused"); re-run before treating it as a failure.
- UI-test flake: SubtitleStyleSheetTesterUITests/testUsingTheSheetDoesNotPausePlayback plays the 6 s clip (no `-uiTestingSampleSeconds`) and reads "Pause" 4–5 s after Play. In 45168178904 (T-023) the app's main thread froze 3.45 s after Play ("building pipeline path_exterior… took 0.91 s"), so it read "Play" after the clip ended. Re-run before treating it as a failure.
- XCUITest: a SwiftUI `Text` has a label but no accessibility value, so `UITestSupport.tapStep`/`waitForValue` never match it; use a button whose `accessibilityValue` holds the spoken value (for example `moveText.down` "5 percent up") or `waitForLabel` (T-024a, 45204137687). The same run had a new 57 s main-thread block right after the portrait player push (UIKit: "blocking its subgraph for 57.47 seconds"); the test passed.
- Builders can't compile Swift here, so after a builder round, scan the changed Swift files for lines with an odd number of `"` (a real line break inside a string literal broke all 4 test jobs in 46100218606).
- The idle stall also hits taps mid-test, not only rotations: in 46112964013 the Play tap in PlaybackOverlayUITests took 48 s and the 30 s clip ran out. Tests that play and then read state need a clip that outlasts two 60 s stalls (120 s).
- Two tasks in flight on one branch that share a file: stage the landing task's version with `git restore --staged --source=<its last commit> -- <file>`, so the other task's uncommitted edits stay in the working tree.
- System banner (T-035): about 7 min after a CI simulator boots, iOS 26 shows a "Ready for Apple Intelligence" SpringBoard banner for about 25–30 s over the top of the screen. It isn't in the app's hierarchy; the app answers VisiblePoint -1 (not hittable) for covered controls (46118672166, 46102226923). The empty full-screen Others at the end of landscape hierarchies are normal.
- A Safari left running by a UI test makes XCTest's next terminate of Clip Deck time out ("Failed to terminate … after 60 s"), so tests that open Safari terminate it in tearDown (T-035).
- Branches built in worktrees from an older base land by tree, not by merge: `git checkout <task commit> -- <its files>` (or `git restore --staged --source=`) onto the goal branch, then one squashed commit.
- The CI simulator boots before the build and the tests start 660 s after the boot (`SETTLE_SECONDS`, T-036): the first ~10 min of a fresh simulator caused the "Failed to terminate", screenshot-timeout and banner flakes.
- To tap a landscape bar button while the video plays, use `UITestSupport.tapBarButtonWhilePlaying`: the bars hide 3 s after Play and one element query can take 2 s on CI, so an `isHittable` check or a 2 s wait loses the race (T-036).
