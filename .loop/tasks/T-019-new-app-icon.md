---
id: T-019
title: New app icon
lane: frontend
depends_on: []
status: todo
round: 0
base_sha:
issue: 21
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Show the new Clip Deck icon on the home screen

### What are we building?
Clip Deck still uses its placeholder icon. After this task the app uses Brent's new 1024 px icon on the home screen. The SideStore source picks it up at the next release, because it reads the same file.

### Why?
The app should look finished on the home screen and in SideStore.

### Done when
- AC-1 `ios/ClipDeck/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` is a byte-for-byte copy of `clip-deck-temp-files/clip-deck_app_icon_1024.png` (a folder next to the repo; the orchestrator passes the full path to the builder). That file is 1024×1024, 8-bit RGB with no alpha (the planner checked it on 2026-11-22). Record the SHA-256 of both files in the implementation notes.
- AC-2 `Contents.json`, the file name and the path don't change, so `scripts/make-source-json.py` (`ICON_PATH`, line 27) keeps pointing at the new art.
- AC-3 The CI ipa job builds with no actool warning or error about the app icon. The IPA contains `Payload/ClipDeck.app/AppIcon60x60@2x.png` and `Assets.car`.
- AC-4 Every existing test still passes.

### How to check
CI only (`ci_only: true`):
1. The orchestrator pushes `loop/player-lookup-timeline`, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`.
2. `gh run list --branch loop/player-lookup-timeline --workflow ios-simulator.yml --limit 3`, then `gh run watch <id> -i 60 --exit-status`. On failure, `gh run view <id> --log-failed`.
3. `gh run download <id> -n ClipDeck-ipa -D <scratch>`. List the IPA (for example `python -I -c "import zipfile,sys; print('\n'.join(n for n in zipfile.ZipFile(sys.argv[1]).namelist() if 'AppIcon' in n))" <ipa>`), extract `AppIcon60x60@2x.png` and look at it: it must show the new art. Search the ipa job log for "AppIcon".
- Unverified for Brent: the icon on his home screen after a Sideloadly install, and in SideStore after the next release.

### Agent notes
- Depends on: none. Source: spec "Fix 1: App icon" (T-019).
- Copy the file as it is and don't re-encode it: re-saving can add an alpha channel, which Apple's tooling rejects for app icons. The same folder also has `clip-deck_app_icon.png` and `deckerd_temp.png`; don't use either.
- No dark or tinted variants. None exist today, and Brent didn't ask for them.
- Nothing to regenerate: the asset catalog already holds a single 1024 universal image, and iOS makes the smaller sizes from it.

### Out of scope
- Dark or tinted icon variants, a launch screen, using the icon inside the app.
- Tagging a release (the orchestrator does that when Brent says so).
