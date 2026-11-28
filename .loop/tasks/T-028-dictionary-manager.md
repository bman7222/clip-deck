---
id: T-028
title: Dictionary manager
lane: frontend
depends_on: [T-026]
status: testing
round: 2
base_sha: 91dc5448c2d5e93823d98327946f04aa557ae3b2
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

## Implementation notes (round 1)
_by loop-frontend · 2026-11-28_
- Changed: Dictionaries sheet and `DictionaryManagerModel` (`Features/Dictionaries/`), Library toolbar button (leftmost, `library.dictionaries`), About link (`about.dictionarySources`) to `DictionarySourcesView`, `-uiTestingDictionary` seed (words-v3, words-second, frequency from `$CLIPDECK_FIXTURES/dictionaries`), and a fresh empty temporary dictionary database on every `-uiTesting` launch. `make-test-media.sh` copies `scripts/fixtures/dictionaries/*.zip` into `$OUT/dictionaries`.
- Files: ios/ClipDeck/Features/Dictionaries/{DictionaryManagerModel,DictionariesView}.swift, App/{ClipDeckApp,RootView}.swift, Features/Library/LibraryView.swift, Features/Settings/AboutView.swift, Services/Dictionary/DictionaryStore.swift (`DictionaryInfo.enabled` is now `var`, so the list can flip it at once), ios/ClipDeckTests/DictionaryManagerModelTests.swift, ios/ClipDeckUITests/DictionaryManagerUITests.swift, scripts/make-test-media.sh, ios/project.yml (comment), CLAUDE.md, docs/{ARCHITECTURE,DESIGN,DEVELOPMENT,PRODUCT_SPEC}.md
- Checked: nothing compiled (no Swift here); every API read by hand, odd-quote scan of the changed Swift files is clean.
- Decisions: reordering needs the Reorder button (edit mode shows the drag handles; swipe-to-delete and the switches stay normal outside it). A cancelled run is silent. "Already installed" shows the importer's message after the download. No background task or idle-timer hold during a long import (the sheet says to keep the app open).
- T-026 Could-fix items: not taken (the `dict` index would change the schema version and `schemaVersionIndexesAndDefaultLocation`; bank order and the size cap are importer-only). Delete runs on the store actor and the row leaves the list at once, so the UI does not wait for the scan.
- Tester, look at: the Reorder drag in `testAReorderSurvivesReopeningTheSheet` (handle position is a guess: window width - 22 pt); swipe Delete and the "Delete dictionary" dialog on iOS 26; `testSourcesAreInTheSheetAndLinkedFromAbout` scrolling; the stub-session progress test (`progressShowsWhileDownloadingAndACancelDeletesTheTempFile` needs AsyncBytes to hand over 128 KB before the end of the response).

### Orchestrator gate (round 1)
- Ponytail review (about 425 product lines): no Must or Should fix. Writes are serialised through one task chain; import and download cancel through the run task (the store's import checks cancellation on the same task); the temp download is always removed; `-uiTestingDictionary` goes through `SourceAccess`, the same path the MKV seeder uses for plain fixture files. ErrorBanner, Theme.danger and the deck fonts exist. Comments 4 %: no comment pass.
- Could-fix: the download iterates `URLSession.AsyncBytes` one byte at a time into a 64 KB buffer; fine for 16 MB but slow-ish. A download task with a progress delegate would avoid it.
- CI: run 46124158721 (296a26d, own branch, scope=all). Pending, not watched.

## Fix round 2 (orchestrator)
CI 46124158721 (296a26d, scope=all): shards 1 and 2 and the ipa green (DictionaryManagerModelTests pass); shards 3 and 4 red.
- `testSwitchingOffAndDeletingWithConfirmation`: "Failed to tap "Delete dictionary" Button … Multiple matching elements found". On iOS 26 the confirmation dialog shows as a popover holding a sheet, with the button in both. Fixed: tap the hittable match.
- `testAReorderSurvivesReopeningTheSheet`: "Row 3 moved above row 1" failed. The drag started at `screen.width - 22`, the builder's guess; the inset-grouped list's reorder control sits inside the row's inset. Fixed: drag the list's own reorder button nearest row 3's midY (label begins with "Reorder"), falling back to the row's trailing edge. On failure it attaches `dictionaries-reorder-tree` with the controls and the hierarchy.
- Not T-028: shard 3 `SubtitleStyleCardUITests/testDoneAVideoTapAndARotationEachCloseTheCard`, "The style card opens" on the third open (the Aa tap landed and no card came; the video is paused, so it's not the auto-hide). It passed in every other run today; watch it.
- CI: run 46130387082 (b89c4df, only_testing DictionaryManagerUITests): "Failed to get screenshot: Timed out" 2.7 min in, before the delete dialog. That was the early-boot simulator flake fixed by T-036, so the delete-dialog fix is still unproven.
- Merged the loop branch (T-025, T-033, T-035, T-036; b77f030) into this branch so the rerun gets the 660 s settle. Conflicts kept both sides (CLAUDE.md flags, DEVELOPMENT.md rows, HANDOFF).

## Fix round 3 · orchestrator
- CI 46150787593 (b9fe85c, only_testing DictionaryManagerUITests, with T-036's settle): the delete-dialog fix passes (`testSwitchingOffAndDeletingWithConfirmation` green). `testAReorderSurvivesReopeningTheSheet` failed, "Row 3 moved above row 1". The round 2 control lookup worked (it pressed row 3's "Reorder Test Frequency" button at 358, 344 and dragged to 183), so the order was the drag itself: `press(forDuration: 0.8, thenDragTo:)` drags fast and lets go on arrival, and the list (a collection view on iOS 26) hadn't moved its drop place yet.
- Fix (test only): `press(forDuration: 0.5, thenDragTo:, withVelocity: .slow, thenHoldForDuration: 1)`.
- CI: run 46153784207 (5416fa7): reorder still fails. The screen recording shows the drag works: row 3 lifts, moves to the top, the others shift down, and it drops at the top (about 25.0 s). Then by 25.3 s it slides back to third. No error banner, so the store write didn't fail: SwiftUI put its old order back, so `onMove` either wasn't called or changed nothing.

## Diagnostic round · orchestrator
- Temporary, removed before landing: a print in `DictionaryManagerModel.move(fromOffsets:toOffset:)` (`-uiTesting` only) showing the offsets and the ids before and after; `testDiagMoveRowThreeAboveRowTwo` (a move in the middle of the list).
- The to-the-top drag now drops inside row 1 (its midY - 8) instead of 4 pt above it, away from the "Installed" header, which is a cell of its own in the iOS 26 list.
