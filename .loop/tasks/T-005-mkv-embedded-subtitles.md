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
Some MKV episodes carry their subtitles inside the file. After this task, importing an MKV also saves each text subtitle track (SRT or ASS) as an ordinary subtitle file in the episode's folder, timed to match the converted video. The upload sheet gets an "Embedded subtitles" picker for choosing which one to use. The saved files then work with the existing subtitle picker, offset and Make a Card. Picture-based tracks are listed as unusable.

### Why?
This is a nice-to-have, delivered last. Brent usually uploads separate subtitle files, and MKV import already works without this (T-006). When a file does include subtitles, he can skip hunting for a separate file.

### Done when
- AC-1 (backend) The FFmpeg build has no srt or ass muxer, so the files are written in Swift.
  - The converter's synchronous core hands out the selected subtitle packets during the same read pass as the MP4: text, pts, duration and the track's CodecPrivate.
  - SubRip and WebVTT become `.srt`.
  - ASS/SSA become `.ass`: the CodecPrivate header (`[Script Info]`, styles), then an `[Events]` section with a `Format:` line. `Dialogue:` lines are rebuilt from the Matroska packet fields (ReadOrder, Layer, Style, Name, margins, Effect, Text) plus the start and end time, in ReadOrder order.
  - Picture tracks are skipped.
- AC-2 (backend) Subtitle times use the MP4's clock (spec timeline rule: MKV time t = MP4 time t, no rebase).
- AC-3 (backend) Files are written into the import's staging folder and moved by `EpisodeImporter` into `Subtitles/<Show>/<Episode>/` on success.
  - Names follow `<n> <language> <title>.<ext>`, run through `FileStore.safeName`, and never overwrite an existing file.
  - Cancel, failure or a failed save leaves none behind (the T-006 rollback covers them).
  - The importer's options value gains "subtitle tracks to extract" and returns the chosen file's relative path.
- AC-4 (backend) The default choice is the file's default-flagged text track, else the first text track, else none. `ConversionPlan` unit tests cover all three, plus picture-only and zero tracks (no warnings).
- AC-5 (backend) Fixture tests:
  - fixture 1's SRT and ASS tracks are written; `SubtitleParser` parses both with the source's cue count and Japanese text, and times within 10 ms;
  - fixture 3's SRT cue times line up with the converted video's timeline (within 40 ms) despite the 1.0 s start offset;
  - fixture 4 still imports with no warnings.
- AC-6 (frontend) After picking an MKV with text tracks, the upload sheet shows "Embedded subtitles" (`upload.embeddedSubtitle`).
  - It lists the text tracks (language · title · format) plus "None", preselected per AC-4.
  - Picture tracks are greyed out as "image-based, can't be used".
  - With no text tracks, the row is hidden and nothing is said.
  - A subtitle file chosen by the user wins; the extracted tracks are still saved.
- AC-7 (frontend) The other extracted tracks appear in the player's "Load different subtitles" list. The `-uiTestingMKV` seed gains "Episode 2" from fixture 1 using its embedded SRT. The UI test sees the embedded line and attaches `mkv-03-embedded`. PRODUCT_SPEC.md moves embedded subtitle tracks out of "Not yet implemented".

### How to check
CI only:
1. `git push origin loop/mkv-landscape-sideload`, then `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload`.
2. `gh run list --branch loop/mkv-landscape-sideload --workflow ios-simulator.yml --limit 3`; `gh run watch <id> --exit-status`; on failure `gh run view <id> --log-failed`.
3. `./scripts/test-ios.sh` and `./scripts/build-ipa.sh` jobs pass.
4. `gh run download <id> -n simulator-results -D <scratch>/ci`; read `screenshots/ui-tests/*mkv-03*`.
Unverified for Brent: a real MKV with ASS "Full" and "Signs" tracks (styles, signs positioning, line breaks).

### Agent notes
- Depends on: T-006 (EpisodeImporter, staging, upload MKV flow), and through it T-004 and T-012.
- Source: `.loop/specs/mkv-import.md` (Conversion rules → Subtitles; Contracts; J-2); review findings 1 and 5. Brent: "helpful… not a requirement."
- Keep libav pointers inside the converter's synchronous core (T-004's rule); pass subtitle packets out as Sendable values, or write the files inside the core.
- MKV text tracks are UTF-8; write UTF-8. Check `SubtitleParser` reads the rebuilt `[Events]` section (it already supports a custom `Format:` order).

### Out of scope
- OCR of picture subtitles; reading subtitles from the MKV at play time.
- Changing T-006's audio, progress or relink UI.
