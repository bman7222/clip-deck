---
id: T-004
title: Convert an MKV file into a playable MP4 inside the app
lane: backend
depends_on: []
status: todo
round: 0
base_sha:
issue: 4
spec: .loop/specs/mkv-import.md
model: opus
---

## Convert an MKV file into a playable MP4 inside the app

### What are we building?
Clip Deck can't read MKV files at all today, because Apple's video framework doesn't understand the Matroska container. This task adds an FFmpeg library and a converter service that looks inside an MKV (video codec, audio tracks, subtitle tracks) and rewrites it as an MP4 the existing player, clip cutter and screenshot code already handle. No screen changes yet.

### Why?
It is the foundation for MKV support: once an MKV becomes a normal MP4, playback, Make a Card and all existing tests keep working unchanged.

### Done when
- AC-1 An FFmpeg Swift package is added in `ios/project.yml` (`packages:` + target `dependencies:`), pinned to an exact version, meeting the spec's requirements (LGPL-only build, `ios-arm64` + `ios-arm64-simulator`, maintained). CI is green for tests and the unsigned IPA. Implementation notes record the package, version, licence evidence (build flags or licence file) and the IPA size before and after.
- AC-2 `MediaProbe` reports container, duration, video (codec, profile, bit depth, size), audio tracks (index, codec, language, title, channels, default) and subtitle tracks (index, codec, language, title, default, text or image), as in the spec's Contracts.
- AC-3 `ConversionPlan` is a pure function with unit tests: copies H.264 8-bit and HEVC (tagged `hvc1`); AV1 only when hardware decode is supported; rejects H.264 10-bit, VP9, MPEG-4 ASP and others with a message naming the codec and suggesting a computer conversion; copies AAC/MP3 audio and transcodes everything else to AAC-LC stereo 192 kbit/s; defaults to the file's default audio track.
- AC-4 `MediaConverter.convert` writes an MP4 with exactly one video and one audio track that `AVURLAsset` reports playable, with duration within 150 ms of the source. It runs off the main actor, reports progress 0 to 1, stops within about 1 s on Task cancellation, and deletes its partial output on cancel or failure.
- AC-5 Unit tests build an MKV at test time (MP4 from `TestMediaFactory`, muxed to MKV with FFmpeg), convert it back, and run `ClipExtractor` on the result: a 2 s clip within ±150 ms and a screenshot are written. A cancel test leaves no file behind.
- AC-6 An MKV with no subtitle tracks, or with only picture-based ones (PGS, VobSub), converts with no error and no warning; subtitle streams are never written into the MP4. Tests: a generated MKV with no subtitle streams converts and passes AC-4's checks; a `ConversionPlan` built from a probe with only PGS tracks succeeds with no warnings and no messages.
- AC-7 `THIRD_PARTY_NOTICES.md` at the repo root carries the FFmpeg LGPL-2.1 notice and source link. ARCHITECTURE.md records the dependency and licence.

### How to check
CI only:
1. `git push origin loop/mkv-landscape-sideload`, then `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload`.
2. `gh run list --branch loop/mkv-landscape-sideload --workflow ios-simulator.yml --limit 3`; `gh run watch <id> --exit-status`; on failure `gh run view <id> --log-failed`.
3. `./scripts/test-ios.sh` (simulator job: new converter tests plus all existing tests) and `./scripts/build-ipa.sh` (ipa job) both pass.
4. `gh run download <id> -n ClipDeck-ipa -D <scratch>/ipa` and compare the IPA size with a run from before this task.
5. Read the package's licence/build configuration to confirm no `--enable-gpl`/`--enable-nonfree`.

### Agent notes
- Depends on: None. Brent approved the approach and all defaults on 2026-11-19 (spec status Accepted).
- Source: `.loop/specs/mkv-import.md` (Technical design, Conversion rules, Contracts).
- Do not use `arthenica/ffmpeg-kit` (retired 2025, binaries withdrawn). If no package meets the requirements, stop and report Blocked with what you found.
- Swift 6 with MainActor default isolation: mark FFmpeg-facing types `nonisolated` or make them an actor; keep C pointers inside it; only Sendable values cross.
- Put code in `ios/ClipDeck/Services/Media/`; tests in `ios/ClipDeckTests/`. Generate fixtures in temp folders; no binary files in git.
- If a fixture MKV needs an FFmpeg muxer or encoder the package lacks, build the fixture with stream copy only.

### Out of scope
- Subtitle track extraction and its picker (T-005, optional, delivered last). The probe still lists subtitle tracks; the plan ignores them.
- Any UI, `EpisodeImporter`, upload or relink changes (T-006).
- Re-encoding video.
