# Clip Deck

An offline iPhone video player for language learners that works like asbplayer:
- watch your own episodes (MP4, MOV, M4V, or MKV converted to MP4 on import) with SRT/ASS subtitles;
- turn any subtitle line into an Anki card (audio clip, screenshot and sentence);
- send all saved cards to desktop Anki with one Sync button when you're back on your home network.

## Technologies

| Part | Technology |
|---|---|
| iPhone app | SwiftUI, iOS 17.0+, SwiftData, AVFoundation, XcodeGen |
| Backend | None. Videos, subtitles and cards stay on the phone; cards sync to desktop Anki through the AnkiConnect add-on |
| Tests | Swift Testing (unit), XCUITest (UI), GitHub Actions macOS runner (simulator) |

## Project structure

```text
ios/
  project.yml              XcodeGen spec (source of truth for the Xcode project)
  ClipDeck/
    App/                   entry point, root view, UI-test seeding
    Models/                SwiftData models: Show, Episode, PendingCard
    Services/
      Subtitles/           SRT/ASS parser, cue lookup, clip-range rules
      Media/               audio clip + screenshot extraction, test-video generator (Debug only)
      Anki/                settings, AnkiConnect client, card syncer
      FileStore.swift      where videos/subtitles/card media live
    Features/
      Library/             home grid, show detail, upload, subtitle picker and browser, missing-file screen
      Player/              player model and screen, subtitle list, offset
      CardEditor/          Make a Card editor
      Sync/                sync sheet
      Settings/            Anki settings
    DesignSystem/          colours, type, tiles, buttons
    Resources/             asset catalog (colours with light/dark, app icon)
  ClipDeckTests/           unit tests
  ClipDeckUITests/         UI tests (launch, full mining flow)
docs/                      product spec, architecture, design, development guide
scripts/                   bootstrap, run in simulator, run tests, build unsigned .ipa
.github/workflows/         simulator tests + .ipa build on a macOS runner
```

## Prerequisites

To build (a Mac, or the GitHub Actions macOS runner):
- macOS with Xcode 26+ and an iOS simulator runtime (Xcode › Settings › Components)
- XcodeGen: `brew install xcodegen`

To use on your iPhone from Windows:
- [Sideloadly](https://sideloadly.io) and an Apple ID;
- the `ClipDeck-ipa` artifact from a GitHub Actions run.

To sync cards: desktop Anki with the AnkiConnect add-on (setup in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md#anki-setup)).

## Setup

```bash
./scripts/bootstrap.sh
```

No credentials are needed to build. The app's only network connection is AnkiConnect, configured inside the app under Anki settings (gear icon).

## Run the backend

There is no backend. For syncing, open Anki on your computer with AnkiConnect installed.

## Run the app in the iOS Simulator

```bash
./scripts/run-ios.sh
```

This builds the app, boots an iPhone simulator, installs and launches the app, and saves a screenshot to `build/screenshots/`.
- Pick a device with `SIM_NAME="<simulator name>"`; list them with `xcrun simctl list devices available`.
- To work in Xcode, run `cd ios && xcodegen generate` and open `ios/ClipDeck.xcodeproj`.

## Install on your iPhone (Windows, no Mac)

1. Push to GitHub. The **iOS simulator** workflow's `ipa` job uploads **ClipDeck-ipa**.
2. Download it from the run page and unzip it to get `ClipDeck.ipa`.
3. In Sideloadly, plug in your iPhone, drop in `ClipDeck.ipa`, and sign in with your Apple ID.
4. On the iPhone:
   - turn on **Settings › Privacy & Security › Developer Mode**;
   - trust your Apple ID under **Settings › General › VPN & Device Management**.

With a free Apple ID the app expires after 7 days. Re-install it the same way; your library and cards are kept.

On a Mac, `./scripts/build-ipa.sh` builds the same file locally.

## Run the tests

```bash
./scripts/test-ios.sh
```

This runs the unit and UI tests in a simulator. UI test screenshots are saved to `build/screenshots/ui-tests/`.

## Documentation

- [Product spec](docs/PRODUCT_SPEC.md): purpose, users, features, scope
- [Architecture](docs/ARCHITECTURE.md): components, decisions, how parts communicate
- [Design](docs/DESIGN.md): visual identity, tokens, screens
- [Development](docs/DEVELOPMENT.md): environment, Anki setup, commands, simulator, troubleshooting
