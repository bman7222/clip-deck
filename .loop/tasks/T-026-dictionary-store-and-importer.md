---
id: T-026
title: Dictionary store and Yomitan importer
lane: backend
depends_on: []
status: done
round: 1
base_sha: 38fd1824bba46a87ef1f739aa55665a01422038c
issue: 31
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Import a Yomitan dictionary .zip into an offline store on the phone

### What are we building?
Clip Deck has no dictionary data. After this task the app can import a Yomitan-format dictionary (.zip) into its own SQLite store on the phone: words, frequency lists and tags. An import either completes or leaves nothing behind, and it reports progress and can be cancelled. No screen uses it yet; the manager is T-028 and the lookups are T-027.

### Why?
This is the base for offline lookups. It must handle JMdict's roughly 200k entries quickly and never leave half an import behind.

### Done when
- AC-1 `DictionaryStore` opens `Library/Application Support/Dictionaries/dictionaries.sqlite` (or a given URL, for tests) through the system SQLite3 C API, with a small Swift wrapper for prepared statements and transactions. No ORM and no SwiftData. Schema, as in the spec:
  - `dictionaries`: id, title, revision, format, kind (words or frequency), priority, enabled, attribution, term/meta/tag counts, approximate bytes;
  - `terms`: dict, expression, reading, defTags, rules, score, sequence, termTags, and the glossary as a compressed JSON blob; indexed on expression and on reading;
  - `term_meta`: dict, term, mode, JSON data; frequency rows only; indexed on term;
  - `tags`.
  `PRAGMA user_version` records the schema version.
- AC-2 `YomitanImporter` reads `index.json` (format 1–3; title, revision and the attribution/author/url fields kept, plus `frequencyMode` if present), `term_bank_*.json`, `term_meta_bank_*.json` (frequency rows only; pitch and IPA are skipped) and `tag_bank_*.json`. Kanji banks are ignored. The import runs off the main actor in one transaction, reports progress from 0 to 1 and honours cancellation. A failure or a cancel rolls back and leaves no rows and no `dictionaries` row.
- AC-3 Each of these is rejected with a clear message and nothing written: a duplicate title + revision ("<title> (<revision>) is already installed"), a zip without `index.json`, an unsupported format, and a corrupt zip or bank file.
- AC-4 A store API for the later tasks: list dictionaries by priority, set the priority order, enable or disable one, delete one (with all its rows), and fetch the term rows for a batch of expressions and readings (T-027 uses this). A new dictionary goes last in priority.
- AC-5 ZIPFoundation (MIT) is added under `packages:` in `ios/project.yml`, pinned to one exact version, and linked to the app. Its MIT notice goes into THIRD_PARTY_NOTICES.md and into a new bundled licence file under `Resources/Licenses/`. That file is shown in Settings › About and checked by `scripts/check-ipa-notices.sh`.
- AC-6 Unit tests with tiny fixtures: a v3 words dictionary (with structured-content glossaries), a second words dictionary, a frequency dictionary, a legacy v1 dictionary, and a corrupt zip. They cover:
  - good imports (counts, priority order);
  - a duplicate rejected;
  - a corrupt zip rolled back with no rows left;
  - a cancel mid-import rolled back;
  - a delete removing every row;
  - enable and priority surviving a reopened store.
  ARCHITECTURE.md describes the store, the schema and the importer.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check the new importer and store tests. The ipa job's notices check must pass with the new licence file.

### Agent notes
- Depends on: none. Source: spec Feature 3, "Chosen approach" and T-026.
- **Licence:** Yomitan is GPL-3.0 and Clip Deck is "all rights reserved". Build from the format description only, and don't copy Yomitan code, schemas or test data into the repo.
- Fixtures: keep the readable JSON sources under `scripts/fixtures/dictionaries/<name>/`, outside every XcodeGen target. Several `index.json` files inside one target would collide in its bundle. Extend `scripts/make-test-media.sh` to zip them into `$OUT/dictionaries/<name>.zip` (plus a truncated `corrupt.zip`). Tests read them through `CLIPDECK_FIXTURES`, as FFmpegFixtureTests.swift:7-15 does. Put the sample cues' words (こんにちは, 元気, です, また) and T-027's cases (食べる, 行く, 高い, する) into the v3 words fixture, so T-027 to T-031 can reuse it.
- Swift 6: the app's default isolation is MainActor. Make the store an `actor` and keep the connection `OpaquePointer` inside it (it isn't Sendable). `import SQLite3` needs no link setting.
- Speed: one transaction, prepared statements reused per bank, `journal_mode=WAL`, `synchronous=NORMAL`, and parse one bank file at a time. Compress glossaries with `NSData.compressed(using: .zlib)`.
- Frequency data can be a number, a string, or an object (`{value, displayValue}`, or `{reading, frequency}`). Store the raw JSON, and let T-027 interpret it.
- The new files go under `ios/ClipDeck/Services/` (for example `Services/Dictionary/`), which XcodeGen picks up. Regenerate the project.

### Out of scope
- Lookups and deinflection (T-027), any screen or the download (T-028).
- Kanji, pitch accent, images inside glossaries.

## Implementation notes (round 1)
_by loop-backend · 2026-11-28_
- Changed: `Services/Dictionary/` (`SQLiteDatabase.swift` wrapper, `DictionaryStore.swift` actor + models + schema, `YomitanImporter.swift`); ZIPFoundation 0.9.19 in `project.yml`; `ZIPFoundation-LICENSE.txt` (bundled, shown in About, checked in `check-ipa-notices.sh`); THIRD_PARTY_NOTICES.md and ARCHITECTURE.md ("Dictionary store").
- Fixtures: `scripts/make-dictionary-fixtures.py` (data inline, `python -I`) writes 8 zips (about 5 KB) to `scripts/fixtures/dictionaries/`, checked in. Tests find them through `#filePath`, not `CLIPDECK_FIXTURES`, and `make-test-media.sh` is untouched (the orchestrator asked for checked-in zips). The words-v3 fixture has the sample-cue words and 食べる, 行く (two readings), 高い, する.
- Tests: `ios/ClipDeckTests/DictionaryStoreTests.swift` (8 tests; run class `ClipDeckTests/DictionaryStoreTests`). Not compiled; not run (no Swift here, `xcodegen` not installed, so the project was not regenerated).
- Tester, look at: the Swift 6 isolation (nonisolated types used from the actor), ZIPFoundation's `Archive(url:accessMode:)`/`extract` signatures, `corrupt.zip` failing to open, the cancel test (cancel on the 3rd progress call).
- Gotchas: `dictionaries.frequency_mode` column added for `frequencyMode`; `terms(matching:)` binds each word twice (keep batches to a few hundred); the import holds the store actor until it ends; kanji-only or pitch-only zips are refused ("no words or frequency data"); zip entries are read at the zip root only; no size cap on a bank file in memory; import speed on 200k rows not measured.

### Orchestrator gate (round 1)
- Ponytail review (440 product lines): no Must or Should fix. `prepareSchema` marked `nonisolated` (called from the actor's init under MainActor default isolation). Two `#require` arguments got their own `try` (Swift Testing wants it inside the macro).
- Comments 6 % of product lines: no comment pass.
- Not committed yet: CI waits for run 46112964013 (T-024b/T-032). `base_sha` is set after those land. CI plan: `only_testing=ClipDeckTests` is not enough because project.yml adds a package, so the round runs `scope=all`.
- CI: run 46115783465 (1487a6c, scope=all), shared with T-024b's verify-only pass. Pending, not watched.
- CI 46115783465 green in every job (scope=all): DictionaryStoreTests and the ipa notices check passed. Re-committed on base 38fd182 after T-024b landed; the tree is unchanged.

## Test report (round 1)
_by loop-tester · 2026-11-28 01:52_

Reviewed `git diff 38fd182..a19098a` (T-033's uncommitted files ignored). No Swift compiler here: the Swift evidence is CI 46115783465 (1487a6c, same T-026 tree, scope=all, all jobs green, as reported by the orchestrator; not re-polled). Local: `python -I scripts/make-dictionary-fixtures.py` run on a copy in scratch rebuilds all 8 zips byte-identical to the checked-in ones; `corrupt.zip` is refused by Python's zipfile ("File is not a zip file"); odd-`"` line scan of the 4 Swift files is clean. I could not revert-and-run a test locally (no Swift).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `DictionaryStore` opens `Library/Application Support/Dictionaries/dictionaries.sqlite` (or a given URL) through the SQLite3 C API with a small wrapper; no ORM/SwiftData; schema as in the spec; `user_version` | Pass (given URL, tables, wrapper) / pending (default path, indexes, user_version, WAL) | Given URL + every table written and read back: all 8 DictionaryStoreTests in 46115783465. Default path, `user_version`, the expression/reading/term indexes and WAL had no running test: added `schemaVersionIndexesAndDefaultLocation` |
| AC-2 importer reads index.json (format 1–3, title, revision, attribution/author/url, frequencyMode), term/term_meta (freq only)/tag banks; kanji ignored; off the main actor in one transaction; progress 0→1; cancel; failure/cancel rolls back with no rows | Pass | `importsWordsFrequencyAndLegacyDictionariesInPriorityOrder` (formats 3 and 1, attribution joined, frequencyMode, kanji bank in words-v3 not counted, pitch row skipped: metaCount 4 of 5, progress first 0 / last 1 / sorted), `aCancelledImportRollsBack`, `badZipsAreRejectedAndLeaveNothing` (bad-bank fails on bank 2 after bank 1 was inserted → [0,0,0,0] through a second connection); 46115783465 |
| AC-3 duplicate title+revision ("<title> (<revision>) is already installed"), no index.json, unsupported format, corrupt zip or bank: rejected, nothing written | Pass | `aDuplicateTitleAndRevisionIsRejected` (exact message, counts unchanged), `badZipsAreRejectedAndLeaveNothing` (missingIndex, unsupportedFormat(9), corrupt("the zip"), corrupt("term_bank_2.json")); 46115783465 |
| AC-4 list by priority, set order, enable/disable, delete with all rows, batch term fetch; new dictionary last | Pass | `termsMatchExpressionsAndReadingsInPriorityOrder`, `deletingRemovesEveryRowOfThatDictionary`, `enabledAndPriorityAreKeptWhenTheStoreIsReopened`, `priorityOrderIgnoresUnknownAndRepeatedIDsAndKeepsTheRest`; 46115783465 |
| AC-5 ZIPFoundation (MIT) under `packages:`, one exact version, linked; notice in THIRD_PARTY_NOTICES.md and `Resources/Licenses/`; shown in About; checked by check-ipa-notices.sh | Pass (package, notices check) / pending (About text) | project.yml `exactVersion: 0.9.19` + app dependency, app built in 46115783465; ipa job's notices check passed there with the new `check ZIPFoundation-LICENSE.txt "MIT License"` line. About uses the same `licenceBlock(LicenceText.load(...))` path as the UI-tested FFmpeg blocks; the load of this file is now asserted in `schemaVersionIndexesAndDefaultLocation` |
| AC-6 unit tests with tiny fixtures (v3 words with structured content, second words, frequency, legacy v1, corrupt) covering good imports, duplicate, corrupt rollback, cancel rollback, delete, enable+priority after reopen; ARCHITECTURE.md describes store, schema, importer | Pass | All listed tests exist and passed in 46115783465; fixtures rebuilt byte-identical; ARCHITECTURE.md "Dictionary store (`Services/Dictionary/`)" added |

Review notes (data safety, isolation, schema, licence):
- Transaction: `BEGIN IMMEDIATE` … `COMMIT`, `ROLLBACK` on any throw; the duplicate check, the `dictionaries` insert and every bank row are inside it, and `UNIQUE(title, revision)` backs the check. The import is synchronous inside the actor (no `await`), so no re-entrancy can interleave. A crash mid-import leaves an uncommitted WAL, which SQLite discards. Sound.
- Swift 6: connection and statements are non-Sendable classes held only by the actor; value types are `nonisolated` + `Sendable`; `prepareSchema` is `nonisolated` for the actor's init. Compiled in CI.
- Schema matches the spec plus two extra columns (`format`, required by AC-1, and `frequency_mode`, from AC-2). Fine.
- Licence: fixtures are hand-written data (generator says so, content is original); ZIPFoundation 0.9.19 is MIT, notice and bundled text present.

### Findings
Could fix
Where: ios/ClipDeck/Services/Dictionary/DictionaryStore.swift:94-101 (schema)
Problem: no index on `terms(dict)`, `term_meta(dict)`, `tags(dict)`, so `delete(_:)` scans every term row of every dictionary.
Proof: Read it, DictionaryStore.swift:153 (`DELETE FROM \(table) WHERE dict = ?`).
Trigger: deleting one dictionary with JMdict (about 200k rows) installed; seconds on a phone, holding the actor.
Fix: add `CREATE INDEX terms_dict ON terms(dict)` etc. now while `schemaVersion` is still 1 (costs import time and size), or measure in T-028 first.

Could fix
Where: ios/ClipDeck/Services/Dictionary/YomitanImporter.swift:53
Problem: banks are sorted as strings, so `term_bank_10.json` comes before `term_bank_2.json`; only progress order and the rowid tie-break in `terms(matching:)` depend on it.
Proof: Read it.
Trigger: a dictionary with 10+ banks (JMdict).
Fix: `sorted { $0.localizedStandardCompare($1) == .orderedAscending }`.

Could fix
Where: ios/ClipDeck/Services/Dictionary/YomitanImporter.swift:130-137
Problem: each bank entry is extracted into memory with no size cap (already noted by the builder).
Proof: Read it.
Trigger: a hostile or broken zip with a huge entry; memory kill, the transaction rolls back on next open, so no data loss.
Fix: refuse an entry whose `uncompressedSize` is over, say, 64 MB before extracting.

```text
VERDICT: Blocked
NEEDED: verify-only pass — run ClipDeckTests/DictionaryStoreTests/schemaVersionIndexesAndDefaultLocation (any run that includes the ClipDeckTests unit target, e.g. T-033's next round)
SPEC: AC-2, AC-3, AC-4, AC-6 met; AC-1 and AC-5 met except the parts the new test decides (default path, user_version, indexes, WAL, licence text load)
CHECKS_RUN: CI 46115783465 (orchestrator-read, scope=all, green: build, 8/8 DictionaryStoreTests, ipa notices check); fixture rebuild byte-identical; corrupt.zip refused; odd-quote scan clean
UNVERIFIED: import speed and memory with real JMdict on an iPhone (Brent / T-028)
REVIEWED_AT: a19098a
```

### Verify-only pass (round 1)
- Tester: Blocked for evidence only. Its new test `schemaVersionIndexesAndDefaultLocation` (AC-1, AC-5) rides in T-033's round 1 run (scope=all).
- CI: run 46118672166 (b6e8831, scope=all), shared with T-033 round 1. Pending, not watched.

### Round 1 addendum (orchestrator)
- CI 46118672166 (b6e8831, scope=all): shard 1 green, so `schemaVersionIndexesAndDefaultLocation` (AC-1, AC-5) passed with every DictionaryStoreTests test. Shard 3's one red test is the hidden-layer Move-Text failure (T-035), outside this task. The tester's only open condition was this test, so the verdict is Pass. Product tree unchanged since the all-green run 46115783465.
- Brent (2026-11-28): land on this evidence, then investigate the layer.
