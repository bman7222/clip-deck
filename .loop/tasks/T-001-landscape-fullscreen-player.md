---
id: T-001
title: Watch in landscape full screen, with controls that appear on tap
lane: frontend
depends_on: []
status: todo
round: 0
base_sha:
issue: 1
spec:
model:
---

## Watch in landscape full screen, with controls that appear on tap

### What are we building?
Today, turning the phone sideways shows the video above a controls bar with the navigation bar still visible. After this task, landscape fills the whole screen with the video. Tapping the video brings up the controls on top of it, and they fade away again on their own while the video plays. Portrait stays exactly as it is.

### Why?
On a phone in landscape, every point of screen matters. Brent wants the episode to fill the screen like any video app, with controls only when he asks for them.

### Done when
- AC-1 In landscape the video fills the screen edge to edge (letterboxed only by its own aspect ratio). The navigation bar, status bar and controls are hidden until the user taps. The home indicator auto-hides (`persistentSystemOverlays(.hidden)`).
- AC-2 Tapping the video shows the overlay controls and tapping again hides them. While playing, they hide after 3 s without a touch. They stay visible while paused, while scrubbing, while a sheet or menu is open, and while VoiceOver is running.
- AC-3 The overlay has a top bar (back button `player.back` that returns to the episode list, episode title, and an empty trailing slot that T-002 fills) and a bottom bar with the same controls as portrait: scrubber, back 5 s, play/pause, forward 5 s, offset, subtitles menu, and Make a Card, all with their existing identifiers. Controls stay inside the safe area (clear of the notch / Dynamic Island).
- AC-4 The current subtitle line stays on the video. It moves up above the bottom bar while the controls are showing, and Look Up still works on it. Make a Card works from landscape (recording chip shows, the editor opens).
- AC-5 Until T-002 lands, the subtitles menu's "Show subtitle list" still opens the existing side list next to the video, so the list is reachable in landscape.
- AC-6 Portrait is unchanged: tapping the video still toggles play, and `MiningFlowUITests` passes without edits.
- AC-7 A new UI test file `ios/ClipDeckUITests/PlayerLandscapeUITests.swift` opens the seeded sample episode, sets `XCUIDevice.shared.orientation = .landscapeLeft`, attaches screenshots `landscape-01-fullscreen` (no controls) and `landscape-02-controls` (after a tap), asserts `player.back` and `player.makeCard` appear after the tap and disappear after tapping again, and resets the orientation to portrait in `tearDown`.

### How to check
CI only (Windows, no Mac):
1. `git push origin loop/mkv-landscape-sideload`
2. `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload`
3. `gh run list --branch loop/mkv-landscape-sideload --workflow ios-simulator.yml --limit 3`, then `gh run watch <id> --exit-status` (check `headSha` matches the pushed commit). On failure: `gh run view <id> --log-failed`.
4. The `simulator` job runs `./scripts/test-ios.sh` (all unit + UI tests) and `./scripts/run-ios.sh`; the `ipa` job runs `./scripts/build-ipa.sh`. Both must be green.
5. `gh run download <id> -n simulator-results -D <scratch>/ci` and read `screenshots/ui-tests/*landscape-01*`, `*landscape-02*` and the existing portrait `03-player` shot. Landscape: video fills the screen, controls only in the second shot. Portrait: same layout as before.
Unverified for Brent: real iPhone feel of the auto-hide timing.

### Agent notes
- Depends on: None
- Source: Brent's goal item 2; `docs/DESIGN.md` (Player, Interaction and motion).
- Code: `ios/ClipDeck/Features/Player/PlayerView.swift` (`landscape(_:)`, `videoScreen(_:)`, `controls(_:)`). Landscape is detected with `GeometryReader` width > height; keep that.
- Navigation: hide the bar with `.toolbar(.hidden, for: .navigationBar)` in landscape only; the swipe-back gesture may stop working, so `player.back` must call `dismiss()`.
- Tap behaviour differs by orientation on purpose: portrait = play/pause, landscape = show/hide controls.
- Use `accessibilityVoiceOverEnabled` from the environment to keep controls up for VoiceOver.
- Give the video surface `accessibilityIdentifier("player.video")` (T-002's test measures it).
- Use `.animation` that respects Reduce Motion (SwiftUI springs already do). Overlay bars use a dark translucent background so white text stays readable on any frame.
- Update `docs/DESIGN.md` Player section and the DEVELOPMENT.md identifier list (`player.back`, `player.video`).
- New test file is picked up by XcodeGen through the `ClipDeckUITests` source folder.

### Out of scope
- The top-right panel button and the 75/25 split (T-002).
- Changing portrait in any way.
- Double-tap-to-seek or gesture scrubbing.
