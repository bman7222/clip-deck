---
id: T-006
title: Add an MKV episode from the upload sheet
lane: fullstack
depends_on: [T-004]
status: done
round: 1
base_sha: 5b8b1a83c2d129012585543a827749ab5e3fac42
issue: 6
spec: .loop/specs/mkv-import.md
model: opus
---

## Add an MKV episode from the upload sheet

### What are we building?
Today the upload sheet refuses `.mkv` files. After this task, Brent picks an MKV and chooses which audio track to keep. He adds a subtitle file the usual way and taps Add episode. The sheet shows progress with a Cancel button and keeps the screen awake. Then the episode plays and makes cards like any other. "Choose the video again" on a missing video accepts MKV through the same flow. A cancelled, failed or crashed import never leaves half-written files behind.

### Why?
This is the part Brent sees: MKV episodes go straight from the Files app (or iCloud Drive) into Clip Deck without a computer. He usually has separate subtitle files, so the normal subtitle import is enough.

### Done when
- AC-1 (backend) `EpisodeImporter` has two steps.
  - Prepare:
    - iCloud: if `ubiquitousItemDownloadingStatus` isn't current, it calls `startDownloadingUbiquitousItem` and reports "downloading", then reads through `NSFileCoordinator`;
    - free space: `volumeAvailableCapacityForImportantUsageKey` must be at least the source size plus max(10 %, 200 MB), otherwise an error with both sizes;
    - it probes the file and builds the plan.
  - Import:
    - converts (MKV) or copies (MP4/MOV/M4V) into `tmp/Converting/<uuid>/`;
    - on success, moves into `Documents/Videos/<Show>/` with `FileStore.uniquePath`;
    - inserts the Episode and saves;
    - if the save fails, deletes the moved files.
  It takes an options value (default: no subtitle extraction) that T-005 extends.
- AC-2 (backend) `tmp/Converting/` is swept at every launch. Unit tests:
  - MP4 copy path;
  - MKV path with fixture 4 (no subtitles);
  - cancel mid-convert: nothing appears in `Videos/` and staging is emptied;
  - leftovers in staging (as after a kill) are removed by the sweep;
  - a forced save failure removes the moved file;
  - the space rule.
- AC-3 (frontend) Both the upload and relink pickers use `[.movie, .item]` and check the extension (`mp4`, `mov`, `m4v`, `mkv`) after picking. Anything else shows "“.xyz” videos aren't supported. Use MP4, MOV, M4V or MKV." The placeholder reads "Choose MP4, MOV, M4V or MKV".
- AC-4 (frontend) After picking an MKV:
  - "Downloading from iCloud…" shows when needed, then a short probing spinner;
  - an "Audio" picker (`upload.audioTrack`) appears when there is more than one track (language · title · codec; default per spec);
  - an unsupported file or too little space shows the message in the `ErrorBanner`, and Add episode stays disabled;
  - built-in subtitle tracks are not mentioned.
- AC-5 (frontend) Add episode shows "Converting… n%" (`upload.progress`) with Cancel (`upload.cancelConvert`). `isIdleTimerDisabled` is on while converting and restored afterwards. A `beginBackgroundTask` covers short trips to the background; when it expires, the conversion is cancelled with the spec's J-5 message. Success dismisses; failure or cancel keeps the sheet open and creates no Episode.
- AC-6 (frontend) `MissingFileView` uses the same importer and the same progress/Cancel UI (default audio track). It updates `videoPath` to the new `.mp4` and opens the player.
- AC-7 A Debug-only `-uiTestingMKV` flag seeds "MKV Show / Episode 1" by importing fixture 4 (from `CLIPDECK_FIXTURES`, passed in by the UI test through `launchEnvironment`) with the sample SRT as its subtitle file. A UI test opens it, sees the subtitle lines, makes a card, and attaches `mkv-01-player` and `mkv-02-card`. The flag is documented in CLAUDE.md and DEVELOPMENT.md.
- AC-8 Docs: PRODUCT_SPEC.md (MKV supported; built-in subtitles still listed as not yet), ARCHITECTURE.md (diagram, "Video formats" row, staging), DEVELOPMENT.md troubleshooting (MKV, codecs, iCloud, space), README formats.

### How to check
CI only:
1. `git push origin loop/mkv-landscape-sideload`, then `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload`.
2. `gh run list --branch loop/mkv-landscape-sideload --workflow ios-simulator.yml --limit 3`; `gh run watch <id> --exit-status`; on failure `gh run view <id> --log-failed`.
3. `./scripts/test-ios.sh` and `./scripts/build-ipa.sh` jobs pass.
4. `gh run download <id> -n simulator-results -D <scratch>/ci`; read `screenshots/ui-tests/*mkv-01*` and `*mkv-02*`.
Unverified for Brent (real iPhone): picking a real MKV from Files and from iCloud Drive, a full episode's conversion time with the screen staying on, HEVC 10-bit playback, switching apps mid-conversion, force-quitting mid-conversion and reopening (nothing half-imported).

### Agent notes
- Depends on: T-004 (and T-012 through it). Not on T-005.
- Source: `.loop/specs/mkv-import.md` (Import, files and lifecycle; J-3 to J-7); review findings 3, 4 and 9.
- Backend first (`Services/EpisodeImporter.swift` + tests), then the frontend wires `UploadEpisodeView` and `MissingFileView` and retires the `FileStore.videoExtensions`/`FileTypes.videos` checks.
- `FileManager.default.temporaryDirectory` is on the same volume as Documents, so the final move is a rename.
- Keep the security-scoped access (and the coordinated read) open from prepare to the end of import.
- Progress reaches SwiftUI on the main actor only.
- `BGContinuedProcessingTask` (iOS 26+) is out of scope; mention it in ARCHITECTURE.md as a possible follow-up.

### Out of scope
- Built-in subtitle extraction and its picker (T-005).
- Switching the audio track after import; batch import; re-encoding video.

<!-- Sections below are appended during the loop. Never delete earlier ones. -->

## Implementation notes (round 1, backend) · opus
_by loop-backend · 2026-11-20 03:48_
- Changed: AC-1, AC-2, the importer side of AC-6, the app side of AC-7 (the `-uiTestingMKV` seed) and the backend docs of AC-8 (ARCHITECTURE.md; the flag in CLAUDE.md and DEVELOPMENT.md). Nothing compiled locally (Windows); CI is the first real check. No UI touched: `UploadEpisodeView`/`MissingFileView` still use the old copy path until the frontend wires the importer.
- Files:
  - `ios/ClipDeck/Services/EpisodeImporter.swift` (new): `EpisodeImporter` (prepare, importEpisode, relink, sweepStaging), `PreparedVideo`, `EpisodeImportOptions`, `NewEpisodeDetails`, `EpisodeImportResult`, `PrepareStage`, `EpisodeImportError`, `StorageSpaceRule`, `ProgressRelay`, `ConversionPlan.Warning.message`.
  - `ios/ClipDeck/Services/SourceAccess.swift` (new): security scope + an `NSFileCoordinator` coordinated read held open on a dedicated thread from prepare to the end of import; iCloud status/poll; `coordinatedCopy` for subtitle files.
  - `ios/ClipDeck/App/ClipDeckApp.swift`: `EpisodeImporter.sweepStaging()` at launch; `LaunchFlags.shouldSeedMKV`.
  - `ios/ClipDeck/App/RootView.swift`: `UITestSeeder.seedMKV` imports fixture 4 through the real importer.
  - `ios/ClipDeckTests/EpisodeImporterTests.swift` (new): 20 tests (below).
  - `docs/ARCHITECTURE.md` (diagram, files list, "Importing episodes" section incl. `BGContinuedProcessingTask` as a follow-up, "Video formats" and new "Import staging" Decisions rows), `docs/DEVELOPMENT.md` (`CLIPDECK_FIXTURES` row, `-uiTestingMKV` how-to), `CLAUDE.md` (the flag; "every import goes through EpisodeImporter").
- How it works:
  - Prepare: extension check → if `ubiquitousItemDownloadingStatus` isn't current, `startDownloadingUbiquitousItem` + `onStage(.downloadingFromICloud)` → coordinated read (`SourceAccess.acquire`, cancellable via `NSFileCoordinator.cancel()`) → poll while iCloud still says `.notDownloaded` (a download error becomes a message) → free space (`volumeAvailableCapacityForImportantUsage` ≥ size + max(10 %, 200 MB), decimal MB) → MKV only: `onStage(.probing)`, `MediaProber.load`, the default plan. If the default audio track has no decoder, the first usable track becomes the default (video errors are thrown as they are).
  - Import: a fresh `tmp/Converting/<uuid>/` (removed on every exit by `defer`) → space re-check → convert (`MediaConverter.convert`) or copy (`FileStore.copySecurityScoped`, detached) into it, plus the subtitle file via a coordinated copy → `Task.checkCancellation()` → move with `FileStore.uniquePath` into `Videos/<Show>/` and `Subtitles/<Show>/<Episode>/` → insert Show (if new) + Episode → `save`. A failed move or save deletes the moved files, removes the folders this import created if they are empty, deletes the inserted models (relink: restores `videoPath`), and throws `.saveFailed`. Success closes the `SourceAccess`; a failure keeps it open for a retry.
  - Show matching ignores case (as the sheet does today). Subtitle files now get `uniquePath` instead of overwriting a same-named file (safer for rollback).
- Checked: every call site and type read against the existing code (FileStore, MediaProber, ConversionPlan, MediaConverter, Models, ConverterGate). No CR bytes in any changed file. Not run: XcodeGen, build, all tests (CI only, `ci_only: true`).

### CONTRACT for loop-frontend
All on the main actor (the app's default isolation). `let importer = EpisodeImporter()` (the default init uses `FileStore.live`, the app's tmp folder, `VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)`, real free space and `context.save()`).

- Picker check (AC-3): `EpisodeImporter.isSupportedVideo(url) -> Bool`, `EpisodeImporter.needsConversion(url) -> Bool` (true for `.mkv`), `EpisodeImporter.videoExtensions`. Or just call `prepare`: it throws `EpisodeImportError.unsupportedVideoType(ext)`, whose `localizedDescription` is exactly "“.xyz” videos aren't supported. Use MP4, MOV, M4V or MKV." Retiring `FileStore.videoExtensions` / `FileTypes.videos` is yours (pickers: `[.movie, .item]`).
- Step 1, right after picking (run it in a `Task` you keep, so the sheet's Cancel or a dismiss can cancel it):
  `func prepare(_ url: URL, onStage: (PrepareStage) -> Void = { _ in }) async throws -> PreparedVideo`
  - `onStage(.downloadingFromICloud)` → show "Downloading from iCloud…"; `onStage(.probing)` (MKV only) → a short spinner. MP4/MOV/M4V return quickly with no stage.
  - Throws `EpisodeImportError` (show `error.localizedDescription` in the `ErrorBanner` and keep Add episode disabled) or `CancellationError` (show nothing). Messages: unsupported type (above); not enough space: "This needs about 1.6 GB free; you have 0.9 GB."; unsupported video: the plan's text, e.g. "H.264 10-bit (Hi10P) video can't be played on iPhone. Convert it on a computer to H.264 (8-bit) or HEVC, for example with HandBrake, then try again."; an unreadable file; an iCloud download failure.
- `PreparedVideo` (a Sendable struct; keep it in `@State`):
  - `needsConversion: Bool` (MKV → "Converting… n%"; otherwise a copy), `fileExtension`, `sourceBytes`, `source`.
  - `audioTracks: [MediaProbe.Audio]` (empty for MP4). Show the `upload.audioTrack` picker when `audioTracks.count > 1`; tag = `track.streamIndex`; label = `prepared.label(for: track)` → "jpn · Original · AAC", "eng · FLAC", or "Track 3 · AC-3" when the file names neither language nor title.
  - `defaultAudioStreamIndex: Int?`: preselect this.
  - `plan(for: EpisodeImportOptions) throws -> ConversionPlan?`: call it when the user changes the audio choice. It throws `EpisodeImportError.unsupported(...)` if that track can't be used (show the message, disable Add). nil for MP4.
  - `warnings: [String]`, e.g. "This video has no sound track, so its cards will have no audio." (optional to show before import).
  - `close()`: call it when the user picks another file or leaves without importing (dropping the last copy also closes it).
- Step 2, Add episode (run it in a `Task` you keep; turn on `isIdleTimerDisabled` and a `beginBackgroundTask` around it; on expiry cancel the task and show "Conversion stopped. Keep Clip Deck open until it finishes."):
  `func importEpisode(_ prepared: PreparedVideo, as details: NewEpisodeDetails, options: EpisodeImportOptions = EpisodeImportOptions(), into context: ModelContext, progress: @escaping @MainActor (Double) -> Void = { _ in }) async throws -> EpisodeImportResult`
  - `NewEpisodeDetails(showName: String, title: String, number: Int? = nil, subtitleFile: URL? = nil)`: names are trimmed; an existing show is matched ignoring case; `subtitleFile` is the picked `.srt/.ass/.ssa` URL (the importer copies it; don't copy it yourself).
  - `EpisodeImportOptions(audioStreamIndex: Int? = nil)`: the picker's selection (nil = the default). T-005 will add built-in subtitle choices here; the default stays "none".
  - `progress` runs on the main actor: 0 → rising (MKV) → 1, never backwards. Show `upload.progress` "Converting… \(Int(value * 100))%" for MKV; for MP4 it is just 0 then 1 (a plain "Adding…" is fine).
  - Cancel (`upload.cancelConvert`): cancel the task → `CancellationError` within about 1 s for MKV (an MP4 copy finishes copying into tmp first, then is discarded). Nothing is added; keep the sheet open; `prepared` stays open, so Add episode can be tapped again.
  - Other errors: `EpisodeImportError` (`.missingShowName` "Enter a show name.", `.missingTitle` "Enter an episode name.", `.unsupportedSubtitleType`, `.notEnoughSpace`, `.copyFailed`, `.subtitleCopyFailed`, `.saveFailed` "The episode couldn't be saved, so nothing was added: …", `.sourceClosed` "The video is no longer open. Choose it again.") or `MediaConversionError` (e.g. `.damagedFile`). Show `localizedDescription`; nothing was added.
  - `EpisodeImportResult`: `episode: Episode` (saved) and `warnings: [String]` (e.g. "3 damaged audio frames were skipped, so the sound may drop out briefly."; normally empty). On success, dismiss (optionally toast the warnings).
- Relink (AC-6, `MissingFileView`): the same `prepare`, then
  `func relink(_ episode: Episode, to prepared: PreparedVideo, options: EpisodeImportOptions = EpisodeImportOptions(), in context: ModelContext, progress: @escaping @MainActor (Double) -> Void = { _ in }) async throws -> EpisodeImportResult`
  It writes next to the old path (same folder and name, `.mp4` for an MKV), sets and saves `episode.videoPath`, and restores it on a failed save. Same progress, cancel and errors. Then show `PlayerView`.
- Debug seed (AC-7): launch with `["-uiTesting", "-uiTestingMKV"]` and `app.launchEnvironment["CLIPDECK_FIXTURES"] = ProcessInfo.processInfo.environment["CLIPDECK_FIXTURES"]`. The library then holds "MKV Show" (tile `library.show.MKV Show`) with "Episode 1" (`episode.row.Episode 1`): video `Videos/MKV Show/Episode 1.mp4` (8 s, colours and beeps from fixture 4) and subtitle `sample.srt` (こんにちは 0.5-2.0 s, 元気ですか 2.0-4.0 s, またね 4.0-5.5 s). "Sample Show" is not seeded with this flag. The flag is already documented in CLAUDE.md and DEVELOPMENT.md; the UI test, its screenshots (`mkv-01-player`, `mkv-02-card`) and the rest of AC-8 (PRODUCT_SPEC, DEVELOPMENT troubleshooting, README) are yours.

### Unit tests added (`EpisodeImporterTests`, serialized; each test has its own Documents, Library and tmp under a fresh temp folder)
- MP4 copy path: `copiesAnMP4AndItsSubtitleIntoTheShowFolders` (paths, identical bytes, picked file kept, progress 0 → 1, staging empty, access closed); `aSecondEpisodeJoinsTheExistingShowIgnoringCaseAndGetsAUniqueName`.
- MKV path with fixture 4: `convertsFixture4IntoAPlayableMP4Episode` (stages == [.probing], one audio track, no warnings, `Videos/MKV Show/Episode 1.mp4` playable, source untouched, progress strictly rising 0 → 1).
- Cancel mid-convert: `cancellingMidConvertLeavesNothingInTheLibraryOrStaging`. It holds the converter at its first progress report with `ConverterGate` (through `EpisodeImporter.onConversionProgress`). While held: staging has 1 entry, Videos/Subtitles have no files. After cancel: `CancellationError`, no library files, `tmp/Converting` empty, no Show or Episode, and the file stays open for a retry.
- Kill leftovers: `sweepRemovesWhatAKilledImportLeftInStaging` (only `tmp/Converting` goes; a repeat sweep is harmless).
- Forced save failure: `aFailedSaveRemovesTheMovedFilesAndAddsNothing` (video and subtitle deleted, the show folders it created removed, no Show or Episode, and a retry gets the plain name, so there is no orphan); `aFailedSaveKeepsAnExistingShowAndItsFiles`; `aFailedRelinkSaveRestoresThePathAndRemovesTheFile`.
- Relink: `relinkingWithAnMKVPointsTheEpisodeAtTheNewMP4` (`Episode 2.mov` → `Episode 2.mp4`).
- Space rule: `requiredSpaceIsTheSourcePlusTheLargerOfTenPercentAnd200MB`, `spaceCheckPassesAtTheLimitAndFailsOneByteBelow`, `notEnoughSpaceMessageGivesBothSizes` (the spec's exact sentence), `prepareRefusesAFileThatDoesNotFit`.
- Also: `rejectsHi10PWhenPreparing`, `rejectsOtherVideoTypesByExtension` (the exact AC-3 text), `missingNamesAreRefusedBeforeAnythingIsWritten` (including `.sourceClosed` after `close()`), `audioLabelsAndChoices`, `anUndecodableDefaultTrackFallsBackToOneThatWorks`, `aFileWithNoAudioTrackWarns`.

### Tester, look at
- Compile first. Spots written blind:
  - `SourceAccess.swift`: `Thread { [self] in … }` resuming a `CheckedContinuation`; `NSFileCoordinator.coordinate(readingItemAt:options:error:byAccessor:)` with a captured `var resumed`; `OSAllocatedUnfairLock.withLock { value -> T in … }` closures that return tuples; `nonisolated private final class`.
  - `EpisodeImporter.swift`: `makePlan`'s `catch { return .failure(error) }` relies on Swift 6 inferring the typed error (the T-004 "always succeeds" warnings show it does); the `progress:` closure passed to `MediaConverter.convert` that calls the optional tap and starts `Task { @MainActor in relay.send(value) }`; init default arguments that reference `EpisodeImporter.deviceSupportsAV1` and `volumeAvailableCapacity`; `kCMVideoCodecType_AV1` (CoreMedia) and `VTIsHardwareDecodeSupported` (VideoToolbox, autolinked).
  - Tests: `Task { @MainActor in … self.makeGatedImporter(gate) … self.container.mainContext }` captures the @MainActor suite.
- Runtime assumptions most likely to be off:
  1. `context.fetch` no longer returns a just-inserted model after `context.delete` (the failed-save tests assert 0 Shows/Episodes).
  2. A coordinated read of a plain local file (the fixtures on the runner, files in the test's temp folder) is granted at once, and the dedicated thread ends on `close()` or deinit.
  3. `missingFolders`/`undo` remove `Videos/Show A` and `Subtitles/Show A` after a failed save (trailing-slash handling in `URL.path`).
- Mutation checks worth doing: drop `moved.undo()` in the save-failure branch (the save-failure tests must fail); remove the `defer` that deletes staging (the cancel test must fail on `stagingEntries`); move files before converting (the cancel test must fail on `libraryFiles` while held); make `sweepStaging` a no-op (the sweep test must fail).
- Device-only (Brent): an iCloud file that isn't downloaded (stage + coordinated read), a third-party file provider, real free-space numbers.

### Gotchas
- 200 MB and the GB message use decimal units (as iOS Settings shows storage). Needed rounds up and free rounds down to 0.1 GB, so a refusal never shows two equal numbers.
- Unknown free space (nil from iOS) passes the check rather than blocking every import.
- If the file's default audio track can't be decoded, the default becomes the first track that can (otherwise Add episode would be stuck); choosing the undecodable one shows its message.
- An MP4 copy can't be interrupted (`FileManager.copyItem`, which can clone on APFS). Cancel takes effect when the copy into tmp finishes; the copy is then deleted.
- The coordinated read stays held while the sheet has the file, so iCloud can't replace it mid-import. It is released on success, on `close()`, or when the `PreparedVideo` is dropped.

## Implementation notes (round 1, frontend) · opus
_by loop-frontend · 2026-11-20 09:06_
- Changed: AC-3, AC-4, AC-5, AC-6, the UI-test side of AC-7 and the frontend docs of AC-8. Nothing compiled locally (Windows); CI is the first real check. The run was interrupted once by a usage limit and resumed from `git status`; nothing was duplicated.
- Files:
  - `ios/ClipDeck/Features/Library/VideoImportModel.swift` (new): an `@Observable` model shared by both screens.
    - `pick(url, onReady:)` closes the previous `PreparedVideo` and refuses a bad extension at once (the `EpisodeImportError.unsupportedVideoType` text). Otherwise it runs `importer.prepare` in a kept `Task` with a token: a stale result is closed, and `CancellationError` is silent. `PrepareStage` maps to "Downloading from iCloud…" / "Reading the video…" ("Opening the video…" before any stage).
    - `selectAudio` re-checks `prepared.plan(for:)` and puts its message in `videoError`, which disables Add.
    - `run(work, completion)` turns on `isIdleTimerDisabled` (the old value is restored in `finishRun`) and starts a `beginBackgroundTask`. Its expiry handler cancels the run and ends the background task at once. The result maps to `.added`, `.cancelled` (silent) or `.failed(message)`; after an expiry the message is "Conversion stopped. Keep Clip Deck open until it finishes."
    - `leave()` (called from onDisappear) cancels both tasks and closes the file. Progress is clamped to 0…1 and set only on the main actor.
  - `ios/ClipDeck/Features/Library/ImportProgressView.swift` (new): `ImportProgressView` and `VideoPreparingRow`. For an MKV the progress view shows "Converting… n%", an aqua bar and "Keep Clip Deck open…"; for a copy it shows a spinner and "Adding…". Both have a red Cancel. Identifiers: `<prefix>.progress`, `<prefix>.cancelConvert`.
  - `ios/ClipDeck/Features/Library/UploadEpisodeView.swift`: uses the model and `importer.importEpisode`. It does no copying of its own; the subtitle URL goes in `NewEpisodeDetails`.
    - While running: a progress section at the top; the fields, the toolbar Cancel and swipe-to-dismiss are locked.
    - Video row: placeholder "Choose MP4, MOV, M4V or MKV", then the `upload.preparing` row while the file is checked. The `upload.audioTrack` picker shows only when `audioTracks.count > 1`. It is tagged by `streamIndex`, takes its labels from `prepared.label(for:)` and starts on the default track. MKV adds a footer note.
    - Banners: `upload.videoError` under the Episode section, `upload.error` at the bottom.
    - Success dismisses the sheet. If the result has warnings, an "Episode added" alert (`upload.warningsOK`) shows them first.
    - `FileTypes.videos` = `[.movie, .item]`.
  - `ios/ClipDeck/Features/Library/SubtitleBrowserView.swift` (`MissingFileView`): uses the same model. After a pick, the relink starts by itself once prepare is ready, with the default audio track, through `importer.relink`.
    - Identifiers: `missing.preparing`, `missing.progress`, `missing.cancelConvert`, `missing.videoError`, and `missing.error` (with "Try again" while the file is still open).
    - While it runs, the back button is hidden and `missing.relink` is disabled.
    - Success shows `PlayerView`; warnings appear in a "Video added" alert (`missing.warningsOK`).
  - `ios/ClipDeck/Features/Library/LibraryView.swift`: the empty-library text lists MKV.
  - `ios/ClipDeck/Services/FileStore.swift`: removed `FileStore.videoExtensions`, now unused. The contract assigned retiring it to the frontend, and nothing else references it.
  - `ios/ClipDeckUITests/MKVImportUITests.swift` (new), using full-app `app.screenshot()` only (no element screenshots):
    - `testMKVEpisodePlaysAndMakesACard`:
      1. Launches with `-uiTesting -uiTestingMKV` and copies `CLIPDECK_FIXTURES` from the runner's environment into `launchEnvironment` (it asserts the variable is set).
      2. Waits up to 90 s for `library.show.MKV Show` and dumps the tree on a timeout.
      3. Checks the three cue rows with `label.contains`, because iOS 26 merges time and text into one label.
      4. Taps line 2, checks `player.subtitle` and attaches `mkv-01-player`.
      5. Make a Card: expects range `0:02.0 – 0:04.0` and sentence `元気ですか`, attaches `mkv-02-card`, saves, and expects the toast.
    - `testUploadSheetOffersMKV`: the placeholder (matched with `label.contains`), Add disabled, no audio picker. Attaches `mkv-00-upload-sheet`.
  - Docs:
    - `docs/DESIGN.md`: the Upload sheet and Missing video rows with every state and identifier; the `ImportProgressView` component.
    - `docs/PRODUCT_SPEC.md`: the MKV flow and scope. "Not yet": other containers and unplayable codecs, switching audio after import, and built-in subtitle tracks (still not yet). Future: built-in tracks, BGContinuedProcessingTask.
    - `README.md`: formats.
    - `docs/DEVELOPMENT.md`: troubleshooting rows for file type, codec, iCloud, space and the background stop; MKVImportUITests in the test list.
- Checked: read every call against the CONTRACT and against `EpisodeImporter.swift`/`SourceAccess.swift` as they are now; no CR bytes in the changed files. Not run: build, unit tests and UI tests (CI only, `ci_only: true`).

### Tester, look at
- Compile first. These spots were written blind:
  - `VideoImportModel.run`'s parameter type `@escaping @MainActor (EpisodeImporter, PreparedVideo, EpisodeImportOptions, @escaping @MainActor (Double) -> Void) async throws -> EpisodeImportResult`, and the closures in both views that capture `ModelContext` in it;
  - `beginBackgroundTask { [weak self] in MainActor.assumeIsolated { … } }`;
  - `Status: Equatable` with a `PrepareStage?` payload;
  - `ErrorBanner(…, action: video.canImport ? { startRelink() } : nil)`;
  - the `Picker` bound through a `Binding<Int>`.
- Flows: MiningFlowUITests and LaunchUITests must still pass. The identifiers are unchanged, and `upload.save` is still disabled with no video. The MKV UI test needs CLIPDECK_FIXTURES in the UI-test runner (test-ios.sh exports TEST_RUNNER_CLIPDECK_FIXTURES).
- The simulator can't show these (Brent on a device): picking a real MKV with 2+ audio tracks from Files or iCloud; the progress and Cancel UI during a real conversion; the screen staying on; a trip to the background and the expiry message; Missing video with an MKV.

### Gotchas
- A refused file (bad extension, unsupported video, not enough space) replaces the previous pick. The row shows the refused file's name next to the banner and Add stays disabled, so what you see is what would be imported.
- `onDisappear` on the sheet and on MissingFileView calls `leave()`. This relies on SwiftUI not firing onDisappear when the file picker opens over the screen (it doesn't for a modal). If it ever did, the only effect is that the earlier pick is forgotten.
- After a successful import the model drops its `PreparedVideo` (the importer already closed it), so Add can't be tapped twice. After Cancel or a failure the file stays prepared, so Add or Try again works without picking it again.
- Import warnings appear in an alert before the sheet closes rather than in a toast, since the sheet goes away. The plan's "no sound track" warning shows only after import (it is part of the result's warnings), not before.

## Test report (round 1)
_by loop-tester · 2026-11-20 09:35_

CI run 44750491956 (headSha b0e466c, scope=all):
- **ipa job: green.** The whole app compiles for the device, including all 19 changed files, and the notice check passed.
- **simulator job: red** on 3 UI tests the diff doesn't touch (see the last row below). The app and test targets compiled, and the new code adds no warnings (the only warnings are the old ConversionPlanTests `as?` casts).
- 165 test runs: 162 Success, 3 Failure. All 19 EpisodeImporterTests passed, as did both MKVImportUITests, MiningFlowUITests and LaunchUITests (read from the xcresult `database.sqlite3` in `simulator-results`).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 (backend) `EpisodeImporter` has two steps. Prepare: iCloud: if `ubiquitousItemDownloadingStatus` isn't current, it calls `startDownloadingUbiquitousItem` and reports "downloading", then reads through `NSFileCoordinator`; free space: `volumeAvailableCapacityForImportantUsageKey` must be at least the source size plus max(10 %, 200 MB), otherwise an error with both sizes; it probes the file and builds the plan. Import: converts (MKV) or copies (MP4/MOV/M4V) into `tmp/Converting/<uuid>/`; on success, moves into `Documents/Videos/<Show>/` with `FileStore.uniquePath`; inserts the Episode and saves; if the save fails, deletes the moved files. It takes an options value (default: no subtitle extraction) that T-005 extends. | Pass (iCloud branch Unverified) | 44750491956, all Success: copiesAnMP4AndItsSubtitleIntoTheShowFolders; convertsFixture4IntoAPlayableMP4Episode (stages == [.probing], playable MP4); aSecondEpisodeJoins…UniqueName (uniquePath); aFailedSaveRemovesTheMovedFilesAndAddsNothing; aFailedSaveKeepsAnExistingShowAndItsFiles; prepareRefusesAFileThatDoesNotFit; notEnoughSpaceMessageGivesBothSizes; spaceCheckPassesAtTheLimitAndFailsOneByteBelow. The iCloud path (EpisodeImporter.swift:109-124) is checked by reading only; the simulator has no iCloud file |
| AC-2 (backend) `tmp/Converting/` is swept at every launch. Unit tests: MP4 copy path; MKV path with fixture 4 (no subtitles); cancel mid-convert: nothing appears in `Videos/` and staging is emptied; leftovers in staging (as after a kill) are removed by the sweep; a forced save failure removes the moved file; the space rule. | Pass | ClipDeckApp `init` calls `EpisodeImporter.sweepStaging()`. 44750491956, both Success: cancellingMidConvertLeavesNothingInTheLibraryOrStaging (while held: 1 staging entry and an empty library; afterwards everything is empty and there are 0 Shows/Episodes) and sweepRemovesWhatAKilledImportLeftInStaging, plus the AC-1 tests. No mutation runs (each needs a CI dispatch; conservative budget) |
| AC-3 (frontend) Both the upload and relink pickers use `[.movie, .item]` and check the extension (`mp4`, `mov`, `m4v`, `mkv`) after picking. Anything else shows "“.xyz” videos aren't supported. Use MP4, MOV, M4V or MKV." The placeholder reads "Choose MP4, MOV, M4V or MKV". | Pass (model test pending) | MKVImportUITests/testUploadSheetOffersMKV Success; screenshot `mkv-00-upload-sheet` shows "Choose MP4, MOV, M4V or MKV" with Add episode disabled. rejectsOtherVideoTypesByExtension Success (exact text). Both `.fileImporter`s use `FileTypes.videos` = `[.movie, .item]`. New tester tests `anUnsupportedExtensionIsRefusedAtOnceWithTheSpecMessage` and `pickersAcceptMoviesAndAnyFile` have not run yet |
| AC-4 (frontend) After picking an MKV: "Downloading from iCloud…" shows when needed, then a short probing spinner; an "Audio" picker (`upload.audioTrack`) appears when there is more than one track (language · title · codec; default per spec); an unsupported file or too little space shows the message in the `ErrorBanner`, and Add episode stays disabled; built-in subtitle tracks are not mentioned. | Partly. Labels and default: Pass. Space → Add disabled: test pending. Picker UI and iCloud: Unverified | Success: audioLabelsAndChoices, anUndecodableDefaultTrackFallsBackToOneThatWorks, rejectsHi10PWhenPreparing. Banner and disabled Add checked by reading UploadEpisodeView.swift:85-92 and :159-161. New tester test `tooLittleSpaceShowsBothSizesAndKeepsAddDisabled` has not run yet. No fixture has 2+ audio tracks, so `upload.audioTrack` has never been rendered. The views never mention subtitle tracks |
| AC-5 (frontend) Add episode shows "Converting… n%" (`upload.progress`) with Cancel (`upload.cancelConvert`). `isIdleTimerDisabled` is on while converting and restored afterwards. A `beginBackgroundTask` covers short trips to the background; when it expires, the conversion is cancelled with the spec's J-5 message. Success dismisses; failure or cancel keeps the sheet open and creates no Episode. | Pending verify-only. Background expiry: Unverified | Read VideoImportModel.swift:186-255 and ImportProgressView.swift. New tester tests, not run yet: `aSuccessfulRunKeepsTheScreenAwakeThenRestoresItAndAddsTheEpisode`; `cancellingAConversionAddsNothingRestoresTheIdleTimerAndKeepsTheFileForARetry`; `aFailedSaveEndsWithTheMessageAndAddsNothing`. The cancel test holds an MKV mid-convert and checks isConverting, "Converting… " and the idle timer on. After Cancel it checks "cancelled", the idle timer restored, 0 Episodes, empty staging and that the file is still importable |
| AC-6 (frontend) `MissingFileView` uses the same importer and the same progress/Cancel UI (default audio track). It updates `videoPath` to the new `.mp4` and opens the player. | Importer side: Pass. Model path: test pending. View: Unverified | relinkingWithAnMKVPointsTheEpisodeAtTheNewMP4 and aFailedRelinkSaveRestoresThePathAndRemovesTheFile: Success. New tester test `relinkingThroughTheModelConvertsAnMKVWithTheDefaultTrack` (pick → onReady → run relink, as MissingFileView does) has not run yet. No UI test reaches MissingFileView (no seed has a missing video) |
| AC-7 A Debug-only `-uiTestingMKV` flag seeds "MKV Show / Episode 1" by importing fixture 4 (from `CLIPDECK_FIXTURES`, passed in by the UI test through `launchEnvironment`) with the sample SRT as its subtitle file. A UI test opens it, sees the subtitle lines, makes a card, and attaches `mkv-01-player` and `mkv-02-card`. The flag is documented in CLAUDE.md and DEVELOPMENT.md. | Pass | MKVImportUITests/testMKVEpisodePlaysAndMakesACard: Success (110.6 s). `mkv-01-player`: "Episode 1" at 0:02.0 of 0:07.9, 元気ですか over the video, 3 cue rows. `mkv-02-card`: range 0:02.0 – 0:04.0 (2.0 s), sentence 元気ですか. The test saved the card and the toast appeared. The seeder is inside `#if DEBUG`. The flag is documented in both files |
| AC-8 Docs: PRODUCT_SPEC.md (MKV supported; built-in subtitles still listed as not yet), ARCHITECTURE.md (diagram, "Video formats" row, staging), DEVELOPMENT.md troubleshooting (MKV, codecs, iCloud, space), README formats. | Pass | Read `git diff 5b8b1a8..b0e466c -- docs README.md CLAUDE.md`: every item is there; BGContinuedProcessingTask is listed as a follow-up |
| MiningFlowUITests, LaunchUITests and earlier tests still pass | Pass except 3 failures the diff can't reach | MiningFlowUITests, LaunchUITests and all unit suites: Success. Failed, pre-existing tap/timing flakes not yet in Learned: AboutUITests/testAboutShowsVersionAndNoticeTextIntact (the tap on `library.settings` never opened Settings; the hierarchy still shows the library); PlayerLandscapeBehaviourUITests testControlsStayWhilePausedAndAutoHideWhilePlaying ("Playing: controls hide on their own") and testOpenSubtitlesMenuKeepsControlsUpWhilePlaying (no buttons after the video tap). No changed file is in Settings, About or Player. The About test ran before any MKV test, with `-uiTestingNoSeed`. All three passed in 44698930097 with the same code for those screens |

### Findings
Could fix
Where: ios/ClipDeck/Services/SourceAccess.swift:146-179, and VideoImportModel (holds the prepared file from pick to import)
Problem: the coordinated read stays held while the sheet sits idle and while the app is suspended, so a Files or iCloud write to that file waits on Clip Deck. That is by design for the import (task note), but it also covers the idle time before Add is tapped.
Proof: Read it. SourceAccess.swift:179 `release.wait()` blocks until `close()`.
Trigger: pick a video, leave the sheet open, switch apps, then edit or move that file in Files.
Fix: optional, after Brent's device check. If it bites, take the coordinated read only during prepare, and again during the import.

Could fix
Where: ios/ClipDeck/Features/Library/SubtitleBrowserView.swift (the `missing.error` ErrorBanner with "Try again")
Problem: `ErrorBanner` (an older component) combines its children into one accessibility element, so VoiceOver may not offer "Try again" as its own button.
Proof: Read it. DesignSystem/Components.swift:124
Fix: when an action is present, give the button its own element (e.g. `.accessibilityElement(children: .contain)`).

No Must fix or Should fix. Also checked:
- Paths: show, episode and subtitle names all go through `FileStore.safeName` ("/", "\\" and ":" are replaced and dots trimmed, so ".." becomes "Untitled"). The relink folder comes from the stored relative path.
- Security scope: started once and stopped once (the `scopeEnded` flag); the subtitle copy is balanced by `defer`.
- `holdRead` resumes its continuation exactly once (inside the accessor, or after it via the `resumed` guard). The close/cancel races go through the lock.
- Progress is relayed only on the main actor and never goes backwards (ProgressRelay).

```text
VERDICT: Blocked
NEEDED: verify-only pass. Commit ios/ClipDeckTests/VideoImportModelTests.swift and run the tests once. A full-tests run (scope=tests, no only_testing) also re-runs the 3 unrelated UI flakes. With a single only_testing value, use ClipDeckTests/VideoImportModelTests and treat the flakes as pre-existing
SPEC: AC-1, AC-2, AC-7 and AC-8 met. AC-3 met; its model test is pending. AC-4, AC-5 and AC-6 rest on reading and the importer tests; their model tests are pending
CHECKS_RUN: CI 44750491956 (b0e466c): ipa success; simulator failure, 162/165 Success, with the 3 failures in About and PlayerLandscapeBehaviour UI tests the diff doesn't touch. build-ipa.sh and test-ios.sh ran in CI; no local checks (ci_only)
UNVERIFIED: iCloud download and "Downloading from iCloud…"; real free space; the picker with 2+ audio tracks; the screen staying on during a real conversion; the background expiry message; the Missing video relink UI with an MKV; HEVC 10-bit playback; force-quitting mid-conversion and relaunching
REVIEWED_AT: b0e466c6524066302332c8504f88fd9f27dd4fb0 (plus the uncommitted tester test file)
```

### Round 1 addendum
_by loop-tester · 2026-11-20 10:02_

Verify-only run: CI 44755434228 (headSha 41bf53a = b0e466c plus VideoImportModelTests.swift; scope=tests).
- The simulator job is green and test-ios.sh printed "Tests passed".
- 172/172 test runs Success, 0 issues. The new test file compiled with no warnings.
- The ipa job was skipped. The ipa already passed on b0e466c, and this commit only adds a test file.

Deciding tests, all Success:
- VideoImportModelTests:
  - `anUnsupportedExtensionIsRefusedAtOnceWithTheSpecMessage`
  - `pickersAcceptMoviesAndAnyFile`
  - `tooLittleSpaceShowsBothSizesAndKeepsAddDisabled`
  - `aSuccessfulRunKeepsTheScreenAwakeThenRestoresItAndAddsTheEpisode`
  - `cancellingAConversionAddsNothingRestoresTheIdleTimerAndKeepsTheFileForARetry`
  - `aFailedSaveEndsWithTheMessageAndAddsNothing`
  - `relinkingThroughTheModelConvertsAnMKVWithTheDefaultTrack`
- These close the pending model-level parts of AC-3, AC-4 (space → Add disabled), AC-5 (idle timer on, then restored; Converting… text; success, cancel and failure outcomes; no Episode on cancel or failure) and AC-6 (relink through the shared model with the default track, ending at `.mp4`).
- The 3 UI tests that failed in 44750491956 all passed on this run, with no code change behind them:
  - AboutUITests/testAboutShowsVersionAndNoticeTextIntact (78.3 s)
  - PlayerLandscapeBehaviourUITests/testControlsStayWhilePausedAndAutoHideWhilePlaying (29.7 s)
  - PlayerLandscapeBehaviourUITests/testOpenSubtitlesMenuKeepsControlsUpWhilePlaying (19.1 s)
- So those 3 are flaky, not a T-006 regression. Candidates for Learned.
- MKVImportUITests, MiningFlowUITests, LaunchUITests and all EpisodeImporterTests passed again.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 | Pass (the iCloud branch is Unverified) | 44750491956 + 44755434228, EpisodeImporterTests |
| AC-2 | Pass | 44750491956 + 44755434228, EpisodeImporterTests (cancel, sweep, failed save) |
| AC-3 | Pass | testUploadSheetOffersMKV + mkv-00 screenshot; rejectsOtherVideoTypesByExtension; VideoImportModelTests (extension, picker types) |
| AC-4 | Pass for what the simulator can show. Unverified: iCloud stage, a real 2+ track picker | audioLabelsAndChoices, anUndecodableDefault…; tooLittleSpaceShowsBothSizesAndKeepsAddDisabled |
| AC-5 | Pass. Background expiry Unverified | VideoImportModelTests success/cancel/failure runs (idle timer, Converting…, outcomes, 0 Episodes) |
| AC-6 | Pass for the importer and the model. The MissingFileView UI is Unverified | relinkingWithAnMKV…, aFailedRelinkSave…, relinkingThroughTheModelConvertsAnMKVWithTheDefaultTrack |
| AC-7 | Pass | testMKVEpisodePlaysAndMakesACard; mkv-01-player, mkv-02-card |
| AC-8 | Pass | docs diff read |

The Could fix findings from round 1 still stand (the coordinated read is held while the sheet sits idle; the ErrorBanner action's accessibility). There are no Must fix or Should fix findings.

```text
VERDICT: Pass
SPEC: AC-1 to AC-8 met; the device-only parts are listed under UNVERIFIED
CHECKS_RUN: CI 44750491956 (b0e466c): ipa success (build-ipa.sh, notice check). CI 44755434228 (41bf53a, scope=tests): simulator success, 172/172, 0 issues (test-ios.sh)
UNVERIFIED: iCloud download and "Downloading from iCloud…"; real free space; the Audio picker with 2+ tracks; the screen staying on through a real conversion; the background expiry message; Missing video relink UI with an MKV; HEVC 10-bit playback; force-quit mid-conversion, then reopen
REVIEWED_AT: 41bf53ad22b82249d10a31e7160941181e77d536
```
