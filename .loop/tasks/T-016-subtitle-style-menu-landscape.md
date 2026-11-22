---
id: T-016
title: Adjust the subtitle style in landscape from a card in the bottom bar
lane: frontend
depends_on: [T-015, T-017]
status: todo
round: 0
base_sha:
issue: 17
spec: .loop/specs/subtitle-style.md
model:
---

## Adjust the subtitle style in landscape from a card in the bottom bar

### What are we building?
In landscape, the new "Aa" button in the bottom bar opens a style card. The card pops up from the bottom of the video, in place of the bottom bar, and holds the same controls as the portrait sheet. The line stays visible just above the card, so every tap shows its effect. The controls don't fade while the card is open. Done, a tap on the video, or a rotation closes it.

### Why?
Most watching happens in landscape full screen, where a sheet would cover the whole video. Brent needs to adjust the line there and see the result.

### Done when
- AC-1 `player.subtitleStyle` fits next to `player.subtitlesMenu` in all three `bottomRow` variants. With the panel dragged to 50% on iPhone 17 Pro, it is hittable, and its frame lies inside the video column (maxX ≤ `player.sidePanel` minX).
- AC-2 The card `subtitleStyle.card`:
  - replaces the bottom bar while open, and the top bar stays;
  - reuses the controls and identifiers from T-015 and T-017, icon only, with the bars' look (`Color.black.opacity(0.55)`, `.dark` colour scheme, Theme tokens only). The three preset chips each show "Aあ" in their font, and `subtitleStyle.font.more` (`ellipsis.circle`) opens T-017's font picker. VoiceOver reads its value as the picked font's name;
  - lays out the 13 controls with `ViewThatFits` as one row, otherwise rows of 7 and 6, otherwise rows of 5, 4 and 4;
  - always stays inside the video column and the safe area.
- AC-3 The card appears with move-from-bottom + opacity, or opacity only when `accessibilityReduceMotion` is on, and leaves the same way.
- AC-4 `styleMenuOpen` and the font picker's presented state are both part of `keepsControlsUp`. The card stays open when the picker closes. The card closes:
  - on Done;
  - on a tap on the video (that tap only closes the card; it doesn't also hide the controls);
  - on a rotation (cleared with `subtitleDialogOpen`).
  Closing restarts the 3 s hide timer.
- AC-5 While the card shows, the line is pushed above it, through T-014's placement with the card's height as the bottom obstruction: `player.subtitle` maxY ≤ `subtitleStyle.card` minY. After closing, with the controls hidden, the line rests at its styled place.
- AC-6 `SubtitleStyleUITests` (landscape) checks:
  - (a) Keep-up, following the "stays visible" rule: play from the first cue, open the card, and check `player.back` and the card repeatedly for 3.5 s. The window ends before the 6 s sample ends, so the end of playback can't bring the controls back. Copy the timing notes in `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying`.
  - (b) Up ×3 and size up ×2 change the line's frame live, and the line stays above the card.
  - (c) The panel at 50% (drag the handle far left): the card's frame is inside the video column, and all 13 controls are hittable.
  - (d) Done, a video tap and a rotation each close the card.
  - (e) More fonts opens the picker. Cancelling it returns to the open card, with the controls still up.
  - Evidence per state: `app.debugDescription` text, plus `XCUIElement.screenshot()` of the window or `player.video` (`landscape-style-01-card`, `landscape-style-02-panel-50`). Not `app.screenshot()` (see Learned).
- AC-7 DESIGN.md's landscape paragraph and "Interaction and motion" cover the card. The existing landscape tests still pass, including the panel-width and keep-up ones.

### How to check
CI only:
1. `git push origin loop/subtitle-style`, then `gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=all`.
2. `gh run watch <id> --exit-status`. On failure, `gh run view <id> --log-failed`. Check Learned for the known flakes before counting a failure.
3. `./scripts/test-ios.sh` and `./scripts/build-ipa.sh` pass.
4. From `simulator-results`, read the landscape-style element screenshots and the frames text: the card sits in the column, the line sits above it, and the fonts and arrows look distinct.

Unverified for Brent: how it feels on his iPhone, and the iPhone SE / mini widths.

### Agent notes
- Carried over from T-017 (31bc513): SystemFontPicker is private in SubtitleStyleSheet.swift, so make it internal to reuse it. Could fix C1: a family whose only face is bold (e.g. ArialRoundedMTBold) draws bold even with Bold off, with no note (SubtitleStyle.swift:245/255); show the no-bold note there too, or say 'This font is always bold'. Re-check ExpiryBannerUITests/testOpenSideStoreWithoutSideStoreKeepsBannerAndExplains (failed in 44960788495 on the sample-episode timing flake) in this task's CI run.
- Depends on: T-015 (button, controls view, identifiers) and T-017 (the picker wrapper, `pickedFontName`, the More fonts control). Source: the spec's "Menu" and "Picked font" sections, and D-1 and D-6 (accepted 2026-11-20).
- `PlayerView.landscape` overlay (:184-199), `bottomBar`/`bottomRow` (:369-398), `keepsControlsUp` (:437), the rotation reset (:70-78), `toggleControls` (`onTap`).
- The tightest row today is about 245 of about 320 pt at 50%, and the new button adds about 52 pt. Measure it, don't assume.
- iOS 26: Menu gestures don't fire. The card's state is plain `@State`.

### Out of scope
- Portrait changes. New style options.
