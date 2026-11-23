---
id: T-022
title: Subtitles avoid the overlay
lane: frontend
depends_on: [T-021]
status: todo
round: 0
base_sha:
issue: 24
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Keep the subtitle line clear of the centre play buttons

### What are we building?
With T-021's overlay, a line moved up to the middle of the video sits under the play buttons. After this task, while the overlay shows, a line that would touch it moves just above or just below it, and goes back when the overlay hides. The saved position never changes.

### Why?
The subtitle stays readable and the buttons stay tappable.

### Done when
- AC-1 `SubtitlePlacement.frame` gains an optional `avoid: CGRect?` band in video-local coordinates, with a default of nil. It stays a pure, `nonisolated` function, and nil gives exactly today's result.
- AC-2 The rule: if the placed frame meets the band, the line moves just above it (bottom = band.minY) or just below it (top = band.maxY). It takes whichever needs the smaller move and still fits inside the active region. If neither fits, it goes below, and the usual clamps keep it inside the region. If there's no overlap, nothing changes.
- AC-3 The band covers the three overlay buttons, from back5's minX to forward5's maxX and 52 pt tall, plus 8 pt of padding on every side. It's computed from T-021's layout rule (25/50/75 %, 52/44 pt), not from measured views. PlayerView passes it only while the overlay is visible, in both orientations. The move uses the existing 0.2 s ease; when the overlay hides, the line goes back. `player.subtitleStyle` is never written.
- AC-4 New unit tests: an overlap where moving above is smaller, an overlap where moving below is smaller, no overlap (unchanged), neither fits (below, clamped), and a nil band reproducing today's frames for a few existing cases. One case combines the band with the landscape top and bottom bar obstructions.
- AC-5 A UI test in portrait and landscape:
  - seed `-uiTestingSubtitleStyle '{"upSteps":9}'` (45 %, mid-video), tap cue row 2 while paused, and show the overlay;
  - `player.subtitle`'s frame doesn't meet any `player.overlay.*` button's frame grown by 8 pt;
  - after the overlay hides, the line is back at the place it had before the overlay showed (within 1 pt).
  Attach `app.debugDescription` as evidence. Every existing test passes, and DESIGN.md describes the rule.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`. Watch it (`gh run watch <id> -i 60 --exit-status`), then download `-p 'simulator-results*'`. Check the new unit tests, the new avoidance UI test and its frames, and the SubtitleStyle* suites, whose placement must be unchanged.

### Agent notes
- Depends on: T-021 (the overlay). Source: spec T-022.
- The spec's UI test seeds "upFraction 0.45", but fractions only arrive in T-023. T-023 keeps the old keys working, so seed `upSteps: 9`, which is the same place.
- Code: `SubtitlePlacement.frame` is at SubtitlePlacement.swift:35-64. `SubtitleLineLayout` (124-155) must pass the band through. `subtitleLine` is at PlayerView.swift:540-562.
- The menu helpers (`canStepUpWithCardOpen`, `highestReachableUpStep`, `upStepAfterDownWithCardOpen`) don't take the band, because menus judge steps without the overlay.
- Learned: in landscape, use element screenshots and `app.debugDescription`. Don't put a mutating call inside `#expect`.
- From T-021/T-034 (orchestrator, 2026-11-23):
  - The overlay hides while the Aa style card is open (T-021 AC-7), and PlayerView.swift:258 is `showsOverlay: shown && !styleMenuOpen`. Avoid the overlay only while it's actually shown.
  - Build new UI tests on `ios/ClipDeckUITests/UITestSupport.swift`: `launchAndOpenSampleEpisode(sampleSeconds:)`, `rotateToLandscape` (the idle-stall guard), `readTogether`, `tapStep` and so on. For anything checked while playing, use `-uiTestingSampleSeconds 30`. Put a new UI class in `SHARD1_UI`, since shard 2 is the tightest at about 28 min.
  - Optional Could fix carried over from T-034's tester:
    - C1: `UITestAnimationWatch` (ios/ClipDeck/App/UITestAnimationWatch.swift:65-80) logs iOS 26 Liquid Glass animations with infinite duration and no delegate, which is noise. Skip those, and reword docs/DEVELOPMENT.md:167-170 to say "no `delegate UIViewAnimationState` line".
    - C2: the 6 mid-test landscape rotations aren't guarded. A stall there costs time, not a red run.

### Out of scope
- Hiding the overlay while the Move-Text menu is open (T-024a; Q3, decided by Brent on 2026-11-22).
- Step sizes and limits.
