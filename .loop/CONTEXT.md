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
- UI-test flake: SubtitleUpLimitTesterUITests/testUpDimsExactlyWhenTheLineReachesTheTopBarWithTwoAndThreeRowCards can lose its last Done tap ("Done closes the card (panel-25)"; card and Done still on screen at failure, 45083671012 shard 1). It passed in 45002423211 and 45070921716. Re-check it before treating it as a failure.
- CI (T-020, three shards, 45083671012): shard 1 20:23, shard 2 28:28 (8.6 min of it was one test's 60 s "wait for idle" stalls), shard 3 27:41. New UI classes land in shard 3; when it nears 35 min, move classes into SHARD1_UI (most headroom).
- Slow-runner freeze (45094204439 shard 1, T-021): on a bad VM the app's UI froze for the whole playback. In the recording the elapsed label stayed put while the video layer kept playing, the post-tap "wait for idle" took 6–15 s and snapshots took 4+ s, and 3 consecutive tests in one 2-minute window failed. Any check that needs the "playing" state of the 6 s clip can hit this.
- Windows triage of an xcresult without xcresulttool: `database.sqlite3` has the failure text and line (TestIssues → TestCaseRuns → TestCases) and every step's start and finish (Activities). Recording frames: Node 26's built-in WebSocket can drive headless Chrome over CDP (seek a `<video>`, draw it to a canvas).
- Flake root cause: PlayerLandscapeBehaviourUITests/testControlsStayWhilePausedAndAutoHideWhilePlaying fails ("Playing: controls hide on their own") when the Play tap takes about 6 s on a slow VM. The 6-s sample plays to its end and stops, and the controls come back (slider 6,000, button "Play"; 45087727557 shard 2). It passed on the same shard filter in 45083671012.
- XCUITest timing: the first check of a `waitForExistence` or XCTNSPredicateExpectation wait comes about 1.0 s after the wait starts (45110218499). A check of something that auto-hides 3 s after Play (the landscape bars, the overlay) only has about 1.6 s of slack for the tap's own "wait for idle".
- Dark mode in UI tests: setting `XCUIDevice.appearance` to dark through KVC logs its step, but the CI simulator stays light (black status bar, light fills; 45110218499). For dark evidence, set it from the workflow with `xcrun simctl ui <udid> appearance dark`.
- `-uiTestingSampleSeconds 30` (T-021) adds 2–6 s to the "Seeded show should appear" wait (at most 7.2 of 30 s in 45110218499). The 60 s idle stall can still outlast a 30 s clip (testScreenshotsLight, 401 s, the clip reached 0:30.0).
- Cold-start flake in targeted runs: with only_testing, the first tests run on a freshly booted simulator. In 45114494368 (T-021) the first 3 tests failed at launch, with launches of 4–55 s: "Seeded show should appear" twice (the library was still empty after the wait, also with the 6 s clip) and "Failed to get background assertion for target app" once. Every seed after them worked (1.1–9.5 s). Treat these as pre-existing (T-034 scope).
