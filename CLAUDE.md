# Clip Deck: notes for Claude Code

Created with the `iphone-app-setup-skill` skill. Stack: SwiftUI, iOS 17.0+, XcodeGen; backend: none.
Read `docs/ARCHITECTURE.md` before structural changes and `docs/DESIGN.md` before UI changes.

## Commands

```bash
./scripts/run-ios.sh
./scripts/test-ios.sh
cd ios && xcodegen generate   # after adding files or editing project.yml
```

## Conventions

- Bundle id `dev.brent.clipdeck`; scheme / target `ClipDeck`.
- `ios/project.yml` is the source of truth; the `.xcodeproj` is generated (`cd ios && xcodegen generate`). Never edit the `.xcodeproj`.
- Feature code in `ios/ClipDeck/Features/<Feature>/` (View + `@Observable` model); shared UI in `DesignSystem/`; non-UI logic (subtitles, media, Anki, files) in `Services/`; SwiftData models in `Models/`.
- App target uses Swift 6 with MainActor default isolation.
- Every interactive element gets an `accessibilityIdentifier` named `feature.element`.
- Server secrets live only in `.env` (git-ignored) on the backend. Never put them in app code or xcconfig.
- Sample/mock data only in tests or behind an explicit, documented switch.

## Verifying changes

- Use the `ios-simulator-skill` skill to build, launch, drive and screenshot the app; check light and
  dark mode and a large Dynamic Type size for UI changes.
- Run the full test suite before committing; report only results you actually ran.
- CI runs the simulator tests as four parallel jobs: shard 1 = `ClipDeckTests` + a listed set of UI classes (`SHARD1_UI` in the workflow), shards 2 and 3 = other listed sets (`SHARD2_UI`, `SHARD3_UI`), shard 4 = everything else (`-skip-testing` of the rest, so new classes and targets land there). Artifacts: `simulator-results-1` to `-4`, `ClipDeck-ipa`. `only_testing` runs one filter in a single job. Details: docs/DEVELOPMENT.md (Tests).
- After structural changes run `python3 ~/.claude/skills/iphone-app-setup-skill/scripts/verify_project.py .`
- To resume setup or re-verify on a new machine: `/iphone-app-setup-skill verify`.

## Project-specific notes

- No backend. The only network code is `Services/Anki/AnkiConnectClient.swift` (AnkiConnect on the user's PC) and the JMdict download in
  `Features/Dictionaries/DictionaryManagerModel.swift` (a user-started HTTPS GET of the JMdict English zip from GitHub). Dictionary lookups never use the network.
- File paths in SwiftData are relative to Documents (`FileStore`); never store absolute paths.
- Card media names are fixed per card (`CardMediaNames`), so Sync retries are idempotent; keep it that way.
- `-uiTesting` launch argument (Debug): in-memory library + generated "Sample Show". `-uiTestingNoSeed` skips the sample.
  `-uiTesting -uiTestingMKV` instead imports MKV fixture 4 through `EpisodeImporter` as "MKV Show / Episode 1" (with the
  sample SRT) and fixture 1 as "Episode 2" (its embedded SRT; the ASS track is saved too); it needs `CLIPDECK_FIXTURES` in the app's environment (UI tests forward it through `launchEnvironment`).
- `-uiTestingSampleSeconds <n>` (Debug, with `-uiTesting`): the seeded "Sample Show" video is n seconds long (1 to 600) instead of 6;
  the subtitles don't change. Tests that play the video use it (for example 30) so a slow runner can't play the clip to its end.
- Every `-uiTesting` launch (Debug) also starts `UITestAnimationWatch` (App/), which only prints: any animation that stays on a
  layer for 3 s or more, to find the cause of the UI-test idle stall (T-034). UI tests rotate the player to landscape in their
  setup with `UITestSupport.rotateToLandscape`, which relaunches the app once if that stall hits (docs/DEVELOPMENT.md, Tests).
- Subtitle style (`player.subtitleStyle` in the standard defaults): every `-uiTesting` launch clears it, unless
  `-uiTestingKeepSubtitleStyle` is passed. `-uiTestingSubtitleStyle <json>` then seeds one, for example
  `{"font":"serif","bold":false,"sizeStep":5,"up":0.2,"right":-0.2}`; the old form `"upSteps":4,"rightSteps":-4` (steps x 0.05) is read too, and the new keys win when both are given (a missing or invalid field takes the default; an invalid new `up`/`right` key falls back to a valid old `upSteps`/`rightSteps`, then the default).
- `-uiTestingDictionary` (Debug, with `-uiTesting`) imports `$CLIPDECK_FIXTURES/dictionaries/` words-v3, words-second, then frequency
  (the zips of `scripts/fixtures/dictionaries`, copied there by `make-test-media.sh`) through the real importer before the library shows.
  Every `-uiTesting` launch uses a new empty temporary dictionary database, never the real one. UI tests never download JMdict.
- The Make a Card timeline's Snap chip (`cardEditor.timelineSnap` in the standard defaults) is cleared on every `-uiTesting` launch unless `-uiTestingKeepTimelineSnap` is passed.
- `-uiTestingExpiry <ISO-8601 date>` (Debug, with `-uiTesting`) overrides the install-expiry date from the signing profile,
  so the library's expiry banner and the Anki settings expiry line can be tested. `-uiTestingKeepExpiryDismissal` keeps the
  banner's dismissal day across a relaunch (the "uiTesting" defaults are otherwise cleared on every launch).
- Every video import goes through `Services/EpisodeImporter.swift`: it stages in `tmp/Converting/`, moves into Documents
  only on success and rolls back on a failed save. Don't copy videos into Documents directly.
- The developer works on Windows with no Mac: Swift is compiled only by GitHub Actions (`.github/workflows/ios-simulator.yml`),
  which also uploads UI-test screenshots and an unsigned `ClipDeck.ipa` for Sideloadly. Check run results before claiming anything builds.

## Current status

- 2026-11-09: v1 features implemented (library, upload, subtitle files/browser, player with offset + cue list + Look Up,
  Make a Card with partial ranges and re-record, offline queue, AnkiConnect settings and Sync).
- 2026-11-10: **verified in CI** (GitHub Actions run 42740461564, iPhone 17 Pro simulator, iOS 26.5): app builds (Debug +
  Release/unsigned .ipa); all unit tests pass (parsers, clip math, AnkiConnect client, syncer, files, real clip extraction);
  UI tests pass (launch; full mining flow: seek via list, Make a Card, add next line + re-record, save, 1 waiting to sync).
  Screenshots reviewed: library, show, player, card editor, sync sheet.
- 2026-11-20: dev loop (`.loop/`, branch `loop/mkv-landscape-sideload`) built and **verified in CI** (last green run
  44833382185, 251/251 tests + IPA):
  - full-screen landscape player with tap controls; a pop-out subtitle panel (default 25% of the usable width) with a
    resizable divider; controls always start hidden in landscape;
  - MKV import: converted on import to MP4 with FFmpeg (FFmpegBuild 3.16.0, LGPL; backup fork bman7222/FFmpegBuild), staged and
    rolled back by `EpisodeImporter`, plus built-in text subtitles extracted to .srt/.ass;
  - Settings › About and licences; root LICENSE (all rights reserved + LGPL §6 exception);
  - SideStore install guide (docs/INSTALL_ON_IPHONE.md), GitHub Releases (`release.yml` on `v*` tags) and a SideStore
    source (`releases/latest/download/apps.json`); a daily expiry reminder banner.
  - Repo made public 2026-11-20 (free Actions minutes). First release v0.2.0 (before the expiry banner and built-in subtitles).
- Not yet verified on a real iPhone: SideStore install and the daily refresh, landscape and the panel, MKV import from Files
  (incl. iCloud, multiple audio tracks, HEVC 10-bit, ASS styles), the expiry banner date, VoiceOver, sync with desktop Anki.
- Not in v1: see docs/PRODUCT_SPEC.md "Not yet implemented". Blocked: T-007 TestFlight (needs a paid Apple Developer account).
