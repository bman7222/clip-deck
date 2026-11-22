---
id: T-029a
title: "Dictionary popup: formatted entries"
lane: frontend
depends_on: [T-027, T-028]
status: todo
round: 0
base_sha:
issue: 34
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Show a word's dictionary entries, nicely formatted, in a popup over the player

### What are we building?
The engine can find entries, but nothing shows them. After this task a popup over the player shows a word's entries: the headword with furigana, frequency badges, and each dictionary's definitions in its own section, formatted like Yomitan and fully offline. It has ✕ to close it, and a slot for "Use for a card", which T-030b wires up. For now it opens only through a test launch flag: tapping words comes in T-030a, and moving and resizing in T-029b.

### Why?
Readable definitions are the point of the dictionary. This proves the formatting and the offline guarantees before the tap flow is built on top.

### Done when
- AC-1 A pure converter turns Yomitan glossary items (plain strings, `text` items and `structured-content`) into safe HTML:
  - every piece of text is escaped;
  - only these tags are allowed: ruby/rt/rp, ul/ol/li, table/thead/tbody/tr/th/td, details/summary, div/span and br; a link is shown as plain text;
  - a small set of styles is allowed (font weight and style, text decoration, font size in em, list style, vertical align);
  - images are dropped.
  Unit tests cover ruby, nested lists, a table, details, a link (text only), a `script` or `onclick` attempt (it ends up as inert text or is dropped), an image (dropped) and HTML special characters (escaped).
- AC-2 The popup view `lookup.popup`:
  - a native top row: ✕ (`lookup.popup.close`) at the top right, and a slot for Use for a card (`lookup.popup.useForCard`) that shows only when a handler is given (none yet);
  - the body is one scrolling WKWebView showing every entry: the headword with its reading as furigana, frequency badges (dictionary title + display value) when a frequency dictionary has data, and one section per dictionary, in priority order;
  - colours come from the Theme tokens, in light and dark mode;
  - the popup's accessibility value is the top entry's "expression reading", for tests.
- AC-3 The web view can't reach the network: JavaScript is off, the data store is non-persistent, a Content-Security-Policy allows inline styles only, and a navigation delegate cancels every navigation except the initial inline load (about:blank).
- AC-4 Empty states: "No entries for <text>", and "No dictionaries yet" with a pointer to the Dictionaries button in the Library when the store is empty.
- AC-5 Placement: in landscape the default size is 300×200 pt, inside the video column; in portrait it's the full width minus 32 by 260 pt, inside the safe area. The default position keeps it out of the way (Q1, Brent 2026-11-22):
  - portrait: full width with 16 pt side margins, over the subtitle list, its bottom edge just above the bottom safe area (16 pt gap);
  - landscape: the top-trailing corner of the video column, 16 pt in from its top and trailing edges (and inside the safe area).
  Keep this default in one place, because T-029b's ↺📄 resets to it. Bars and the centre overlay always draw above the popup, so every control stays usable.
- AC-6 `-uiTestingLookup <text>` (Debug, with `-uiTesting -uiTestingDictionary`) runs an exact lookup of `<text>` when the player appears and opens the popup. It's documented in CLAUDE.md. UI tests in both orientations:
  - `-uiTestingLookup 元気` shows `lookup.popup` with the value "元気 げんき", the definition text in the web view, and a frequency badge;
  - ✕ closes the popup;
  - a word with no entry shows "No entries for …", and an empty store shows "No dictionaries yet";
  - the popup lies inside the video column (landscape) or the safe area (portrait), and `player.playPause` stays hittable;
  - the default frame matches AC-5 within 1 pt: in portrait x = 16, width = screen width − 32, and bottom = safe-area bottom − 16; in landscape it's 16 pt in from the video column's top and trailing edges (inside the safe area).
  DESIGN.md describes the popup.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check the renderer unit tests, the popup UI tests and the screenshots in light and dark mode.
- Unverified for Brent: real JMdict entries in the popup, and an airplane-mode check.

### Agent notes
- Depends on: T-027 (the result contract) and T-028 (`-uiTestingDictionary`). Source: spec T-029; section G "Formatted popup".
- Q1, answered by Brent on 2026-11-22: the default position is out of the way, as in AC-5. It's also the ↺📄 reset target (T-029b).
- XCUITest sees the text inside a WKWebView as `app.webViews.staticTexts`. Give ids to the native top row and the container, and don't rely on the web view's element frames.
- Code: the landscape stack that draws the bars over the video is at PlayerView.swift:263-293, and the portrait layout at 179-203.
- Learned: in landscape, use element screenshots and `app.debugDescription`. Known flakes are in CONTEXT.

### Out of scope
- Moving, resizing, remembering and resetting the popup (T-029b).
- Tapping words, pausing and highlighting (T-030a), Use for a card (T-030b).
- Images, and the dictionaries' own `styles.css`.
