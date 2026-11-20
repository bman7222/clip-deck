---
id: T-004
title: Convert an MKV file into a playable MP4 inside the app
lane: backend
depends_on: [T-012]
status: done
round: 2
base_sha: bbbb970e5caaa1b2cf0f2b66f72fed2b3406cb8d
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

## Implementation notes (round 1) · opus
_by loop-backend · 2026-11-20 02:31_
- Changed: AC-1 to AC-8 in one round (no split needed). Nothing compiled (Windows, no Swift toolchain); CI is the first real check. Every FFmpeg declaration used was checked against the FFmpegBuild 3.16.0 simulator-slice headers (`gh api .../contents/Sources/AetherLib*.xcframework/.../Headers/*.h?ref=3.16.0`), and the muxer/demuxer behaviour against the FFmpeg n8.1.3 sources (`libavformat/movenc.c`, `mux.c`, `demux.c`, `libswresample/swresample_frame.c`, `doc/examples/remux.c`, `transcode_aac.c`).
- Files:
  - `ios/ClipDeck/Services/Media/FFmpegSupport.swift` (new): the values of FFmpeg's function-like macros (AVERROR_EOF/EXIT/INVALIDDATA, AVERROR(EAGAIN), MKTAG `hvc1`, AV_NOPTS_VALUE) and its flag bits as plain constants, so nothing depends on Swift importing `(1 << n)` macros. Also `describe`, `metadata`, `seconds`, and `path(url)`, which adds a `file:` prefix so a colon in a file name isn't read as a protocol.
  - `ios/ClipDeck/Services/Media/MediaProbe.swift` (new): `MediaProbe` (Sendable values), plus `MediaProber.read(url:)` (sync) and `load(url:)` (Task.detached).
  - `ios/ClipDeck/Services/Media/ConversionPlan.swift` (new): the pure `ConversionPlan.make(...)` with typed `throws(UnsupportedMediaError)`.
  - `ios/ClipDeck/Services/Media/MediaConverter.swift` (new): `MediaConverter.convert`, `makeStagingFolder`, `MediaConversionError`, `ConversionCancelFlag`, `ProgressThrottle`, `TimestampFixer`, `ConversionCore`, `ConversionSession`.
  - `ios/ClipDeckTests/ConversionPlanTests.swift` (new: plan tests plus helper tests for the throttle and the timestamp fixer) and `ios/ClipDeckTests/MediaConverterTests.swift` (new: fixture tests).
  - `docs/ARCHITECTURE.md`: a diagram node; an "MKV conversion" section with the allow-list, the audio rule, the **Concurrency rule** and the **Timeline rule**; an FFmpegSupport rule; a Decisions row.
  - `FFmpegInspector.swift`, `project.yml` and `make-test-media.sh` are untouched. XcodeGen picks up the new files from the existing `ClipDeck` and `ClipDeckTests` source folders. The tests import no FFmpeg module (ARCHITECTURE rule).
- How each AC is built:
  - AC-1: `MediaProber` reports:
    - the container, duration and start;
    - video: codec, profile (and its name via `av_get_profile_name`; `avcodec_profile_name` is not in these headers), pixel format, bit depth and chroma (from `av_pix_fmt_desc_get`), size, and the Dolby Vision profile, level and compatibility id (`av_packet_side_data_get(codecpar->coded_side_data, …, AV_PKT_DATA_DOVI_CONF)`, where FFmpeg 7+ keeps it), plus start and offset from the container start;
    - audio: index, codec, language, title, channels (`ch_layout.nb_channels`), sample rate, start, offset, isDefault, canDecode;
    - subtitles: index, codec, language, title, isDefault, isText (`AV_CODEC_PROP_TEXT_SUB`).
    Cover-art video streams (`AV_DISPOSITION_ATTACHED_PIC`) are skipped.
  - AC-2: the video rules check chroma and bit depth from the probe. So `yuv420p10le` H.264 gives `.h264TenBit`, and 4:2:2, 4:4:4 and 12-bit each name themselves in the message.
    - HEVC must also be profile Main (1) or Main 10 (2).
    - Dolby Vision profile 5 (or any DV record with compatibility id 0) is rejected. Other DV is copied as the `hvc1` base layer, with the DV record removed from the output codecpar.
    - AV1 only with `supportsAV1`. Every other codec gives `.videoCodec(name)`.
    - Audio: AAC/MP3 with 1-2 channels is copied. Everything else gives `.transcodeToAAC(sampleRate: min(src, 48k) snapped to an AAC rate, channels: 2, bitRate: 192_000)`. The default track is the default-flagged one, else the first.
    - Plans have no subtitle field at all.
  - AC-3: `convert` is a `nonisolated` func. It awaits `Task.detached { ConversionCore.run(...) }` inside `withTaskCancellationHandler`, whose `onCancel` sets `ConversionCancelFlag` (`OSAllocatedUnfairLock<Bool>`).
    - Two places read the same flag. An `AVIOInterruptCB` on both the input and output contexts (a C callback; its opaque pointer is the unretained flag, kept alive with `withExtendedLifetime`) reads it during blocking I/O. The packet loop reads it at the top of every iteration.
    - All libav pointers live in `ConversionSession`, which is created and closed inside `ConversionCore.run`.
    - Progress is 0 after the header is written, then byte position / file size capped at 0.99 (at most every 0.1 s, always rising), then 1 after the trailer.
    - It writes only the output URL. It refuses if the file exists or its folder is missing, and deletes it on any failure or cancel.
    - I used `Task.detached`, not `@concurrent`: the spec allows either, and this doesn't depend on the Swift 6.2 attribute.
  - AC-4: no rebase. Packets are only `av_packet_rescale_ts`'d.
    - The mp4 muxer has `AVFMT_TS_NEGATIVE`, so `avoid_negative_ts` is disabled. With `use_editlist=1`, `mov_write_edts_tag` writes an empty edit for a positive start and trims a negative one.
    - Packets go through `av_interleaved_write_frame`. `TimestampFixer` keeps DTS strictly increasing and PTS ≥ DTS, as `fftools/ffmpeg_mux.c` does (median rule, bump to last+1). Well-formed files pass unchanged.
    - No movflags at all, so no `+faststart`.
    - Transcoded audio: the first decoded frame's `best_effort_timestamp` anchors the output clock, and samples are counted from there.
  - Audio transcode chain:
    - decoder (an UNSPEC layout gets a default layout);
    - `swr_config_frame` and `swr_init` on the first frame, reconfigured once if `swr_convert_frame` fails (a format change mid-stream);
    - `AVAudioFifo` → 1024-sample FLTP frames → the native `aac` encoder (`AV_CODEC_FLAG_GLOBAL_HEADER`, because mp4 has `AVFMT_GLOBALHEADER`);
    - packets rescaled from 1/rate to the stream time base.
    Flush order: the decoder, then the resampler tail, then the short last frame, then the encoder. Damaged audio packets (`AVERROR_INVALIDDATA` from `avcodec_send_packet`) are skipped, as ffmpeg does.
  - HEVC: `codec_tag = MKTAG('h','v','c','1')`; movenc then filters in-band parameter sets (movenc.c:6934). Other streams get `codec_tag = 0` (remux.c). Streams the plan doesn't name get `discard = AVDISCARD_ALL`, so subtitle packets are never even read (AC-7).
  - AC-5/6/7 tests (`MediaConverterTests`, `@MainActor`, `.serialized`):
    - Fixtures 1-4, parameterized:
      - `isPlayable`;
      - exactly 1 video and 1 audio track, 2 tracks in total, and no text, subtitle or closedCaption tracks;
      - duration = video start + 8 s ±150 ms;
      - the first video media segment at the source's first video frame (±1 frame);
      - a ClipExtractor 2 s clip (3.0-5.0 s, ±150 ms) and a screenshot.
    - Per fixture:
      - 1: H.264 with copied AAC, 2 ch, 48 kHz;
      - 2: sample entry `hvc1` (`kCMVideoCodecType_HEVC`) and AAC stereo;
      - 3: an empty first video edit, video media at 1.0 s ±1 frame, audio media at the source audio start ±40 ms, AAC stereo;
      - 4: AAC 5.1 becomes stereo, with no warnings.
    - Fixture 5 is rejected as `.h264TenBit` at the plan stage, and the staging folder stays empty.
    - Sync on fixtures 1 and 3:
      - the colour index at each change ±(1 frame + 10 ms) and at mid-second, via `AVAssetImageGenerator` with zero tolerance;
      - beep onsets from `AVAssetReaderAudioMixOutput` (float stereo 48 kHz; onset = the first sample above 0.05 after 0.5 s of quiet), each within 40 ms of video start + delay + 2k.
  - AC-3 tests:
    - `report.ranOnMainThread == false`;
    - progress starts at 0, ends at 1, strictly rises, stays in 0...1, and has at most 10 reports a second + 3;
    - heartbeat: a main-actor task ticks every 10 ms while the first 4 progress calls sleep 120 ms on the conversion thread (the conversion lasts ≥ 300 ms; ≥ 8 ticks expected);
    - cancel: the first progress call (the output is already open) blocks until the test calls `task.cancel()` and releases it. Expected: `CancellationError` in < 1 s, the output gone, the folder empty;
    - an already-cancelled task gives `CancellationError` and writes nothing.
    - Also: an existing output file is never overwritten, and a plan that no longer matches the file throws `MediaConversionError.sourceChanged` and writes nothing.
- Fixture expectations: nothing in T-012's `make-test-media.sh` or `FFmpegFixtureTests` needed changing. The new tests take "second 0" of each fixture from the probe's video start, so they still hold if Homebrew's ffmpeg shifts a whole file for B-frame delay.
- Checked: every FFmpeg call read against the 3.16.0 headers (above); `grep -c $'\r'` → 0 on all new and edited files (LF).
- Not run: XcodeGen, the Swift build, all tests (CI only, `ci_only: true`).
- Tester, look at:
  - Compile first. The riskiest Swift/C spots (written blind):
    - the `AVIOInterruptCB(callback: { opaque in … }, opaque:)` closure-to-C-pointer conversion (`ConversionSession.interruptCallback`);
    - `withMemoryRebound(to: UnsafeMutableRawPointer?.self, …)` on `extended_data` for `av_audio_fifo_write/read`;
    - `frame.map { UnsafePointer($0) }` for the nullable `const AVFrame *` arguments;
    - `loadUnaligned(as: AVDOVIDecoderConfigurationRecord.self)`;
    - typed throws in `ConversionPlan` (`throws(UnsupportedMediaError)`);
    - `nonisolated static let` on the `@MainActor` test suite.
  - Runtime assumptions most likely to be off:
    1. `AVAssetTrack.segments` shows the empty edit for fixture 3 (`fixture3KeepsItsOffsetsInEditLists`).
    2. `AVAssetReaderAudioMixOutput` timestamps are on the asset timeline with edits applied (both sync tests).
    3. MP4 duration ≈ video start + 8 s. If Homebrew's `-t 8` cuts differently, compare with the logged numbers before changing the bound.
    4. The 18 colour reads per fixture use zero tolerance, so a wrong frame shows up as a colour mismatch with the time in the message.
  - Mutation checks worth doing once it compiles:
    - remove `use_editlist`, or subtract the start time: the fixture-3 tests must fail;
    - drop the `hvc1` tag: the fixture-2 subtype test must fail;
    - call `ConversionCore.run` directly instead of in `Task.detached`: the heartbeat and off-main tests must fail.
  - `ClipExtractorTests.cutsExactAudioAndScreenshot` is the known flake. The new parameterized test also uses ClipExtractor.
- Contract for T-006 (`EpisodeImporter`):
  - `MediaProber.load(url: URL) async throws -> MediaProbe`, which throws `FFmpegError` for unreadable files. `MediaProbe.audioTracks` lists the choices: `streamIndex`, `codec`, `language`, `title`, `channels`, `isDefault`.
  - `ConversionPlan.make(probe:, audioStreamIndex: Int? = nil, supportsAV1: Bool) throws(UnsupportedMediaError) -> ConversionPlan`.
    - Pass `VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)` as `supportsAV1`.
    - `error.message` is the inline text for J-4.
    - `plan.warnings` is empty except for `.noAudioTrack`.
    - `ConversionPlan.defaultAudioTrack(in:)` gives the preselected track.
  - `MediaConverter.makeStagingFolder() throws -> URL` (`tmp/Converting/<uuid>/`), then `MediaConverter.convert(source:, plan:, to: folder/<name>.mp4, progress: @Sendable (Double) -> Void) async throws -> MediaConverter.Report`.
    - Progress arrives off the main actor: `{ value in Task { @MainActor in model.progress = value } }`.
    - To stop (the Cancel button, or J-5 background expiry), cancel the calling task. That throws `CancellationError` and deletes the output.
    - Other errors: `MediaConversionError` (`LocalizedError`): `.failed(FFmpegError)`, `.sourceChanged`, `.outputExists`, `.outputFolderMissing`, `.noAACEncoder`.
  - The converter starts and stops security-scoped access on `source` itself. It does not do the iCloud download, coordinated reads, free-space checks, the move into Documents or the launch sweep (all T-006).
- Gotchas:
  - `yuvj420p` (full-range 8-bit 4:2:0) counts as 4:2:0 8-bit and is allowed for H.264. The spec names only `yuv420p`, but rejecting full-range files would be a false refusal. Say if you want it rejected.
  - Dolby Vision: besides profile 5, any record with base-layer compatibility id 0 is rejected (no playable base layer). Profiles 4, 7 and 8 keep the HEVC base layer.
  - A file with no audio track gives a video-only plan with `.noAudioTrack`. The spec says "exactly one track" but doesn't cover zero, and refusing a playable file seemed worse.
  - Transcoded audio counts samples from the first frame. So an MKV whose audio has gaps (not just a start delay) would drift by the length of the gap. Copied audio is unaffected. Gap filling is a possible follow-up.
  - `MediaConversionError.failed` wraps T-012's `FFmpegError`. `FFmpegInspector` keeps its own private `describe` (unchanged).

## Test report (round 1)
_by loop-tester · 2026-11-20 02:50_

Reviewed `git diff bbbb970..1ecf97a` against `.loop/specs/mkv-import.md` and `mkv-import.review.md`. Results of CI run 44695949361 (headSha 1ecf97a):
- **ipa job: green.** The Release device archive compiled all four new Media files, `check-ipa-notices` passed, and the only warning is the old orientation one.
- **simulator job: red.** The app target compiled cleanly for Debug-iphonesimulator, with 0 errors and 0 new warnings (xcresult build log: "Compiling FFmpegSupport.swift, … MediaConverter.swift, MediaProbe.swift (in target 'ClipDeck')"). Then the test target failed with **1 compile error** (build errorCount = 1), so testing was cancelled ("Testing cancelled because the build failed") and no test ran.

All of the blind C-interop code compiled on the first try. The only error is a Swift Testing macro problem in a test file.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `MediaProbe` reports everything in the spec's Contracts: pixel format, bit depth, Dolby Vision profile, start time, per-track start offset, channels and sample rate included. | Fail (not run) | The fields exist (MediaProbe.swift:103-147) and compile. probeFixture1/2/3/5 never ran because the test bundle didn't build (run 44695949361) |
| AC-2 `ConversionPlan` is a pure function of (probe, chosen audio index, `supportsAV1`) that follows the spec's allow-list and audio rules. Unit tests on probe values cover: copied H.264 `yuv420p`, HEVC Main and Main10 (tagged `hvc1`), Dolby Vision 8.1 (as `hvc1`); rejected with a message naming the format: Dolby Vision 5, 4:2:2, 4:4:4, 12-bit, H.264 10-bit, VP9; AV1 with `supportsAV1` true and false; audio: AAC stereo is copied; AAC 5.1, AC-3, FLAC and Opus are transcoded to AAC-LC stereo 192 kbit/s at most 48 kHz (a 96 kHz FLAC comes out at 48 kHz, 44.1 kHz stays 44.1 kHz); the default audio track is the default-flagged one; zero subtitle tracks and picture-only tracks both give a plan with no warnings. | Fail (not run) | ConversionPlanTests.swift has a test for every listed case (lines 54-247), and its compile job had no errors. It didn't run because the same test bundle failed on MediaConverterTests.swift:82 |
| AC-3 `MediaConverter.convert` is `@concurrent` (or `Task.detached` around a synchronous core). Every libav pointer stays inside one synchronous function. Cancellation goes through `withTaskCancellationHandler` → an `OSAllocatedUnfairLock<Bool>` read by an `AVIOInterruptCB` and the packet loop. Tests: off main thread; main-actor heartbeat; cancel within about 1 s, no output file. Progress 0 to 1, at most about 10 times a second. Writes only to the output URL. | Fail (not run) | The code matches: MediaConverter.swift:35-45 (a detached core inside withTaskCancellationHandler), :79-85 (the OSAllocatedUnfairLock flag), :268-275 (an AVIOInterruptCB on input, output and avio_open2), :436 (the packet-loop check), :182-186 (close, then delete). The tests (MediaConverterTests.swift:285-358) never ran |
| AC-4 Timeline rule: MP4 time t = MKV time t, no rebasing; start offsets and audio delay become edit lists; `remux.c` pattern; no `+faststart`. | Fail (not run) | Code: only `av_packet_rescale_ts` (:461, :626); `use_editlist=1` and no movflags (:423); `av_interleaved_write_frame` (:477). fixture3KeepsItsOffsetsInEditLists never ran. See finding 2 for the DTS repair arithmetic |
| AC-5 Fixtures 1 to 4 each convert to an MP4 that is playable, has exactly 1 video and 1 audio track, lasts the source duration ±150 ms, and gives a 2 s ClipExtractor clip (±150 ms) and a screenshot. Fixture 5 is rejected at the plan stage and writes nothing. | Fail (not run) | convertsToAPlayableMP4 (4 arguments) and fixture5IsRejected… never ran. The fixtures were generated in CI (log 07:34:49-51) |
| AC-6 Sync tests on fixtures 1 and 3: the screenshot at time t has the colour of the source frame at t (within one frame); beep onsets are within 40 ms of their source times. | Fail (not run) | fixture1/3PictureAndSoundStayInSync never ran. No measured offsets exist yet |
| AC-7 An MKV with no subtitle tracks, or only picture ones, converts with no error and no warning, and subtitle streams are never written into the MP4. | Fail (not run) | Code: every unplanned stream gets `discard = AVDISCARD_ALL` (:300-302), and the plan has no subtitle field. The tests never ran |
| AC-8 ARCHITECTURE.md records the concurrency rule and the timeline rule. | Pass (docs), with finding 3 | docs/ARCHITECTURE.md:144 "**Concurrency rule.**" and :146 "**Timeline rule.**" are present and match the code. But the edit deleted the `## Decisions` heading (finding 3) |

### Findings

**1. Must fix: the test target does not compile**
Where: ios/ClipDeckTests/MediaConverterTests.swift:82
Problem: in `#expect(probe.subtitleTracks.allSatisfy(\.isText))`, Swift Testing expands the expression to `$0.allSatisfy($1)` with a throwing argument closure. The exact compiler message: `@__swiftmacro_13ClipDeckTests0030MediaConverterTestsswift_eDAEifMX81_8_6expectfMf14_.swift:2:3: error: call can throw, but it is not marked with 'try' and the error is not handled`, with the note `call is to 'rethrows' function, but argument function can throw` (in expansion of macro 'expect' at MediaConverterTests.swift:82:9).
Proof: Ran it. CI 44695949361, simulator job, "Unit and UI tests" step, exit 65. The xcresult build errorCount is 1.
Trigger: every build of the test target.
Fix: **the tester already applied it in the working tree (uncommitted, test file only)**: `#expect(probe.subtitleTracks.allSatisfy { $0.isText })`. That is the form that already compiles at AnkiTests.swift:171 and MediaConverterTests.swift:298. Builder: keep it.
Likely next errors: none at the type level.
- The type-check of MediaConverterTests.swift reported only this error.
- ConversionPlanTests.swift's compile job was clean.
- The app target compiled for both Debug-sim and Release-device.

SIL-stage diagnostics only appear once type-checking passes. The only plausible one is a region-isolation "sending" diagnostic on `generator.image(at:)`, called from the @MainActor `colourIndex` (MediaConverterTests.swift:444). `@preconcurrency import AVFoundation` should keep that a warning at most. The real risk is now at runtime: see the builder's list (segments for fixture 3's empty edit, the AVAssetReader timeline, durations).

**2. Should fix: Int64 overflow traps on untrusted timestamps crash the app**
Where: ios/ClipDeck/Services/Media/MediaConverter.swift:122 (`lastDTS.map { $0 + 1 }`), :131-132 (`lastDTS + 1` and `p + d + next - min - max`), :140 (`lastDTS + 1`), :609 (`pts + Int64(count)`).
Problem: these lines use Swift's trapping `+` on timestamps that come straight from the file:
- `av_packet_rescale_ts` uses `AV_ROUND_PASS_MINMAX`, so an `INT64_MAX` timestamp passes through unchanged.
- A Matroska block time is an unsigned cluster time (up to 8 bytes) plus an int16 offset, so the file controls these values.
- The C code this copies (fftools/ffmpeg_mux.c) only wraps on overflow. Swift aborts the process instead.

So a crafted or corrupt MKV crashes Clip Deck during import instead of failing with a message.
Proof: Traced. Take a cluster timestamp of 0x7FFFFFFFFFFFFFFF with two blocks at relative time 0. Packet 1 has pts = dts = Int64.max, which sets `lastDTS = .max`. Packet 2 then hits `d <= lastDTS`, and `lastDTS + 1` traps. The median sum `p + d + next` already overflows for values from about 2^62. I added no test for this: on the current code it would crash the whole test run, and Swift Testing exit tests aren't available on iOS.
Trigger: a malformed or hostile MKV picked in Files.
Fix (also apply it to `nextAudioPTS`):
- Use wrapping or saturating arithmetic. Compute the median by comparison: `max(min(p, d), min(max(p, d), next))`.
- Better: reject a timestamp whose magnitude is above a sane bound (for example `abs > 1 << 60` in the output time base) with `MediaConversionError.failed(... AVERROR_INVALIDDATA)`.
- Add ConverterHelperTests that call `fix(pts: .max, dts: .max)` twice, and `fix(pts: .max - 1, dts: .max)` after a near-max packet, and expect no trap.

**3. Should fix: ARCHITECTURE.md lost its `## Decisions` heading**
Where: docs/ARCHITECTURE.md:147 (between the Timeline rule paragraph and the `| Area | Decision | Why |` table)
Problem: the diff replaced the `## Decisions` line with the new `### MKV conversion` section. The project-wide decisions table (ATS, builds without a Mac, testing media, …) now sits under "MKV conversion (`Services/Media/`)", and the document has no Decisions section any more (`grep -n '^#' docs/ARCHITECTURE.md`).
Proof: Read it. `git diff bbbb970..1ecf97a -- docs/ARCHITECTURE.md`, hunk @@ -121.
Trigger: anyone reading the doc.
Fix: put `## Decisions` back above the table.

**4. Could fix: any audio decode error except INVALIDDATA from send_packet aborts the whole import**
Where: ios/ClipDeck/Services/Media/MediaConverter.swift:504-505, :514
Problem: `avcodec_send_packet` errors other than INVALIDDATA, and any `avcodec_receive_frame` error, fail the conversion. The ffmpeg CLI logs decode errors and skips them (unless `-xerror` is set). So one damaged audio frame in a long episode loses the whole import.
Proof: Read it.
Fix: skip non-fatal decode errors (everything except ENOMEM and EXIT), perhaps up to a cap.

**5. Could fix: `MediaProber.load` can't be cancelled**
Where: ios/ClipDeck/Services/Media/MediaProbe.swift:164-184
Problem: it has no interrupt callback and no cancellation handler, so a slow probe (a large or remote file) can't be stopped. This matters for T-006's prepare step.
Proof: Read it.
Fix: reuse `ConversionCancelFlag` and the interrupt callback.

Notes (no change requested):
- A correction to the suggested mutation check: removing `use_editlist` would **not** make the fixture-3 tests fail. movenc's default is auto (-1), which becomes 1 for non-fragmented MP4. The useful mutation is `use_editlist=0`. That also makes the muxer use `avoid_negative_ts=make_zero`, which rebases the timeline.
- The spec deviations the builder disclosed are Brent's call: `yuvj420p` is accepted for H.264, and a file with no audio gives a `.noAudioTrack` warning instead of being rejected.
- The mutation checks (no use_editlist, no hvc1 tag, running the core inline) weren't done because no test has run yet.

```text
VERDICT: Fail
SPEC: AC-8 met (the Decisions heading was lost); AC-1 to AC-7 are implemented and compile but are unproven, because the test bundle failed to build and no test ran
CHECKS_RUN: CI 44695949361 (1ecf97a): ipa job pass (build-ipa.sh + check-ipa-notices.sh); simulator job fail (test-ios.sh: 1 compile error at MediaConverterTests.swift:82, testing cancelled, 0 tests run); xcresult build log read (app target: 0 errors, 0 new warnings)
UNVERIFIED: every runtime value (sync offsets, segments, durations, heartbeat ticks, cancel latency) until a run with the test fix; device-only (Brent): HEVC 10-bit and Dolby Vision playback, real-world MKVs
REVIEWED_AT: 1ecf97a7cf081123c2408dfc358e80c7abc08522 (+ the tester's uncommitted one-line test fix)
```

## Fix round 2
_orchestrator · 2026-11-20 · sent the round-1 Test report findings to the same loop-backend (opus): Must fix (test compile error, already fixed by the tester), 2 Should fix (Int64 overflow on malformed timestamps; the lost ## Decisions heading), 2 Could fix (skip audio decode errors; make MediaProber.load cancellable for T-006)._

## Implementation notes (round 2) · opus
_by loop-backend · 2026-11-20_
- Changed: all 5 round-1 findings. Nothing compiled locally (no Swift toolchain); CI is the check.
- Findings:
  1. Must fix, test compile error (MediaConverterTests.swift:82): kept the tester's `allSatisfy { $0.isText }`. I checked the other `#expect`s for a top-level call with a key-path argument; there are none (the `map(\.x) == …` ones sit inside a comparison, which compiled in round 1). The new tests hoist mutating and `inout` calls out of `#expect`.
  2. Should fix, Int64 overflow (MediaConverter.swift):
     - `TimestampFixer.fix` now `throws(TimestampOutOfRange)` for any PTS or DTS beyond ±2^60 (`TimestampFixer.limit`; that is 36,000+ years even at 1 GHz).
     - The median is found by comparison: `max(min(p, d), min(max(p, d), next))`, the same value as ffmpeg_mux.c's sum formula.
     - The only addition left is `lastDTS &+ 1`.
     - `write()` turns the throw into `MediaConversionError.damagedFile("a timestamp is out of range: …")`, whose message reads "This video file looks damaged (…). Try another copy of the file." The output is then deleted as on any failure.
     - The transcoded-audio anchor (`av_rescale_q` of the first frame's timestamp) is bounds-checked the same way, and `nextAudioPTS` now advances with `&+`.
     - New tests, in ConverterHelperTests, run with no trap:
       - `.max`, `.min`, `.max - 1`, `.min + 1` and ±(limit + 1), each twice in a row, as PTS+DTS, DTS only and PTS only;
       - `.max`/`.min` after a packet at the limit;
       - bumping and the median at the limit (limit + 1, + 2, + 3);
       - the damaged-file message.
  3. Should fix: `## Decisions` is restored in docs/ARCHITECTURE.md (line 148), between the MKV conversion section and the table.
  4. Could fix, audio decode errors: `avcodec_send_packet` (including the flush) and `avcodec_receive_frame` errors are skipped, as ffmpeg does. ENOMEM, AVERROR_EXIT and cancellation stay fatal.
     - A failed `receive_frame` ends the drain for that packet, so the loop can't spin.
     - `DecodeErrorBudget` (pure, unit-tested) gives up only past 50 errors that are also more than 1 in 10 audio packets. The import then fails with `.damagedFile("N of M audio packets can't be decoded; last error: …")`.
     - The skipped count is reported in `Report.warnings` as `.skippedDamagedAudio(count)`, with a `message`. The fixture tests assert `report.warnings` is empty.
  5. Could fix, cancellable probe: the interrupt callback moved onto `ConversionCancelFlag.interruptCallback()` and is shared by the converter and the prober.
     - `MediaProber.read(url:cancel:)` (`cancel` defaults to a fresh flag) allocates the context with the callback and maps any failure while the flag is set to `CancellationError`.
     - `load(url:)` wraps the detached read in `withTaskCancellationHandler`.
     - New tests:
       - `cancellingAProbeThrowsCancellationError`: a task cancelled before it starts;
       - `aSetCancelFlagStopsTheProbe`: the synchronous core with a set flag throws `CancellationError`, and then the same file probes fine with a fresh flag.
- Correction to my round-1 mutation list (thanks, tester): leaving `use_editlist` out changes nothing, because movenc's auto default is 1 for non-fragmented MP4. The mutation that must make the fixture-3 and no-rebase tests fail is `use_editlist=0`. That also makes movenc set `avoid_negative_ts=make_zero`, which rebases the timeline.
- Files:
  - ios/ClipDeck/Services/Media/MediaConverter.swift: `Report.warnings`, `MediaConverter.Warning`, `.damagedFile`, `ConversionCancelFlag.interruptCallback()`, `TimestampOutOfRange`, the bounded `TimestampFixer`, `DecodeErrorBudget`, `skipDecodeError`;
  - ios/ClipDeck/Services/Media/MediaProbe.swift: cancellable read and load;
  - ios/ClipDeckTests/ConversionPlanTests.swift: the fixer tests now `throws`/`try`; overflow, budget and message tests;
  - ios/ClipDeckTests/MediaConverterTests.swift: the tester's line 82 fix, 2 probe-cancel tests, and `report.warnings.isEmpty` in the fixture test;
  - docs/ARCHITECTURE.md: the heading; probe cancel, skipped audio and the timestamp bound added to the MKV section.
- Checked: re-traced every new fixer case by hand against the code (the expected values are in the tests). `grep -c $'\r'` → 0 on all changed files. Not run: build and tests (CI only).
- Tester, look at:
  - `catch` in `ConversionSession.write` is deliberately untyped and interpolates the error, so it compiles without a warning whether or not Swift infers the typed error.
  - `withExtendedLifetime(cancel) { … }` in `MediaProber.read` has a multi-statement throwing closure that returns `MediaProbe`.
  - `for _ in 0..<n where !budget.recordError()` calls a mutating method in a `where` clause.
  - Mutation checks once tests run: `use_editlist=0`; no `hvc1` tag; `ConversionCore.run` called inline. Also try removing the range check in `fix`: the extreme-value test should then crash the run.
- Contract changes for T-006: `MediaConverter.Report.warnings: [MediaConverter.Warning]` (show `.message` after an import that had damaged audio); new `MediaConversionError.damagedFile(String)`; `MediaProber.load` is now cancellable. Nothing else changed.

## Test report (round 2)
_by loop-tester · 2026-11-20 03:25_

Reviewed `git diff 1ecf97a..60857c0 -- ios docs`. f9e7796, the CI workflow inputs, is not part of T-004 and was not reviewed. CI run 44698930097 (headSha 60857c0, dispatched with scope=tests) passed. The simulator job was green and the ipa job was skipped on purpose (round 1's run 44695949361 compiled Release).
- test-ios.sh printed "Tests passed". The xcresult (`database.sqlite3`) has **144 test-case runs: 144 Success, 0 TestIssues, 0 SkipNotices**. Every T-004 test is listed as run: 35 ConversionPlanTests (9 audio arguments), 13 ConverterHelperTests, 23 MediaConverterTests (convertsToAPlayableMP4 × 4). The 7 T-012 FFmpegFixtureTests and the known ClipExtractor flake also passed.
- Build issues: 4 warnings, all in the test target ("conditional cast … always succeeds"). The app target has none.
- run-ios.sh ran; the launch screenshot is in the artifact (T-004 changes nothing on screen).
- **The measured values were not recorded.** Swift Testing writes values only into failure messages, and these tests attach nothing. So the evidence is "each tolerance below was asserted and held". The xcresult per-test durations give upper bounds: cancellingMidway… took 0.012 s in total, so the cancel latency is < 12 ms. mainActorKeepsTicking… took 0.514 s (≥ 300 ms of conversion asserted). fixture3PictureAndSoundStayInSync took 0.665 s.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `MediaProbe` reports everything in the spec's Contracts: pixel format, bit depth, Dolby Vision profile, start time, per-track start offset, channels and sample rate included. | Pass | CI 44698930097: probeFixture1/2/3StartAndAudioOffset/5 pass. They assert pixel format (yuv420p, yuv420p10le), bit depth 8/10, chroma, size, `dolbyVision == nil`, profile 2 and 110, container start 1.0 ±0.05, audio offset 0.5 ±0.05, channels 2/6, sample rate 48 000, and the subtitle codec, language, title and isText. Dolby Vision fields are covered by the plan tests on probe values |
| AC-2 `ConversionPlan` is a pure function of (probe, chosen audio index, `supportsAV1`) that follows the spec's allow-list and audio rules. Unit tests on probe values cover: copied H.264 `yuv420p`, HEVC Main and Main10 (tagged `hvc1`), Dolby Vision 8.1 (as `hvc1`); rejected with a message naming the format: Dolby Vision 5, 4:2:2, 4:4:4, 12-bit, H.264 10-bit, VP9; AV1 with `supportsAV1` true and false; audio: AAC stereo is copied; AAC 5.1, AC-3, FLAC and Opus are transcoded to AAC-LC stereo 192 kbit/s at most 48 kHz (a 96 kHz FLAC comes out at 48 kHz, 44.1 kHz stays 44.1 kHz); the default audio track is the default-flagged one; zero subtitle tracks and picture-only tracks both give a plan with no warnings. | Pass | CI 44698930097 ran each of these as its own test, all Success: copiesH264yuv420p, copiesHEVCMainAsHVC1, copiesHEVCMain10AsHVC1, copiesDolbyVision81AsHVC1BaseLayer, rejectsDolbyVisionProfile5, rejects422, rejects444, rejects12Bit, rejectsH264TenBit, rejectsVP9, av1IsCopiedOnlyWhenTheDeviceDecodesIt, aacStereoIsCopied, otherAudioIsTranscodedToStereoAAC (aac 6ch, ac3 6ch, eac3, flac 96 kHz, flac 44.1 kHz, opus, vorbis, truehd, mp3 6ch), outputSampleRates, defaultAudioIsTheDefaultFlaggedTrack, zeroSubtitleTracksGiveNoWarning, pictureOnlySubtitleTracksGiveNoWarning |
| AC-3 `MediaConverter.convert` is `@concurrent` (or `Task.detached` around a synchronous core). Every libav pointer stays inside one synchronous function. Cancellation goes through `withTaskCancellationHandler` → an `OSAllocatedUnfairLock<Bool>` read by an `AVIOInterruptCB` and the packet loop. Tests: the core reports it did not run on the main thread; a main-actor heartbeat keeps ticking during a conversion; cancelling mid-way returns within about 1 s and leaves no output file. Progress is reported 0 to 1, at most about 10 times a second. It writes only to the output URL it is given. | Pass | CI 44698930097, all Success: coreRunsOffTheMainThreadAndReportsThrottledProgress (`ranOnMainThread == false`; first 0, last 1, strictly rising, ≤ 10/s + 3), mainActorKeepsTickingDuringAConversion (≥ 8 ticks over ≥ 300 ms), cancellingMidwayStopsWithinASecondAndLeavesNoFile (CancellationError, < 1 s, file and folder gone; the whole test took 0.012 s), alreadyCancelledTaskWritesNothing, refusesToOverwriteAnExistingFile, aPlanThatNoLongerMatchesTheFileFailsAndWritesNothing. Structure read in MediaConverter.swift:49-59, 96-113, 244-246, 507. See Could fix 2 (no test isolates the interrupt callback) |
| AC-4 Timeline rule: MP4 time t equals MKV time t, with no rebasing; start offsets and audio delay become edit lists; packets follow FFmpeg's `remux.c` pattern (rescaled timestamps, valid increasing DTS, interleaved writes); no `+faststart`. | Pass | fixture3KeepsItsOffsetsInEditLists: the first video segment is empty, video media starts at 1.0 s ±1 frame, and audio media is within 40 ms of the source audio start. convertsToAPlayableMP4 × 4: the MP4's first video frame is within 1 frame of the source's. The ConverterHelperTests timestamp tests pass (B-frames unchanged, negative start kept, bump, median, fill). Code: `av_packet_rescale_ts` only, `av_interleaved_write_frame`, `use_editlist=1`, no movflags (MediaConverter.swift:494, 532, 555) |
| AC-5 Fixtures 1 to 4 from T-012 (B-frames, HEVC Main10 open GOP with FLAC, 1.0 s offset with delayed AC-3 5.1, no subtitles with AAC 5.1) each convert to an MP4 that: `AVURLAsset` reports playable; has exactly 1 video and 1 audio track; lasts the source duration ±150 ms; gives a 2 s `ClipExtractor` clip (±150 ms) and a screenshot. Fixture 5 (Hi10P) is rejected at the plan stage and writes nothing. | Pass | convertsToAPlayableMP4 ran for all 4 fixtures (Arguments table: 01, 02, 03, 04), all Success. It asserts: playable; 1 video, 1 audio, 2 tracks in total; duration = video start + 8 s ±0.15; a 3.0-5.0 s clip at 2000 ±150 ms; a non-empty JPEG. Per fixture: fixture1CopiesH264AndAAC, fixture2TagsHEVCAsHVC1AndTranscodesFLAC (sample entry hvc1), fixture4AAC51BecomesStereoAndHasNoWarnings. fixture5IsRejectedAtThePlanStageAndWritesNothing (`.h264TenBit`, empty folder) |
| AC-6 Sync tests on fixtures 1 and 3: the screenshot at time t has the colour of the source frame at t (within one frame); beep onsets found with `AVAssetReader` are within 40 ms of their source times. | Pass | fixture1PictureAndSoundStayInSync and fixture3PictureAndSoundStayInSync: Success. They make 18 zero-tolerance colour reads per fixture, at every change ±(1 frame + 10 ms) and at mid-second. The onset count equals the expected count, and every onset is within 0.04 s. The expected times match make-test-media.sh:83 and 117-119 (beeps at even seconds; fixture 3 has `-itsoffset 0.5` and `-output_ts_offset 1`, so beeps at 1.5/3.5/5.5/7.5 s). The exact offsets were not recorded (passing expectations have no values) |
| AC-7 An MKV with no subtitle tracks, or only picture ones, converts with no error and no warning, and subtitle streams are never written into the MP4 (fixture 4 + AC-2's plan tests). | Pass | fixture4AAC51BecomesStereoAndHasNoWarnings and convertsToAPlayableMP4("04-…"): `plan.warnings` and `report.warnings` are empty. For all 4 fixtures (1 and 3 carry SRT/ASS) there are exactly 2 tracks and no text, subtitle or closedCaption track. zeroSubtitleTracks…/pictureOnlySubtitleTracksGiveNoWarning pass |
| AC-8 ARCHITECTURE.md records the concurrency rule and the timeline rule. | Pass | docs/ARCHITECTURE.md:131 "### MKV conversion", the Concurrency and Timeline rule paragraphs, and `## Decisions` restored at :148 (`grep -n '^#'`). The round-2 additions (cancellable probe, skipped audio, the ±2^60 bound) match the code |

Round-1 findings:
1. Must fix (test compile error): **fixed.** The test target built and all 144 runs passed.
2. Should fix (Int64 overflow traps): **fixed.**
   - MediaConverter.swift:164-197 now rejects |ts| > 2^60 before any arithmetic, finds the median by comparison, and bumps with `&+`.
   - The audio anchor is bounded (:629) and the sample count advances with `&+` (:712).
   - The only other `+` left is on packet counters.
   - The probe's offset math is Double.
   - extremeTimestampsAreRejectedWithoutATrap, extremeValueAfterANearLimitPacketIsRejected and repairsAtTheLimitDoNotTrap ran with no trap (CI 44698930097).
3. Should fix (`## Decisions` heading): **fixed** (ARCHITECTURE.md:148).
4. Could fix (decode errors): **done.** skipDecodeError (MediaConverter.swift:593-601); decodeErrorsAreSkippedUntilTheTrackLooksBroken passes. The fixture tests assert `report.warnings` is empty.
5. Could fix (cancellable probe): **done.** MediaProbe.swift:331-379; cancellingAProbeThrowsCancellationError and aSetCancelFlagStopsTheProbe pass.

Mutation checks: traced against FFmpeg's movenc.c, not run. Running them would cost CI dispatches the budget doesn't have.
- `use_editlist=0`: movenc writes no `edts` box when use_editlist is 0 (it only logs "Not writing any edit list even though one would have been required"), and it sets `avoid_negative_ts=make_zero`, which rebases the start to 0. Then fixture3KeepsItsOffsetsInEditLists fails on `videoSegments.first?.isEmpty` and on video start 1.0 ±1 frame, and convertsToAPlayableMP4("03-…") fails on its first-frame check.
- No `hvc1` tag: movenc's default HEVC sample entry is `hev1`, so fixture2's `subtype == kCMVideoCodecType_HEVC` ('hvc1') fails.
- Running `ConversionCore.run` inline: under approachable concurrency, `convert` runs on the test's main actor. That gives `ranOnMainThread == true`, and the heartbeat can't tick during the conversion, so both tests fail.
- Removing the range check in `fix`: `Int64.max` is accepted, so `first == expected` fails. Because of `&+` and the comparison median, there is no crash.

### Findings

**1. Could fix: 3 new test-target warnings, "conditional cast … always succeeds"**
Where: ios/ClipDeckTests/ConversionPlanTests.swift:345 (new this round, `return error as? TimestampOutOfRange`), and :39 and :216 (`as? UnsupportedMediaError`, from round 1)
Problem: with typed throws, `error` already has the concrete type, so the cast is a no-op and Xcode warns (4 BuildIssues in the xcresult).
Proof: Ran it. CI 44698930097 log, 08:01:55.
Fix: use `error` directly (for example `return error` and `#expect(error == .audioChoice(0))`). Test files only.

**2. Could fix: no test proves the AVIOInterruptCB itself stops libavformat**
Where: ios/ClipDeckTests/MediaConverterTests.swift:392-404 (aSetCancelFlagStopsTheProbe), ios/ClipDeck/Services/Media/MediaProbe.swift:359
Problem: aSetCancelFlagStopsTheProbe would also pass with a callback that never fires, because `read` checks the flag again after `avformat_find_stream_info` and throws CancellationError. The mid-way cancel test stops through the packet-loop check. So the AC-3 mechanism "read by an AVIOInterruptCB" is shown by code reading only.
Proof: Traced. With a dead callback, open and find_stream_info succeed, and :359 throws the same error.
Fix: add a test that calls `ConversionCore.run` directly with an already-set flag and a progress recorder, and expects CancellationError, **no progress calls**, and an empty folder. If the callback works, the input open fails before the header is written. If it doesn't, the header is written and `progress(0)` is called before the packet loop throws.

**3. Could fix: passing runs keep no measured values**
Where: ios/ClipDeckTests/MediaConverterTests.swift (checkSync, convertsToAPlayableMP4, the heartbeat and cancel tests)
Problem: the AC-6 onset errors, durations, segment starts, tick counts and cancel latency appear only in failure messages, so a green run can't show how close each one is to its bound.
Fix: record them with `Attachment.record("…", named:)` (Swift Testing, Xcode 26), or collect them into one text attachment per test.

Notes:
- The spec deviations from round 1 are still Brent's call: `yuvj420p` is accepted for H.264, and a file with no audio gets a `.noAudioTrack` warning instead of being rejected.
- No tests were added by the tester this round. Writing tests for Could fix 2 or 3 would need another CI dispatch, and the verdict doesn't depend on them.

```text
VERDICT: Pass
SPEC: AC-1 to AC-8 met, each with a test that ran and passed in CI 44698930097; all 5 round-1 findings fixed
CHECKS_RUN: CI 44698930097 (60857c0, scope=tests): simulator job pass (test-ios.sh "Tests passed": 144/144 Success, 0 issues, 0 skips; run-ios.sh pass); ipa job skipped by design (Release compile proven in 44695949361); xcresult database.sqlite3 queried for per-test results, arguments and build issues
UNVERIFIED: the exact measured values (not recorded on passing runs; bounds only); the mutation checks (traced, not run); device only (Brent): HEVC 10-bit and Dolby Vision playback of converted files, real-world MKVs, conversion time and memory on a phone
REVIEWED_AT: 60857c0a1871f95b099c6272fc3c04eb139cb3ce
```
