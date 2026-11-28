---
id: T-027
title: Deinflection and lookup engine
lane: backend
depends_on: [T-026]
status: testing
round: 2
base_sha: 91dc5448c2d5e93823d98327946f04aa557ae3b2
issue: 32
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Find the dictionary entry for a tapped word, including conjugated forms

### What are we building?
With dictionaries in the store, nothing can look a word up yet. After this task an offline engine takes a subtitle line and a tapped character (or a selected piece of text) and returns the best-matching entries. It turns conjugated forms like 食べた back into their dictionary form, 食べる. No screen uses it yet.

### Why?
This is the heart of the Yomitan-style popup: it has to be fast, offline and accurate.

### Done when
- AC-1 Deinflection rules are ported from the Apache-2.0 JL/Nazeka deconjugator and kept as data (a checked-in JSON resource or a Swift table), with the source URL and commit recorded. Each result carries its word type, mapped to Yomitan's rule ids (v1, v5, vk, vs, vz, adj-i, …), and the chain of reasons ("past", "negative", …). The licence is confirmed and recorded in THIRD_PARTY_NOTICES.md and in T-026's bundled licence file.
- AC-2 `scan(text:at:)` runs the pipeline:
  1. normalise: half-width to full-width, plus katakana → hiragana as an extra candidate;
  2. move the start back to the beginning of the word with `NLTokenizer` (Japanese), then try substrings of 16 down to 1 characters from there;
  3. deinflect each substring;
  4. run one batched SQL query;
  5. keep entries whose rules match the deinflected type (any entry, for a form that wasn't deinflected).
  It returns the matched range in the original text.
- AC-3 `lookup(exact:)` handles a selection: the same pipeline on the whole selected text, deinflection included, but with no substring scan.
- AC-4 Ranking: longest match, then dictionary priority, then frequency, then score. Frequencies are rank-based (lower is better) unless `index.json` says `frequencyMode: "occurrence-based"` (higher is better). Entries are grouped by expression + reading, and each enabled dictionary's definitions form their own section, in priority order, alongside each frequency dictionary's value. Disabled dictionaries are ignored.
- AC-5 The result contract has its own file, since T-029a to T-031 use it. It holds the matched range and the entries. Each entry has an expression, a reading, the reasons, frequencies (dictionary title, value, display text) and sections (dictionary id and title, definitions with tags and decoded glossary items). The engine imports no URLSession.
- AC-6 Unit tests:
  - 食べた → 食べる, 行かなかった → 行く, 高くない → 高い, してしまった → する;
  - katakana input (タベタ) finds 食べる through the hiragana candidate;
  - a tap on べ in 食べた finds 食べる, with a range covering 食べた;
  - the longest match wins (元気 over 元);
  - priority and frequency order, a disabled dictionary ignored, and an exact lookup of a selection.
  A performance test against a synthetic store of about 200k generated terms attaches its timings, and the median scan is under 50 ms on the CI simulator. ARCHITECTURE.md describes the engine.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check the engine tests and the performance attachment. Grep the engine files for URLSession: there must be none.

### Agent notes
- Depends on: T-026 (the store, the fixtures and the batch fetch). Source: spec T-027, and the trade-off "may miss a few rare conjugations".
- **Licence check first:** run `gh api repos/<owner>/<repo>/license -q .license.spdx_id` on each repo you port from (for example rampaa/JL and wareya/nazeka). If one isn't Apache-2.0, MIT or BSD, stop and report Blocked. Never use Yomitan's deinflector (GPL-3.0).
- Extend T-026's v3 fixture if a case needs more words.
- Lookups run on the store's actor, and the API is async (Swift 6, MainActor default isolation).
- A term's `rules` column is space-separated; match it against the deinflected type.
- Learned: no mutating call inside `#expect`.

### Out of scope
- Kanji lookups, pitch accent, name dictionaries, any UI.

## Implementation notes (round 1)
- Licence: `gh api repos/rampaa/JL/license` = Apache-2.0 (its LICENSE is the plain licence text, no copyright line). `wareya/nazeka` has no LICENSE file (API 404), but its README says "Copyright 2017~2019; Licensed under the Apache License, Version 2.0", and JL's README credits it for the rules. Rules ported from JL at b6ce75c441d40fe66ee9e4208c036fbcc572bb21 (`JL.Core/Resources/deconjugation_rules.json`, copied unchanged). Recorded in THIRD_PARTY_NOTICES.md, `Resources/Licenses/Deconjugation-LICENSE.txt` (Apache text + provenance), Settings > About, and `check-ipa-notices.sh`. No Yomitan code or data.
- Algorithm written for Swift from Nazeka's background-script.js and JL's Deconjugator.cs; checked against a Node mirror of the same logic for the AC-6 words (食べた, 行かなかった, 高くない, してしまった, 来なかった give the expected forms and reasons).
- Added `DictionaryStore.frequencies(matching:)` (+ `FrequencyRow`) because the engine needs term_meta; nothing else in the store changed.
- Files: Services/Dictionary/{Deconjugator,LookupEngine,LookupResult}.swift, Resources/Dictionary/deconjugation_rules.json, ClipDeckTests/LookupEngineTests.swift, three new fixtures (lookup-words, frequency-rank, frequency-occurrence; the existing zips are byte-identical), docs/ARCHITECTURE.md.
- Contract for T-029+: `LookupEngine(store:deconjugator: try Deconjugator.bundled())`; `await scan(text:at: String.Index) -> LookupResult?`, `await lookup(exact:) -> LookupResult?` (types in LookupResult.swift).
- Tester, look at: NLTokenizer's word start for 食べた (tests assume it does not split 食|べた); `Attachment.record(String, named:)` compiling on CI's Swift; the performance median on the CI simulator (attachment `scan-timings.txt`).
- Gotchas: a scan only tries lengths that include the tapped character, so a tap on た of 食べ|た cannot match 食べ alone. Half-width katakana widening uses ICU per character and keeps the original if the result isn't one character. `cop` has no Yomitan rule id and keeps its name. A form deconjugated with no named reason is dropped (it was only a stem change).
- Not run: everything Swift (CI only). Classes: ClipDeckTests/LookupEngineTests, DictionaryStoreTests; `scripts/check-ipa-notices.sh` on the IPA job.

### Orchestrator gate (round 1)
- Ponytail review (about 440 product lines): no Must or Should fix. One batched term query, rule match on Yomitan `rules`, ranking longest match > priority > frequency > score as the spec says. The rule JSON is consistent (156 rules, every list field an array, only the four kinds the decoder knows), so `Deconjugator(rulesJSON:)` won't throw on it. The JSON is bundled flat (Resources/Dictionary is a group, not a folder), so `forResource:` with no subdirectory is right. Comments 7 %: no comment pass.
- Could-fix: half-width katakana with a separate ﾞ/ﾟ mark widens to two characters (カ + ゛), not ガ.
- CI: run 46124072581 (77f6d0d, own branch, scope=all). Pending, not watched.

## Fix round 2 (orchestrator)
CI 46124072581 (77f6d0d, scope=all): shards 2, 3, 4 and the ipa green. Shard 1 ran ClipDeckTests green, including LookupEngineTests and DictionaryStoreTests. Its one red test was `MiningFlowUITests/testMakeACardFromSubtitleLine`, "Card editor should open after recording", the shard's first UI test, 0.5 min in.
- The failure-time screen shows playback done (paused at 0:04.0, the end of line 2) and the app still on "Recording clip". So `CardDraft.recordMedia`, the clip extraction running in parallel, was still going after 25 s on the cold simulator. This task doesn't touch that path, and the test passed in every earlier run today.
- Fix (tests only): the four UI tests that wait for the card editor after a recording wait 60 s instead of 20, like CardTimelineUITests already does. They are MiningFlowUITests:33, MKVImportUITests:54, PlayerLandscapeBehaviourUITests:120 and PlayerLandscapeUITests:123.
