---
id: T-005
title: "Optional: use the subtitles built into an MKV"
lane: fullstack
depends_on: [T-006]
status: done
round: 2
base_sha: 854e1025ca6c8900a058ea7071c6a12c31d39f66
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

## Implementation notes (round 1, backend) · sonnet
_by loop-backend · 2026-11-20_
- Changed: AC-1 to AC-5. Nothing compiled locally (Windows); CI is the first real check.
- Files:
  - `ios/ClipDeck/Services/Media/SubtitleFileWriter.swift` (new): `SubtitleCuePacket`, `SubtitleCollector` (packets of one track; drops a track over 16 MB), `SubtitleFileWriter` (`subRip`, `ass`, clocks, header handling). Pure Swift, no libav.
  - `ConversionPlan.swift`: `SubtitleKind`, `SubtitleExtraction`, `plan.subtitles`, `make(..., extractingSubtitleStreams:)`, `defaultSubtitleTrack(in:)`, `isUsableSubtitle`, `subtitleFileName`, `UnsupportedMediaError.subtitleChoice`, display names for subtitle codecs.
  - `MediaConverter.swift`: `convert(..., subtitlesFolder:)`; selected subtitle streams are not discarded and their packets are collected in the packet loop; the files are written after the MP4 is finished; `Report.subtitleFiles`; new warnings `.emptySubtitleTrack` / `.oversizedSubtitleTrack`; `MediaConversionError.subtitleWriteFailed`. Any failure or cancel deletes the MP4 and every subtitle file already written.
  - `EpisodeImporter.swift`: `EpisodeImportOptions` gains `embeddedSubtitleStreams` and `chosenSubtitleStream`; `EmbeddedSubtitleTrack`; `PreparedVideo.subtitleTracks / usableSubtitleTracks / usableSubtitleStreamIndices / defaultSubtitleStreamIndex`; staging in `tmp/Converting/<uuid>/Embedded/`; moves with the user's file, never overwriting (a collision gets " (2)"); rollback reuses `MovedFiles.undo()`; relink ignores subtitle options.
  - `FileStore.swift`: `safeName` is now `nonisolated` (the plan builds file names off the main actor).
  - `ios/ClipDeckTests/EmbeddedSubtitleTests.swift` (new, 3 suites, about 40 tests): rules and writer on values (default rule: default-flagged text, first text, none, picture-only, zero tracks, no warnings; names; ReadOrder; commas in text; `SubtitleParser` round trip for srt and ass); fixtures 1, 3, 4 through the converter; the same through `EpisodeImporter` (all tracks, chosen, none, user file wins, name collision, second episode, failed save, cancel, fixture 4).
  - `docs/ARCHITECTURE.md`: subtitle extraction paragraph and the options sentence.
- Checked: read every changed call against the existing code; no CR bytes. Not run: XcodeGen, build, tests (CI only).
- Tester, look at:
  - Compile first: `packet.pointee.data` as an optional in a `guard let`; `UnsafeBufferPointer(start: UnsafePointer(data), ...)`; `try` inside the memberwise `ConversionPlan(... subtitles: try ...)`; the `catch` of a typed throw in `PreparedVideo.plan(for:)`.
  - Runtime assumptions most likely off:
    1. Matroska ASS packets reach us as `ReadOrder,Layer,Style,Name,MarginL,MarginR,MarginV,Effect,Text` (as the spec says). If FFmpeg 8.1 hands out `Dialogue:` lines instead, fixture 1's ASS test fails with 0 cues (and the warning `.emptySubtitleTrack`).
    2. Fixture cue times: expected = source cue + the video's first-frame time (`probe.video.startSeconds`), because the muxer shifts every stream by the same amount (B-frame delay in fixture 1, `-output_ts_offset 1` in fixture 3). Tolerance 10 ms (fixture 1) and 40 ms (fixture 3); ASS times are rounded to centiseconds.
    3. WebVTT packets are `identifier\nsettings\npayload` (matroska_parse_webvtt). No fixture has WebVTT; only the writer is tested.
    4. The ASS CodecPrivate of fixture 1 contains `[V4+ Styles]` and `Style: Default,Arial,...`.
  - Mutations once tests run: drop the `[Events]` cut in `assHeader` (the one-`[Events]` checks must fail); sort ASS by time instead of ReadOrder (the ReadOrder test must fail); skip `moved.undo()` on a failed save (the subtitle rollback test must fail).

### CONTRACT for loop-frontend
All on the main actor, in `EpisodeImporter.swift`. Nothing changes for MP4 or for callers that don't set the new options.
- After `prepare`, for an MKV:
  - `prepared.subtitleTracks: [EmbeddedSubtitleTrack]` (all subtitle tracks, file order). Each has `streamIndex` (picker tag), `label` ("jpn · Full · ASS", "eng · PGS", "Track 2 · ASS"), `language`, `title`, `formatName` ("SRT", "ASS", "WebVTT", "PGS", "VobSub", ...), `isDefault`, `isUsable`.
  - `isUsable == false` (picture tracks, and text formats Clip Deck can't write): show greyed out as "image-based, can't be used", and never pass them in the options.
  - `prepared.usableSubtitleTracks`: the rows to offer. **If it is empty, hide the "Embedded subtitles" row (`upload.embeddedSubtitle`) and say nothing** (no tracks, or pictures only). MP4/MOV/M4V give empty arrays.
  - `prepared.defaultSubtitleStreamIndex: Int?`: the preselected row (default-flagged text track, else the first text track, else nil = "None").
  - `prepared.usableSubtitleStreamIndices: [Int]`.
- Choosing: `EpisodeImportOptions(audioStreamIndex:, embeddedSubtitleStreams:, chosenSubtitleStream:)`.
  - `chosenSubtitleStream`: the picker's selection, or nil for "None". That file becomes the episode's `subtitlePath`.
  - `embeddedSubtitleStreams`: always pass `prepared.usableSubtitleStreamIndices`, so every text track is saved and appears under "Load different subtitles" (J-2). The chosen stream is extracted even if it is missing here.
  - A subtitle file the user picked (`NewEpisodeDetails.subtitleFile`) wins: `subtitlePath` is that file, and the extracted tracks are still saved.
  - The default `EpisodeImportOptions()` extracts nothing, so today's behaviour is unchanged.
- `importEpisode` returns the `Episode` as before. Files land in `Subtitles/<Show>/<Episode>/` named `<n> <language> <title>.srt|.ass` (e.g. `1 jpn SRT.srt`, `2 jpn Full.ass`). The player's existing "Load different subtitles" list (`FileStore.subtitleFiles`) shows them with no further wiring (J-2, AC-7).
- Errors and warnings: a stream index that is not a subtitle track makes `prepared.plan(for:)` and `importEpisode` throw `EpisodeImportError.unsupported(.subtitleChoice(n))` ("The chosen subtitle track isn't in this file. Choose another one."); the UI should never cause it. A text track with no lines, or one over 16 MB, is skipped and shows up in `result.warnings` (for example "The subtitle track “2 jpn Signs.ass” has no lines, so no file was saved for it."). The sheet already shows warnings in an alert.
- Relink (`MissingFileView`) ignores the subtitle options.
- Seed (AC-7), Episode 2 with its embedded SRT: `prepare` fixture 1, then `importEpisode(..., options: EpisodeImportOptions(embeddedSubtitleStreams: prepared.usableSubtitleStreamIndices, chosenSubtitleStream: prepared.subtitleTracks.first?.streamIndex))`. Track 1 is the SRT (`1 jpn SRT.srt`; cues こんにちは、世界。, これはテストです。, さようなら。 at the source's 1.0-2.5, 3.0-4.5 and 5.0-6.5 s plus the video's first-frame time, so read cue times from the file and don't hardcode them).

### Gotchas
- The default track rule uses *usable* text tracks (SRT, WebVTT, ASS/SSA, plain text). A text track in another format (for example mov_text or USF) counts as unusable, like a picture track.
- A track with neither language nor title is named `<n> Subtitles.<ext>`. Titles are cut at 60 characters.
- ASS times have centisecond precision (rounded), so they can differ from the MKV's millisecond time by up to 5 ms.
- A subtitle packet with no duration shows for 2 s. Packets with no timestamp or no text are skipped.
- All cues of a track are held in memory until the pass ends (a 24-minute episode is well under 1 MB; a track over 16 MB is dropped with a warning).
- The MKV is still read once: subtitle packets come from the same `av_read_frame` loop as video and audio.

## Implementation notes (round 1, frontend) · sonnet
_by loop-frontend · 2026-11-20_
- Changed: AC-6 and AC-7. Nothing compiled (Windows); CI is the first check.
- `VideoImportModel`: `selectedSubtitle` (preselected to `prepared.defaultSubtitleStreamIndex`), `selectSubtitle`, `usableSubtitleTracks`, `unusableSubtitleTracks`; `options` always passes `usableSubtitleStreamIndices` and the chosen stream. Relink is unchanged (importer ignores them).
- `UploadEpisodeView`: `upload.embeddedSubtitle` picker (None + usable tracks) under the audio picker, hidden when no usable tracks. Unusable tracks listed below it, greyed, "image-based, can't be used" (`upload.embeddedSubtitle.unusable.<n>`, only when a picker shows). Footer note (`upload.embeddedSubtitleNote`) says a chosen subtitle file wins and tracks are still saved. Warnings use the existing alert.
- `RootView.seedMKV`: after Episode 1, imports fixture 1 as "Episode 2" with the SRT chosen and all usable tracks extracted.
- `MKVImportUITests.testEmbeddedSubtitlesShowInPlayerAndPicker`: opens Episode 2, checks the three cue texts (times not hardcoded), attaches `mkv-03-embedded`, opens Load different subtitles, expects a `1 ... .srt` and a `2 ... .ass` file button (`mkv-04-subtitle-picker`).
- Docs: DESIGN.md (upload sheet row), PRODUCT_SPEC.md (supported; removed from Not yet implemented and Future), CLAUDE.md (seed).
- Tester, look at: the picker's `Int?` tags (None = `Int?.none`); the portrait Menu tap for "Load different subtitles"; the seed now needs two imports so the 120 s library wait; no UI test drives the upload sheet's new picker (needs the file importer); the new test attaches the upload-sheet look only via CI screenshots of existing tests, so none.

## Test report (round 1)
_by loop-tester · 2026-11-20 15:00_

CI run 44806223525 (scope=all, headSha 61bb9a4): **both jobs fail to compile** on a parse error. No unit or UI test ran, so no criterion has run-time evidence. The ipa job's Release archive and the simulator job's Debug test build report the same 8 errors, all in one file and nothing else. The compiler stops at parsing, so type-checking never ran. I traced every other symbol the change uses (helpers, initializers, enum cases, identifiers, typed-throw catches) by hand and found no second compile error. No other bare lines and no broken string literals in the changed Swift files (scanned).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 Swift writer; packets from the same read pass; SRT/WebVTT → .srt; ASS/SSA → .ass from CodecPrivate + rebuilt Dialogue in ReadOrder; pictures skipped | Fail | Does not compile (M1). Read: design matches (packets collected in the `av_read_frame` loop, MediaConverter.swift:600-622; writer SubtitleFileWriter.swift). Runtime assumption 1 (ASS packets are `ReadOrder,Layer,...`) is **correct**: FFmpeg n8.1 matroska.c:70-73 maps S_TEXT/ASS, S_TEXT/SSA, S_ASS, S_SSA to AV_CODEC_ID_ASS, and matroskadec.c:4228-4240 sends them through `matroska_parse_frame` with no ASS fix-up. Assumption 3 (WebVTT) is **wrong**: see S1 |
| AC-2 Subtitle times on the MP4 clock (no rebase) | Fail (not run) | Read: packet pts are rescaled to ms with no rebase (MediaConverter.swift:610-619), matching the converter's timeline rule. Not run. Added `EmbeddedSubtitleTimelineTesterTests.fixture3CueTimesMatchTheConvertedMP4sVideoClock` (it measures against AVFoundation's video start in the converted MP4, not the source probe) |
| AC-3 Staging → move; names `<n> <language> <title>.<ext>` via safeName, never overwrite; rollback; options + chosen path | Fail (not run) | Read: staging in `Embedded/`, `reserveSubtitlePath`, moves join `MovedFiles.undo()`, `.withoutOverwriting`. Path traversal: not possible (traced: `/` `:` `\` replaced, the leading number stops `.`/`..` names; added `trackMetadataCannotEscapeTheFolder`). Name length: S2 |
| AC-4 Default rule (default-flagged text, first text, none; picture-only and zero tracks without warnings) | Fail (not run) | `EmbeddedSubtitleRuleTests` covers all five; it did not run (compile) |
| AC-5 Fixture 1 SRT+ASS parse with cue count, Japanese text, 10 ms; fixture 3 within 40 ms; fixture 4 no warnings | Fail (not run) | `EmbeddedSubtitleFixtureTests` / `EmbeddedSubtitleImportTests`; did not run |
| AC-6 Upload sheet "Embedded subtitles" row, None, preselect, greyed pictures, hidden with no text tracks, user file wins | Fail (not run) | Read: UploadEpisodeView.swift:76-108, VideoImportModel. No test drives the row. Added `EmbeddedSubtitlePickerModelTests` (preselect, None still saves every track, choosing ASS, clear, fixture 4 hides the row with no warning). The greyed picture row is only reachable with a picture-track fixture: Unverified |
| AC-7 Other tracks under Load different subtitles; seed Episode 2; UI test `mkv-03-embedded`; PRODUCT_SPEC updated | Fail (not run) | `MKVImportUITests.testEmbeddedSubtitlesShowInPlayerAndPicker` did not run. PRODUCT_SPEC.md updated (read) |
| Plain MP4 flow and relink untouched | Pass (traced) | MP4 takes the `else` branch of `stage` (no plan, `embedded` empty). With an empty `taken` set, `reserveSubtitlePath` returns the same `uniquePath` result as before. Relink clears both subtitle options before `stage` (EpisodeImporter.swift:274-278). Not run |
| T-004/T-006 suites, MiningFlow, landscape, Expiry, About still pass | Fail (not run) | Build failed before any test |

### Findings

**M1 · Must fix**
Where: ios/ClipDeck/Services/Media/ConversionPlan.swift:94-96
Problem: the doc comment on `SubtitleKind.webVTT` contains real line breaks where `\n` was meant, so lines 95 (`settings`) and 96 (`` payload`. Written as `.srt`. ``) are bare code inside the enum.
Proof: Ran it. CI 44806223525, both jobs:
```
ConversionPlan.swift:95:1: error: found an unexpected second identifier in enum 'case' declaration; is there an accidental break?
ConversionPlan.swift:96:1: error: expected 'func' keyword in instance method declaration
ConversionPlan.swift:96:8: error: found an unexpected second identifier in function declaration; is there an accidental break?
ConversionPlan.swift:96:23: error: expected '(' in argument list of function declaration
ConversionPlan.swift:96:23: error: consecutive declarations on a line must be separated by ';'
ConversionPlan.swift:96:23: error: expected declaration
ConversionPlan.swift:96:28: error: expected member name following '.'
```
(The ipa job's `** ARCHIVE FAILED **` and the simulator's `** TEST FAILED **` have the same root cause.)
Fix: make it one line, e.g. `/// WebVTT in Matroska: the packet is the cue payload (FFmpeg moves identifier and settings to side data). Written as .srt.` (see S1). Then check the file has no other literal line breaks inside comments or strings.

**S1 · Should fix**
Where: ios/ClipDeck/Services/Media/SubtitleFileWriter.swift:96-100 (the `isWebVTT` branch of `subRip`), and the test `EmbeddedSubtitleRuleTests.webVTTPacketsLoseTheirIdentifierAndSettingsLines`
Problem: runtime assumption 3 is wrong. FFmpeg's demuxer has already split the WebVTT block: `pkt->data` is the payload only, and the identifier and settings go to `AV_PKT_DATA_WEBVTT_IDENTIFIER` / `_SETTINGS` side data. The writer still treats the first two lines as identifier and settings, so any WebVTT cue with 3 or more lines loses its first two lines.
Proof: Traced it. FFmpeg n8.1 libavformat/matroskadec.c:3780-3880 (`matroska_parse_webvtt`: `memcpy(pkt->data, text, text_len)` and the side-data calls). Every WebVTT codec id goes through it (matroskadec.c:4228). matroska.c:62-65 maps only `D_WEBVTT/*` to WebVTT. Source fetched to %LOCALAPPDATA%\Temp\clip-deck-loop\T-005-r1\ffmpeg-src.
Trigger: an MKV/WebM with a WebVTT track and a three-line cue, e.g. "One\nTwo\nThree" is written as "Three".
Fix: for `.webVTT`, use the packet text as is, the same as SubRip. Change the builder's WebVTT test to match. The tester test `EmbeddedSubtitleTesterRuleTests.webVTTPacketsAreThePayloadAndKeepEveryLine` fails against today's code (traced: `lines.count == 3` keeps only "Three").

**S2 · Should fix**
Where: ios/ClipDeck/Services/Media/ConversionPlan.swift `subtitleFileName` (the language part is not capped; the title is capped at 60 Characters, not bytes); the effect shows at MediaConverter.swift:290-296
Problem: language and title come from the file. A long language tag, or 60 multi-scalar graphemes, makes a name over 255 UTF-8 bytes. The write then fails with `subtitleWriteFailed`, and the whole video import fails. The UI always extracts every usable track (even with "None"), so the user can't import the episode at all.
Proof: Traced it. FFmpeg copies the Matroska Language/LanguageBCP47 string into `language` metadata with no length limit. `prefix(60)` of "é̂̃̄" (9 bytes per grapheme) is 540 bytes. APFS NAME_MAX is 255 bytes. Test added: `EmbeddedSubtitleTesterRuleTests.subtitleFileNamesStayWithinTheFileSystemLimit` (fails today on the 400-char language and the 100-grapheme title).
Fix: cap the language (e.g. 20 characters) and cut the joined name to about 200 UTF-8 bytes before the extension. Better still: a subtitle file that can't be written becomes a warning for that track (like `.emptySubtitleTrack`), so the video still imports.

**C1 · Could fix**: MediaConverter.swift:620. Each packet is decoded into a `String` before the 16 MB cap is checked, and that happens even after the track is already dropped. Check `collectors[index]?.isTooLarge` and `packet.size` first. Memory stays bounded either way, because libav already holds the packet.
**C2 · Could fix**: `FileStore.safeName` keeps newlines and control characters inside a name (only the ends are trimmed), so a title with "\n" makes an odd file name in the picker.
**C3 · Could fix**: UploadEpisodeView.swift:88 says "image-based, can't be used" for unusable *text* formats too (mov_text, USF), and those aren't images.
**C4 · Could fix**: docs/DESIGN.md:101. The parenthesis opened at "(`upload.audioTrack`" closes only after the embedded-subtitles sentences.
**C5 · Could fix**: `EmbeddedSubtitleFixtureTests.checkCues` expects source + the *source* probe's video start. That is circular for "lines up with the converted video". The tester's timeline test measures the MP4 instead.

### Tests added (test files only)
`ios/ClipDeckTests/EmbeddedSubtitleTesterTests.swift`: `EmbeddedSubtitleTesterRuleTests` (WebVTT payload, name byte limit, folder containment), `EmbeddedSubtitlePickerModelTests` (AC-6 on VideoImportModel, fixtures 1 and 4), `EmbeddedSubtitleTimelineTesterTests` (fixture 3 against the MP4's AVFoundation video start). They have not compiled yet. Two are expected to fail until S1 and S2 are fixed. I couldn't do the revert check (nothing compiles). The S1 test fails against the current code by construction.

```text
VERDICT: Fail
SPEC: AC-1..AC-7 not met yet: the build fails at ConversionPlan.swift:95-96, so no test ran. Design read as matching for AC-1..AC-4 and AC-6..AC-7, except WebVTT (S1) and name length (S2)
CHECKS_RUN: CI 44806223525 ipa job → ARCHIVE FAILED (parse errors ConversionPlan.swift:95-96); simulator job → TEST FAILED (same errors, no tests run); FFmpeg n8.1 matroskadec.c/matroska.c read via gh api
UNVERIFIED: greyed picture-track row (no picture-track fixture); real MKV with ASS Full/Signs (styles, signs positioning, line breaks): Brent
REVIEWED_AT: 61bb9a47b39d7f994eaf085d615d822802eb42ac
```

## Fix round 2
_orchestrator · 2026-11-20 · round 1 failed on Sonnet; Brent chose to retry on Sonnet (ask_on_sonnet_fail). Sent the round-1 Test report to the same loop-backend (sonnet): Must fix (parse error at ConversionPlan.swift:94-96), S1 (WebVTT packets are payload only), S2 (subtitle file name byte length; a failed track write becomes a warning), plus Could fix C1-C5._

## Implementation notes (round 2) · sonnet
_by loop-backend · 2026-11-20_
- Changed: all round-1 findings. Nothing compiled locally (CI only).
- Findings:
  - M1 (parse error, ConversionPlan.swift:94-96): the `SubtitleKind.webVTT` doc comment is one line now. Cause: my edit script wrote `\n` inside a non-raw Python string. I scanned every file I changed (ConversionPlan, MediaConverter, SubtitleFileWriter, EpisodeImporter, FileStore, EmbeddedSubtitleTests) for lines that start at column 0 with anything but a declaration or comment: none left. The other files were written whole with the Write tool, not through Python strings.
  - S1 (WebVTT): `SubtitleFileWriter.subRip` no longer drops two lines for WebVTT; both kinds keep every line (the `isWebVTT` parameter stays for callers but changes nothing). My test is now `webVTTPacketsAreWrittenLikeSubRipWithEveryLine`. The tester's `webVTTPacketsAreThePayloadAndKeepEveryLine` should pass. Round-1 assumption 3 was wrong; the ARCHITECTURE text only says "SubRip and WebVTT packets become `.srt`", so it still holds.
  - S2 (names and write failures):
    - `subtitleFileName`: the language is capped at 16 characters, the title at 60, and the whole name is cut character by character (never the leading number) until it is at most 200 UTF-8 bytes including the extension (`ConversionPlan.maximumSubtitleFileNameBytes`).
    - Behaviour chosen for a failed write: the track chosen as the episode's subtitle (`SubtitleExtraction.isRequired`, set from `EpisodeImportOptions.chosenSubtitleStream`) still fails the import with `MediaConversionError.subtitleWriteFailed`, because the episode would otherwise end up with no subtitle after the user picked one. Any other track becomes the warning `.subtitleNotSaved(name)`, which reaches `result.warnings`. The video still imports.
    - Plumbing: `ConversionPlan.make(..., requiredSubtitleStream:)`, `subtitleExtractions(..., required:)`, `EpisodeImporter.makePlan(..., requiredSubtitleStream:)`; `PreparedVideo.plan(for:)` passes the chosen stream.
    - Not tested: forcing a disk write error in a unit test is not reliable on the simulator. Read-only coverage; the name tests cover the cause the tester found.
  - C1: `collectSubtitle` returns before decoding a packet once the track is dropped for size.
  - C2: `FileStore.safeName` turns control characters (including newlines and tabs) into spaces. Normal names are unchanged (asserted in `codecsMapToFileKinds`' neighbour test `subtitleFileNamesFollowNumberLanguageTitle`).
  - C3: `EmbeddedSubtitleTrack.isImageBased` (true when the probe says the track is not text). `UploadEpisodeView` says "image-based, can't be used" only for those, and "format not supported" for other unwritable text formats. docs/DESIGN.md is updated to match.
  - C4: docs/DESIGN.md:101 now closes the parenthesis after "the file's default preselected".
  - C5: kept `EmbeddedSubtitleFixtureTests.checkCues` (source cue plus the source probe's video start; 10 ms and 40 ms), but the tester's `EmbeddedSubtitleTimelineTesterTests` is the check against the converted MP4's clock. I left that file untouched.
- Files: ios/ClipDeck/Services/Media/ConversionPlan.swift, MediaConverter.swift, SubtitleFileWriter.swift; ios/ClipDeck/Services/EpisodeImporter.swift, FileStore.swift; ios/ClipDeck/Features/Library/UploadEpisodeView.swift (C3 wording only); ios/ClipDeckTests/EmbeddedSubtitleTests.swift; docs/DESIGN.md.
- Checked: re-read each edit against the surrounding code; no CR bytes. Not run: build and tests (CI only).
- Tester, look at: the new file-name test lines in `subtitleFileNamesFollowNumberLanguageTitle` (12 + a 100-character language: expects "12 " followed by 16 x); the `safeName` loop that builds a `String.UnicodeScalarView`; `catch ... continue` inside the write loop of `ConversionCore.run`.

## Test report (round 2)
_by loop-tester · 2026-11-20 16:07_

CI run 44812195849 (scope=all, headSha 5a71053). **It compiles.** The ipa job (Release archive) is green. Simulator: 245 tests pass and 1 fails. The one failure is a stale expectation in the builder's own test, not a product bug: `EmbeddedSubtitleRuleTests.webVTTPacketsAreWrittenLikeSubRipWithEveryLine` was renamed for S1, but it still asserted the old drop-two-lines output. Recorded issue: `(cues.map { $0.text } → ["cue-1\nline:0\nHello", "No id", "id\nsettings\nTwo\nlines"]) == ["Hello", "No id", "Two\nlines"]`. That actual output is the S1-correct behaviour. I fixed the expectation in the test file (test files only). It needs one verify-only run. Every other test has 0 issues (xcresult database.sqlite3: TestCaseRuns, TestIssues). All 3 known UI flakes passed. All earlier suites passed: T-004/T-006 converter and importer, MiningFlow, landscape x14, Expiry x5, About x3, VideoImportModel, FileStore.

Round-1 findings:

| Finding | Status | Evidence |
|---|---|---|
| M1 parse error | Fixed | Both jobs compiled (ipa success; the simulator built and ran 246 tests) |
| S1 WebVTT payload | Fixed | `EmbeddedSubtitleTesterRuleTests.webVTTPacketsAreThePayloadAndKeepEveryLine` passed. The stale builder test's failure output shows every line kept |
| S2 names | Fixed | `EmbeddedSubtitleTesterRuleTests.subtitleFileNamesStayWithinTheFileSystemLimit` (400-char language, 100 multi-scalar graphemes, 200 x 字) and `subtitleFileNamesFollowNumberLanguageTitle` (16-char language cap, <= 200 bytes) passed. `trackMetadataCannotEscapeTheFolder` passed |
| S2 warning on a failed write | Fixed (traced, not run) | MediaConverter.swift:300-309: a non-chosen track's write failure gives `.subtitleNotSaved(name)` + `continue`. Only `isRequired` throws. `isRequired` is set from `chosenSubtitleStream` (ConversionPlan.swift:218, EpisodeImporter.swift:642-652). No test forces a write error (the builder says so too) |
| C1 | Fixed (read) | MediaConverter.swift:622 returns before decoding once `isTooLarge` |
| C2 | Fixed | `safeName("A\nB\tC") == "A B C"` asserted and passed. See C6 below for a side effect |
| C3 | Fixed (read) | UploadEpisodeView.swift:87 + `isImageBased = !track.isText` (EpisodeImporter.swift:576). DESIGN.md updated |
| C4 | Fixed (read) | docs/DESIGN.md:101 parenthesis closes after "the file's default preselected" |
| C5 | Addressed | `EmbeddedSubtitleTimelineTesterTests.fixture3CueTimesMatchTheConvertedMP4sVideoClock` passed (cues within one frame of the MP4's AVFoundation video start + 1/3/5 s; video start > 900 ms) |

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 Swift writer, same read pass, SRT/WebVTT to .srt, ASS/SSA to .ass (CodecPrivate header + `[Events]` + `Format:` + Dialogue in ReadOrder), pictures skipped | Pass | CI 44812195849: `fixture1WritesItsSRTAndASSTracks` (files `1 jpn SRT.srt`, `2 jpn Full.ass`, cue counts [3,3], `[Script Info]`, `[V4+ Styles]`, `Style: Default,Arial`, exactly one `[Events]`, the Format line), `rebuildsAnASSFileFromTheHeaderAndPackets`, `anASSTrackWithoutAHeaderGetsADefaultOne`, `theSubtitleParserReadsTheWrittenASS/SRT`, `codecsMapToFileKinds`, `aTextFormatWeCannotWriteIsUnusable`, `aDefaultFlaggedPictureTrackIsNotTheDefault`, tester WebVTT test: all pass. The builder's WebVTT test fails only on its stale expectation (fixed, awaiting re-run) |
| AC-2 Times on the MP4 clock, no rebase | Pass | `fixture3CueTimesMatchTheConvertedMP4sVideoClock` (measured on the converted MP4) and `fixture3SubtitleTimesLineUpWithTheConvertedTimelineDespiteTheOffset` (first cue >= 1950 ms) passed |
| AC-3 Staging then move, names via safeName, never overwrite, rollback, options + chosen path | Pass | `importsEveryTextTrackAndChoosesTheDefault`, `aSecondEpisodeNeverOverwritesExistingSubtitleFiles`, `aPickedFileWithTheSameNameAsATrackDoesNotCollideWithIt`, `anExistingSubtitleFileIsNeverOverwritten`, `aFailedSaveRemovesTheExtractedSubtitleFilesToo`, `aCancelledImportLeavesNoSubtitleFiles`, `aMissingSubtitleFolderIsRefusedBeforeAnythingIsWritten`, `onlyTheChosenTrackIsExtractedWhenNoneIsListed`, name tests: all pass |
| AC-4 Default rule + picture-only + zero tracks, no warnings | Pass | `defaultIsTheDefaultFlaggedTextTrack`, `defaultFallsBackToTheFirstTextTrack`, `noDefaultForPictureOnlyOrNoSubtitles`, `ConversionPlanTests.pictureOnlySubtitleTracksGiveNoWarning`, `zeroSubtitleTracksGiveNoWarning`: pass |
| AC-5 Fixture 1 SRT+ASS (cue count, Japanese text, 10 ms); fixture 3 (40 ms); fixture 4 no warnings | Pass | `fixture1WritesItsSRTAndASSTracks`, `fixture3SubtitleTimesLineUp...`, `fixture4HasNoSubtitlesAndStillConvertsWithoutWarnings`, `EmbeddedSubtitleImportTests.fixture4ImportsWithNoSubtitlesAndNoWarnings`: pass (fixtures are `#require`d, so these can't pass vacuously) |
| AC-6 Upload sheet row, None, preselect, greyed pictures, hidden with no text tracks, user file wins | Pass (model) / Unverified (greyed picture row) | `EmbeddedSubtitlePickerModelTests` (both tests: labels "jpn · SRT · SRT", "jpn · Full · ASS"; preselect = default; None still saves every track; fixture 4 hides the row with no warning) and `aSubtitleFileTheUserPickedWinsAndTheTracksAreStillSaved`: pass. No fixture has a picture track, so the greyed row and "format not supported" wording were only read (UploadEpisodeView.swift:76-108) |
| AC-7 Other tracks under Load different subtitles; seed Episode 2; UI test + mkv-03; PRODUCT_SPEC | Pass | `MKVImportUITests.testEmbeddedSubtitlesShowInPlayerAndPicker` passed (29.8 s). mkv-03-embedded: Episode 2 player with こんにちは、世界。 / これはテストです。 / さようなら。 at 0:01.0 / 0:03.0 / 0:05.0. mkv-04-subtitle-picker: "Subtitles for Episode 2", folder Subtitles > MKV Show > Episode 2, `1 jpn SRT.srt` (checked) and `2 jpn Full.ass`. PRODUCT_SPEC updated (read in round 1) |
| Earlier suites still pass | Pass | 245/246. The only failure is the stale test above. Known flakes AboutUITests/testAboutShowsVersionAndNoticeTextIntact, PlayerLandscapeBehaviour...AutoHideWhilePlaying and ...OpenSubtitlesMenuKeepsControlsUpWhilePlaying passed |

### Findings

**S3 · Should fix (test only; I fixed it, so it needs a run)**
Where: ios/ClipDeckTests/EmbeddedSubtitleTests.swift:167-177 `webVTTPacketsAreWrittenLikeSubRipWithEveryLine`
Problem: the test was renamed for S1, but it still expected the identifier and settings lines to be dropped, so `./scripts/test-ios.sh` fails.
Proof: Ran it. CI 44812195849, TestIssues: `(cues.map { $0.text } → ["cue-1\nline:0\nHello", "No id", "id\nsettings\nTwo\nlines"]) == ["Hello", "No id", "Two\nlines"]`
Trigger: every full test run.
Fix (done by tester, test file only): expect `["cue-1\nline:0\nHello", "No id", "id\nsettings\nTwo\nlines"]`. Decided by a verify-only run of `ClipDeckTests/EmbeddedSubtitleRuleTests`.

**C6 · Could fix**: FileStore.swift:43-47. `CharacterSet.controlCharacters` is Unicode Cc **and Cf**, so format characters also become spaces: ZWJ in emoji sequences, ZWNJ (Persian/Indic), soft hyphen, LRM/RLM, BOM. `subtitleFolderPath`/`videoFolderPath` recompute folder names from show and episode names (FileStore.swift:57-63, `subtitleFiles` :136, SubtitlePickerSheet.swift:74). So for an existing show or episode whose name has such a character, the Subtitles tab and "Load different subtitles" no longer find the folder created before this change. The episode's own stored `subtitlePath` still works. Fix: replace only `scalar.properties.generalCategory == .control` (Cc). Unlikely for Brent's Japanese titles.
**C7 · Could fix**: EpisodeImporter.swift:642/651. `isRequired` follows `chosenSubtitleStream` even when the user picked their own subtitle file, which then wins. A write failure of that embedded track still fails the whole import, though the episode doesn't need it. Pass `required: nil` when `NewEpisodeDetails.subtitleFile` is set (needs plumbing, since `plan(for:)` doesn't see the details).
**C8 · Could fix**: no test drives the `.subtitleNotSaved` warning path (S2's chosen behaviour). It is traced only.

### Tests changed (test files only)
`ios/ClipDeckTests/EmbeddedSubtitleTests.swift`: the S3 expectation. The revert check for S1 is covered by evidence that ran: this same CI run shows the old expectation (the pre-S1 output) failing against the new code, while the tester's payload test passes. Swift can't be built locally, so no separate local revert was possible.

```text
VERDICT: Blocked
NEEDED: verify-only pass. Commit the test fix, then dispatch scope=tests, only_testing=ClipDeckTests/EmbeddedSubtitleRuleTests (decides S3: webVTTPacketsAreWrittenLikeSubRipWithEveryLine)
SPEC: AC-1..AC-5 and AC-7 met with CI evidence; AC-6 met on the model (greyed picture row unverified, no fixture)
CHECKS_RUN: CI 44812195849: ipa job success; simulator 245/246 (only failure: stale builder test, fixed); screenshots mkv-03-embedded, mkv-04-subtitle-picker viewed
UNVERIFIED: greyed picture-track row and "format not supported" wording (no fixture); real MKV with ASS Full/Signs tracks (Brent)
REVIEWED_AT: 5a71053ba52d6b458d2fd0f30534f3e054c7d644
```

### Round 2 addendum
_by loop-tester · 2026-11-20 16:18_

- Commit 141d94f changes only the S3 expectation in `ios/ClipDeckTests/EmbeddedSubtitleTests.swift` (plus this task file). Checked with `git diff 5a71053 141d94f -- ios/`.
- CI 44817982486 (scope=tests, only_testing=ClipDeckTests/EmbeddedSubtitleRuleTests, headSha 141d94f): the simulator job is green ("Tests passed"); the ipa job was skipped by scope. xcresult: 19/19 Success, 0 TestIssues, including `EmbeddedSubtitleRuleTests/webVTTPacketsAreWrittenLikeSubRipWithEveryLine()`, so S3 is closed.
- Everything else was proven in 44812195849 on 5a71053 (ipa green, 245/246, the only failure was this test). Product code is unchanged since then.
- C6, C7 and C8 remain Could fix; the orchestrator is taking them to its loose-ends pass.

```text
VERDICT: Pass
SPEC: AC-1..AC-7 met (AC-6's greyed picture row read only: no fixture)
CHECKS_RUN: CI 44812195849 (scope=all on 5a71053: ipa success, simulator 245/246); CI 44817982486 (scope=tests on 141d94f: EmbeddedSubtitleRuleTests 19/19, deciding test passed)
UNVERIFIED: greyed picture-track row and "format not supported" wording (no fixture); real MKV with ASS Full/Signs tracks (Brent)
REVIEWED_AT: 141d94faacf88c7d62af4718591f812465a9c06c
```
