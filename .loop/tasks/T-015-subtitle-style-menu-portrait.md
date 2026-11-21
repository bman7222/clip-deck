---
id: T-015
title: Adjust the subtitle style from a menu in the portrait player
lane: frontend
depends_on: [T-014]
status: todo
round: 0
base_sha:
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
- Depends on: T-014 (`SubtitleStyle`, its mutators, the seed and keep flags). Source: the spec's "Menu" section, and D-5, D-8.
- Learned: on iOS 26, a gesture on a `Menu` doesn't fire, so the opener is a Button with `@State` presentation.
- Call it "position", never "offset". `player.offset` is the timing offset.
- If `textformat.size.smaller`/`.larger` aren't available on iOS 17, draw a small and a large "A" instead.

### Out of scope
- "More fonts…" and the system font picker (T-017).
- The landscape card, landscape keep-up, and the 50% bar fit (T-016).
- Changes to the timing offset sheet.
