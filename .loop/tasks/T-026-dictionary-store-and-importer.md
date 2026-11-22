---
id: T-026
title: Dictionary store and Yomitan importer
lane: backend
depends_on: []
status: todo
round: 0
base_sha:
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
