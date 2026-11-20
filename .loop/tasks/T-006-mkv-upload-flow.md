---
id: T-006
title: Add an MKV episode from the upload sheet
lane: fullstack
depends_on: [T-004]
status: todo
round: 0
base_sha:
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
