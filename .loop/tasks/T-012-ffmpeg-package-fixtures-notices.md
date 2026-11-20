---
id: T-012
title: Add the FFmpeg libraries, the test MKVs and the licence notices
lane: fullstack
depends_on: []
status: done
round: 2
base_sha: f68c5b98f18f009b135b200dcc6359fc73829ab5
issue: 12
spec: .loop/specs/mkv-import.md
model: opus
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

## Implementation notes (round 1, backend) · sonnet
_by loop-backend · 2026-11-19_
- Changed: AC-1 to AC-6 and the backend part of AC-8. Nothing compiled (Windows); CI is the first real check.
- **Package facts, read from the raw files at tag 3.16.0** (`gh api repos/superuser404notfound/FFmpegBuild/...`):
  - Tag 3.16.0 is commit `7de456f9b6efea4d6c8c6617cc77e7c79cb1e280`; repo licence LGPL-2.1; the GitHub release has no assets.
  - `Package.swift` uses `.binaryTarget(name:, path: "Sources/AetherLibX.xcframework")`. **The binaries are committed in the package's git repo, with no download URLs and no SPM checksums.** Supply-chain pin = the tag/commit, plus the per-binary sha256 list in `BUILD-INFO.txt` ("Shipped binaries (sha256)"). A fork at the tag would keep the bytes (needs Brent's OK; I forked nothing). BUILD-INFO: "Built 2026-11-19T07:41:54Z", FFmpeg `n8.1.3 1041abdc962f4cc4f394aa8de9dc5236c0c3b9e7`, dav1d 1.5.4, zimg 3.0.6, libzvbi 0.2.46. The tag was cut the same day it was built, so a moved tag is plausible: docs pin the commit too.
  - Products present: `AetherLibavformat`, `AetherLibavcodec`, `AetherLibavutil`, `AetherLibswresample`, `AetherLibswscale`, `AetherLibdav1d`, `AetherLibavfilter`, `AetherLibzimg`, `AetherLibzvbi`, `AetherFFmpegBuild`. Each xcframework has `ios-arm64` and `ios-arm64_x86_64-simulator` slices.
  - BUILD-INFO.txt `ios-arm64:` configure line, quoted pieces: `--enable-shared --disable-encoders --disable-muxers --disable-bsfs --disable-network ... --enable-audiotoolbox --enable-videotoolbox --enable-libdav1d`, then
    - demuxers: `--disable-demuxers --enable-demuxer=hls ... --enable-demuxer=matroska --enable-demuxer=mov ... --enable-demuxer=srt --enable-demuxer=ass ...`
    - decoders: `--enable-decoder=h264 --enable-decoder=hevc ... --enable-decoder=av1 --enable-decoder=libdav1d ... --enable-decoder=aac --enable-decoder=ac3 --enable-decoder=eac3 --enable-decoder=flac --enable-decoder=mp3 --enable-decoder=opus --enable-decoder=vorbis --enable-decoder=truehd --enable-decoder=mlp --enable-decoder=dca ... --enable-decoder=pcm_s16le --enable-decoder=pcm_s24le --enable-decoder=pcm_f32le ...` (many more pcm_*)
    - parsers: `--enable-parser=aac ... --enable-parser=ac3 --enable-parser=flac --enable-parser=h264 --enable-parser=hevc ... --enable-parser=opus --enable-parser=vorbis ... --enable-parser=av1 --enable-parser=dca --enable-parser=mlp`
    - muxers/encoders: `--enable-muxer=mp4 --enable-muxer=mov --enable-muxer=hls --enable-encoder=flac --enable-encoder=eac3 --enable-encoder=aac --enable-encoder=alac`; `--enable-bsf=aac_adtstoasc` also on
    - `--enable-swresample`. A grep of the whole file for `gpl|nonfree|version3` returns nothing, so `--enable-gpl`, `--enable-version3` and `--enable-nonfree` are all absent (the package's LICENSES/README says the same).
  - Against the spec's list: matroska demuxer yes; mov/mp4 muxers yes; AC-3, E-AC-3, FLAC, Opus, Vorbis, DTS (`dca`), TrueHD (`truehd`/`mlp`) and PCM decoders yes; AAC encoder yes, but only the native `aac` (`--enable-audiotoolbox` is on, yet no `aac_at` encoder is enabled; the spec allows "else aac"); swresample yes; h264, hevc, av1 parsers yes. Nothing required is missing, so not Blocked.
- **Deviation from AC-1 (orchestrator and tester, please look): the app links six products, not four.** I parsed the Mach-O load commands of the simulator-slice binaries (python, nothing executed): `AetherLibavcodec` and `AetherLibavformat` both load `@rpath/AetherLibdav1d.framework/AetherLibdav1d` and `@rpath/AetherLibzvbi.framework/AetherLibzvbi`. The package README calls them "link-only backends". The four wanted products don't depend on those targets, so SwiftPM would not embed them and dyld would fail at app launch. So `project.yml` also lists `AetherLibdav1d` and `AetherLibzvbi`; their licences (BSD-2-Clause; MIT/LGPL) are in `Other-Components.txt`. `AetherLibswscale`, `AetherLibavfilter` and `AetherLibzimg` are not linked (no load command from avformat, avcodec, avutil or swresample references them).
- **IPA size:** I couldn't build before and after. Device slices added: avcodec 6,065,760 B, avformat 1,117,696, avutil 754,560, swresample 135,872, dav1d 826,576, zvbi 521,152 = 9,421,616 B (about 9.4 MB uncompressed, before IPA compression). Tester: compare the CI `ClipDeck-ipa` size with an earlier run.
- Files:
  - `ios/project.yml` (packages, dependencies, Licenses folder source)
  - `scripts/make-test-media.sh` (new), `scripts/test-ios.sh`, `scripts/bootstrap.sh`, `scripts/check-ipa-notices.sh` (new)
  - `.github/workflows/ios-simulator.yml` (`brew install xcodegen ffmpeg` in `simulator`; notice check in `ipa`; `workflow_dispatch` untouched)
  - `ios/ClipDeck/Services/Media/FFmpegInspector.swift` (new), `ios/ClipDeckTests/FFmpegFixtureTests.swift` (new)
  - `LICENSE`, `THIRD_PARTY_NOTICES.md`, `ios/ClipDeck/Resources/Licenses/{ClipDeck-LICENSE,FFmpeg-LGPL-2.1,FFmpeg-NOTICE,Other-Components}.txt`
  - `docs/ARCHITECTURE.md`, `docs/DEVELOPMENT.md`
- Design points:
  - The unit test calls `FFmpegInspector` (app target, `internal import Aether...`) instead of importing the C modules, so the test target needs no package dependency. If CI says "no such module AetherLibavformat" in the test target, add the products to the `ClipDeckTests` dependencies.
  - `Licenses/` is a second `sources:` entry with `type: folder`, `buildPhase: resources`, excluded from the main `ClipDeck` source, so the bundle has `Licenses/<name>.txt` (not flattened).
  - `ClipDeck-LICENSE.txt` is a copy of root `LICENSE`; `check-ipa-notices.sh` fails when they differ. Scripts are called with `bash scripts/...`, so no exec bit is needed from Windows.
  - `make-test-media.sh` writes each fixture to a temp dir and moves it on success; it skips the work when all five exist and are newer than the script.
- Checked: `bash -n` on every script → ok. Not run (no ffmpeg, no Mac): the fixture script, XcodeGen, any Swift.
- Tester, look at:
  - First CI run: does `xcodegen generate` resolve the package, and does the app link and embed six frameworks (`check-ipa-notices.sh` fails if any `Frameworks/*.framework` is missing)? Is `Licenses/` really a folder in the `.app`?
  - The fixture recipes are untested. Likely trouble spots: fixture 3's start times (`-itsoffset 0.5` plus `-output_ts_offset 1`; the test expects container and video start 1.0 ±0.05 and audio at least 0.4 s later), the x265 open-gop flags, and the `geq` expression. Loosen a test threshold only if the files differ from the intent, not to hide a bug.
  - The Swift/C interop in `FFmpegInspector.swift` (`AVPixelFormat(rawValue:)`, the `AVMEDIA_TYPE_*` switch, IUO pointers) was written blind.
- Contract for the frontend (AC-7):
  - Bundle resources (all `.txt`, UTF-8, in `Licenses/`): `Bundle.main.url(forResource: "FFmpeg-LGPL-2.1", withExtension: "txt", subdirectory: "Licenses")`, and the same for `ClipDeck-LICENSE`, `FFmpeg-NOTICE`, `Other-Components`. `ClipDeck-LICENSE.txt` is the text of the root `LICENSE` (first line is the "Not legal advice" line; contains "All rights reserved"). `FFmpeg-LGPL-2.1.txt` is about 26 KB and starts with "GNU LESSER GENERAL PUBLIC LICENSE": show it in a scrollable view.
  - No loader helper exists yet; the frontend adds a small one (return the string, or a clear "Licence text missing" fallback, never crash).
  - Source links: FFmpegBuild `https://github.com/superuser404notfound/FFmpegBuild/tree/3.16.0` (`about.ffmpegBuildSource`); FFmpeg `https://ffmpeg.org/releases/ffmpeg-8.1.3.tar.xz` (or `https://github.com/FFmpeg/FFmpeg/tree/n8.1.3`) (`about.ffmpegSource`). Versions to show: FFmpeg n8.1.3, FFmpegBuild 3.16.0.
  - App version: `CFBundleShortVersionString` (MARKETING_VERSION 0.1.0).
- Gotchas: don't edit the `.xcodeproj`; the repo has `* text=auto eol=lf`, so scripts must stay LF.
- For Brent / orchestrator: (1) the six-product link set above; (2) mirror decision: the binaries are in git, so by the spec a fork at tag 3.16.0 (commit 7de456f) is possible. I forked nothing. A fork only protects against the repo vanishing; say if you want it.

## Implementation notes (round 1, frontend) · sonnet
_by loop-frontend · 2026-11-19_
- Changed: AC-7 and the DESIGN.md part of AC-8. Nothing compiled (Windows).
  - `settings.about` NavigationLink row in the Settings screen (`AnkiSettingsView`, which is the gear sheet) pushes `AboutView`.
  - `AboutView`: versions (app from CFBundleShortVersionString, FFmpeg n8.1.3, FFmpegBuild 3.16.0), Clip Deck licence (`about.appLicense`), FFmpeg notice (`about.ffmpegNotice`), links `about.ffmpegSource` and `about.ffmpegBuildSource`, full LGPL text (`about.lgpl`), other components (`about.otherComponents`). One List so it scrolls; footnote monospaced text so Dynamic Type applies.
  - `LicenceText.load(_:)` reads `Licenses/<name>.txt`; returns "Licence text missing: <name>" instead of crashing.
- Files: ios/ClipDeck/Features/Settings/{AboutView,LicenceText,AnkiSettingsView}.swift, ios/ClipDeckUITests/AboutUITests.swift, docs/DESIGN.md
- Checked: nothing runnable here; CI only.
- Tester, look at: `about-01-licences` screenshot; the UI test finds the huge Text as `staticTexts["about.lgpl"]` and reads its `label` (a 26 KB label may be truncated or exposed oddly by XCUI; if so, assert on a shorter marker). The row is found by scrolling Settings (it sits above "Set up AnkiConnect"); check it is a `buttons` element and the `Link`s are `links`. Check at a large Dynamic Type size.
- Gotchas: Settings is the Anki settings sheet (no separate Settings root), so the row is added there. Source link for FFmpeg uses the GitHub n8.1.3 tree.

## Orchestrator note
_2026-11-19 · Brent approved the backup fork: bman7222/FFmpegBuild (public; tag 3.16.0 = 7de456f verified). The app keeps pointing at upstream. Recorded in docs/ARCHITECTURE.md. Accepted the backend deviation from AC-1 (six products: dav1d and zvbi are needed at load time)._

## Test report (round 1)
_by loop-tester · 2026-11-19 23:45_

CI run 44674913642 (workflow_dispatch, headSha 4ba67bc). Both jobs passed on the first attempt. Simulator job: 69/69 test runs passed (xcresult database), including the six FFmpegFixtureTests, AboutUITests, MiningFlowUITests, every player test and ClipExtractorTests (the known flake passed). run-ios launched `dev.brent.clipdeck` (pid 27232) and took a screenshot. Scratch: `C:\Users\Brent\AppData\Local\Temp\clip-deck-loop\T-012-r1`.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 package pinned, products linked, BUILD-INFO quoted, IPA size, binaries location | Pass (with the accepted six-product deviation) | `project.yml` exactVersion 3.16.0. I checked the tag myself: `gh api .../git/ref/tags/3.16.0` = 7de456f. BUILD-INFO.txt at the tag: `n8.1.3 1041abdc…`; matroska demuxer, mp4/mov muxers, aac encoder, ac3/eac3/flac/opus/vorbis/dca/truehd decoders, h264/hevc/av1 parsers and swresample are present; a grep for `enable-gpl`/`version3`/`nonfree` returns 0. The IPA from 44674913642 has exactly six frameworks (avcodec, avformat, avutil, swresample, dav1d, zvbi) and no swscale, avfilter or zimg. The app launches: all 18 UI tests pass and run-ios launched it, so dyld found dav1d and zvbi. IPA size: 451,955 B (run 44672073767, 35dba5d) → 4,618,295 B (+4.17 MB compressed; 10.7 MB uncompressed, of which 9.47 MB is frameworks) |
| AC-2 make-test-media.sh, test-ios.sh, CI ffmpeg, bootstrap, no media in git | Pass | CI log: `brew install xcodegen ffmpeg` (ffmpeg 9.0.2_1, x264 r3222, x265 4.3); "Generating fixtures in …/build/fixtures" lists all five, then "Fixtures ready" (04:31:21–04:31:23). Run locally without ffmpeg: `make-test-media.sh` prints "ffmpeg not found: brew install ffmpeg" and exits 1 with nothing written; `test-ios.sh` (with a fake xcodegen) prints the "brew install ffmpeg" message and exits 1. `git ls-files` has no .mkv/.mp4/.mov, and `build/` is git-ignored. `bootstrap.sh` has the `need ffmpeg` line (read only) |
| AC-3 unit test opens every fixture with libavformat; codecs, counts, fixture 3 at 1.0 s | Pass | xcresult: `fixture1…5` and `missingFileThrowsAClearError` all Success. Fixture 3 asserts container start and video start at 1.0 ±0.05. The audio check had only a lower bound (`> 0.4`), so audio at 3 s would also have passed. The tester tightened it to delay 0.5 ±0.05 and audio start 1.5 ±0.05 (not run yet; it runs in the next CI run). By my reading of the recipe, AC-3 priming should put audio at about 1.495 s |
| AC-4 bundled LGPL text + notice with versions and source URLs; THIRD_PARTY_NOTICES.md | Pass | `FFmpeg-LGPL-2.1.txt` is byte-identical to FFmpeg's `COPYING.LGPLv2.1` at n8.1.3 (diff). The notice names n8.1.3, FFmpegBuild 3.16.0, the `tree/3.16.0` URL, `ffmpeg-8.1.3.tar.xz` and the GitHub n8.1.3 tree. THIRD_PARTY_NOTICES.md says the same. All four files are in the IPA under `Payload/ClipDeck.app/Licenses/` (zip listing). See the second Should fix for a missing copyright line |
| AC-5 root LICENSE wording; bundled copy | Pass | The first line is exactly "Not legal advice; written for personal use, review before any wider release." It has "Copyright (c) 2026 Brent. All rights reserved.", the no-copy/reuse/modify/redistribute sentence, the single LGPL-2.1 §6 exception ("This exception gives no other permission"), and FFmpeg stays under LGPL-2.1. `diff LICENSE ClipDeck-LICENSE.txt` shows no difference. CI cmp check passed |
| AC-6 ipa job runs check-ipa-notices.sh | Pass | ipa job log: three `ok:` lines, then "IPA notice check passed". Run locally against synthetic IPAs: good → exit 0; missing LGPL, notice without the tag URL, LICENSE copy differs, files flattened outside `Licenses/`, missing AetherLibzvbi, missing IPA → each fails with a clear message, exit 1 |
| AC-7 About and licences screen + UI test + about-01-licences | Partly proven | `testAboutShowsLicences` passed: the row, the Clip Deck licence ("All rights reserved") and the LGPL label ("GNU LESSER…") are found. In the screenshot `292789A6-…png`, the nav title is "About and licences" and the versions read Clip Deck 1.0, FFmpeg n8.1.3, FFmpegBuild 3.16.0; the licence text starts with the "Not legal advice" line. **The links are not shown or asserted.** The final `scrollTo(app.links["about.ffmpegSource"], upward: false)` has no assert, and the screenshot ended at the top of the list (the test took 46 s), so the `links` query probably never matched. Tester added `testSourceLinksAreShownAndOpenInSafari`: it queries by identifier with any element type, checks both links are hittable and their labels carry n8.1.3 and 3.16.0, taps each one, waits for Safari in the foreground, and attaches `about-02-links`, `about-03/04-safari-*` and the element trees. Not run yet. The version shows "1.0", not 0.1.0 (pre-existing; see the second Could fix) |
| AC-8 docs | Fail (partly) | ARCHITECTURE.md is complete (package, tag commit, fork, binaries-in-git and BUILD-INFO sha256 as the checksums, licence, products, size, rules). DESIGN.md has the About row. **DEVELOPMENT.md never mentions `CLIPDECK_FIXTURES` or `TEST_RUNNER_CLIPDECK_FIXTURES`. It still says "Environment variables: There are none" (lines 20–29), and the Environment line (5) lists only XcodeGen.** `brew install ffmpeg` appears only as a troubleshooting row |
| Workflow keeps workflow_dispatch; earlier jobs pass | Pass | `on:` still has `workflow_dispatch:`, and this run was dispatched. All 62 earlier tests pass, including all player and landscape tests and MiningFlow |

### Findings
Should fix
Where: docs/DEVELOPMENT.md:5 and :20-29
Problem: AC-8 asks DEVELOPMENT.md to cover `brew install ffmpeg` for tests, the fixtures and `CLIPDECK_FIXTURES`. The variable is not mentioned anywhere, the "Environment variables" section still says "There are none", and the prerequisites line lists only XcodeGen even though bootstrap.sh now fails without ffmpeg.
Proof: Read it. `grep -n -i "CLIPDECK_FIXTURES" docs/DEVELOPMENT.md` finds nothing.
Trigger: a developer on a new Mac follows Environment/First-time setup, and bootstrap fails on ffmpeg; nobody can find how to point the tests at another fixtures folder.
Fix: add ffmpeg (tests only) to the Environment line. Add a row to the variables table: `CLIPDECK_FIXTURES` (test process; set by test-ios.sh as `TEST_RUNNER_CLIPDECK_FIXTURES`; default `<repo>/build/fixtures`) and `SIMCTL_CHILD_CLIPDECK_FIXTURES` for manual sim launches (spec). Add a short "Fixtures" paragraph under Tests: what make-test-media.sh makes, where, and that it skips the work when the files are fresh.

Should fix
Where: ios/ClipDeck/Resources/Licenses/FFmpeg-NOTICE.txt:9-10, THIRD_PARTY_NOTICES.md:8-13 (and Other-Components.txt for libzvbi)
Problem: LGPL-2.1 §6 says: "If the work during execution displays copyright notices, you must include the copyright notice for the Library among them, as well as a reference directing the user to the copy of this License." The About screen displays "Copyright (c) 2026 Brent", but there is no FFmpeg copyright notice anywhere (only a trademark line), and no libzvbi copyright line either (libzvbi is the second LGPL library in the app).
Proof: Read it. `grep -i copyright FFmpeg-NOTICE.txt` gives only the trademark sentence. FFmpeg n8.1.3's own notice is "Copyright (c) 2000-2026 the FFmpeg developers" (`fftools/opt_common.c:201` with `CONFIG_THIS_YEAR 2026` in `configure`).
Trigger: the public release (T-009/T-010) ships an About screen that shows the app's copyright but not the library's.
Fix: add "FFmpeg: Copyright (c) 2000-2026 the FFmpeg developers. Licensed under LGPL-2.1-or-later; see FFmpeg-LGPL-2.1.txt" to the notice and to THIRD_PARTY_NOTICES.md. Add libzvbi's copyright line, taken from its source headers or the package's copy, to Other-Components.txt. Keep `ClipDeck-LICENSE.txt` untouched. (Not legal advice. This is the licence text's own wording; the orchestrator or Brent may downgrade it.)

Could fix
Where: ios/ClipDeck/Services/Media/FFmpegInspector.swift:112
Problem: CI warning: `'init(cString:)' is deprecated` for `String(cString: buffer)` on a `[CChar]`.
Proof: Ran it (CI log, simulator job).
Fix: decode the bytes up to the NUL with `String(decoding:as: UTF8.self)`, or call `String(cString:)` with a pointer.

Could fix (pre-existing, not caused by this diff)
Where: ios/project.yml:67-69 (`info.properties`)
Problem: the built app says CFBundleShortVersionString "1.0" (Info.plist in the CI IPA, and the About screenshot), while `MARKETING_VERSION` is "0.1.0" and the task notes promise 0.1.0. XcodeGen's generated Info.plist hard-codes 1.0.
Proof: Ran it (plistlib on the IPA's Info.plist: CFBundleShortVersionString 1.0, CFBundleVersion 1).
Fix: add `CFBundleShortVersionString: $(MARKETING_VERSION)` and `CFBundleVersion: $(CURRENT_PROJECT_VERSION)` to `info.properties`. This matters before public releases (T-009/T-010).

Note (test defect, fixed by the tester in test files): `AboutUITests.swift:30` scrolls to `app.links["about.ffmpegSource"]` with no assert, so the "tappable source links" part of AC-7 had no test and the screenshot doesn't show the links. Covered by the new test above. I couldn't do the mutation check (revert AboutView's Links, see the test fail) because nothing compiles locally.

```text
VERDICT: Fail
SPEC: AC-1 met (six products, accepted); AC-2 met; AC-3 met (fixture-3 audio bound tightened by tester, pending CI); AC-4 met (copyright line missing, Should fix); AC-5 met; AC-6 met; AC-7 met except the source links, which are unproven (tester test added, pending CI); AC-8 partly (DEVELOPMENT.md lacks CLIPDECK_FIXTURES and the ffmpeg prerequisite)
CHECKS_RUN: CI 44674913642 (headSha 4ba67bc): simulator success (69/69 tests, run-ios launched the app), ipa success (check-ipa-notices: 3 ok + passed); bash -n on 4 scripts → ok; check-ipa-notices.sh against 7 synthetic IPAs → exit codes as expected; make-test-media.sh and test-ios.sh without ffmpeg → exit 1 with the brew message; LGPL text diff vs FFmpeg n8.1.3 COPYING.LGPLv2.1 → identical; BUILD-INFO.txt at tag 3.16.0 grepped; IPA zip listings before/after
UNVERIFIED: the new tester tests (testSourceLinksAreShownAndOpenInSafari, the tightened fixture-3 bounds) until the next CI run; real-device launch with the six frameworks (Sideloadly, Brent); About screen at a large Dynamic Type size and in dark mode (not captured)
REVIEWED_AT: 4ba67bc98b9a5aea56951b15b45023aed6de99bf (+ tester test edits in the working tree)
```

## Fix round 2
_orchestrator · 2026-11-19 · round 1 failed on Sonnet; Brent chose to switch to Opus (ask_on_sonnet_fail). A fresh loop-backend (opus) gets the round-1 Test report: 2 Should fix (DEVELOPMENT.md fixtures/ffmpeg docs; FFmpeg and libzvbi copyright lines) plus 2 Could fix (String(cString:) deprecation; CFBundleShortVersionString = $(MARKETING_VERSION))._

## Implementation notes (round 2) · opus
_by loop-backend · 2026-11-19_
- Changed: every round-1 Test report finding (2 Should fix, 2 Could fix). Nothing compiled (Windows); CI is the check.
- Findings:
  - Should fix, DEVELOPMENT.md: the Environment section now names Homebrew ffmpeg (with libx264/libx265) as a test-only prerequisite that `test-ios.sh` and `bootstrap.sh` need. "There are none" is replaced: the app reads no variables, and a table lists the script/test ones that really exist in code: `SIM_NAME` (run-ios/test-ios), `CLIPDECK_FIXTURES` (read by `FFmpegFixtureTests.fixturesFolder()`, default `<repo>/build/fixtures`) and `TEST_RUNNER_CLIPDECK_FIXTURES` (exported by test-ios.sh). **`SIMCTL_CHILD_CLIPDECK_FIXTURES` is not documented**: nothing reads it (only the unit-test process reads the variable; the app never does), so it would document something that isn't there. A new "Fixtures" paragraph and table under Tests cover what make-test-media.sh writes, where, the freshness skip, how to force a rebuild, CI, and how the tests find the folder. I also added the AboutUITests line to the UI-tests list.
  - Should fix, copyright lines (all checked against upstream sources at the exact versions in FFmpegBuild 3.16.0's BUILD-INFO.txt; I checked that the tags resolve to the BUILD-INFO commits: dav1d 1.5.4 → 54706fc, libzvbi v0.2.46 → 34bb6f6):
    - FFmpeg: "Copyright (c) 2000-2026 the FFmpeg developers". `fftools/opt_common.c` at n8.1.3 prints `" Copyright (c) %d-%d the FFmpeg developers"` with `program_birth_year = 2000` and `configure`'s `CONFIG_THIS_YEAR 2026`. It is in `FFmpeg-NOTICE.txt` (new paragraph after the licence paragraph) and `THIRD_PARTY_NOTICES.md`.
    - dav1d: upstream `COPYING` at tag 1.5.4 says "Copyright © 2018-2025, VideoLAN and dav1d authors". The round-1 text (copied from FFmpegBuild's `LICENSES/dav1d.BSD-2-Clause.txt`) said 2018-2019, so I corrected the year. The rest of the BSD text is byte-identical to upstream (diff).
    - libzvbi: from `COPYING.md` at v0.2.46, the "All files in src/*" block (LGPL-2+): Manish Singh 1998, Michael H. Schimek 1999-2008, Stefan Westerfeld 2000, Iñaki G. Etxebarria 2000-2003, Tom Zoerner 2003-2004. Also the src/dvb/dmx.h + frontend.h block (LGPL-2.1+; io-dvb.c is in `libzvbi_la_SOURCES`). Also FFmpegBuild's own LGPL stub `src/packet-830-stub.c` ("Copyright (C) 2026 Vincent Herbst", from build.sh `patch_zvbi` at 3.16.0), with a pointer to where the modification is published. The ure.c MIT notice was checked as identical in v0.2.46 (it said "v0.2.44"; now says v0.2.46). Added a libzvbi source link (`github.com/zapping-vbi/zvbi/tree/v0.2.46`). `THIRD_PARTY_NOTICES.md` has a Copyright column in the components table and a dav1d source link (`code.videolan.org/videolan/dav1d/-/tree/1.5.4`).
    - `LICENSE` and `ClipDeck-LICENSE.txt` untouched (cmp: identical).
  - Could fix, `FFmpegInspector.swift:112`: `String(cString: buffer)` on `[CChar]` → `String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)`. Same result: bytes up to the first NUL, invalid UTF-8 repaired to U+FFFD. The other three `String(cString:)` calls take `UnsafePointer<CChar>` (not deprecated) and are unchanged.
  - Could fix, `ios/project.yml` `info.properties`: added `CFBundleShortVersionString: $(MARKETING_VERSION)` and `CFBundleVersion: $(CURRENT_PROJECT_VERSION)`. Both settings are defined in the ClipDeck target's `settings.base` ("0.1.0", "1"); the xcconfigs don't override them. build-ipa.sh only archives and zips, and reads no version, so it isn't affected. No test asserts "1.0".
- Tester's uncommitted edits kept unchanged: `AboutUITests.testSourceLinksAreShownAndOpenInSafari` and the fixture-3 bounds (delay 0.5 ±0.05, audio start 1.5 ±0.05). By reading, neither shows a product problem: both `Link`s carry their identifiers and labels with "n8.1.3" / "3.16.0"; the fixture-3 recipe (`-itsoffset 0.5` on the audio input plus `-output_ts_offset 1`) should give audio at about 1.495 s (AC-3 priming of 256 samples).
- Files: docs/DEVELOPMENT.md, ios/ClipDeck/Resources/Licenses/FFmpeg-NOTICE.txt, ios/ClipDeck/Resources/Licenses/Other-Components.txt, THIRD_PARTY_NOTICES.md, ios/ClipDeck/Services/Media/FFmpegInspector.swift, ios/project.yml
- Checked: `cmp LICENSE ios/ClipDeck/Resources/Licenses/ClipDeck-LICENSE.txt` → identical; `check-ipa-notices.sh` against a synthetic IPA built from the current `Licenses/*.txt` plus the six framework folders → 3 ok, passed, exit 0; `bash -n scripts/*.sh` → ok; diff of our dav1d text against upstream 1.5.4 COPYING → identical after the year fix; all edited files LF. Not run: XcodeGen, Swift build, tests (CI only).
- Tester, look at:
  - The About screenshot's version should now read 0.1.0, not 1.0 (IPA Info.plist: CFBundleShortVersionString 0.1.0, CFBundleVersion 1).
  - The CI log should no longer have the `init(cString:)` deprecation warning for FFmpegInspector.swift.
  - The new tester tests (links + Safari, fixture-3 bounds) run for the first time in this CI run.
  - Read the copyright strings against the upstream sources quoted above if you want them double-checked.
- Gotchas: FFmpegBuild's bundled `LICENSES/dav1d.BSD-2-Clause.txt` carries an older year (2018-2019) than dav1d 1.5.4's own COPYING (2018-2025); upstream wins.

## Test report (round 2)
_by loop-tester · 2026-11-20 00:08_

CI run 44677264701 (workflow_dispatch, headSha 6e0a299). **ipa job: success. simulator job: failure, but only in the last step.** "Unit and UI tests" passed (`Tests passed`; xcodebuild exit 0; all five fixtures generated), and run-ios launched `dev.brent.clipdeck` (pid 31404). Then "Upload screenshots and test results" failed with `Failed to CreateArtifact: ... Request timeout` after 5 attempts. That is a GitHub artifact-service timeout, not caused by this diff. So the run has **no simulator-results artifact** (no xcresult, no screenshots). Scratch: `C:\Users\Brent\AppData\Local\Temp\clip-deck-loop\T-012-r2`.

Round-1 findings, checked:
- Should fix, DEVELOPMENT.md: **fixed.** The Environment section names `brew install ffmpeg` (test-only). The variables table has `SIM_NAME`, `CLIPDECK_FIXTURES` and `TEST_RUNNER_CLIPDECK_FIXTURES`, and every row matches the code (`test-ios.sh:20-22`, `FFmpegFixtureTests.swift:11-16`, `pick-simulator.py`). The Fixtures paragraph matches `make-test-media.sh` (8 s, 320x180, beep 0.2 s on even seconds, the five names). Leaving out `SIMCTL_CHILD_CLIPDECK_FIXTURES` is right, because nothing in the app reads it.
- Should fix, copyright lines: **fixed, checked against upstream by me** (`gh api`, raw files at each tag):
  - FFmpeg: n8.1.3 dereferences to 1041abdc (= BUILD-INFO). `fftools/opt_common.c:201` prints `" Copyright (c) %d-%d the FFmpeg developers"`, with `program_birth_year = 2000` (`fftools/ffmpeg.c:90`) and `#define CONFIG_THIS_YEAR 2026` (`configure:8699`). So "Copyright (c) 2000-2026 the FFmpeg developers" is right.
  - dav1d: 1.5.4 dereferences to 54706fc. Our dav1d block, compared with upstream `COPYING` with blank lines ignored, is identical (2018-2025).
  - libzvbi: v0.2.46 dereferences to 34bb6f6. The `src/*` holders and the DVB-header holders match `COPYING.md:62-79` exactly. Our ure.c notice matches `src/ure.c:1-30` (only the closing `*/` differs). The FFmpegBuild stub "Copyright (C) 2026 Vincent Herbst", LGPL-2.0+, and the removal of packet-830.c, pdc.c and exp-vtx.c match `build.sh:352-380` at tag 3.16.0.
- Could fix, deprecation: **fixed.** Round 1 (44674913642) had `FFmpegInspector.swift:112:16: warning: 'init(cString:)' is deprecated` in both jobs. Round 2 has it in neither. The only compiler warning left is the orientation warning, which is pre-existing (also in 44672073767 and 44674913642).
- Could fix, version: **fixed in the build.** The CI IPA's Info.plist (plistlib) reads `CFBundleShortVersionString 0.1.0`, `CFBundleVersion 1`. On screen it is unproven (no screenshots; see below).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 package, products, BUILD-INFO, IPA size, binaries location | Pass (unchanged from round 1) | IPA from 44677264701 has exactly the 6 accepted frameworks. Size 4,618,880 B (round 1: 4,618,295) |
| AC-2 fixtures script, test-ios, CI ffmpeg, bootstrap, no media in git | Pass | CI log: brew ffmpeg 9.0.2_1, "Generating fixtures" lists all five, "Fixtures ready". Not changed in this round |
| AC-3 fixture-opening unit test, incl. fixture 3 at 1.0 s | Pass | The tightened fixture-3 bounds (delay 0.5 ±0.05, audio 1.5 ±0.05) ran for the first time. The suite passed with xcodebuild exit 0, so every unit test passed, including these. No per-test xcresult this run (upload failed) |
| AC-4 bundled LGPL + notice with versions/URLs; THIRD_PARTY_NOTICES.md | Pass | All 4 `Licenses/*.txt` in the IPA are byte-identical (cmp) to the repo files. The NOTICE has the FFmpeg copyright line. THIRD_PARTY_NOTICES.md has the same line and the Copyright column. Strings checked upstream (above) |
| AC-5 LICENSE + bundled copy | Pass | Untouched. `cmp` of the IPA copy against the repo copy: identical. CI check `ok: ... "All rights reserved"` |
| AC-6 ipa job runs check-ipa-notices.sh | Pass | ipa log 44677264701: three `ok:` lines + "IPA notice check passed" |
| AC-7 About screen + UI test + links | Pass for links (log evidence), Unverified on screen | `testSourceLinksAreShownAndOpenInSafari` ran: UI-test app launches went 18 (r1) to 19 (r2), the method has no skip path, and xcodebuild exited 0. So both links are hittable, carry n8.1.3 and 3.16.0, and opened Safari. The `about-02..04` screenshots and trees were lost with the artifact. Version 0.1.0 on screen and the ©/ñ/í rendering were not observable: no assertion covered them and there are no screenshots. Tester added `testAboutShowsVersionAndNoticeTextIntact` (not run yet) |
| AC-8 docs | Pass | DEVELOPMENT.md fixed (above). ARCHITECTURE.md and DESIGN.md unchanged from round 1 (pass) |
| Workflow keeps workflow_dispatch; earlier tests pass | Pass | Dispatched run; whole suite green |

### Findings
Could fix
Where: THIRD_PARTY_NOTICES.md (libzvbi row, Copyright column)
Problem: the summary row gives `ure.*` only "Computing Research Labs, New Mexico State University". libzvbi's COPYING.md:93-97 lists three holders for `src/ure.*` (CRL, Iñaki García Etxebarrria, Michael H. Schimek). The bundled Other-Components.txt is fine: it has the verbatim ure.c header, which names both modifiers.
Proof: Read it, against zvbi v0.2.46 COPYING.md.
Trigger: someone reads only the repo summary table.
Fix: add "; modifications by Iñaki García Etxebarrria and Michael H. Schimek" to that cell, or say "see Other-Components.txt".

Could fix (infra, not caused by this diff)
Where: .github/workflows/ios-simulator.yml (simulator upload step)
Problem: a GitHub artifact-service timeout turned a green test run red and lost the evidence.
Proof: Ran it (44677264701 log-failed: `Failed to CreateArtifact ... Request timeout`).
Trigger: GitHub artifact service outage.
Fix: none needed in code. Re-dispatch the run.

Tests added (test files only, not run yet; nothing compiles here, so I couldn't do the revert-to-fail check):
- `ios/ClipDeckUITests/AboutUITests.swift` `testAboutShowsVersionAndNoticeTextIntact`: asserts the version text is 0.1.0 (and no "1.0"). Asserts the FFmpeg notice label has "Copyright (c) 2000-2026 the FFmpeg developers". Asserts the `about.otherComponents` label contains "Copyright © 2018-2025, VideoLAN and dav1d authors", "Iñaki G. Etxebarria" and "Iñaki García Etxebarrria", with no U+FFFD and no "Ã"/"Â". Attaches `about-05-versions(-tree)` and `about-06-other-components(-label)`.
- `ios/ClipDeckTests/FFmpegFixtureTests.swift` `missingFileErrorCarriesFFmpegMessage`: the changed `describe()` returns exactly "No such file or directory" with no NUL, for step `avformat_open_input` and code < 0.

```text
VERDICT: Blocked
NEEDED: verify-only pass. Commit the two tester test edits, then `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload` (this also replaces the lost simulator-results artifact). Deciding tests: AboutUITests.testAboutShowsVersionAndNoticeTextIntact and FFmpegFixtureTests.missingFileErrorCarriesFFmpegMessage. I then read about-01/02/05/06 and append the addendum
SPEC: AC-1..AC-6 met; AC-7 met for links (log evidence), version/non-ASCII on screen pending the new test; AC-8 met. All 4 round-1 findings fixed
CHECKS_RUN: CI 44677264701 (headSha 6e0a299): ipa success (check-ipa-notices 3 ok + passed; no cString warning); simulator tests passed + run-ios launched; upload step failed (GitHub artifact timeout). IPA: plistlib 0.1.0/1, 6 frameworks, Licenses cmp identical. Upstream checks via gh api: FFmpeg n8.1.3 opt_common.c/ffmpeg.c/configure, dav1d 1.5.4 COPYING (diff identical), zvbi v0.2.46 COPYING.md + src/ure.c (diff identical), FFmpegBuild 3.16.0 build.sh patch_zvbi
UNVERIFIED: real-device launch with six frameworks (Brent, Sideloadly); About at large Dynamic Type and dark mode
REVIEWED_AT: 6e0a2999787d6ff6f3f9e604d398a0d061c37900 (+ 2 tester test edits in the working tree)
```

### Round 2 addendum
_by loop-tester · 2026-11-20 00:25_

CI run 44679269822 (workflow_dispatch, headSha ac3ba1a = HEAD; that commit adds only the two tester tests and the task file). ipa: success. simulator: failure in "Unit and UI tests" (exit 65); run-ios was skipped. The artifact uploaded this time. Scratch: `C:\Users\Brent\AppData\Local\Temp\clip-deck-loop\T-012-r2\ci2`.

xcresult (database.sqlite3): 72 test runs, 70 Success and 2 Failure.
- `ClipExtractorTests.cutsExactAudioAndScreenshot`: `Caught error: .timedOut` at MediaAndFileTests.swift:52. This is the known flake (CONTEXT "Learned"). This diff doesn't touch it, so it is pre-existing.
- `AboutUITests.testAboutShowsVersionAndNoticeTextIntact` (my test) recorded 2 issues, both **test defects, not product defects**:
  1. `XCTAssertTrue failed - About shows app version 0.1.0` (AboutUITests.swift:105). The app is right. In the `about-05-versions-tree` attachment, the LabeledContent row is one StaticText with `label: 'Clip Deck, 0.1.0'`, and the `about-05-versions` screenshot shows "Clip Deck 0.1.0 · FFmpeg n8.1.3 · FFmpegBuild 3.16.0". My predicate only matched a bare "0.1.0" text, or a "Clip Deck" element whose value is "0.1.0".
  2. `Failed to get screenshot ... Rendering screen failed` (line 123): the element screenshot of the very tall `about.otherComponents` Text cannot render on CI.
  - XCTest continued after both. Only those 2 issues were recorded, so these assertions passed:
    - the FFmpeg notice contains "Copyright (c) 2000-2026 the FFmpeg developers";
    - the Other-Components label contains "Copyright © 2018-2025, VideoLAN and dav1d authors", "Iñaki G. Etxebarria" and "Iñaki García Etxebarrria";
    - the label has no U+FFFD and no "Ã"/"Â".
  - The `about-06-other-components-label` attachment is **byte-identical** (cmp) to `ios/ClipDeck/Resources/Licenses/Other-Components.txt`.
- `FFmpegFixtureTests.missingFileErrorCarriesFFmpegMessage`: Success. The changed `describe()` returns exactly "No such file or directory".
- `fixture3StartsAtOneSecondWithDelayedAC3` (tightened bounds): Success. `testSourceLinksAreShownAndOpenInSafari`: Success. `testAboutShowsLicences`: Success.

Screenshots read (extracted from the xcresult Data folder):
- about-05: version 0.1.0 on screen.
- about-02: both links visible, "FFmpeg n8.1.3 source" and "FFmpegBuild 3.16.0 source".
- about-03: Safari in the foreground at github.com, showing a first-run "Start Page" card.
- about-04: Safari on the superuser404notfound/FFmpegBuild GitHub page.

Test fix (test file only, uncommitted, not run): `AboutUITests.swift` now matches `label == "Clip Deck, 0.1.0"` or a bare "0.1.0". It also checks that neither "1.0" nor "Clip Deck, 1.0" is shown, and attaches `app.screenshot()` instead of the element screenshot. The pre-fix run already acts as a "fails when wrong" check for the predicate: it failed on a label it didn't expect. I could not do a product-revert mutation (nothing compiles here).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 | Pass | unchanged; ipa job green in 44679269822 |
| AC-2 | Pass | fixtures generated again in 44679269822 |
| AC-3 | Pass | xcresult: fixture1-5 + both missing-file tests Success, including the tightened fixture-3 bounds |
| AC-4 | Pass | as in the round-2 report; the FFmpeg copyright line is shown on screen (assertion passed) |
| AC-5 | Pass | about-05 shows the licence text; unchanged |
| AC-6 | Pass | ipa job green (check-ipa-notices) |
| AC-7 | Pass on evidence, but its deciding test is red because of a test defect | version 0.1.0 (tree + screenshot), links shown and opening Safari (test Success + about-02/03/04), licence + LGPL shown (testAboutShowsLicences Success), ©/ñ/í label byte-identical to the UTF-8 file |
| AC-8 | Pass | as in the round-2 report |

```text
VERDICT: Blocked
NEEDED: verify-only pass. Commit the fixed ios/ClipDeckUITests/AboutUITests.swift (test file only) and dispatch ios-simulator.yml once more. Deciding test: AboutUITests.testAboutShowsVersionAndNoticeTextIntact. If ClipExtractorTests.cutsExactAudioAndScreenshot times out again, that is the known flake: re-run CI (`gh run rerun <id> --failed`); no code change
SPEC: AC-1..AC-8 met on run evidence (44677264701 + 44679269822); no product finding open
CHECKS_RUN: CI 44679269822 (headSha ac3ba1a): ipa success; simulator 70/72 (known flake ClipExtractorTests timeout; my About test's two test-defect issues); xcresult DB queried; about-02/03/04/05 screenshots and about-05/06 attachments read; cmp of the label attachment vs Other-Components.txt → identical
UNVERIFIED: real-device launch with six frameworks (Brent, Sideloadly); About at large Dynamic Type and dark mode
REVIEWED_AT: ac3ba1adaa4c38f81edc69a40fb8eb3346a7c2bb (+ fixed AboutUITests.swift in the working tree)
```

### Round 2 addendum 2
_by loop-tester · 2026-11-20 00:39_

CI run 44681060076 (workflow_dispatch, headSha cb9c452 = HEAD; that commit adds only the fixed AboutUITests.swift and the task file). **Both jobs succeeded, every step green**, including the artifact upload and run-ios launch. xcresult: **72/72 Success, 0 issues**. That covers `testAboutShowsVersionAndNoticeTextIntact` (the deciding test), `testSourceLinksAreShownAndOpenInSafari`, `testAboutShowsLicences`, `missingFileErrorCarriesFFmpegMessage`, fixture1-5 (tightened fixture-3 bounds) and `ClipExtractorTests.cutsExactAudioAndScreenshot` (the flake passed this time). ipa: check-ipa-notices 3 `ok:` + passed; no `init(cString:)` warning anywhere in the run log. Screenshot `about-06` (`C:\Users\Brent\AppData\Local\Temp\clip-deck-loop\T-012-r2\ci3\png`) shows "Copyright © 2018-2025, VideoLAN and dav1d authors" rendered correctly. The ñ/í lines are proven by the passing label assertions. All AC-1..AC-8 are proven by run evidence; no Must fix or Should fix is open. Could fix left: the THIRD_PARTY_NOTICES.md ure.* copyright cell (see the round-2 report).

```text
VERDICT: Pass
SPEC: AC-1..AC-8 met (AC-1 with the accepted six-product link set). All round-1 findings fixed
CHECKS_RUN: CI 44681060076 (headSha cb9c452): simulator success (72/72, run-ios launched, artifacts uploaded), ipa success (check-ipa-notices passed); earlier: 44677264701 (IPA plist 0.1.0/1, Licenses cmp identical, no cString warning), 44679269822 (test-defect run, product evidence); upstream copyright checks via gh api
UNVERIFIED: real-device launch with six frameworks (Brent, Sideloadly); About at large Dynamic Type and dark mode
REVIEWED_AT: cb9c452ab89d028d1460134fb3f0f6498ad34e62
```
