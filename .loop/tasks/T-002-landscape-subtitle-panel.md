---
id: T-002
title: Pop the subtitle list out on the right in landscape
lane: frontend
depends_on: [T-001]
status: todo
round: 0
base_sha:
issue: 2
spec:
model:
---

## Pop the subtitle list out on the right in landscape

### What are we building?
In full-screen landscape (T-001), a button in the top-right corner of the tap-up controls opens the subtitle section. The video shrinks slightly and slides to the left, taking three quarters of the screen, and the subtitle list slides in to fill the right quarter. Pressing the button again closes it and the video goes back to full width.

### Why?
Brent wants to see and tap subtitle lines while watching sideways, without losing the video. Today the list only opens from a menu item and is a fixed 320 pt panel.

### Done when
- AC-1 When the landscape controls are showing, the top-right corner has a button (`player.panelToggle`, SF Symbol `sidebar.right`, spoken "Show subtitle list" / "Hide subtitle list").
- AC-2 Tapping it animates the video area to 75 % of the screen width on the left (the picture keeps its aspect ratio and shrinks a little) and slides in the panel (`player.sidePanel`) on the right with the remaining 25 %, never narrower than 180 pt. The panel holds, top to bottom: the subtitle-problem banner when there is one, a compact Make a Card button (`player.panel.makeCard`), and the cue list (current line highlighted, auto-scrolls, tap to seek).
- AC-3 The panel stays open when the overlay controls auto-hide. The overlay bars and the on-video subtitle line stay inside the video area while the panel is open.
- AC-4 Tapping the button again closes the panel and the video returns to full width. Rotating to portrait shows the normal portrait screen; rotating back restores the panel's open/closed state for that visit.
- AC-5 The "Show subtitle list" item is removed from the subtitles menu (and the old 320 pt panel code goes away); "Load different subtitles" stays.
- AC-6 `PlayerLandscapeUITests` gains a test that opens the panel and asserts `player.sidePanel` width is 25 % ± 2 % of the window width (or 180 pt if larger) and `player.video` width about 75 %; taps `cue.row.1` and sees `player.subtitle`; taps `player.panel.makeCard` and the card editor's `card.save` appears; attaches `landscape-03-panel` and `landscape-04-panel-card`. Orientation is reset in `tearDown`.

### How to check
CI only:
1. `git push origin loop/mkv-landscape-sideload`
2. `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload`
3. `gh run list --branch loop/mkv-landscape-sideload --workflow ios-simulator.yml --limit 3`, then `gh run watch <id> --exit-status`; on failure `gh run view <id> --log-failed`.
4. `./scripts/test-ios.sh` (simulator job) and `./scripts/build-ipa.sh` (ipa job) must be green; `MiningFlowUITests` still passes unchanged.
5. `gh run download <id> -n simulator-results -D <scratch>/ci`; read `screenshots/ui-tests/*landscape-03*` and `*landscape-04*`: video on the left ~3/4, list on the right ~1/4, current line highlighted.
Unverified for Brent: how the split feels on his iPhone; readability of long lines at 25 %.

### Agent notes
- Depends on: T-001 (full-screen landscape, overlay controls, `player.video`).
- Source: Brent's goal item 2 ("3/4 or 7/8 of video, last vertical slice for subtitles"). Brent confirmed 2026-11-19: default video 3/4, panel 1/4, panel at least 180 pt. Keep the ratio as one constant; T-011 makes it draggable and remembered.
- Code: `ios/ClipDeck/Features/Player/PlayerView.swift`; reuse `CuePanel` as is. `showSidePanel` already exists.
- Use `GeometryReader` widths, not hard-coded points. Respect the trailing safe area inside the panel; its background may run to the edge.
- Slide in from the trailing edge with the existing `.spring(duration: 0.3)`.
- Two Make a Card buttons can be on screen together (overlay + panel), so the panel one needs its own identifier.
- Update `docs/DESIGN.md` (landscape side panel: 25 %, button top-right) and the DEVELOPMENT.md identifier list.

### Out of scope
- Portrait layout.
- Dragging to resize the panel and remembering its width (T-011); remembering whether the panel was open between app launches.
- iPad layouts.
