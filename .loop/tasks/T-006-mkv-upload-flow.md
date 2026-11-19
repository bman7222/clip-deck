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
Today the upload sheet refuses `.mkv` files. After this task Brent can pick an MKV, choose which audio track to keep, add a subtitle file the usual way, and tap Add episode. The sheet shows conversion progress with a Cancel button, then the episode plays and makes cards like any other. "Choose the video again" on a missing video also accepts MKV. Subtitles built into the MKV are not used yet (optional T-005).

### Why?
This is the part Brent sees: his MKV episodes go straight from the Files app into Clip Deck without a computer. He usually has separate subtitle files to upload, so the normal subtitle import is enough.

### Done when
- AC-1 (backend) `EpisodeImporter` copies MP4/MOV/M4V as today, or for MKV runs probe → plan → convert into `Videos/<Show>/<Episode>.mp4`, using `FileStore.uniquePath`. It checks free space first (needs about the source size), holds a UIApplication background task while converting, cancels if that expires, and returns relative paths. On cancel or failure nothing is left behind. Unit tests cover the MP4 path, the MKV path (including an MKV with no subtitle tracks) and a cancel.
- AC-2 (frontend) The video picker accepts `.mkv`, and the placeholder reads "Choose MP4, MOV, M4V or MKV". After picking an MKV, an "Audio" picker (`upload.audioTrack`) appears when it has more than one track (language · title · codec; default = the file's default track). The subtitle-file row works exactly as for MP4. Built-in subtitle tracks are neither shown nor mentioned, and their absence never produces an error or warning.
- AC-3 An unsupported MKV shows the plan's message in the sheet's `ErrorBanner`, and Add episode stays disabled.
- AC-4 Add episode shows "Converting… n%" (`upload.progress`) with Cancel (`upload.cancelConvert`). Success saves the Episode with the chosen subtitle file (if any) and dismisses. Failure, cancel or backgrounding keeps the sheet open with a message (spec J-5) and creates no Episode.
- AC-5 `MissingFileView` "Choose the video again" accepts an MKV, converts it with the default audio track, updates `videoPath` to the new `.mp4`, and opens the player.
- AC-6 A Debug-only `-uiTestingMKV` launch flag seeds "MKV Show / Episode 1" by importing a generated MKV (no subtitle streams) through `EpisodeImporter`, then assigns the sample SRT as a normal subtitle file. A UI test opens it, sees the subtitle lines in the list, makes a card, and attaches screenshots `mkv-01-player` and `mkv-02-card`. The flag is documented in CLAUDE.md and DEVELOPMENT.md.
- AC-7 Docs: PRODUCT_SPEC.md (MKV moves out of "Not yet implemented"; upload flow; built-in subtitles still listed there until T-005), ARCHITECTURE.md ("Video formats" row, diagram), DEVELOPMENT.md troubleshooting (MKV rows, codec advice), README formats.

### How to check
CI only:
1. `git push origin loop/mkv-landscape-sideload`, then `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload`.
2. `gh run list --branch loop/mkv-landscape-sideload --workflow ios-simulator.yml --limit 3`; `gh run watch <id> --exit-status`; on failure `gh run view <id> --log-failed`.
3. `./scripts/test-ios.sh` (simulator job, including the new UI test and importer tests) and `./scripts/build-ipa.sh` (ipa job) pass.
4. `gh run download <id> -n simulator-results -D <scratch>/ci`; read `screenshots/ui-tests/*mkv-01*` and `*mkv-02*`.
Unverified for Brent (real iPhone): picking a real MKV in Files (not greyed out), conversion time on a full episode, HEVC 10-bit playback, locking the screen mid-conversion.

### Agent notes
- Depends on: T-004 (converter). Not on T-005: built-in subtitles are an optional later add-on.
- Source: `.loop/specs/mkv-import.md` (J-1, J-3 to J-6, Files picker, Contracts → EpisodeImporter).
- Backend first: `EpisodeImporter` in `Services/` with tests. Then the frontend wires `UploadEpisodeView` and `MissingFileView` (`Features/Library/`) to it and replaces the `FileStore.videoExtensions`/`FileTypes.videos` checks.
- Design `EpisodeImporter` so T-005 can later pass "subtitle tracks to extract + destination folder" without changing its callers much (e.g. an options value that defaults to none).
- The probe runs when the file is picked (show a small spinner). Keep the security-scoped URL access open from the probe to the end of conversion.
- Progress updates reach the UI on the main actor; don't update SwiftUI state from the converter's thread.
- Extend the seeding in `App/RootView.swift` / `LaunchFlags` without changing `-uiTesting` behaviour.

### Out of scope
- Built-in subtitle extraction and its picker (T-005).
- Switching audio track after import.
- Converting existing MP4 episodes, or batch import.
- Re-encoding unsupported video.
