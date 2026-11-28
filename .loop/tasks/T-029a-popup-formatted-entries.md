---
id: T-029a
title: "Dictionary popup: formatted entries"
lane: frontend
depends_on: [T-027, T-028]
status: testing
round: 1
base_sha: 51e88b2
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

## Implementation notes (round 1) · sonnet
_by loop-frontend · 2026-11-28 09:35_
- Changed:
  - `GlossaryHTML` (pure): glossary items to safe HTML. Text escaped; tags ruby/rt/rp, ul/ol/li, table parts, details/summary, div/span, br; a link is its text; `img`, `script` and `style` give nothing; unknown tags keep only their text; only `style` survives as an attribute, from word lists (weight, style, decoration, size in em 0.1 to 5, list style, vertical align); depth capped at 24.
  - `LookupPage` (pure): the popup's HTML document (furigana headword, reasons, frequency badges, one section per dictionary, CSP `default-src 'none'; style-src 'unsafe-inline'`), `summary` (the "expression reading" value) and `headword`.
  - `LookupPopupView` / `LookupWebView` / `LookupPopupState`: native top row (✕ `lookup.popup.close`, Use for a card `lookup.popup.useForCard` only with a handler) over one WKWebView (JS off, non-persistent store, only `about:blank` navigation allowed). Empty states "No entries for <text>" and "No dictionaries yet" (+ pointer), plus a failed state.
  - `LookupPopupPlacement.defaultFrame(in:isLandscape:)`: the one place for AC-5.
  - `PlayerView`: `lookup` state; landscape draws the popup from `videoScreen` (under the centre overlay, and so under the bars), portrait overlays the portrait layout. `-uiTestingLookup <text>` (`LaunchFlags.lookupText`) opens it from `setUp()` (Debug).
  - `DictionaryManagerModel.makeEngine()`; `popup-frequency.zip` fixture (a frequency row for 元気, because the existing `frequency` fixture has none and its entry counts are asserted elsewhere); seeded only when `-uiTestingLookup` is passed.
- Files:
  - New: `ios/ClipDeck/Services/Dictionary/GlossaryHTML.swift`; `ios/ClipDeck/Features/Lookup/{LookupPage,LookupPopup,LookupPopupPlacement}.swift`; `ios/ClipDeckTests/{GlossaryHTMLTests,LookupPageTests}.swift`; `ios/ClipDeckUITests/LookupPopupUITests.swift`; `scripts/fixtures/dictionaries/popup-frequency.zip`.
  - Edited: `PlayerView.swift`, `ClipDeckApp.swift` (LaunchFlags), `RootView.swift` (seeder), `DictionaryManagerModel.swift`, `scripts/make-dictionary-fixtures.py` (the other zips rebuild byte-identical), `CLAUDE.md`, `docs/{DESIGN,ARCHITECTURE,DEVELOPMENT}.md`.
- Checked: nothing compiled (Windows). Read every API by hand; scanned the changed Swift files for lines with an odd number of `"` (none); rebuilt the fixture zips and compared them with the checked-in ones.
- Tester, look at:
  - **Landscape place**: "16 pt in from the video column's top and trailing edges (inside the safe area)" is measured from the column edges inset by the safe area (`barInsets`: the safe trailing inset, or the 32 pt handle clearance with the side panel open). With no inset it is exactly 16 pt from the column edge.
  - **Test hook**: in UI-test launches the popup's accessibility label is "Dictionary area x y w h" (screen points), so the frame tests don't need to know the device's safe area. A normal launch says "Dictionary".
  - **Container frame**: `lookup.popup` is an `.accessibilityElement(children: .contain)` with a background, so XCUITest should report its real frame (CONTEXT, T-016). If it reports the union of its children, the frame checks in `testPortraitDefaultFrame…` and `testLandscapeDefaultFrame…` fail on a few points at the top edge; the attached `…-frame` text shows the numbers.
  - **Value on a container**: the value "元気 げんき" is set on the same container. If XCUITest doesn't expose it there, every popup test fails at `waitForEntry`.
  - Web text: the tests read `app.webViews.staticTexts` with a label CONTAINS match (the badge may arrive as one text or two).
  - Light and dark: the page colours come from `Color.resolve(in:)` at build time; CI can't switch to dark (CONTEXT), so dark is unchecked.
- Gotchas: the popup reloads its page when the layout flips between portrait and landscape (a new web view). A link in a dictionary is plain text, so nothing in the web view is tappable.

### Orchestrator gate (round 1)
- 388 added product lines across 8 Swift files, comments 8%: no comment pass; ponytail review after a Pass (over 150 lines). Fixture script compiles; the builder rebuilt the 11 existing zips byte-identical.
- CI: run 46155569943 (3379643, only_testing ClipDeckTests + LookupPopupUITests + DictionaryManagerUITests). Pending, not watched.
