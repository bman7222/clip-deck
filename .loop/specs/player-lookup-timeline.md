# Plan: clip-deck: new icon, video-style controls, Move-Text menu, offline dictionary, clip timeline

## Context
Brent wants five things in Clip Deck:
1. a new app icon;
2. player controls that work like a normal video player (a centred ⟲5 ⏯ 5⟳ overlay);
3. subtitle positioning split out of the Font menu into its own Move-Text menu, with a draggable outline;
4. a Yomitan-style **offline** dictionary popup with Lookup Mode;
5. a draggable whole-episode timeline in Make a Card.

Fix 2 means rearranging the bars so these new pieces fit.
This document is the roadmap Brent asked for. It is based on a read-only inspection of the code, research into offline dictionaries, and his answers (all recorded below).
**Nothing gets built until he approves it.** After approval:
- `loop-planner` turns each roadmap task into `.loop/tasks/T-019…`, with GitHub issues, on branch `loop/player-lookup-timeline`;
- then `/dev-loop run --auto` builds them on Sonnet, with ask-on-fail and conservative CI.

---

## A. What the codebase has today (inspected; paths under `ios/ClipDeck/`)

| Area | File(s) | What it does now | Matters because |
|---|---|---|---|
| Player screen | `Features/Player/PlayerView.swift` | Everything for the player. **Portrait:** controls always visible under a 16:9 video, and a tap on the video toggles play (`videoScreen(onTap: model.togglePlay)` ~181). **Landscape:** top and bottom bars over the video, with a tap toggle and auto-hide after 3 s (`controlsVisible`, `restartHideTimer` 597, `keepsControlsUp` 569). Buttons come from `transportButtons(_:landscape:skips:)` 625-682: −5, play/pause `player.playPause`, +5, offset chip, Subtitles, Aa. Make a Card has 3 copies: portrait full width, landscape bar `player.makeCard`, side panel `player.panel.makeCard`. | Features 1, 2, 3 and Fix 2 |
| Player state | `Features/Player/PlayerModel.swift` | `@Observable`: `isPlaying`, `currentMs`, `durationMs`, `track`, `currentCue`, `cueForCard`, `togglePlay/skip/seek/playSegment` | Pause/resume rules, Use for a card |
| Button styles | `DesignSystem/Components.swift` 69-98 `DeckIconButtonStyle(isActive:)` | Active = aqua `Theme.accent` fill with white glyph; idle = Shell background with Ink glyph. Play/pause is **always** active. | 1B colour rule |
| Subtitle line | `Components.swift` 163-236 `SelectableText` (a UITextView, selectable, no coordinator); used at `PlayerView.swift` 540-562, id `player.subtitle` | Long-press and double-tap select text, and the edit menu offers Copy and iOS Look Up. `updateUIView` resets `attributedText` on every pass, which probably clears a selection. | Lookup taps, selection |
| Style model | `Features/Player/SubtitleStyle.swift` | JSON in `player.subtitleStyle`: font, bold, sizeStep −4…10, `upSteps` 0…18 and `rightSteps` −8…8 (whole 5 % steps), pickedFontName. Reset puts **everything** back to default. | Dragging needs finer positions; the resets must be separate |
| Placement | `Features/Player/SubtitlePlacement.swift` | `frame(...)` is pure: resting region, top/bottom obstructions, clamps, plus the T-018 helpers `canStepUpWithCardOpen`, `highestReachableUp`, `upAfterDownWithCardOpen` (renamed from the step forms in T-023) | Collision avoidance, drag limits |
| Style menus | `SubtitleStyleSheet.swift` (portrait: Font, Size, Position, Reset sections), `SubtitleStyleCard.swift` (landscape: 13 icons, 1/2/3 rows, replaces the bottom bar) | Position arrows live here today | Split into Font and Move-Text |
| Card editor | `Features/CardEditor/CardEditorView.swift`, `CardDraft.swift`; `Services/Subtitles/CueTrack.swift` (`ClipRange` in Int ms, `ClipMath.adjusted`, min 200 ms) | A sheet. **Discard and Save card are in the top title bar.** "Start"/"End" are ±0.1/±0.5 s **nudge rows** (no set-to-playhead buttons). Range changes make `needsRerecord` true. All fields are `TextField`s. Has `track.cues`, `offsetMs`, `videoDurationMs` (may be 0 until loaded). | Timeline, Lookup in the editor |
| Library | `Features/Library/LibraryView.swift` | Toolbar holds Add episode and Sync on the top right | Home for the dictionary button |
| Persistence | SwiftData (`App/ClipDeckApp.swift` 39-46), UserDefaults JSON settings | No SQLite yet | The dictionary needs its own store |
| App icon | `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (one 1024 image) | Placeholder art. `scripts/make-source-json.py:27` points SideStore's icon URL at this exact path. | Keep the file name and path |
| CI | `.github/workflows/ios-simulator.yml` | Simulator job took **46 of its 60 min** on the last run | Many new UI tests would push it past the limit |

**Conflicts and limits found:**
- Portrait tap = play/pause is asserted by `PlayerLandscapeBehaviourUITests.testPortraitTapStillTogglesPlay`. It must change.
- Several tests assume ±5 sits in the bar, or use the play button's `maxY` as the bar reference (`SubtitleStyleCardTesterUITests.checkCard`).
- The landscape style card covers the default subtitle spot. That's why Move-Text goes at the top (Brent's choice).
- The video picture rect is never measured exactly. Letterboxing counts as "video"; that's acceptable.
- Swift is compiled only on CI, so every task ends with CI runs.

---

## B–D. Tasks, with technical approach and UI spec
The lane is shown in brackets. Each task adds `accessibilityIdentifier`s (`feature.element`), unit and UI tests, and DESIGN.md notes.

### Fix 1: App icon
**T-019 New app icon [frontend]**
- Copy `clip-deck-temp-files/clip-deck_app_icon_1024.png` (a folder next to the repo; the orchestrator passes the full path to the builder; verified 1024×1024, RGB, no alpha) over `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
- Contents.json and the path stay as they are, so `make-source-json.py` keeps working.
- iOS generates every smaller size from the 1024 image. No dark or tinted variants (none exist today).
- Check: the CI build plus actool, and the IPA contains `AppIcon60x60@2x.png`.

### CI capacity (needed before the UI-heavy tasks)
**T-020 Split the simulator job [backend]**
- Shard the UI tests into 2 parallel jobs, keeping unit tests and the IPA as they are.
- The repo is public, so minutes are free. Keep the `scope`/`only_testing` inputs.
- Done when a full run finishes under 35 min per job.

### Feature 1 + Fix 2: Player controls
**T-021 Centred playback overlay, plain bottom pause button, new bar layout [frontend]**
- **Overlay** in both orientations, positioned against the **video container**, not the screen:
  - Three white glyphs, each on a translucent black circle for contrast: back 5 s, play/pause, forward 5 s. Ids: `player.overlay.back5`, `player.overlay.playPause`, `player.overlay.forward5`.
  - Their centres sit at **25 %, 50 % and 75 %** of the video width (equal gaps from edge to button to centre). They are vertically centred.
  - Size: the centre button is a 52 pt circle and the skips are 44 pt.
  - It fades in and out with the existing landscape controls: 0.2 s, 3 s auto-hide while playing, stays while paused, a plain fade under Reduce Motion.
- **Portrait:** a tap on the video now shows or hides the overlay and no longer toggles play. Update `testPortraitTapStillTogglesPlay`.
- **1D:** remove ±5 from the portrait row and the landscape bar. Drop the `skips:` variant.
- **1B:** the bar's play/pause uses `DeckIconButtonStyle(isActive: !model.isPlaying)`. Idle (Shell/Ink) while playing; aqua while paused. Add an accessibility value of "Playing" or "Paused" so tests can check it.
- **Fix 2 layout** (approved mockup):
  - Portrait: row `⏯ ±0.0s Subs Aa ✥A [↺📄]`, then `📄🔍 [Make a Card]`.
  - Landscape bar: `⏯ ±0.0s Subs Aa ✥A [↺📄] … 📄🔍 [Make a Card]`.
  - Side panel: `📄🔍 [Make a Card]`.
  - T-021 only reserves the order. ✥A, 📄🔍 and ↺📄 arrive in T-024, T-030 and T-029, so each task inserts its button in the agreed spot.
  - Keep the `ViewThatFits` fallbacks.

**T-022 Subtitles avoid the overlay [frontend]**
- Add an optional `avoid: CGRect?` band to `SubtitlePlacement.frame` (pure).
- While the overlay is visible and the line's frame meets the overlay band (plus 8 pt padding), place the line just above or just below the band. Pick whichever needs the smaller move and still fits the region; if neither fits, use below.
- Animate it with the existing 0.2 s ease. When the overlay hides, the line goes back.
- It never writes the saved style.
- Unit tests: overlap above or below, no overlap, nothing fits. A UI test: seed `upFraction` 0.45 so the line sits mid-video, show the overlay, and assert there's no intersection.

### Feature 2: Move-Text menu
**T-023 Continuous position plus separate resets [backend]**
- `SubtitleStyle` gets `up: Double` (0…0.90) and `right: Double` (−0.40…0.40) in place of whole steps.
- Tolerant decode migrates the old `upSteps`/`rightSteps` (×0.05). It keeps `-uiTestingSubtitleStyle` working by accepting either the old or the new keys.
- Arrow buttons move **±0.05 from the current value**, clamped. That's 5 % per tap, as Brent chose.
- `resetFont()` covers font, pickedFontName, bold and size. `resetPosition()` covers up and right. Each leaves the other group alone.
- Adapt `SubtitlePlacement` and the T-018 helpers to fractions, so "can move up" works the same way.
- Unit tests: migration, clamps, both resets kept apart.

**T-024 Move-Text button and menu; Font menu without arrows; blue outline [frontend]**
- **Icon `✥A`:** a SwiftUI view with an "A" and four small outward arrows, in `DeckIconButtonStyle`. Aqua when the position isn't the default. Id `player.moveText`. It goes right after Aa.
- **Font menu:**
  - Remove the arrows and the Position section.
  - Reset becomes `resetFont()`; its value reads "Default" or "Changed" for the font group only.
  - New card rows:
    - one row: sans, rounded, serif, More, Bold, size−, size+, Reset, Done;
    - two-row fallback: [fonts, More, Bold] / [size−, size+, Reset, Done].
  - Reset sits toward the left of its row.
  - The sheet loses its Position section with no gap: Size and Reset move up.
- **Move-Text menu:**
  - Portrait: a sheet with SheetFit, keeping the video visible. It holds the four arrows (`moveText.left|up|down|right`), a value line ("Up 20 % · Left 10 %"), Reset (`moveText.reset`, position only, reset-arrow icon) and Done.
  - Landscape: a compact card that **replaces the top bar** (Brent's choice). The bottom stays free, the line shows at its true place, and Up dims when another step can't visibly move it, because the menu is a top obstruction.
- Opening the menu pauses playback; Done resumes only if the menu paused it.
- **Outline:**
  - A 2 pt rounded rectangle in `Theme.accent`, padded 6 pt around the line's real frame from `SubtitlePlacement`.
  - With no line on screen, it frames a placeholder one-line sample ("あいう Abc") measured in the user's current font and size, so it shows where text will go.
  - Id `moveText.outline`.

**T-025 Drag the outline [frontend]**
- Long-press of 0.25 s on the outline. Then:
  - four aqua arrows appear 8 pt outside each edge;
  - the outline and arrows scale to 1.06 with a spring (under Reduce Motion: no scale, the stroke goes to 3 pt);
  - a light haptic plays.
- Dragging moves the line live; the text follows the outline exactly because it uses the same frame function.
- The pointer position maps to continuous `up`/`right` and clamps to the same limits as the arrows: 0…0.90, ±0.40, plus the region clamp.
- Saved on release. Arrows and drag edit the same stored value.
- VoiceOver gets adjustable actions.
- UI test: `press(forDuration:thenDragTo:)` moves the line by about the dragged distance, stops at the limits, and the arrows still step by 5 %.

### Feature 3: Offline dictionary and Lookup Mode
**Chosen approach (Brent): a native Swift engine reading Yomitan dictionary .zip files.** No Yomitan code is used: it's GPL-3.0, and Clip Deck is "all rights reserved".

| Approach | Verdict |
|---|---|
| **Native Swift: Yomitan zip → SQLite; own lookup; deinflection from Apache-2.0 rules (JL/Nazeka line)** | **Chosen.** Offline, fast, iOS 17, no licence risk |
| hoshidicts (MIT C++) | Not chosen: needs the Swift 6.2/C++23 toolchain, declares iOS 18 |
| Yomitan JS in a WKWebView | Not chosen: fragile, and GPL-3.0 applies the moment the app is shared |
| Apple Look Up | Kept as it is (the edit menu's Look Up); not the popup |

- **Storage:** `Library/Application Support/Dictionaries/dictionaries.sqlite`, accessed through the system `SQLite3` C API with a small Swift wrapper. No ORM; SwiftData is too slow at about 200k rows.
- **Size:** JMdict English is a 15.6 MB zip, about 40–80 MB on disk (an estimate).
- **New dependency:** ZIPFoundation (MIT) through SPM in `project.yml`, for unzipping. Add it to THIRD_PARTY_NOTICES with the JL/Nazeka Apache-2.0 notice and the EDRDG CC BY-SA 4.0 attribution.

**T-026 Dictionary store and Yomitan importer [backend]**
- **Schema:**
  - `dictionaries` (id, title, revision, kind, priority, enabled, attribution, counts, bytes);
  - `terms` (dict, expression, reading, defTags, rules, score, sequence, termTags, glossary as a compressed JSON blob), indexed on expression and on reading;
  - `term_meta` (dict, term, mode, JSON data), indexed on term, with **freq only for now**; pitch and IPA rows are skipped;
  - `tags`.
- Import formats v1–v3 from a .zip. Term banks, frequency meta banks and tag banks; kanji banks are ignored for now.
- Runs in a background actor with progress and cancel, inside one transaction. On failure it rolls back and leaves nothing half-imported.
- Rejects a duplicate title and revision.
- Unit tests use tiny fixture zips (checked in, about 2 KB).

**T-027 Deinflection and lookup engine [backend]**
- Rules are ported from the Apache-2.0 JL/Nazeka deconjugator. The builder confirms the licence and records it in NOTICES.
- Pipeline:
  1. Normalize: half-width to full-width, katakana to hiragana as an extra candidate.
  2. Scan from the tapped character: NLTokenizer moves the start back to the beginning of the word, then try substrings of 16 down to 1 characters.
  3. Deinflect.
  4. One batched SQL query.
  5. Keep only entries whose rules match the deinflected form.
  6. Rank: longest match, then dictionary priority, then frequency, then score.
- Groups entries by expression and reading and merges definitions per dictionary.
- Also offers an exact lookup for a selection (no scanning).
- Network-free by design: the engine has no URLSession dependency.
- Unit tests: 食べた→食べる, 行かなかった→行く, 高くない→高い, してしまった→する, katakana, tap in the middle of a word, longest match wins.
- Every lookup must take under 50 ms on the CI simulator.

**T-028 Dictionary manager [frontend]**
- **Opener:** a Library toolbar button on the **top right, leftmost**, before Add episode and Sync. Icon `character.book.closed.ja`, id `library.dictionaries`. Only there.
- **Sheet contents:**
  - The installed dictionaries, each with title, kind (Words/Frequency), entry count and size. Drag to reorder: the order is the priority, and "first available" for Use for a card follows it. Each has an enable toggle and swipe-to-delete (with confirmation).
  - **Import from Files** through `.fileImporter` for .zip files, with progress.
  - **Download JMdict English** from `https://github.com/yomidevs/jmdict-yomitan/releases/latest/download/JMdict_english.zip`, with a progress bar and cancel. This is the app's only new network call, and lookups never use the network.
  - A Sources section with the EDRDG text and each dictionary's `attribution`. It's also linked from Settings › About.
- Update CLAUDE.md's "only network code" note.

**T-029 Dictionary popup [frontend]**
- **Structured-content renderer:** a pure Swift converter from Yomitan structured-content JSON to safe HTML. It handles ruby/furigana, lists, tags, tables, `details` and links (links shown as text; no images in v1). Unit-tested.
- **Popup view** (`lookup.popup`):
  - The body is one WKWebView with scrolling, no network access (the load is blocked) and styling from the app's colour tokens in light and dark.
  - The headword and reading show with furigana. Frequency badges appear when a frequency dictionary exists. Each dictionary's definitions sit in their own section.
  - A highlighted matched range sits on the subtitle.
  - Empty states: "No entries for X", or "No dictionaries yet" with a pointer to the Library button.
- **Popup chrome:**
  - Top left: a **drag-handle button** (`lookup.popup.move`). Dragging moves the popup.
  - Top right: **"Use for a card"** (`lookup.popup.useForCard`) and **✕** (`lookup.popup.close`).
  - Pressing and dragging the left, right, top or bottom border (a 16 pt hit zone) resizes from that side.
  - The minimum is the default size: 300×200 pt in landscape, full width minus 32 by 260 pt in portrait. The maximum is the whole allowed area.
- **Bounds:** landscape keeps the popup inside the video area; portrait lets it use the whole screen. It never goes off-screen; a maximum-size popup dragged into a corner stays clamped in the corner.
- Bars and the centre overlay always draw above the popup, so every control stays usable.
- Position and size are remembered **per orientation** (UserDefaults JSON, kept across launches).
- **↺📄 popup reset** (`player.lookupReset`): a reset arrow with a document, in the bar spot from Fix 2, shown only while a popup is open. It restores the default size and position.

**T-030 Lookup Mode in the player [frontend]**
- **Toggle 📄🔍:** `doc.text.magnifyingglass`, id `player.lookupMode`. Idle (dark/ink) when off, aqua when on. Remembered across launches.
- It sits immediately left of all three Make a Card buttons.
- **`SelectableText` gains a coordinator.** With Lookup Mode on:
  - **A single tap on a word:**
    1. find the character index;
    2. scan with the engine;
    3. highlight the matched range;
    4. **pause**;
    5. open or replace the popup.
  - The single tap waits for the double-tap to fail, so selection still works.
  - **Press and hold** brings up the normal iOS selection handles to widen or narrow the text. Each selection change re-runs an **exact** lookup of the selected text and updates the popup. Copy and Look Up stay in the edit menu.
  - Stop resetting `attributedText` unless the text or style actually changed, so selections survive re-renders.
- With Lookup Mode off, everything behaves as it does today.
- A tap elsewhere on the video still toggles the controls.
- **Closing:** ✕ closes the popup and resumes playback only if the lookup paused it. **Resuming playback any other way also closes the popup.**
- **Use for a card:**
  1. runs the same path as Make a Card for the current line;
  2. once the draft is ready, fills **Word** (the entry's headword in dictionary form) and **Definition** (the first-priority dictionary's senses for the top entry, as a plain numbered list "1. … 2. …");
  3. the popup stays open behind the editor.
- Make a Card and every other control work while the popup is open.

**T-031 Lookup in Make a Card [frontend]**
- The same toggle sits in the editor's **top bar next to Save card**.
- While the toggle is on, the Sentence field shows as tappable read-only text (the same coordinator, same tap and hold behaviour). Turning it off makes the field editable again.
- The popup is bounded by the editor sheet and remembers its own position and size.
- Its **Use for a card** fills **this** card's Word and Definition, replacing them; both stay editable.

### Feature 4: Clip timeline
**T-032 Timeline maths [backend]**
- A pure `ClipTimeline` type:
  - **Notches:** cue start and end times in video time (offset applied), with shared boundaries merged (equal within 1 ms; on screen, notches closer than 2 pt draw as one).
  - **Zoom window:** 30 s centred on the clip, widened to the clip length plus 20 % for long clips, clamped to [0, duration]. Duration falls back to the last cue's end while `videoDurationMs` is 0.
  - Mapping between time and x.
  - **Snapping:** within 10 pt of a notch, with a pull-off past 16 pt.
  - **Handle clamps:** start ≥ 0, end ≤ duration, start ≤ end − 200 ms, reusing `ClipMath.minimumDurationMs`.
  - **Handle choice** when the two overlap: the nearest one wins; on a tie, the drag direction decides.
- Unit tests.

**T-033 Timeline view in Make a Card [frontend]**
- It sits above the nudge rows (`card.timeline`) and has two parts:
  - **Overview strip:** the whole episode, 8 pt tall, with an aqua block marking the clip.
  - **Zoomed track:** a rounded track in the normal theme. **Blue** (`Theme.accent`) 2×10 pt notches, a 25 % accent fill between the handles, and two white-with-accent-border **28 pt circular handles with 44 pt hit areas** (`card.timeline.start`, `card.timeline.end`). While dragging, a bubble shows the time (m:ss.t). The window labels show the window's start and end.
- Optional: a playhead line while Play clip plays.
- **Snap** chip (`card.timeline.snap`): an on/off switch, remembered.
- One source of truth: handles and nudge rows both write the editor's `range`. After a drag, `needsRerecord` behaves exactly as it does after a nudge: Save is disabled and the red Re-record button appears.
- The window re-centres when a drag ends outside it.
- No cues means no notches and the Snap chip is disabled.
- VoiceOver: each handle is adjustable by ±0.1 s.
- Small phones: the track is full width, and the time bubble flips inward at the edges.

### Docs (part of each task's acceptance criteria)
- DESIGN.md: overlay, colours, Move-Text, popup, timeline.
- PRODUCT_SPEC: move the dictionary out of "Not yet implemented".
- ARCHITECTURE: the dictionary store and engine.
- THIRD_PARTY_NOTICES and in-app licences.
- CLAUDE.md network note and new `-uiTesting` flags.

---

## E. Testing plan
- **Unit tests (CI):**
  - placement with the avoid band, fraction migration and clamps, separate resets;
  - importer (good, corrupt and duplicate zips, rollback);
  - deinflection table cases, scan and ranking, exact lookup;
  - structured-content HTML;
  - timeline maths (notch merging, zoom, snapping, clamps, handle choice);
  - Use-for-a-card field text.
- **UI tests (CI, iPhone 17 Pro simulator, both orientations):**
  - overlay positions at 25/50/75 % and its fade;
  - the bar has no ±5; the play button's value is Playing/Paused;
  - the line avoids the overlay;
  - the Font menu has no arrows and its Reset leaves the position alone; Move reset leaves the font alone;
  - the Move menu pauses; the outline exists with no cue; drag stays within limits; arrows step 5 %;
  - Lookup: tap a word, popup with its entry, video paused, ✕ resumes, play closes it; press and hold to change the selection updates the popup; drag and resize are clamped; ↺📄 resets; Use for a card fills Word and Definition;
  - editor lookup and the Sentence toggle;
  - timeline drag, snap toggle, nudge sync, re-record gating.
- **Test hooks:**
  - `-uiTestingDictionary` imports a tiny fixture dictionary into a temporary database at launch, so CI never needs the network.
  - Existing `-uiTesting` seeds are extended for subtitle positions given as fractions.
- **Offline:**
  - The engine has no network dependency (checked in review).
  - The WKWebView blocks every load except about:blank and inline content.
  - A real-device check in airplane mode.
- **Screen sizes:** UI tests on the Pro simulator. Unit tests cover layout maths at SE (375×667) and mini widths. Brent checks on his iPhone.
- **Regression:** the whole existing suite (390 tests) stays green. The known flakes are listed in CONTEXT "Learned".
- **Brent checks on his iPhone:**
  - how the overlay and fades feel;
  - drag precision;
  - the long-press selection plus lookup with real Japanese subtitles;
  - popup drag and resize;
  - JMdict download and import time;
  - airplane-mode lookups;
  - timeline handles on a 24-minute episode.

## F. Implementation order (dependencies)
1. **T-019 icon** and **T-020 CI split**: independent and quick, and they unblock the heavy UI testing.
2. **T-021 overlay and bars**, then **T-022 avoidance**.
3. **T-023 position model**, then **T-024 Move-Text and Font split**, then **T-025 drag**. These need T-021's bar.
4. **T-032 timeline maths**, then **T-033 timeline view**. Independent of the player work, so they could also run earlier.
5. **T-026 store and importer**, then **T-027 engine**, then **T-028 manager** and **T-029 popup**, then **T-030 player lookup** (needs T-021's bar), then **T-031 editor lookup**.

Shared pieces come before the features that depend on them:
- `DeckIconButtonStyle` state use (T-021);
- the `SubtitlePlacement` API (T-022/T-023);
- the `SelectableText` coordinator (T-030, reused in T-031).

There are 15 tasks, and each pauses only for a failed Sonnet round (ask_on_sonnet_fail) or a product question.

## G. Decisions
**Brent's answers:**
- Native Swift engine.
- Import plus a JMdict download button, only from the Library top right (leftmost).
- Formatted popup.
- Use for a card = Make a Card plus Word and Definition, with the popup staying open and every control still working.
- Pause on lookup; press and hold adjusts the selection.
- Popup: a drag handle at the top left; ✕ and Use for a card at the top right; edge resize with minimum and maximum; never off-screen; bounded by the video in landscape and the screen in portrait; remembered per orientation; a ↺📄 reset in the bar; resuming playback closes it; ✕ resumes only if the lookup paused.
- In the editor: the Sentence becomes tappable; the toggle sits next to Save; Use for a card fills this card.
- No lookup in the subtitle list for now.
- Overlay in portrait too.
- Move menu at the top in landscape.
- 5 % arrow steps.
- Fix 2 layout as in the mockup.
- Whole-episode strip plus zoomed track.
- Snap with an on/off switch.
- Re-record stays the same as now.
- Icon from the 1024 file.
- Words plus frequency dictionaries.
- Download JMdict English.
- Japanese only.
- Definition as a plain numbered list.

**My defaults, for Brent to confirm by approving or change now:**
1. **Make a Card / Use for a card while the popup is open:** the recording playback (`playSegment`, while `miningRange != nil`) does **not** close the popup. Only playback the user starts does: the centre or bar play button, or releasing the scrubber. Brent confirmed this on 2026-11-22; Use for a card needs the popup to stay open.
2. **Move menu Done:** resumes only if opening the menu paused the video, matching the popup rule.
3. **Arrows after a drag:** they step 5 % from wherever the drag left the line (no snapping back to the old grid).
4. **Lookup Mode:** remembered across app launches.
5. **Overlay buttons:** white glyphs on translucent dark circles, so they stay readable on bright scenes.
6. **Timeline colours (Brent, 2026-11-22):** the notches are **blue**. Notches are solid `Theme.accent` 2×10 pt on the normal-theme track. The selected range is accent at 25 % opacity, so the notches stay visible inside it. Handles are white with a 3 pt accent border. This works in light and dark mode.
7. **Outline with no subtitle:** frames a one-line sample in your current font and size.
8. **T-020 CI split:** added by me because the suite already takes 46 of its 60 minutes.

**Planner questions, answered 2026-11-22 (Brent):**
- **Q1, the popup's default position (T-029a, T-029b):** out of the way. Portrait: full width with 16 pt margins, over the subtitle list, just above the bottom safe area. Landscape: the top-trailing corner of the video, 16 pt in. ↺📄 resets to this place and the default size.
- **Q2, the editor's Lookup toggle (T-031):** the editor keeps its own remembered Lookup setting, separate from the player's.
- **Q3, the overlay during Move-Text (T-024a):** the centred overlay is hidden while the Move-Text menu is open, and returns on Done.

**Trade-offs to know:**
- The dictionary is the biggest piece (T-026 to T-031) and adds about 40–80 MB on the phone per large dictionary.
- Deinflection from Apache-licensed rules may miss a few rare conjugations that Yomitan handles. The long-press selection is the fallback.

## Verification (end to end)
- Each task: a fresh `loop-tester` judges the CI run (`gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`) against the task's Done-when. At least one green `scope=all` run before each task lands.
- At the end: a PR to `main` (not merged without Brent's OK), then release v0.5.0 when he says so. Brent then runs the iPhone checks listed in section E, including airplane mode.
