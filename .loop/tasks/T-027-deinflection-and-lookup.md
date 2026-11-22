---
id: T-027
title: Deinflection and lookup engine
lane: backend
depends_on: [T-026]
status: todo
round: 0
base_sha:
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
