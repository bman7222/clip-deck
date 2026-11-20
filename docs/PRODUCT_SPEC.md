# Clip Deck: product spec

## Purpose

Mining sentences from shows into Anki usually needs a computer running asbplayer and Yomitan. Clip Deck brings that workflow to the iPhone, fully offline:
- watch your own episodes with subtitles;
- turn a subtitle line into a card with its audio and a screenshot;
- send the cards to desktop Anki later, when you're back on your home network.

## Target users

Language learners, Japanese learners in particular, who already mine cards with asbplayer + Yomitan + Anki on a computer. They want to keep watching and mining on their phone: on a train, a plane, or anywhere without internet.

## Core features

1. **Library:** shows as tiles, each holding episodes. Upload a video, name the episode, and optionally attach subtitles.
2. **Player:**
   - play/pause, scrubbing and ±5 s skips;
   - subtitle overlay, plus a subtitle list you tap to jump;
   - subtitle offset, and "Load different subtitles";
   - iOS Look Up on subtitle text.
3. **Make a Card:**
   - jumps to the current line's start and plays it to the end while cutting that audio and a screenshot;
   - opens an editor to replay the audio, extend or trim the range (whole or partial lines), re-record, and edit fields.
4. **Offline queue and Sync:** cards wait on the phone. The library's Sync button sends them to desktop Anki through AnkiConnect, with per-card status.
5. **Subtitle files:** stored as Subtitles/Show/Episode folders, browsable in the app's Subtitles tab and in the Files app.
6. **Clear errors:** a missing video or subtitle file says which file is missing and where it should be.

## Main user flows

**Mine a card (primary flow):**
1. Library: tap a show tile.
2. Tap an episode. The player opens where you left off.
3. Watch. Optionally adjust the offset, or tap a line in the list to jump.
4. Tap **Make a Card**. The video jumps to the line's start and plays to its end while the clip is recorded.
5. Card editor:
   - replay the clip;
   - optionally **Add next line** / **Add previous line** or nudge the start/end, then **Re-record**, which refreshes the audio, screenshot and sentence;
   - edit Word / Definition / Translation / Notes;
   - tap **Save card**.
6. A confirmation shows how many cards are waiting to sync.

**Sync:** at home, with Anki open on the computer, tap **Sync** on the library. Cards go to the chosen deck and note type with audio and screenshot. Duplicates are reported, not re-added.

**Add an episode:** library **+**:
1. pick or create a show;
2. choose the MP4, MOV, M4V or MKV file (from the Files app or iCloud Drive) and name the episode. For an MKV with several audio tracks, pick the one to keep (the file's default is preselected);
3. optionally choose SRT/ASS subtitles;
4. tap **Add episode**. An MKV is converted to MP4 on the phone, with "Converting… n%" and Cancel; keep Clip Deck open until it finishes (the screen stays on). The original MKV isn't kept.

If the video can't play on iPhone (for example H.264 10-bit, VP9 or 4:2:2), or there isn't enough free space, the sheet says so and Add episode stays disabled. **Choose the video again** on a missing video accepts MKV the same way.

**Assign or change subtitles:** use the subtitle icon on an episode row, or the player's subtitles menu › **Load different subtitles**. Import a file there, or pick one already in that episode's folder.

## Data

Everything is stored on the phone, for one user, with no account:
- **SwiftData:** shows, episodes (file paths relative to Documents, offset, last position), and cards (fields, clip range, media file names, sync status, Anki note id).
- **Files:** videos and subtitles in Documents (visible in the Files app); card media in Library/CardMedia.
- **Settings:** Anki settings in UserDefaults.

Nothing syncs between devices. Cards are copied to Anki on Sync.

## Accounts, integrations, and device capabilities

- **Accounts:** none.
- **Integration:** desktop Anki via the AnkiConnect add-on over the local network (HTTP, optional API key). Anki itself syncs to AnkiWeb, and from there to AnkiMobile.
- **Dictionary:** iOS's built-in Look Up on selected subtitle text. Field names default to the Lapis/Yomitan note type so cards match existing mining decks.
- **Device capabilities:** Local Network (to reach Anki), Files app access, background audio. No camera, microphone, location or photos.

## Initial scope (v1)

Everything in Core features and Main user flows:
- the full primary flow, from video to queued card to Anki;
- SRT and ASS subtitles;
- MP4/MOV/M4V video, and MKV converted to MP4 on import (one audio track; H.264 8-bit, HEVC or AV1 video where the iPhone supports it);
- light and dark mode, portrait and landscape.

## Not yet implemented

- **Other containers** (AVI, WebM, TS) and MKV video the iPhone can't play (H.264 10-bit, VP9, 4:2:2/4:4:4, 12-bit, Dolby Vision profile 5). Convert them on a computer, for example with HandBrake.
- **Switching the audio track** of an MKV episode after import. Add it again to keep another track.
- **In-app Yomitan-style dictionary popups** and auto-filling Word/Definition. Use iOS Look Up and type them in.
- **Exporting an .apkg** for AnkiMobile without a computer.
- **Editing or re-opening a card** after saving. You can delete it from the Sync sheet.
- **Renaming shows or episodes**, and moving an episode to another show.
- **Built-in subtitle tracks** inside MKV or MP4 files. Use separate SRT/ASS files.

## Future considerations

- An AnkiMobile .apkg export path (no computer needed).
- Built-in MKV subtitle tracks extracted as SRT/ASS files on import.
- Converting in the background after leaving the app (`BGContinuedProcessingTask`, iOS 26+).
- An offline dictionary using imported Yomitan dictionaries (JMdict) with Japanese deinflection.
- Card thumbnails and search in the Sync sheet; batch delete.
- iPad layout (the code is iPhone-only today: `TARGETED_DEVICE_FAMILY = 1`).

## Assumptions and defaults

- **Platform:** iOS 17.0 minimum, iPhone only, portrait and landscape, light and dark.
- **App identity:** bundle id `dev.brent.clipdeck`; the "Clip Deck" name can be changed.
- **Audio clip:** 0 ms before and 500 ms after the line (asbplayer-like), adjustable in settings.
- **Cards in Anki:**
  - field mapping defaults to Lapis/Yomitan names (Sentence, Expression, MainDefinition, SentenceAudio, Picture, MiscInfo);
  - tag `clipdeck`;
  - duplicates checked within the deck.
- **Offset:** positive values show subtitles later. Saved per episode.
- **Installing:** builds come from a GitHub Actions macOS runner and are installed with Sideloadly. The developer works on Windows without a Mac.
