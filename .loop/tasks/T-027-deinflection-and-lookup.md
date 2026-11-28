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
- CI: run 46128345124 (d0b5a82, scope=all), also the landing run if green. Pending, not watched.

## Test report (round 2)
_by loop-tester · 2026-11-28 18:10_

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 Deinflection rules are ported from the Apache-2.0 JL/Nazeka deconjugator and kept as data (a checked-in JSON resource or a Swift table), with the source URL and commit recorded. Each result carries its word type, mapped to Yomitan's rule ids (v1, v5, vk, vs, vz, adj-i, …), and the chain of reasons ("past", "negative", …). The licence is confirmed and recorded in THIRD_PARTY_NOTICES.md and in T-026's bundled licence file. | Pass | Ran: `gh api repos/rampaa/JL/license` = Apache-2.0; JL has no NOTICE file (404); Nazeka readme line 23 "Licensed under the Apache License, Version 2.0". `sha256` of the bundled JSON = JL's file at b6ce75c (459e329a…), byte-identical. Full Apache text (TERMS…END OF TERMS) in Resources/Licenses/Deconjugation-LICENSE.txt, shown in About, checked by check-ipa-notices.sh (ipa job green in 46124072581/46128345124). No Yomitan code. `deconjugatesTheCommonForms`, `mapsWordClassesToYomitanRuleIds` green in 46124072581. The licence is in its own bundled file next to T-026's ZIPFoundation one, not inside it; that is the right shape. |
| AC-2 `scan(text:at:)` runs the pipeline: normalise (half-width to full-width, katakana → hiragana candidate); NLTokenizer word start, substrings 16 down; deinflect; one batched SQL query; keep entries whose rules match. Returns the matched range in the original text. | Unverified (tests added) | Katakana, NLTokenizer start (tap on べ), range: green in 46124072581. Half-width and the rule filter had no test: added `halfWidthKatakanaIsWidenedBeforeTheLookup` (ﾈｺ → 猫) and `aDeconjugatedFormNeedsAnEntryWhoseRulesMatch` (食べる seeded with rules "v5": 食べた → nil, 食べる → found). One query: read LookupEngine.swift resolve() (one `terms(matching:)`). |
| AC-3 `lookup(exact:)` handles a selection: the same pipeline on the whole selected text, deinflection included, but with no substring scan. | Pass | `anExactLookupDeconjugatesTheWholeSelectionWithoutScanning` green in 46124072581 (食べるzz → nil proves no substring scan). |
| AC-4 Ranking: longest match, then dictionary priority, then frequency, then score. Frequencies rank-based unless `frequencyMode: "occurrence-based"`. Grouped by expression + reading, one section per enabled dictionary in priority order, alongside each frequency dictionary's value. Disabled dictionaries ignored. | Pass | `theLongestMatchWins`, `definitionsFormOneSectionPerDictionaryInPriorityOrder`, `rankBasedFrequency…`, `occurrenceBasedFrequency…`, `entriesWithTheSameWordAndDifferentReadingsRankByScore`, `aDisabledDictionaryIsIgnoredCompletely` green in 46124072581. |
| AC-5 The result contract has its own file … expression, reading, reasons, frequencies (title, value, display text), sections (id, title, definitions with tags and decoded glossary). The engine imports no URLSession. | Pass | LookupResult.swift read; grep URLSession in Deconjugator/LookupEngine/LookupResult.swift: none. |
| AC-6 Unit tests: 食べた/行かなかった/高くない/してしまった; タベタ; tap on べ; 元気 over 元; priority and frequency order, disabled dictionary, exact lookup. Performance test against ~200k terms attaches timings, median scan under 50 ms on CI. ARCHITECTURE.md describes the engine. | Pass | All named tests and `medianScanOfA200kTermStoreIsUnder50ms` (`#expect(median < 50)`, attachment scan-timings.txt) green in 46124072581 per the orchestrator; ARCHITECTURE.md "Lookup engine" section read. |

Round-2 diff (0c6f93d): only the four UI-test editor waits 20 → 60 s; tests only, fine. 46128345124 shard 3 red (MoveTextTesterUITests terminate failure) is pre-existing, outside this diff (T-036).

### Findings
Could fix
Where: ios/ClipDeck/Services/Dictionary/LookupEngine.swift:53-60
Problem: the scan only tries substrings from the NLTokenizer word start. If the tokenizer keeps a compound the dictionary lacks as one token (e.g. 日本語学校, tap on 学), every probe starts at 日 and the tap finds nothing, though 学校 exists.
Proof: Traced it (probes run from `start` down to `tapped - start + 1` only).
Trigger: tap inside a long token that is not itself a dictionary word.
Fix: if `resolve` returns nothing and `start < tapped`, run it once more with `start = tapped`.

Could fix
Where: ios/ClipDeck/Services/Dictionary/LookupEngine.swift:150-151
Problem: an entry's frequency key is the first frequency dictionary that has it, so two entries can be ordered by values from different frequency dictionaries (and modes).
Proof: Read it. Trigger: two frequency dictionaries that each cover different words. Fix: key on the highest-priority frequency dictionary that has a value for any compared entry, or leave as is.

Could fix
Where: ios/ClipDeck/Services/Dictionary/LookupEngine.swift:76
Problem: `lookup(exact:)` trims the text but returns the range of the untrimmed text. Fix: return the trimmed range.

Could fix (known from round 1): half-width kana with a separate ﾞ/ﾟ stay half-width (no ガ from ｶﾞ); no crash, the character is kept.

Not done: the revert-and-fail mutation check (no Swift compiler here; CI only).

```text
VERDICT: Blocked
SPEC: AC-1, AC-3, AC-4, AC-5, AC-6 met; AC-2 met by reading, half-width and rule filter wait on the added tests
CHECKS_RUN: CI 46124072581 (ClipDeckTests green, ipa notices green); CI 46128345124 (shards 1, 2, 4, ipa green; shard 3 pre-existing T-036); licence API + upstream JSON sha256 match; URLSession grep none
NEEDED: verify-only pass of ClipDeckTests/LookupEngineTests (halfWidthKatakanaIsWidenedBeforeTheLookup, aDeconjugatedFormNeedsAnEntryWhoseRulesMatch)
UNVERIFIED: none for Brent (no UI)
REVIEWED_AT: 0c6f93d04cbde3bccc1ead3fadb70745832f3535
```
- CI: run 46137931107 (b9ca2af, only_testing ClipDeckTests/LookupEngineTests) for the tester's two AC-2 tests. Pending, not watched.

### Round 2 addendum · orchestrator
- Verify-only run 46137931107 (b9ca2af, only_testing ClipDeckTests/LookupEngineTests): green, including the tester's `halfWidthKatakanaIsWidenedBeforeTheLookup` and `aDeconjugatedFormNeedsAnEntryWhoseRulesMatch`. That was the only missing evidence and the tester found nothing to fix, so the verdict is Pass. Landing: by tree onto the loop branch after T-036, then one full run.
