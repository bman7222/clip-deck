---
id: T-021
title: Centred playback overlay, plain bottom pause button, new bar layout
lane: frontend
depends_on: []
status: todo
round: 0
base_sha:
issue: 23
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Control playback from big buttons in the middle of the video, like a normal video player

### What are we building?
Today a tap on the portrait video plays or pauses, and ±5 s are small buttons in the bar. After this task both orientations show a centred ⟲5 ⏯ 5⟳ overlay that appears on a tap and fades like the landscape controls. The ±5 s buttons leave the bar, and the bar's play/pause button is plain while playing and aqua only while paused.

### Why?
It works like every other video app, and it frees room in the bar for the Move-Text and Lookup buttons that come next.

### Done when
- AC-1 Overlay: three white glyphs (`gobackward.5`, play/pause, `goforward.5`), each on a translucent black circle: 52 pt for the centre one, 44 pt for the skips. Their centres sit at 25 %, 50 % and 75 % of the video container's width, vertically centred. The container is the 16:9 video in portrait and the video column in landscape, so the overlay re-centres when the panel opens or is resized. Ids `player.overlay.back5`, `player.overlay.playPause` and `player.overlay.forward5`. Labels "Back 5 seconds", "Play"/"Pause" and "Forward 5 seconds". The play/pause value is "Playing"/"Paused".
- AC-2 Timing. In landscape the overlay shows and hides with the existing controls (`controlsShown`). In portrait it follows the same rules with its own state: it starts hidden, a tap on the video shows or hides it (and no longer toggles play), and a real pause (playing → paused) shows it. In both: a 0.2 s fade, auto-hide after 3 s while playing, it stays while paused, opacity only under Reduce Motion, always shown under VoiceOver, and hidden after a rotation. A skip tap restarts the countdown.
- AC-3 ±5 s is gone from the portrait row and from every landscape bar variant, and the `skips:` parameter is removed.
- AC-4 The bar's `player.playPause` (both orientations) uses `DeckIconButtonStyle(isActive: !model.isPlaying)`: Shell/Ink while playing, aqua while paused. Its accessibility value is "Playing"/"Paused"; its id and labels don't change.
- AC-5 Bar order for the later buttons. Portrait: the row `⏯ ±0.0s Subs Aa`, then Make a Card on its own row. Landscape: `⏯ ±0.0s Subs Aa … Make a Card`, with these ViewThatFits variants: (1) one row with the full Make a Card label; (2) one row with an icon-only Make a Card; (3) two rows, `⏯ ±0.0s Subs Aa` above Make a Card (icon) on the trailing side. In each variant a comment marks where ✥A (after Aa, T-024a), ↺📄 (after ✥A, T-029b) and 📄🔍 (just left of each Make a Card, T-030a) will go.
- AC-6 `testPortraitTapStillTogglesPlay` becomes a test that a portrait tap shows the overlay and leaves the play state alone. New UI tests in both orientations:
  - the overlay centres are within 2 pt of 25/50/75 % of `player.video`'s width and of its vertical centre;
  - while paused mid-video, back5 and forward5 move the time by about 5 s, and the overlay play/pause toggles playback;
  - the overlay is gone 3 s after playing starts and stays while paused;
  - `player.bottomBar` and the portrait controls hold no 5-second skip button;
  - `player.playPause` reads "Paused", then "Playing".
  Every existing test passes, and DESIGN.md documents the overlay and the play-button colour rule.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`. Watch it with `gh run watch <id> -i 60 --exit-status`, and on failure read `gh run view <id> --log-failed`. Then `gh run download <id> -p 'simulator-results*' -D <scratch>`. Check the new overlay tests, all of PlayerLandscapeBehaviourUITests, SubtitleStyleCardTesterUITests, and the frames in the `app.debugDescription` attachments.
- Unverified for Brent: how the overlay and its fades feel, and how readable it is on bright scenes.

### Agent notes
- Depends on: none. Order it after T-020 so the extra UI tests have CI room. Source: spec T-021, section G defaults 5 (white glyphs on dark circles).
- Code in PlayerView.swift: the portrait tap `videoScreen(model, onTap: { model.togglePlay() })` is at line 181. The landscape overlay stack and `controlsShown` are at 219-295, `keepsControlsUp` at 569, and `restartHideTimer` at 597; it returns early unless `isLandscape`, so portrait needs its own path. `transportButtons(_:landscape:skips:)` is at 626-682 and the bottom-bar ViewThatFits at 471-475. `DeckIconButtonStyle` is in Components.swift:69-98.
- Z-order: line, then overlay, then bars. The recording badge stays visible. A tap on an overlay button must not also toggle the overlay.
- Tests use `app.buttons["player.playPause"]` with the labels "Play"/"Pause" (PlayerLandscapeBehaviourUITests.swift:42-55, 227-228), so keep the bar button's id and labels. The overlay button has its own id.
- The sample video is 6 s long, with cues at 0.5–2.0, 2.0–4.0 and 4.0–5.5 s. Test the skips from about 3 s while paused.
- Learned: landscape `app.screenshot()` comes out rotated, so use `XCUIElement.screenshot()` and attach `app.debugDescription`. A `.contain` container's frame is the union of its children. Known flakes are in PlayerLandscapeBehaviourUITests.

### Out of scope
- The subtitle line avoiding the overlay (T-022).
- The ✥A, ↺📄 and 📄🔍 buttons themselves.
- Double-tap-to-skip gestures, scrubber changes.
