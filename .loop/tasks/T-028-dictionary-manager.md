---
id: T-028
title: Dictionary manager
lane: frontend
depends_on: [T-026]
status: todo
round: 0
base_sha:
issue: 33
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Add, order and remove dictionaries from the library, including a one-tap JMdict download

### What are we building?
There's no way to get a dictionary onto the phone. After this task a dictionary button in the Library's top-right corner opens a Dictionaries sheet. It shows the installed dictionaries in priority order (drag to reorder, switch off, swipe to delete), Import from Files for a Yomitan .zip, a Download JMdict English button with progress and Cancel, and the sources and attributions.

### Why?
JMdict installs in one tap, frequency lists can be added, and you choose which dictionary wins.

### Done when
- AC-1 The Library toolbar gets a `character.book.closed.ja` button (id `library.dictionaries`, label "Dictionaries"), leftmost in the top-right group, before Sync and Upload. It's the only way in.
- AC-2 The sheet `dictionaries.sheet` lists one row per dictionary (`dictionaries.row.<id>`): title, kind (Words or Frequency), entry count and size. Rows can be dragged to reorder; the order is the priority and is saved at once, and VoiceOver has "Move up"/"Move down" actions. Each row has an enable toggle and swipe-to-delete with a confirmation. With nothing installed, the sheet explains what to do.
- AC-3 Import from Files (`dictionaries.import`) uses `.fileImporter` for .zip files with a security-scoped read, and shows a progress bar with Cancel. Errors from T-026 appear in an ErrorBanner. A new dictionary appears last.
- AC-4 Download JMdict English (`dictionaries.downloadJMdict`) fetches `https://github.com/yomidevs/jmdict-yomitan/releases/latest/download/JMdict_english.zip` to a temp file with URLSession, with progress and Cancel, then imports it with the same progress UI. A revision that's already installed says so. This is the app's only new network call; lookups never use the network.
- AC-5 A Sources section (`dictionaries.sources`) shows the EDRDG/JMdict attribution (CC BY-SA 4.0, with links) and each installed dictionary's `attribution`. Settings › About links to it (`about.dictionarySources`).
- AC-6 `-uiTestingDictionary` (Debug, with `-uiTesting`) imports T-026's fixtures from `$CLIPDECK_FIXTURES/dictionaries/` into a fresh temporary database through the real importer, before the library shows: the words v3 fixture, the second words fixture, then the frequency fixture. It's documented in CLAUDE.md. Without the flag, UI-test launches use an empty temporary database, never the real one.
- AC-7 Tests:
  - unit: the download model with a stub `URLProtocol` (progress; a cancel deletes the temp file; a failed download imports nothing; a success hands the file to the importer), and reorder, enable and delete through the model;
  - UI: the button is leftmost in the trailing group; with `-uiTestingDictionary` the sheet lists the three fixtures in order, with their kinds and counts; toggling and deleting (with the confirmation) work; a reorder survives reopening the sheet; Import shows the system file picker; the Download button exists (CI never taps it).
  Docs: the network notes in CLAUDE.md (line 34) and ARCHITECTURE.md (line 7), PRODUCT_SPEC (the dictionary leaves "Not yet implemented"), and DESIGN.md.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check the new manager unit and UI tests and their screenshots.
- Unverified for Brent: the real JMdict download and how long its import takes on his iPhone, and Import from Files with a real dictionary.

### Agent notes
- Depends on: T-026 (store, importer, fixtures). It doesn't call T-027's engine, but the board orders it after T-027. Source: spec T-028; section G "Import plus a JMdict download button, only from the Library top right (leftmost)".
- Code: the toolbar is at LibraryView.swift:53-68 (Sync, then Upload, in one ToolbarItemGroup), and the About screen is AboutView.swift. Launch flags follow the pattern in `ClipDeckApp.init`, and seeding the one in RootView `UITestSeeder` (`-uiTestingMKV` reads `CLIPDECK_FIXTURES`). MKVImportUITests.swift:14-19 forwards `CLIPDECK_FIXTURES` through `launchEnvironment`.
- For the EDRDG wording, use the attribution text from the EDRDG licence page (edrdg.org/edrdg/licence.html) and link CC BY-SA 4.0.
- Learned: XCUITest reads a List row's label and value as one StaticText. A `.contain` container reports the union of its children's frames.

- Could-fix from T-026's tester: there's no index on `dict`, so `delete` scans every row (slow with JMdict installed); banks are imported in string order (bank 10 before 2; only progress order); a bank file is read whole with no size cap.

### Out of scope
- Lookups and the popup, automatic dictionary updates, other download sources, non-Japanese dictionaries.
