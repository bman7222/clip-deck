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
- After structural changes run `python3 ~/.claude/skills/iphone-app-setup-skill/scripts/verify_project.py .`
- To resume setup or re-verify on a new machine: `/iphone-app-setup-skill verify`.

## Project-specific notes

- No backend. The only network code is `Services/Anki/AnkiConnectClient.swift` (AnkiConnect on the user's PC).
- File paths in SwiftData are relative to Documents (`FileStore`); never store absolute paths.
- Card media names are fixed per card (`CardMediaNames`), so Sync retries are idempotent; keep it that way.
- `-uiTesting` launch argument (Debug): in-memory library + generated "Sample Show". `-uiTestingNoSeed` skips the sample.
- The developer works on Windows with no Mac: Swift is compiled only by GitHub Actions (`.github/workflows/ios-simulator.yml`),
  which also uploads UI-test screenshots and an unsigned `ClipDeck.ipa` for Sideloadly. Check run results before claiming anything builds.

## Current status

- 2026-11-09: v1 features implemented (library, upload, subtitle files/browser, player with offset + cue list + Look Up,
  Make a Card with partial ranges and re-record, offline queue, AnkiConnect settings and Sync).
- 2026-11-10: **verified in CI** (GitHub Actions run 42740461564, iPhone 17 Pro simulator, iOS 26.5): app builds (Debug +
  Release/unsigned .ipa); all unit tests pass (parsers, clip math, AnkiConnect client, syncer, files, real clip extraction);
  UI tests pass (launch; full mining flow: seek via list, Make a Card, add next line + re-record, save, 1 waiting to sync).
  Screenshots reviewed: library, show, player, card editor, sync sheet.
- Not yet verified: on a real iPhone (Sideloadly install), real-video import from Files, sync against desktop Anki,
  landscape layout, dark mode, large Dynamic Type.
- Not in v1: see docs/PRODUCT_SPEC.md "Not yet implemented".
