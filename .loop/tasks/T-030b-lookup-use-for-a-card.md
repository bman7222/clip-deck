---
id: T-030b
title: "Lookup Mode in the player: Use for a card"
lane: frontend
depends_on: [T-030a]
status: todo
round: 0
base_sha:
issue: 37
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Make a card straight from the dictionary popup, with Word and Definition filled in

### What are we building?
After a lookup you'd still have to type the word and its meaning into the card yourself. After this task "Use for a card" in the popup makes a card for the current line, exactly like Make a Card, and fills in Word (the dictionary form) and Definition (the first dictionary's senses as a numbered list). The popup stays open behind the editor.

### Why?
One tap from "what does this mean?" to a finished card.

### Done when
- AC-1 `lookup.popup.useForCard` appears at the top right of the player's popup, next to ✕, whenever the popup shows an entry. It runs the same path as Make a Card for the current line (`cueForCard`, the recording playback, the extraction). The popup stays open during the recording (spec G default 1) and behind the editor.
- AC-2 When the draft is ready, the editor opens with:
  - Word = the top entry's expression, in dictionary form;
  - Definition = the top entry's section from the first enabled words dictionary (in priority order) that has one, as plain text: "1. …", then "2. …" on the next line, one line per definition. Each definition's glossary items are flattened to text and joined with "; ", and ruby readings are dropped.
  Both fields stay editable. Sentence, audio, screenshot and Source are filled as today.
- AC-3 Make a Card and every other control keep working while the popup is open. After Save or Discard, the popup is still there.
- AC-4 Unit tests for the field-text builder: plain strings; structured content with ruby, lists and tags; several definitions numbered; a single definition ("1. …"); a higher-priority dictionary without that entry skipped; no definitions → an empty field.
- AC-5 A UI test with `-uiTestingDictionary` and Lookup Mode on: tap 元気, then Use for a card. The recording badge shows while the popup stays open. The editor opens with `card.field.word` "元気" and `card.field.definition` starting with "1. ". Save works, and the popup is still open after the editor closes. DESIGN.md and PRODUCT_SPEC are updated (auto-filling Word and Definition is no longer "not implemented").

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check the builder unit tests, the new UI test and MiningFlowUITests.
- Unverified for Brent: a card made this way arriving in desktop Anki with the right Word and Definition fields.

### Agent notes
- Depends on: T-030a (lookups in the player). Source: spec T-030, "Use for a card"; section G "Use for a card = Make a Card plus Word and Definition", "Definition as a plain numbered list", default 1.
- Code: `makeCard(_:)` is at PlayerView.swift:739-774; the draft is created at 763-770. Give `CardDraft` (CardDraft.swift) optional starting values for word and definition. CardEditorView's init (32-46) seeds `values` from the draft. `CardField` has `.word` and `.definition` (Models.swift:67-86).
- Flatten structured content with T-029a's parsed model, so there's one tree walk. T-031 reuses this builder.

### Out of scope
- Lookups in the editor (T-031), choosing among several entries, adding the reading or pitch, changing the Anki field mapping.
