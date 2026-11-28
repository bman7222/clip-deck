---
id: T-035
title: Find and remove the invisible layer over the landscape player
lane: frontend
depends_on: []
status: todo
round: 0
base_sha:
issue: 40
spec: .loop/specs/player-lookup-timeline.md
model: opus
---

## Find and remove the invisible layer over the landscape player

### What are we building?
Sometimes, in landscape with the Move-Text card open, XCUITest reports a card button as not hittable. In CI 46118672166 (shard 3, MoveTextTesterUITests/testFirstDownFromAboveTheReachableTopMovesTheLineLandscape, "Done closes the card"), the failure-time hierarchy has two empty full-screen `Other` elements (874 x 402) above the whole player subtree, siblings at the presentation level. Earlier in the same test the card's Up and Down taps worked, so the layer appeared mid-test (between about 87 s and 89 s). The same symptom hit Reset in 46102226923 (testButtonFollowsAaInEveryLandscapeBarVariantAndTheCardFitsAtHalfWidth), on unchanged code.

### Why?
If the layer is real, it blocks Brent's taps on the player too. If it's a test artifact, it makes the Move-Text tests flaky and wastes CI runs.

### Done when
- AC-1 The cause is named with evidence (the view or presentation that owns the layer, and what makes it appear), from the xcresult of 46118672166 shard 3 (hierarchy, activities, the screen recording) and the code.
- AC-2 The layer no longer covers the controls: fixed in the product if it's real, or in the tests if it's an XCUITest artifact.
- AC-3 A test, or a check in the existing tests, fails if the layer comes back.

### Agent notes
- Brent (2026-11-28): land T-026 and T-033 first, then this task, before T-025 lands. Opus.
- Windows has no xcresulttool: see CONTEXT Learned for reading database.sqlite3 and the zstd Data blobs.
- Candidates to rule in or out: a sheet or fullScreenCover being presented or dismissed (the Aa font picker, the portrait Move-Text sheet), the playback overlay's container while hidden, a root overlay (toast, banner), the UITestAnimationWatch.

### Out of scope
- The idle stall (T-034).
