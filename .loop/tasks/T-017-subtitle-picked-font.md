---
id: T-017
title: Pick any installed font for subtitles, with Japanese that always renders cleanly
lane: frontend
depends_on: [T-015]
status: todo
round: 0
base_sha:
issue: 18
spec: .loop/specs/subtitle-style.md
model:
---

## Pick any installed font for subtitles, with Japanese that always renders cleanly

### What are we building?
The portrait style sheet gets a "More fonts…" row below the three presets. It opens the iPhone's own font picker, so any installed font can be used for the subtitle line. Most fonts have no Japanese letters, so Japanese text always falls back to the matching Hiragino face (Sans, Rounded or Mincho) instead of boxes or a random font. The row shows the picked font's name and a mixed sample "Aa あア漢字", so both scripts can be judged. A picked font that later disappears quietly becomes Sans.

### Why?
Clip Deck is a Japanese and English app. Brent wants more font choice without ever breaking how Japanese lines look.

### Done when
- AC-1 `SubtitleStyle` gains `pickedFontName: String?` (a PostScript name), as the spec's "Picked font" section describes:
  - it takes the place of the preset, and picking a preset clears it;
  - `isDefault` needs it to be nil;
  - old JSON without the field still decodes;
  - `-uiTestingSubtitleStyle` accepts it.
- AC-2 Missing font: if `UIFont(name:size:)` returns nil for the stored name, the read drops it and the style uses Sans. Everything else is kept, and nothing crashes.
- AC-3 Closest preset and cascade, per the spec:
  - the closest preset is a pure function: names first ("Mincho"/"Serif" → Serif, "Rounded"/"Maru" → Rounded), then the serif family classes, otherwise Sans;
  - the cascade goes to that preset's Hiragino face (W3, or W6 with Bold; Maru W4);
  - Bold uses the family's bold face if it has one, otherwise the regular face unchanged.
- AC-4 Sheet: `subtitleStyle.font.more` ("More fonts…", `ellipsis.circle`) opens `UIFontPickerViewController`, wrapped for SwiftUI, with `includeFaces = false`, as a sheet from the style sheet.
  - Choosing a family saves it and updates the line live. Cancel changes nothing.
  - The row shows the picked font's name and "Aa あア漢字" drawn exactly as the line draws it (the cascade included). It is aqua while selected.
  - "This font has no bold weight." shows under it when that is true.
  - VoiceOver hears "More fonts", with the value set to the picked name or "None".
- AC-5 Unit tests (`SubtitleStyleTests` or a new `SubtitleFontTests`):
  - the closest-preset function, with synthetic names and traits;
  - real fonts: Georgia → Serif, `ArialRoundedMTBold` → Rounded, Helvetica → Sans;
  - CoreText runs of "Aa あア漢字" with Georgia: the Latin run uses Georgia, and the Japanese runs use `HiraMinProN-W3`, or `-W6` with Bold. No run uses `.LastResort`;
  - Georgia with Bold → `Georgia-Bold`;
  - a family without bold (for example Zapfino) keeps its face;
  - a missing name decodes to Sans;
  - JSON without the field decodes.
- AC-6 UI tests (portrait):
  - a seeded `{"pickedFontName":"Georgia"}` launch shows "Georgia" in the More fonts row, the opener is aqua, and the line shows;
  - a seeded `"NoSuchFont-Regular"` launch opens the player without a crash, with Sans selected and the opener not aqua;
  - More fonts opens the picker (wait for its search field or list), and cancelling returns to the sheet;
  - attach `style-03-picked-font`.
  - Don't drive a selection inside the system picker; it's flaky.
- AC-7 DESIGN.md and PRODUCT_SPEC.md describe More fonts and the Japanese fallback. Every existing test still passes.

### How to check
CI only:
1. `git push origin loop/subtitle-style`, then `gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=all`.
2. `gh run watch <id> --exit-status`. On failure, `gh run view <id> --log-failed`.
3. `./scripts/test-ios.sh` and `./scripts/build-ipa.sh` pass.
4. Read `style-03-picked-font`: Georgia for the Latin text, Mincho for the Japanese, no boxes.

Unverified for Brent: picking a font by hand on his iPhone, and a user-installed font that is later removed.

### Agent notes
- Depends on: T-015 (the sheet, the controls view, the presets with samples). T-016 reuses this wrapper and control in the landscape card. Source: the spec's "Picked font" section, D-1 (Brent: "both").
- The cascade uses `UIFontDescriptor.AttributeName.cascadeList`. Build the picked font through the same single font builder as the presets, so the line, the sample and the tests agree.
- Store the descriptor's PostScript name. `UIFont(name:)` with it must work at the next launch.
- Presenting a sheet from the style sheet is fine in portrait. Landscape is T-016.

### Out of scope
- The landscape card (T-016). Faces and italics. Bundled or downloaded fonts.
