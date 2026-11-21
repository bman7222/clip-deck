---
id: T-015
title: Adjust the subtitle style from a menu in the portrait player
lane: frontend
depends_on: [T-014]
status: testing
round: 1
base_sha: 29491a8a99698de0de6b9141cd3e1ee961b711ca
issue: 16
spec: .loop/specs/subtitle-style.md
model:
---

## Adjust the subtitle style from a menu in the portrait player

### What are we building?
A new "Aa" button right next to the subtitles button in the portrait player. It opens a sheet with the style controls: three font chips, Bold, smaller and larger text, four arrows that move the line, Reset to default, and Done. Each tap changes the line on the video straight away, and the video stays visible above the sheet. The choice is remembered across launches.

### Why?
Brent can make the line easier to read, or move it off burnt-in text, without changing the iPhone's text size for every app.

### Done when
- AC-1 `player.subtitleStyle` is a `Button` (not a `Menu`) with the `textformat` icon in `DeckIconButtonStyle`. It is aqua when the style isn't the default, sits directly after `player.subtitlesMenu` in `transportButtons`, and has the label "Subtitle style". (Landscape shows it too. T-016 wires its card; until then it may open nothing in landscape, but must not break the bar.)
- AC-2 The sheet holds the spec's controls, each with its `subtitleStyle.*` identifier:
  - one row per font preset: the name, and the sample "Aa あア漢字" drawn in that font (so both scripts can be judged), aqua when selected. Leave room below the presets for T-017's "More fonts…" row;
  - `bold`, `textformat.size.smaller`, `textformat.size.larger`;
  - `arrow.up|down|left|right` and `arrow.counterclockwise`;
  - Done.
  The values show: "130%", and position like "Up 20% · Left 10%" or "Default place". The icons are distinct from each other, and the colours come only from the Theme tokens: idle Shell/Ink, on or selected Accent with white, values InkSoft. `DeckIconButtonStyle` gains a 0.45-opacity disabled look.
- AC-3 Each control changes the line live through T-014's mutators:
  - a button at its limit is disabled (size at 60%/200%, down at the default bottom, up at 18, left and right at ±8);
  - Reset is disabled while the style is the default;
  - playback is not paused.
- AC-4 VoiceOver hears a label and value on every control, for example:
  - "Larger text", "130 percent";
  - "Move subtitles up", "20 percent up";
  - "Bold", "On";
  - the selected font chip has the `.isSelected` trait.
- AC-5 Layout: the sheet uses `presentationBackground(Theme.panel)` and a fixed-height detent plus `.large`. At the default text size on iPhone 17 Pro, every control's minY is at or below `player.video`'s maxY. The content scrolls, so at an accessibility text size Reset can be reached.
- AC-6 `SubtitleStyleUITests` (portrait) checks:
  - opening the sheet; size up ×3 makes the `player.subtitle` frame taller and shows "130%";
  - up ×2 lowers its maxY; Serif and Bold off are selected or off;
  - relaunch with `-uiTestingKeepSubtitleStyle` keeps the style;
  - Reset brings back the default frame (±2 pt) and disables Reset;
  - size-up is disabled after reaching 200%;
  - a run with `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` scrolls to Reset;
  - attachments `style-01-sheet` and `style-02-large-text`.
- AC-7 DESIGN.md (player controls row and the new sheet: icons, colours, motion, accessibility) and PRODUCT_SPEC.md (core feature) are updated. Every existing test still passes.

### How to check
CI only:
1. `git push origin loop/subtitle-style`, then `gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=all`.
2. `gh run watch <id> --exit-status`. On failure, `gh run view <id> --log-failed`.
3. `./scripts/test-ios.sh` and `./scripts/build-ipa.sh` pass.
4. Download `simulator-results` and read the `style-01`/`style-02` screenshots: distinct icons, app colours, the video uncovered, the line changed.

Unverified for Brent: the feel on a real iPhone, and dark mode (unless a screenshot covers it).

### Agent notes
- Carried over from T-014's review (Could fix): C2: the subtitle line overlay is now drawn above RecordingBadge (PlayerView.swift:436), so a line moved up and left can cover the badge. Keep the badge on top, or keep the line clear of it. C3: SubtitleStyle step mutators (SubtitleStyle.swift:86-103) can overflow if a field is set to Int.max in code; clamp before adding.
- Depends on: T-014 (`SubtitleStyle`, its mutators, the seed and keep flags). Source: the spec's "Menu" section, and D-5, D-8.
- Learned: on iOS 26, a gesture on a `Menu` doesn't fire, so the opener is a Button with `@State` presentation.
- Call it "position", never "offset". `player.offset` is the timing offset.
- If `textformat.size.smaller`/`.larger` aren't available on iOS 17, draw a small and a large "A" instead.

### Out of scope
- "More fonts…" and the system font picker (T-017).
- The landscape card, landscape keep-up, and the 50% bar fit (T-016).
- Changes to the timing offset sheet.

## Implementation notes (round 1) · sonnet
_by loop-frontend · 
- Changed (nothing compiled here, CI only):
  - New `Features/Player/SubtitleStyleSheet.swift`: `SubtitleStyleSheet` (the portrait sheet) and a `nonisolated extension SubtitleStyle` with the menu texts (`sizeText` "130%", `positionText`, spoken values). The sheet owns its own `@AppStorage(SubtitleStyle.storageKey)`, so each tap writes the JSON the player already observes and the line changes live. The playback model is never touched, so it isn't paused.
  - `PlayerView`: `showStyleSheet` state, the sheet, and the `player.subtitleStyle` Button (`textformat`, label "Subtitle style", value Default/Changed, aqua when not default) placed after `player.subtitlesMenu` in `transportButtons`, so it is in portrait and in all three landscape rows. In landscape it opens the same sheet for now (T-016 replaces that with the card); rotating closes it, and it holds the landscape controls up (`keepsControlsUp`).
  - `DeckIconButtonStyle`: now a small View-backed style with the 0.45-opacity disabled look; the press-scale is skipped under Reduce Motion.
  - C2: the `RecordingBadge` moved from the ZStack into an `.overlay` after the line overlay, so it is drawn above the line.
  - C3: new `SubtitleStyle.clampedSum` (clamp, then `addingReportingOverflow`, then clamp) used by the three step mutators.
  - Docs: DESIGN.md (new "Subtitle style menu" section, components, motion, accessibility, player row), PRODUCT_SPEC.md.
- Sheet: header (title + Done pinned), then a ScrollView: Font rows (name + "Aa あア漢字" in that font, aqua+white when selected; stacked at accessibility sizes), Bold, Size ([smaller] value [larger]), Position (left, up, down, right + value line), full-width Reset. Detents `.height(520)` + `.large`, `presentationBackground(Theme.panel)`, background interaction on at the first detent so the video isn't dimmed. The "More fonts…" row goes where the comment says (under the presets, before Bold).
- Icons (all distinct): textformat, bold, textformat.size.smaller/larger, arrow.left/up/down/right, arrow.counterclockwise, checkmark. Colours only Theme tokens.
- Identifiers: `subtitleStyle.font.sans|rounded|serif`, `.bold`, `.sizeDown`, `.sizeUp`, `.left`, `.up`, `.down`, `.right`, `.reset`, `.done`, plus `.sizeValue`, `.positionValue`, `.title`.
- Tests: SubtitleStyleTests (+3: overflow, texts, limits); SubtitleStyleUITests (+5: sheet live + video uncovered + font/bold/size/position, keep flag relaunch, reset, 200% limit, XXXL scroll to Reset; attachments `style-01-sheet`, `style-02-large-text`).
- Gotchas: the sheet's frame checks use `player.video` read before opening; the line is measured after Done (an open sheet may hide the player from the accessibility tree). The tests use `reveal()` (swipe up until hittable) for controls under the first detent. Landscape bar fit at 50%: the third `ViewThatFits` row (icon Make a Card, no skips) gains one 44 pt button plus 8 pt, about 280 of about 320 pt; T-016 must prove it.
- Tester, look at: `style-01-sheet` screenshot (icons distinct, aqua only on selected/on, line changed, video uncovered); that background interaction doesn't let a tap on the video misbehave; the landscape bottom bar with the extra button at a 50% panel; the three Could-fix items above; XXXL (`style-02-large-text`).
