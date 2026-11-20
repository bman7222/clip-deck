---
id: T-004
title: Convert an MKV file into a playable MP4 inside the app
lane: backend
depends_on: [T-012]
status: todo
round: 0
base_sha:
issue: 4
spec: .loop/specs/mkv-import.md
model: opus
---

## Convert an MKV file into a playable MP4 inside the app

### What are we building?
Clip Deck can't read MKV files today, because Apple's video framework doesn't understand the Matroska container. This task adds a converter service. It looks inside an MKV (video format, audio tracks, subtitle tracks), decides whether the iPhone can play it, and rewrites it as an MP4 that the existing player, clip cutter and screenshot code already handle. Picture, sound and timings stay lined up exactly as in the source. Nothing changes on screen yet.

### Why?
It is the heart of MKV support: once an MKV becomes a normal MP4, playback, Make a Card and the existing tests keep working unchanged. Getting the timing and threading right here prevents out-of-sync cards and a frozen app later.

### Done when
- AC-1 `MediaProbe` reports everything in the spec's Contracts: pixel format, bit depth, Dolby Vision profile, start time, per-track start offset, channels and sample rate included.
- AC-2 `ConversionPlan` is a pure function of (probe, chosen audio index, `supportsAV1`) that follows the spec's allow-list and audio rules. Unit tests on probe values cover:
  - copied: H.264 `yuv420p`; HEVC Main and Main10 (tagged `hvc1`); Dolby Vision 8.1 (as `hvc1`);
  - rejected with a message naming the format: Dolby Vision 5, 4:2:2, 4:4:4, 12-bit, H.264 10-bit, VP9;
  - AV1 with `supportsAV1` true and false;
  - audio: AAC stereo is copied; AAC 5.1, AC-3, FLAC and Opus are transcoded to AAC-LC stereo 192 kbit/s at most 48 kHz (a 96 kHz FLAC comes out at 48 kHz, 44.1 kHz stays 44.1 kHz);
  - the default audio track is the default-flagged one;
  - zero subtitle tracks and picture-only tracks both give a plan with no warnings.
- AC-3 `MediaConverter.convert` is `@concurrent` (or `Task.detached` around a synchronous core). Every libav pointer stays inside one synchronous function. Cancellation goes through `withTaskCancellationHandler` → an `OSAllocatedUnfairLock<Bool>` read by an `AVIOInterruptCB` and the packet loop. Tests:
  - the core reports it did not run on the main thread;
  - a main-actor heartbeat keeps ticking during a conversion;
  - cancelling mid-way returns within about 1 s and leaves no output file.
  Progress is reported 0 to 1, at most about 10 times a second. It writes only to the output URL it is given.
- AC-4 Timeline rule:
  - MP4 time t equals MKV time t, with no rebasing;
  - start offsets and audio delay become edit lists;
  - packets follow FFmpeg's `remux.c` pattern (rescaled timestamps, valid increasing DTS, interleaved writes);
  - no `+faststart`.
- AC-5 Fixtures 1 to 4 from T-012 (B-frames, HEVC Main10 open GOP with FLAC, 1.0 s offset with delayed AC-3 5.1, no subtitles with AAC 5.1) each convert to an MP4 that:
  - `AVURLAsset` reports playable;
  - has exactly 1 video and 1 audio track;
  - lasts the source duration ±150 ms;
  - gives a 2 s `ClipExtractor` clip (±150 ms) and a screenshot.
  Fixture 5 (Hi10P) is rejected at the plan stage and writes nothing.
- AC-6 Sync tests on fixtures 1 and 3:
  - the screenshot at time t has the colour of the source frame at t (within one frame);
  - beep onsets found with `AVAssetReader` are within 40 ms of their source times.
- AC-7 An MKV with no subtitle tracks, or only picture ones, converts with no error and no warning, and subtitle streams are never written into the MP4 (fixture 4 + AC-2's plan tests).
- AC-8 ARCHITECTURE.md records the concurrency rule and the timeline rule.

### How to check
CI only:
1. `git push origin loop/mkv-landscape-sideload`, then `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload`.
2. `gh run list --branch loop/mkv-landscape-sideload --workflow ios-simulator.yml --limit 3`; `gh run watch <id> --exit-status`; on failure `gh run view <id> --log-failed`.
3. `./scripts/test-ios.sh` (simulator job: converter, plan, sync and concurrency tests plus all existing tests) and `./scripts/build-ipa.sh` (ipa job) pass.
4. `gh run download <id> -n simulator-results -D <scratch>/ci`; check the xcresult lists the new tests as run, not skipped.

### Agent notes
- From T-012 (1489506): the app links six FFmpegBuild products (avformat, avcodec, avutil, swresample, plus dav1d and zvbi, which load at launch). `FFmpegInspector` already wraps opening and probing with libavformat. Build the converter next to it and reuse its patterns (internal import of the Aether modules, error describe()). The only AAC encoder is FFmpeg's native `aac` (no `aac_at`). Fixtures 1-5 are in build/fixtures via CLIPDECK_FIXTURES.
- Depends on: T-012 (libraries, fixtures through `CLIPDECK_FIXTURES`, notices).
- Source: `.loop/specs/mkv-import.md` (Concurrency, Conversion rules, Contracts); review findings 2, 5 and 6 in `.loop/specs/mkv-import.review.md`.
- `SWIFT_APPROACHABLE_CONCURRENCY` makes a plain `nonisolated async` function run on the caller's actor, so it would freeze the UI. Hence `@concurrent`. `Synchronization.Atomic`/`Mutex` need iOS 18; use `OSAllocatedUnfairLock` (`os`).
- HEVC: set `codecpar->codec_tag = MKTAG('h','v','c','1')`. Dolby Vision 8.x: keep the HEVC base layer as `hvc1`.
- AAC encoder: use `aac_at` if `BUILD-INFO.txt` lists it (T-012 notes), else `aac`. Resample with swresample.
- Edit lists: the mp4 muxer's `use_editlist` option; check offsets with `AVURLAsset` track `timeRange`/segments.
- Code in `ios/ClipDeck/Services/Media/`, tests in `ios/ClipDeckTests/`. Staging folders and the move into Documents belong to T-006; here the caller passes the output URL.

### Out of scope
- Subtitle extraction (T-005, optional). The probe still lists subtitle tracks; the plan and converter ignore them.
- `EpisodeImporter`, staging, any UI, relink (T-006).
- Re-encoding video.
