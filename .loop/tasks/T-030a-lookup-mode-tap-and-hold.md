---
id: T-030a
title: "Lookup Mode in the player: tap or hold a word"
lane: frontend
depends_on: [T-021, T-029b]
status: todo
round: 0
base_sha:
issue: 36
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Turn on Lookup Mode, then tap or hold a word in the subtitle to look it up

### What are we building?
Today the subtitle line can only be selected for Copy and the iOS Look Up. After this task a Lookup Mode button (📄🔍) next to every Make a Card turns on Yomitan-style lookups. A single tap on a word finds it, highlights it, pauses the video and opens the popup. Press and hold selects text you can widen or narrow, and the popup follows the selection. ✕ resumes playback only if the lookup paused it, and playing again closes the popup.

### Why?
This is the core mining loop: pause on a line, read the word, keep watching.

### Done when
- AC-1 The toggle `player.lookupMode` (`doc.text.magnifyingglass` in `DeckIconButtonStyle`: idle when off, aqua when on; label "Lookup Mode", value "On"/"Off") sits immediately left of all three Make a Card buttons: portrait, the landscape bar and the side panel, at T-021's markers. All three share one state, remembered across launches. `-uiTesting` launches clear it unless `-uiTestingKeepLookupMode` is passed.
- AC-2 `SelectableText` gets a coordinator, and stops resetting `attributedText` unless the text or the style changed, so a selection survives re-renders. With Lookup Mode off, the line behaves exactly as today.
- AC-3 With Lookup Mode on, a single tap on the line (which waits for the double-tap to fail):
  1. finds the character index;
  2. scans with the engine (T-027);
  3. highlights the matched range on the line, with a `Theme.accent` background at about 35 %;
  4. pauses, remembering that the lookup paused it;
  5. opens the popup, or replaces its content.
  A tap that finds nothing shows the "No entries" popup. A tap elsewhere on the video still shows or hides the overlay and controls.
- AC-4 Press and hold brings up the normal iOS selection handles. Each selection change runs an exact lookup of the selected text, updates the popup, and pauses if the video is playing. Copy and Look Up stay in the edit menu.
- AC-5 Closing: ✕ closes the popup, clears the highlight, and resumes only if the lookup paused the video. Playback the user starts (the centre or bar play button, or releasing the scrubber) also closes the popup. The recording playback (`playSegment` while `miningRange != nil`) doesn't. The highlight also clears when the line changes.
- AC-6 Tests:
  - unit: the "paused by lookup" rules, kept in a small state type;
  - UI, both orientations, with `-uiTestingDictionary` and Lookup Mode on: a tap on 元気 in 元気ですか opens the popup with the value "元気 げんき" and `player.playPause` reads "Paused"; a tap on こんにちは replaces the content; ✕ resumes ("Playing") when the video was playing, and leaves it paused when it was paused before; play closes the popup; press and hold, then dragging a selection handle, updates the popup; with Lookup Mode off a tap opens nothing; the toggle's state survives a relaunch with the keep flag.
  DESIGN.md and PRODUCT_SPEC are updated.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check the new lookup UI tests (screenshots of the highlight and the popup) and the existing MiningFlow and SubtitleStyle suites.
- Unverified for Brent: tap and long-press selection with real Japanese subtitles, and lookups in airplane mode.

### Agent notes
- Depends on: T-021 (the bar markers) and T-029b (the finished popup). Source: spec T-030; section G "Pause on lookup; press and hold adjusts the selection", "No lookup in the subtitle list", and defaults 1 and 4.
- Code: `SelectableText` is at Components.swift:163-236, and its `updateUIView` (215-218) resets the text on every pass. In PlayerView.swift: `subtitleLine` at 540-562, `makeCardButton` at 684-698, `sidePanel` at 408-432, and the Scrubber at 826-857 (a release is `onEditingChanged(false)`). PlayerModel's `togglePlay`, `play` and `playSegment` are at 86-128.
- Character index: `UITextView.closestPosition(to:)` plus `offset(from:to:)`. The tap recognizer must `require(toFail:)` the text view's own double-tap recognizer.
- To tap one word in a UI test, tap cue row 2 while paused, then tap at a normalised x inside `player.subtitle`. 元気 is the first two of the five characters in 元気ですか, so x ≈ 0.2.
- Learned: in landscape, use element screenshots and `app.debugDescription`. Known flakes are in CONTEXT.

### Out of scope
- Use for a card (T-030b), lookups in the subtitle list (not planned), the editor (T-031).
