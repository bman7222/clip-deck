# Architecture review: MKV episodes (convert on import)

* Spec: `.loop/specs/mkv-import.md`
* Reviewed at: 7f76886 (independent /architecture-review, 2026-11-19)
* Verdict: Request changes
* Resolution: spec and tasks revised by loop-planner, 2026-11-19 (T-004 split: package, fixtures and notices moved to new T-012)

## Findings

### 1. Package choice and capabilities
**Finding:** `kingslay/FFmpegKit` is GPL (LGPL is paid). ffmpeg-kit forks are unmaintained GPL re-hosts. MPVKit is LGPL-3.0 with no FFmpeg-only product. `kewlbear/FFmpeg-iOS` was last released in 2023. The only qualifying package is `superuser404notfound/FFmpegBuild` 3.16.0 (FFmpeg n8.1.3, LGPL-2.1, no `--enable-gpl`/`--enable-version3`, dynamic xcframeworks, `ios-arm64` + simulator, iOS 16+, per-library products). Caveats: only MP4/MOV/HLS muxers (no matroska, srt or ass), one maintainer, locally built binaries. Fix:
* name it as the first candidate;
* pin with exactVersion;
* mirror or fork it at the tag;
* use the individual libav* products;
* fall back to our own LGPL build in CI;
* list the required components in the AC, checked against BUILD-INFO.txt;
* T-005 writes .srt/.ass in Swift.

**Resolved in:**
* spec › FFmpeg package (T-012), and Decisions › Package;
* T-012 AC-1 (exactVersion 3.16.0, four Aether libav* products, BUILD-INFO.txt component check, binary-location record);
* T-005 AC-1 (Swift writer from packets plus CodecPrivate);
* fixtures come from Homebrew FFmpeg (T-012 AC-2).

**Planner deviation (mirror):** a GitHub fork doesn't copy release assets. So the spec makes the mirror step depend on where the binaries live:
* binaries in the package's git repo: the orchestrator forks at the tag (with Brent's OK) and pins the fork;
* URL release assets: the SPM checksums already lock the bytes; URLs and checksums go in ARCHITECTURE.md, and re-hosting is a follow-up.
The own-build fallback is unchanged.

### 2. Concurrency: work would run on the main actor
**Finding:** with `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY` (NonisolatedNonsendingByDefault), a `nonisolated async` convert runs on the main actor and freezes the UI. Fix:
* `@concurrent`, or `Task.detached` around a synchronous core;
* all libav pointers inside one synchronous function;
* cancel through `AVIOInterruptCB` with an `OSAllocatedUnfairLock<Bool>` (Atomic/Mutex need iOS 18);
* test that the work is off the main thread.

**Resolved in:** spec › Concurrency, Contracts (`MediaConverter.convert` is `@concurrent`), Acceptance AC-11; T-004 AC-3 (off-main test, main-actor heartbeat test, cancel within ~1 s with no output) and Agent notes.

### 3. Partial files and rollback
**Finding:** convert into `tmp/Converting/<uuid>/`, move into `Documents/Videos` with `uniquePath` only on success, and sweep at launch. The importer owns commit/rollback, including deleting the moved files when the SwiftData save fails (today's `save()` already orphans files then). Relink goes through the same importer and UI. A kill mid-convert followed by a relaunch must leave nothing in `Videos/`.

**Resolved in:** spec › Import, files and lifecycle (Staging, Relink), Decisions › Where conversion writes, J-5, Acceptance AC-6 and AC-8; T-006 AC-1 (staging, move on success, save-failure rollback, also for the MP4 copy path), AC-2 (sweep at launch; tests for cancel, kill leftovers and forced save failure), AC-6 (relink through the same importer and UI); T-004 AC-3 (converter writes only to the URL it is given); T-005 AC-3 (subtitles staged and rolled back the same way).

### 4. Backgrounding, free space, iCloud files, faststart
**Finding:**
* `beginBackgroundTask` gives about 30 s, so auto-lock kills long conversions; set `isIdleTimerDisabled`.
* `BGContinuedProcessingTask` on iOS 26+ is optional and unverified on a free sideload.
* Free space: `volumeAvailableCapacityForImportantUsageKey` ≥ source size + margin.
* iCloud: check `ubiquitousItemDownloadingStatus`, read through `NSFileCoordinator`, show "Downloading…" before probing.
* No `+faststart`.

**Resolved in:**
* spec › Import, files and lifecycle (Screen lock and background, Free space, iCloud files), Non-goals (`BGContinuedProcessingTask` deferred as a follow-up), J-7, Acceptance AC-13;
* T-006 AC-1 (iCloud download plus coordinated read; free space ≥ source + max(10 %, 200 MB)), AC-4 (Downloading UI), AC-5 (idle timer off while converting, background task cancels on expiry);
* spec › Conversion rules and T-004 AC-4 (no `+faststart`).

### 5. Timeline rule
**Finding:** MP4 time t = MKV time t, with no rebase. Start offsets and audio delays become edit lists, and extracted subtitles use the same clock. Use the `remux.c` pattern with valid increasing DTS. New AC: an MKV with B-frames, a 1.0 s start offset and a delayed audio track converts so that the screenshot at t and the cue times line up within one frame or 40 ms.

**Resolved in:** spec › Conversion rules (Timeline rule), Decisions › Timeline, Acceptance AC-10 and AC-4; T-004 AC-4 (rule) and AC-6 (fixtures 1 and 3: frame colour at t within one frame, beep onsets within 40 ms); T-005 AC-2 and AC-5 (subtitles on the same clock; fixture 3 cue times within 40 ms); T-012 AC-2 (fixture 3: 1.0 s offset plus 0.5 s audio delay, with B-frames in fixture 1).

### 6. Codec allow-list
**Finding:**
* H.264: allow `yuv420p` only.
* HEVC Main/Main10: allow `yuv420p` and `yuv420p10le`.
* Reject 4:2:2, 4:4:4 and 12-bit.
* Dolby Vision: reject profile 5; tag 8.x as `hvc1`.
* Pass `supportsAV1` into the pure plan.
* Resample transcoded audio to at most 48 kHz.
* Decide whether AAC 5.1 is copied or made stereo.
* Prefer the AudioToolbox AAC encoder.

**Resolved in:** spec › Conversion rules (Video allow-list, Audio), Contracts (`ConversionPlan` inputs include `supportsAV1`), Decisions › Multichannel audio (**AAC/MP3 above 2 channels are transcoded to stereo**: proposed by the planner, confirmed by Brent 2026-11-19), Non-goals; T-004 AC-1 (probe fields) and AC-2 (allow-list, DV 5 vs 8.1, 4:2:2/4:4:4/12-bit, AV1 with and without `supportsAV1`, ≤ 48 kHz, 5.1 → stereo), Agent notes (`aac_at` preferred, else `aac`).

### 7. Test fixtures
**Finding:** the package can't mux MKV, and `TestMediaFactory` can't produce the risky cases. In CI, `brew install ffmpeg` (build-time only) generates fixture MKVs into a temp folder:
* H.264 with B-frames;
* HEVC Main10 with open GOP;
* a 1.0 s offset;
* FLAC and AC-3 audio;
* SRT and ASS tracks;
* a variant with no subtitles;
* a Hi10P sample to reject.
Pass the folder through `TEST_RUNNER_`/`SIMCTL_CHILD_` variables. No binaries in git. The `-uiTestingMKV` seed uses the same fixtures. This goes in T-004 and touches `ios-simulator.yml` and `test-ios.sh`.

**Resolved in:**
* spec › Tests (fixtures 1 to 5, `TEST_RUNNER_CLIPDECK_FIXTURES`, `SIMCTL_CHILD_CLIPDECK_FIXTURES`, `launchEnvironment` for UI tests);
* T-012 AC-2 (`scripts/make-test-media.sh`, `brew install ffmpeg` in the simulator job, `test-ios.sh` export, bootstrap check, `build/fixtures` git-ignored) and AC-3 (every fixture opens with libavformat);
* T-004 AC-5 and AC-6; T-006 AC-7 (seed from fixture 4); T-005 AC-5 and AC-7 (fixtures 1 and 3; seed Episode 2 from fixture 1).

**Planner deviation:** the fixture work went into the new T-012 instead of T-004, because T-004 would have been too large.

### 8. LGPL compliance for public releases
**Finding:** public releases (T-009/T-010) are distribution. They need:
* the licence text and notices bundled in the app (a Settings › About row is enough);
* a link to the exact FFmpegBuild source tag in the release notes and in the app;
* app terms that allow modification and reverse engineering.
Add a CI check that unzips the IPA and finds the notices. The repo has no LICENSE file: ask Brent which licence to use before the repo goes public.

**Resolved in:**
* spec › LGPL compliance, Decisions › Licence handling, Risks › Licence, Acceptance AC-12, Open decisions › App licence (decided by Brent: all rights reserved + LGPL-2.1 §6 clause; T-010 depends on T-012, so the repo goes public only after the licence lands);
* T-012 AC-4 (bundled LGPL text plus notice with source URLs, `THIRD_PARTY_NOTICES.md`), AC-5 (root `LICENSE`: all rights reserved + LGPL-2.1 §6 clause, bundled in the app), AC-6 (`scripts/check-ipa-notices.sh` in the ipa job, including the app licence), AC-7 (Settings › About and licences with the app licence, source links and a UI test).

**Partly open:** the release-notes source link belongs in T-009 (`release.yml`). That task file was outside this revision's allowed files, so the orchestrator should add to T-009: "release notes include the FFmpegBuild 3.16.0 source tag link and point to THIRD_PARTY_NOTICES.md".

### 9. Files picker
**Finding:** use `[.movie, .item]` from the start and check the `.mkv` extension after picking, as subtitles already do.

**Resolved in:** spec › Import, files and lifecycle (Picker); T-006 AC-3 (both the upload and relink pickers, extension check, message text).

## Checked and fine (no change)
* No SwiftData migration is needed.
* Rollback works.
* Relative paths are kept.
* One audio track keeps `ClipExtractor` correct.
* `hvc1` tagging is correct.
* Reading the MKV in place is right.
