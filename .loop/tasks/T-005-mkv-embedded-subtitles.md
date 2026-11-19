---
id: T-005
title: "Optional: use the subtitles built into an MKV"
lane: fullstack
depends_on: [T-006]
status: todo
round: 0
base_sha:
issue: 5
spec: .loop/specs/mkv-import.md
model:
---

## Optional: use the subtitles built into an MKV

### What are we building?
Some MKV episodes carry their subtitles inside the file. After this task, converting an MKV also saves each text subtitle track (SRT or ASS) as an ordinary subtitle file in the episode's folder. The upload sheet gets an "Embedded subtitles" picker for choosing which one to use. The saved files then work with the existing subtitle picker, offset and Make a Card. Picture-based tracks are listed as unusable.

### Why?
This is a nice-to-have, delivered last. Brent usually uploads separate subtitle files, and MKV import already works without this (T-006). When a file does include subtitles, he can skip hunting for a separate file.

### Done when
- AC-1 (backend) The converter accepts the subtitle tracks to extract plus a destination folder, and in the same read pass as the MP4 writes: SubRip → `.srt`; ASS/SSA → `.ass` with its styles and `[Events]` format intact; WebVTT and mov_text → `.srt`. Picture tracks (PGS, VobSub, DVB) are skipped.
- AC-2 (backend) File names follow `<track number> <language> <title>.<ext>` (missing parts dropped), pass through `FileStore.safeName`, and never overwrite an existing file in `Subtitles/<Show>/<Episode>/`. `EpisodeImporter` passes the folder and returns the chosen file's relative path. Cancel or failure removes the subtitle files written so far.
- AC-3 (backend) The default choice is the file's default-flagged text track, else the first text track, else none. Unit tests cover all three.
- AC-4 (backend) Unit tests: a generated MKV with one SRT track and one ASS track (Japanese text, written from strings at test time) converts. Both files exist, and `SubtitleParser` parses them with the same cue count, text and times (±10 ms) as the source strings. An MKV without subtitle tracks still converts with no warnings (T-004 AC-6 keeps passing).
- AC-5 (frontend) After picking an MKV that has text tracks, the upload sheet shows "Embedded subtitles" (`upload.embeddedSubtitle`) listing them (language · title · format) plus "None", preselected per AC-3. Picture tracks are shown greyed as "image-based, can't be used". For an MKV with no text tracks the row is hidden, with no message. If the user also chose a subtitle file, that file is assigned and the extracted tracks are still saved.
- AC-6 (frontend) The other extracted tracks appear in the player's "Load different subtitles" list.
- AC-7 The `-uiTestingMKV` seed gains a second episode whose MKV has an embedded SRT. The UI test opens it, sees the embedded line, and attaches `mkv-03-embedded`. PRODUCT_SPEC.md moves "embedded subtitle tracks" out of "Not yet implemented".

### How to check
CI only:
1. `git push origin loop/mkv-landscape-sideload`, then `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload`.
2. `gh run list --branch loop/mkv-landscape-sideload --workflow ios-simulator.yml --limit 3`; `gh run watch <id> --exit-status`; on failure `gh run view <id> --log-failed`.
3. `./scripts/test-ios.sh` (simulator job) and `./scripts/build-ipa.sh` (ipa job) pass.
4. `gh run download <id> -n simulator-results -D <scratch>/ci`; read `screenshots/ui-tests/*mkv-03*`.
Unverified for Brent: a real MKV with ASS "Full" and "Signs" tracks.

### Agent notes
- Depends on: T-006 (EpisodeImporter, upload sheet MKV flow), which depends on T-004.
- Source: `.loop/specs/mkv-import.md` (Conversion rules → Subtitles; J-2). Brent 2026-11-19: "helpful… not a requirement."
- One read pass for MP4 plus subtitles: reading a 1.5 GB file twice on a phone is noticeably slower.
- Check that `SubtitleParser` handles the ASS FFmpeg writes (it already supports a custom `Format:` order and comments).
- MKV text tracks are UTF-8; write UTF-8.

### Out of scope
- OCR of picture subtitles.
- Reading subtitles from the MKV at play time.
- Changing T-006's audio or progress UI.
