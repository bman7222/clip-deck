---
id: T-031
title: Lookup in Make a Card
lane: frontend
depends_on: [T-030b]
status: todo
round: 0
base_sha:
issue: 38
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Look up words in the Make a Card sentence

### What are we building?
In the card editor, the Sentence is only a text field. After this task a Lookup Mode toggle in the editor's top bar, next to Save card, turns the Sentence into tappable text, with the same tap and press-and-hold lookups as the player. The popup stays inside the editor, and its "Use for a card" fills this card's Word and Definition.

### Why?
Often the word worth learning only stands out while checking the card.

### Done when
- AC-1 The toggle `card.lookupMode` sits in the editor's top bar next to Save card, with the player toggle's icon and colours. It has its own remembered setting, separate from the player's Lookup Mode (Q2, Brent 2026-11-22). It has its own UserDefaults key, is off until first turned on, and is kept across editor openings and app launches. `-uiTesting` launches clear it unless `-uiTestingKeepLookupMode` is passed, the same keep flag as the player's.
- AC-2 While it's on, the Sentence shows as read-only tappable text, using T-030a's `SelectableText` coordinator: the same single tap and press-and-hold behaviour. Nothing pauses, because the editor has no video, and Play clip isn't affected. Turning it off makes the field editable again, with any earlier edits kept.
- AC-3 The popup stays inside the editor sheet. It moves and resizes as in T-029b, and remembers its own place and size, under its own keys, per orientation.
- AC-4 Its Use for a card fills this card's Word and Definition with T-030b's builder, replacing what's there. Both stay editable, and no new draft is made.
- AC-5 UI tests: Make a Card on line 2, turn the editor toggle on, and tap 元気 in the Sentence; the popup shows 元気. Use for a card fills `card.field.word` and `card.field.definition`. Turning the toggle off makes the Sentence editable (type into it). The popup stays inside the sheet. The two settings stay independent: turning the editor toggle on leaves the player's `player.lookupMode` value unchanged, and the reverse. The editor's setting is still on after closing and reopening the editor. Every existing test passes, and DESIGN.md is updated.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check the new editor lookup tests, MiningFlowUITests and the timeline tests (the same screen).

### Agent notes
- Depends on: T-030b (the coordinator from T-030a, and the field-text builder). Source: spec T-031; section G "In the editor: the Sentence becomes tappable; the toggle sits next to Save; Use for a card fills this card".
- Q2, answered by Brent on 2026-11-22: the editor keeps its own remembered Lookup setting, separate from the player's (AC-1).
- Code: in CardEditorView.swift the toolbar is at 62-77 (Save card is the `.confirmationAction` item), and the Sentence `TextField` is in `fieldsPanel` at 180-205. T-033 also edits this screen; keep its timeline intact.
- Learned: a `.contain` container reports the union of its children's frames.

### Out of scope
- Lookups in other fields, editing the dictionary entry, new drafts from the editor.
