---
id: T-014
title: Draw the on-video subtitle line in a saved style that always stays inside the video
lane: frontend
depends_on: []
status: todo
round: 0
base_sha:
issue: 15
spec: .loop/specs/subtitle-style.md
model:
---

## Draw the on-video subtitle line in a saved style that always stays inside the video

### What are we building?
Today the line on the video has one fixed look and one fixed place. After this task the player draws it from a saved style: font (Sans, Rounded or Serif), bold on or off, a size from 60% to 200%, and a position moved up or sideways. The line stays inside the video and the safe area in both orientations, also while the landscape bars show. There is no menu yet: a style can be set only through a Debug test flag. The default style looks exactly like today.

### Why?
This is the base the style menu (T-015, T-016) builds on. With the "always on screen" rule settled and tested here first, the menu tasks only have to change the style.

### Done when
- AC-1 `SubtitleStyle` and `SubtitleFont` exist as the contract in the spec ("Style value"): Int steps, ranges, `default`, `isDefault`, clamping mutators that report whether another step is possible, and JSON under `player.subtitleStyle` that is decoded per field and clamped on read.
- AC-2 The line uses the style's font, with Japanese cascades. Weight is bold or regular. The size is Dynamic Type `.title3` × scale, capped at a quarter of the region height. The white fill and black outline are unchanged. Only `player.subtitle` changes; the cue list and side panel don't.
- AC-3 The line is placed by a pure placement function that follows the spec's "Placement" section. The text view's frame hugs the text, which today it doesn't (`sizeThatFits` returns the full width). With the default style, the frame is bottom-centre, where it is today, with the landscape controls hidden and shown.
- AC-4 Unit tests (`ios/ClipDeckTests/SubtitleStyleTests.swift`) cover:
  - clamping and steps at both ends;
  - garbage, partial and out-of-range JSON;
  - a JSON round trip;
  - the fonts' weight and cascade;
  - placement: default; moved up and left; a bar that pushes the line; a line already clear of the bar that doesn't move; extreme steps clamped inside; a line taller than the region pinned to the bottom; landscape insets and the open panel's handle clearance.
- AC-5 `-uiTesting` launches clear the key unless `-uiTestingKeepSubtitleStyle` is passed, and `-uiTestingSubtitleStyle <json>` seeds a style. Both are documented in CLAUDE.md.
- AC-6 A new `SubtitleStyleUITests` seeks via a cue row while paused and compares the `player.subtitle` frame with the `player.video` frame:
  - portrait: default vs seeded {size +5, up 4, right −4, serif, bold off}. The seeded line is taller, higher and further left, and stays inside the video;
  - landscape (`-uiTesting`): the same, with the controls hidden and shown. While shown, the line is below the top bar's maxY and above the bottom bar's minY. Add `player.topBar` and `player.bottomBar` identifiers (`.accessibilityElement(children: .contain)`);
  - an extreme style {size +10, up 18, right 8} stays inside the video and the window's safe frame in both orientations;
  - evidence: `app.debugDescription` attached as text, and in landscape `XCUIElement.screenshot()` of `player.video` (see Learned).
- AC-7 ARCHITECTURE.md (key and placement rule) and PRODUCT_SPEC.md (global style assumption) are updated. Every existing test still passes.

### How to check
CI only (`ci_only: true`):
1. `git push origin loop/subtitle-style`, then `gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=all`.
2. `gh run list --branch loop/subtitle-style --workflow ios-simulator.yml --limit 3`, then `gh run watch <id> --exit-status`. On failure, `gh run view <id> --log-failed`.
3. `./scripts/test-ios.sh` (simulator job) and `./scripts/build-ipa.sh` (ipa job) pass.
4. `gh run download <id> -n simulator-results -D <scratch>`, then read the SubtitleStyleUITests attachments: the frames text and the landscape element screenshots (serif, regular weight, larger, moved).

Unverified for Brent: how the fonts look on his iPhone.

### Agent notes
- Depends on: none. Source: `.loop/specs/subtitle-style.md` ("Style value", "Placement", "Launch flags", "ASS files").
- Brent accepted D-1..D-8 on 2026-11-20. D-1 also adds "More fonts…", but that is T-017's job: keep the JSON decoding tolerant of unknown fields, so T-017's additive `pickedFontName` field fits in. Keep the font builder a single function (style → `UIFont`), so T-017 can extend it with the cascade.
- Code: `PlayerView.videoScreen` (subtitle at :413, the `subtitleBottomPadding` and `edgeInsets` callers at :173-178), `SelectableText` in `DesignSystem/Components.swift`, `ClipDeckApp.init` (the panelFraction reset is the pattern for the key reset).
- Don't make the style both `RawRepresentable` and `Codable` (infinite recursion).
- ASS needs nothing: the parser already drops every style and tag.
- The new files sit under `ios/ClipDeck` and `ios/ClipDeckTests`, which XcodeGen picks up. Regenerate the project.
- The sample cues are short (0.5–2 s, 2–4 s, 4–5.5 s). Tap a cue row while paused so the line stays put.

### Out of scope
- The style button and menu (T-015, T-016). Picked fonts (T-017).
- Colours, outline, background box. ASS file styles.
