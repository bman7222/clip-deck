# Clip Deck: architecture

Created with the `iphone-app-setup-skill` skill.

## Overview

Clip Deck is a single native SwiftUI app with no server of its own. Everything works offline. The only network traffic is the user-started Sync, which calls the AnkiConnect add-on on the user's computer.

```mermaid
flowchart LR
  subgraph iPhone[Clip Deck on iPhone]
    UI[SwiftUI views] --> PM[PlayerModel / AVPlayer]
    UI --> SD[(SwiftData: Show, Episode, PendingCard)]
    UI --> FS[FileStore: Documents/Videos, Subtitles; Library/CardMedia]
    PM --> SP[SubtitleParser + CueTrack]
    UI --> CE[ClipExtractor: AVAssetExportSession + AVAssetImageGenerator]
    CE --> FS
    UI --> CS[CardSyncer]
    CS --> AC[AnkiConnectClient]
  end
  Files[Files app] <--> FS
  AC -- HTTP JSON, LAN --> Anki[Desktop Anki + AnkiConnect :8765]
  Anki --> AnkiWeb[(AnkiWeb)] --> AnkiMobile[AnkiMobile / AnkiDroid]
```

## Frontend

- **Framework:** SwiftUI, iOS 17.0+, SwiftData, AVFoundation, XcodeGen.
- **Language:** Swift 6 with MainActor default isolation in the app target. AVFoundation is imported with `@preconcurrency` where non-Sendable types cross `await`s.
- **Entry point:** `App/ClipDeckApp.swift`. It sets up:
  - the SwiftData container (in-memory under `-uiTesting`);
  - `SettingsStore` in the environment;
  - the Documents folders;
  - the `.playback` audio session.

  `App/RootView.swift` shows `LibraryView`, after seeding sample media in Debug UI tests.
- **Navigation:** one `NavigationStack` at the library. It pushes `Show` (episode list) and `Episode` (player, or the missing-file screen). Upload, Sync, Anki settings, subtitle picker, offset and card editor are sheets.
- **Features (`Features/`):**
  - Library;
  - Player: `PlayerModel` is `@Observable` and owns the `AVPlayer`, a 20 Hz time observer, the current cue, the offset, and `playSegment`;
  - CardEditor;
  - Sync;
  - Settings.
- **Design system:** `DesignSystem/` (tokens, `DeckTile`, button styles, `ErrorBanner`, `Toast`). `SelectableText` is a `UITextView` wrapper that makes subtitle text selectable so iOS **Look Up** works. Details in DESIGN.md.
- **Persistence:**
  - SwiftData for the library and the card queue;
  - UserDefaults (JSON) for Anki settings;
  - files in the app sandbox.

  Paths are stored **relative to Documents**, because the container path changes on re-install (which happens every 7 days with a free Apple ID).

## Backend

None. The app needs no server: the user owns all the data, and Anki is the destination. AnkiConnect, running inside desktop Anki, plays the role of an API.

## Data and access control

**SwiftData models** (`Models/Models.swift`):
- `Show`: name (unique), colour. Cascade-deletes its episodes.
- `Episode`:
  - title and number;
  - `videoPath` and `subtitlePath` (relative);
  - `offsetMs` and `lastPositionMs`.
- `PendingCard`:
  - id and source;
  - clip range;
  - fields as JSON;
  - media file names;
  - status: `pending` / `synced` / `failed` / `duplicate`;
  - Anki note id and last error.

**Files** (`Services/FileStore.swift`):
- `Documents/Videos/<Show>/<Episode>.<ext>`;
- `Documents/Subtitles/<Show>/<Episode>/<file>`, visible in the Files app;
- `Library/CardMedia/clipdeck_<card-id>.m4a|.jpg`, private.

**Access control:** everything is in the app sandbox. AnkiConnect access can require the optional API key set on both sides.

## Communication

`AnkiConnectClient` (`Services/Anki/`) posts `{action, version: 6, params, key}` JSON to the address the user enters, with an 8 s timeout. It uses these actions:
- `version`, `deckNames`, `modelNames`, `modelFieldNames`;
- `storeMediaFile` (base64);
- `addNote` (`allowDuplicate: false`, `duplicateScope: deck`).

Error handling:
- A transport failure becomes `AnkiError.unreachable`, with setup advice.
- AnkiConnect's `error` string becomes `AnkiError.anki`. Duplicates are detected from that message.

`CardSyncer` sends queued cards oldest-first:
- It uploads media under stable per-card names, so a retry overwrites instead of duplicating.
- It maps fields through the user's field map, HTML-escapes text and turns newlines into `<br>`.
- It records per-card results.
- It stops at the first "unreachable" error so the remaining cards stay queued.

## Configuration and secrets

| Value | Where it lives | Public? |
|---|---|---|
| AnkiConnect address | In-app Anki settings (UserDefaults) | Yes (a LAN address) |
| AnkiConnect API key (optional) | In-app Anki settings (UserDefaults) | No. A shared password with the user's own Anki, stored on the device; never in the repo |
| Deck, note type, field map, tags, audio padding | In-app Anki settings | Yes |
| Bundle id, display name | `ios/project.yml`, `ios/Config/Shared.xcconfig` | Yes |

The build has no secrets. `.env.example` and `Secrets.example.xcconfig` are unused scaffold placeholders.

## FFmpeg (MKV import, in progress)

The app links FFmpeg to convert MKV files to MP4 on import (spec: `.loop/specs/mkv-import.md`; the converter itself arrives in later tasks). T-012 added the libraries, the test fixtures and the licence notices.

| Item | Value |
|---|---|
| Package | `superuser404notfound/FFmpegBuild`, `exactVersion: 3.16.0` in `ios/project.yml` (tag commit `7de456f9b6efea4d6c8c6617cc77e7c79cb1e280`) |
| Backup | Fork `bman7222/FFmpegBuild` (made 2026-11-19, tag `3.16.0` = `7de456f`). The app still builds from upstream. If upstream disappears, change the package URL in `ios/project.yml` to the fork. |
| FFmpeg | n8.1.3 (commit `1041abdc962f4cc4f394aa8de9dc5236c0c3b9e7`), a few local patches listed in the package README |
| Licence | LGPL-2.1-or-later; built without `--enable-gpl`, `--enable-version3`, `--enable-nonfree`. See `THIRD_PARTY_NOTICES.md` |
| Linked products | `AetherLibavformat`, `AetherLibavcodec`, `AetherLibavutil`, `AetherLibswresample`, plus the link-only `AetherLibdav1d` and `AetherLibzvbi` that libavcodec and libavformat load at launch (`@rpath`). Without them the app would not start |
| Binaries | Dynamic xcframeworks **committed in the package's git repo** (path binary targets, no download URLs or SPM checksums). The tag is the pin; the sha256 of every shipped binary is in the package's `BUILD-INFO.txt` at that tag. A tag can be moved, so the commit above is the real identity. Forking or mirroring the repo at the tag would keep the bytes if the package vanishes (needs Brent's OK) |
| Size | iOS device slices: avcodec 6.07 MB, avformat 1.12 MB, avutil 0.75 MB, swresample 0.14 MB, dav1d 0.83 MB, zvbi 0.52 MB, about 9.4 MB in total |
| Not in the build | Matroska, SRT and ASS muxers, so MKV test files come from Homebrew FFmpeg. The only AAC encoder is the native `aac` (no `aac_at`) |

Rules:
- Libav pointers stay inside one synchronous function; only Sendable values cross (`FFmpegInspector` is the model). The app target defaults to MainActor, so the converter must be `@concurrent` or run in `Task.detached`.
- The unit tests import no FFmpeg module: they call app-side helpers, which keeps the C modules out of the test target.
- The bundled licence texts live in `ios/ClipDeck/Resources/Licenses/` (a folder reference, so they sit in the app at `Licenses/`). `ClipDeck-LICENSE.txt` must equal the root `LICENSE`; `scripts/check-ipa-notices.sh` (the `ipa` CI job) checks that and the other texts inside the built IPA.
- Changing the FFmpeg version means updating `project.yml`, the notice, `THIRD_PARTY_NOTICES.md` and the check script's tag URL together.

## Decisions

| Area | Decision | Why | Alternatives considered |
|---|---|---|---|
| Frontend | Native SwiftUI, iOS 17 | iPhone-only; AVFoundation gives frame-exact seeking and audio export; Look Up is built in | Expo/React Native (needs native modules for clipping anyway; no gain) |
| asbplayer integration | Re-implemented natively (offset, cue list, partial ranges, re-record, field mapping) | asbplayer is a browser extension/web app and can't run inside an iPhone app offline | Embedding asbplayer's web app in a WebView (no tab-audio capture on iOS; no offline file access) |
| Audio capture | Cut audio from the file (`AVAssetExportSession`, M4A) while the segment plays on screen | Exact and independent of device volume or interruptions; same UX as asbplayer's "record" | Recording the output in real time (impossible to capture app audio without ReplayKit) |
| Video formats | MP4/MOV/M4V via AVPlayer; MKV is converted to MP4 on import with an LGPL FFmpeg build (libraries and notices landed in T-012, converter to follow) | Native, reliable seeking and export | VLCKit for MKV (large dependency; audio export much harder) |
| Anki | Queue on the phone, Sync via AnkiConnect to desktop | User's choice; full fidelity (audio + image + any note type) | .apkg export to AnkiMobile (future option) |
| Dictionary | iOS Look Up + Yomitan-compatible field names | User's choice; zero extra data | Bundled Yomitan dictionaries (future) |
| Project generation | XcodeGen | Text project file, editable from Windows | Committed .xcodeproj |
| Persistence | SwiftData + relative file paths | Simple, local; survives re-install path changes | Core Data, a JSON store |
| ATS | `NSAllowsArbitraryLoads` + `NSAllowsLocalNetworking` | AnkiConnect is HTTP-only and its address is user-entered (LAN IP, `.local`, Tailscale name). The app makes no other requests | Local-networking only (would block VPN hostnames) |
| Builds without a Mac | GitHub Actions macOS runner: simulator tests + unsigned .ipa; Sideloadly installs | Developer has Windows only | Appetize.io (still needs a cloud build; limited minutes) |
| Testing media | Debug-only `TestMediaFactory` generates an MP4 with AVAssetWriter; `scripts/make-test-media.sh` generates five MKV fixtures with Homebrew ffmpeg into `build/fixtures/` | No binary fixtures in git; works on any runner | Committed media files |

## Deployment (not yet done)

- **Personal use (now):**
  - unsigned `.ipa` from CI, installed with Sideloadly;
  - with a free Apple ID: re-install every 7 days, 3-app limit.
- **TestFlight / App Store:**
  - needs an Apple Developer account ($99/yr), a team id (`DEVELOPMENT_TEAM` in `ios/project.yml`), and signing certificates and profiles stored as GitHub secrets;
  - an `xcodebuild -exportArchive` step;
  - a privacy manifest review;
  - before App Store review, reconsider `NSAllowsArbitraryLoads`, which needs a justification.
