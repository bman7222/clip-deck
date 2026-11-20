---
id: T-011
title: Drag the divider to resize the landscape subtitle panel
lane: frontend
depends_on: [T-002]
status: todo
round: 0
base_sha:
issue: 11
spec:
model:
---

## Drag the divider to resize the landscape subtitle panel

### What are we building?
T-002 opens the subtitle panel at a fixed quarter of the screen. After this task, a handle on the divider between the video and the panel can be dragged to make the panel wider or narrower, within sensible limits. Clip Deck remembers the chosen width across launches, and a double-tap on the handle puts it back to the default (video 3/4, panel 1/4).

### Why?
Brent wants to choose the split himself: a wider panel for long lines, a narrower one to see more video.

### Done when
- AC-1 With the panel open, the divider shows a grip (a small rounded bar on the panel's leading edge) with at least a 44 pt wide touch area (`player.panelHandle`).
- AC-2 Dragging it left or right resizes the panel and the video live; the panel stays between 180 pt and 50 % of the screen width. The video keeps its aspect ratio and stays to the left of the panel.
- AC-3 The width is saved as a fraction of the screen width with `@AppStorage` (default 0.25), so it survives relaunch and fits other screen sizes; on each screen it is clamped to the limits.
- AC-4 Double-tapping the handle animates back to 0.25.
- AC-5 VoiceOver: the handle is an adjustable element "Subtitle panel width", value as a percentage; swipe up/down changes it by 5 %; a custom action resets it.
- AC-6 `PlayerLandscapeUITests` gains a test: double-tap the handle to start from the default; drag it 120 pt left and assert `player.sidePanel` got wider; terminate and relaunch (`-uiTesting`), open the panel and assert the width is kept (±4 pt); drag it far right and assert it stops at 180 pt or wider; double-tap and assert 25 % ± 2 % again (leaves the default for other tests). Attaches `landscape-05-panel-resized`. Orientation is reset in `tearDown`.

### How to check
CI only:
1. `git push origin loop/mkv-landscape-sideload`, then `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload`.
2. `gh run list --branch loop/mkv-landscape-sideload --workflow ios-simulator.yml --limit 3`; `gh run watch <id> --exit-status`; on failure `gh run view <id> --log-failed`.
3. `./scripts/test-ios.sh` (simulator job; T-002's landscape tests still pass) and `./scripts/build-ipa.sh` (ipa job) pass.
4. `gh run download <id> -n simulator-results -D <scratch>/ci`; read `screenshots/ui-tests/*landscape-05*`: wider panel, video still fully visible.
Unverified for Brent: how the drag feels on his iPhone.

### Agent notes
- From T-002 round 2 (Brent's decision): panel widths count only the usable content area (full width minus both landscape safe-area insets); the trailing inset is added on top as padding. The drag limits (180 pt minimum, 50% maximum) and the stored fraction use that same usable width. Panel rows are compact (timestamp above the text).
- Depends on: T-002 (panel, `player.sidePanel`, `player.video`, the ratio constant).
- Source: Brent's decision 2026-11-19: default 3/4 + 1/4 (panel at least 180 pt), customizable by dragging, remembered across launches, double-tap to reset.
- Replace T-002's fixed constant with the stored fraction; keep 0.25 as the default constant.
- Use `DragGesture` on the handle only, so it doesn't fight the video's tap-to-show-controls or the cue list's scrolling. While dragging, keep the overlay controls from auto-hiding.
- Save once when the drag ends, not on every change.
- `UserDefaults` survive between UI-test launches (only SwiftData is in-memory), so the test must leave the default behind.
- Update `docs/DESIGN.md` (landscape panel is resizable) and the DEVELOPMENT.md identifier list (`player.panelHandle`).

### Out of scope
- Resizing in portrait.
- Collapsing the panel by dragging it closed (the toggle button does that).
