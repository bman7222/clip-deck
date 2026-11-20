---
id: T-012
title: Add the FFmpeg libraries, the test MKVs and the licence notices
lane: fullstack
depends_on: []
status: todo
round: 0
base_sha:
issue: 12
spec: .loop/specs/mkv-import.md
model:
---

## Add the FFmpeg libraries, the test MKVs and the licence notices

### What are we building?
MKV support needs three foundations before any conversion code. This task adds them:
- the FFmpeg libraries (an LGPL build), linked into the app;
- a set of test MKV files that CI generates fresh on every run, covering the tricky cases;
- the FFmpeg licence and notices, shipped inside the app and shown under Settings › About and licences.

After it, the app builds with FFmpeg inside, and CI proves each test file can be opened.

### Why?
The converter (T-004) needs working libraries and realistic test files. And once releases go public, FFmpeg's licence requires its text and source links in the app. Doing this first means a broken package or licence problem shows up before any feature depends on it.

### Done when
- AC-1 (backend) `ios/project.yml` adds `superuser404notfound/FFmpegBuild` with `exactVersion: 3.16.0`. The app target links only `AetherLibavformat`, `AetherLibavcodec`, `AetherLibavutil` and `AetherLibswresample`. Implementation notes quote the package's `BUILD-INFO.txt` lines showing every required component from the spec (matroska demuxer, mov/mp4 muxer, the listed audio decoders, an AAC encoder, swresample, the h264/hevc/av1 parsers) and the absence of `--enable-gpl`, `--enable-version3` and `--enable-nonfree`. Also record the IPA size before and after, and whether the binaries are in the package's git repo or URL assets (spec › Supply-chain plan). If anything required is missing, stop and report Blocked.
- AC-2 (backend) A new `scripts/make-test-media.sh` uses Homebrew `ffmpeg` to write the five fixtures from the spec's Tests section into `build/fixtures/`: solid colour per second plus beeps at known times. `scripts/test-ios.sh` runs it first (failing early with "brew install ffmpeg" if `ffmpeg` is missing) and exports `TEST_RUNNER_CLIPDECK_FIXTURES`. The `simulator` job in `.github/workflows/ios-simulator.yml` runs `brew install ffmpeg` before the tests; `scripts/bootstrap.sh` checks for it. No media files in git.
- AC-3 (backend) A unit test opens every fixture with libavformat (`avformat_open_input` + `avformat_find_stream_info`) and checks its stream list (codecs, track counts, the 1.0 s start time of fixture 3). This proves the libraries link and run in the simulator.
- AC-4 (backend) The app bundles `Licenses/FFmpeg-LGPL-2.1.txt` and a notice naming FFmpeg n8.1.3, FFmpegBuild 3.16.0 and their source URLs (the exact FFmpegBuild tag and the FFmpeg source release). `THIRD_PARTY_NOTICES.md` at the repo root says the same.
- AC-5 (backend) A root `LICENSE` file, in plain words:
  - "Copyright (c) 2026 Brent. All rights reserved." Nobody may copy, reuse, modify or redistribute the Clip Deck code or app.
  - One exception, required by LGPL-2.1 §6: anyone may modify the app and reverse engineer it, but only to debug their own modifications to the bundled FFmpeg libraries, and may replace those libraries with modified versions.
  - A note that FFmpeg itself stays under LGPL-2.1 (see `THIRD_PARTY_NOTICES.md`).
  - A first line marked "Not legal advice; written for personal use, review before any wider release."
  The same text is bundled into the app as `Licenses/ClipDeck-LICENSE.txt`.
- AC-6 (backend) The `ipa` job runs a new `scripts/check-ipa-notices.sh`. It unzips `build/ipa/ClipDeck.ipa` and fails unless all three are inside `Payload/ClipDeck.app`: the bundled LGPL text (containing "GNU LESSER GENERAL PUBLIC LICENSE"), the notice with the FFmpegBuild tag URL, and the Clip Deck licence (containing "All rights reserved").
- AC-7 (frontend) Settings (the gear sheet) gets an "About and licences" row (`settings.about`). It opens a screen with:
  - the app version;
  - the Clip Deck licence from `LICENSE` (`about.appLicense`);
  - the FFmpeg notice;
  - the full LGPL-2.1 text (scrollable);
  - tappable source links (`about.ffmpegSource`, `about.ffmpegBuildSource`).
  A UI test opens it, checks the Clip Deck licence and the LGPL text are shown, and attaches `about-01-licences`.
- AC-8 Docs: ARCHITECTURE.md (dependency, version, checksums or URLs, licence), DEVELOPMENT.md (`brew install ffmpeg` for tests, the fixtures, `CLIPDECK_FIXTURES`).

### How to check
CI only:
1. `git push origin loop/mkv-landscape-sideload`, then `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload`.
2. `gh run list --branch loop/mkv-landscape-sideload --workflow ios-simulator.yml --limit 3`; `gh run watch <id> --exit-status`; on failure `gh run view <id> --log-failed`.
3. The simulator job (`./scripts/test-ios.sh`, including the fixture-opening test and the About UI test) and the ipa job (`./scripts/build-ipa.sh` + `scripts/check-ipa-notices.sh`) pass.
4. `gh run download <id> -n simulator-results -D <scratch>/ci`; read `screenshots/ui-tests/*about-01*`. `gh run download <id> -n ClipDeck-ipa -D <scratch>/ipa`; compare its size with a run from before this task.
5. Read the quoted `BUILD-INFO.txt` lines against the spec's list.

### Agent notes
- Depends on: None. Spec: `.loop/specs/mkv-import.md` (FFmpeg package, Tests, LGPL compliance); review: `.loop/specs/mkv-import.review.md` findings 1, 7 and 8.
- LICENSE wording: Brent chose "All rights reserved + LGPL clause". Keep it short and plain; don't add other permissions. T-010 waits for this file before the repo goes public.
- Backend implementer first (package, scripts, CI, bundled files, fixture test), then frontend (About screen).
- XcodeGen: `packages: FFmpegBuild: {url: …, exactVersion: 3.16.0}` and target `dependencies: - package: FFmpegBuild, product: AetherLibavformat` (one entry per product). Dynamic xcframeworks are embedded automatically.
- Fixture recipes: lavfi `color` + `sine`/`aevalsrc` sources; `-bf 2` for B-frames; `libx265 -x265-params open-gop=1 -pix_fmt yuv420p10le`; `-output_ts_offset 1` plus `-itsoffset 0.5` on the audio; `-c:a flac`/`ac3 -ac 6`/`aac -ac 6`; `-c:s srt`/`ass` from text files written by the script; `libx264 -pix_fmt yuv420p10le` for Hi10P. Keep each fixture at 6 to 10 s and small.
- Simulator processes can read the Mac's file system, so the absolute `build/fixtures` path works in tests.
- Don't touch `ios/ClipDeckUITests/PlayerLandscape*` (T-001 is in progress).

### Out of scope
- Probe, plan and conversion code (T-004).
- Mirroring or forking the package (the orchestrator does it with Brent's OK if the spec's supply-chain check says so).
- Choosing a different licence (Brent decided 2026-11-19: all rights reserved + the LGPL clause).
