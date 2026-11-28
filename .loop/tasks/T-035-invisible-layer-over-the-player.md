---
id: T-035
title: Find and remove the invisible layer over the landscape player
lane: frontend
depends_on: []
status: testing
round: 2
base_sha: 91dc5448c2d5e93823d98327946f04aa557ae3b2
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

## Diagnosis (round 1)
_by loop-frontend · 2026-11-28 · diagnosis only, no product or test code changed_

**Cause: an iOS system notification banner, not app UI.** About 88.5 s into the test, SpringBoard showed "Ready for Apple Intelligence / Time to experience the new personal intelligence system" (Settings app, "now") across the top of the landscape screen, right over the Move-Text card. It lives in SpringBoard's window, so it never appears in the app's hierarchy. The app can only report that its own button is covered.

Evidence (46118672166 shard 3, TestCaseRuns rowid 3, the app process is pid 11974):
- Recording frames: 84–88 s show the card clear; 89, 92, 96, 100, 104 and 110 s show the banner over the whole card; by 120 s it has gone by itself (about 25–30 s on screen). The element screenshots `tester-move-card` (89.6 s) and `tester-move-card-video` (89.9 s) also show the banner over the card.
- App stdout at 07:01:58.617 (test time 89.96 s, activity 452 "Find the moveText.done Button"): `XC_kAXXCAttributeVisiblePoint` for Done (elementID 4484932800.179) returns X = -1, Y = -1, which means not hittable. Its frame is still (590.7, 8, 44, 44). That is the only -1 reply out of 221 VisiblePoint replies in the shard. Up and Down got real points (318/373, 30) at 07:01:46–54, before the banner.
- So `UITestSupport.tap` (UITestSupport.swift:152, `guard element.exists, element.isHittable`) never tapped Done. It waited 5 s (activities 453–473, existence checks only, no Tap), and line 82 "Done closes the card" failed.
- The same banner caused the 46102226923 failure (rowid 2, "reset can be tapped at half width"): Reset's VisiblePoint is -1 at 03:28:01.59, and the recording shows the same banner arriving between 69 and 70 s. In both runs it arrived about 7 minutes after the shard's simulator started (xcresult 06:54:07 → 07:01:57; 03:21:18 → 03:28:01). This suggests a one-off "Apple Intelligence ready" notification that a freshly booted iOS 26 simulator posts once. That is inferred, not proven.

**The two empty full-screen `Other`s are not the layer.** They appear as the last siblings in all 8 landscape hierarchies extracted from both runs. That includes passing tests where every card control was asserted hittable (`tester-move-card-half-width-frames` in 46118672166, `landscape-style-02-panel-50-frames` in both runs), and the same test passing in 46102226923 (`tester-move-first-down-frames`). They are a normal part of the player's SwiftUI container tree, probably the NavigationStack or presentation hosts. I didn't trace them to a line, because they block nothing.

**Users are not affected.** Nothing in the app covers the controls. On a real phone a system banner sits over any app the same way and can be swiped away.

**Smallest fix (test side, UITestSupport.swift):** add one helper, e.g. `dismissSystemBanner()`. It queries `XCUIApplication(bundleIdentifier: "com.apple.springboard")` for a banner (try identifier `NotificationShortLookView`, else any element whose label contains "Apple Intelligence"). If it finds one, it swipes it up, then logs a GitHub `::warning` "System banner over the app" plus an attachment `system-banner-guard`, the same pattern as `idle-stall-guard`. Call it in `tap` (line 152) and `tapStep` (line 169) when the element exists but `!isHittable`, then check once more. Also call it before the direct `isHittable` asserts (MoveTextTesterUITests.swift:72, :293). Unverified: the banner's identifier on iOS 26 SpringBoard. If the first run's guard doesn't find it, attach `springboard.debugDescription`. Alternative on the CI side (less certain): boot the simulator and let it settle before xcodebuild, so the notification fires before the tests.

**Check that fails if it comes back:** the existing `isHittable` asserts already go red. To tell a real app overlay apart from a system banner, the tester scans the app stdout for `XC_kAXXCAttributeVisiblePoint` replies of -1. The script is `t035vp.py` in the scratchpad: any -1 means a covered element. Each one should line up with a `system-banner-guard` attachment. A -1 without one means a real in-app layer.

## Implementation notes (round 1)
_by loop-frontend · 2026-11-28 · UI-test code and the test script only, no product code_

- `UITestSupport.dismissSystemBanner()`: queries `XCUIApplication(bundleIdentifier: "com.apple.springboard")` for `NotificationShortLookView`, else any element whose label contains "Apple Intelligence"; swipes it up and waits up to 3 s for it to go. It always logs a `system-banner-guard` activity plus attachment (summary line, then `springboard.debugDescription`), so a miss shows SpringBoard's tree. `logStall` became `logGuard(_:name:tree:)`, shared with the idle-stall guard.
- Called in `tap` and `tapStep` when the element exists but isn't hittable (then the existing hittable guard checks once more), and before the `isHittable` asserts at MoveTextTesterUITests.swift:72 (card controls at half width) and :294 (`checkOrder`).
- scripts/test-ios.sh: `system-banner-guard` attachments now become `::warning title=System banner over the app::` lines, next to the idle-stall ones. Checked locally: `bash -n`, and the embedded Python run against a fake manifest printed both warning kinds and skipped other attachments.
- AC-2: the banner is swiped away before the tap or assert. AC-3: the `isHittable` asserts and `tap` conditions still go red when anything else covers a control; a banner guard warning with no app failure tells a system banner apart from an in-app layer (with `t035vp.py`'s -1 VisiblePoint scan).
- Look closely: not compiled (no Swift here). The banner identifier on iOS 26 is unverified; if the first CI warning says "no SpringBoard banner was found", read its attachment for the real identifier. A control that isn't hittable during a fade (after a tap that landed) also fires the guard, which costs one SpringBoard query and a warning but fails nothing.
- Classes: MoveTextTesterUITests (shard 3) plus every class that uses `UITestSupport.tap`/`tapStep` (MoveTextUITests, AboutUITests).
- CI: run 46123625075 (964ea81, branch loop/T-035-system-banner-guard, scope=all). Pending, not watched.

## Fix round 2 (orchestrator)
CI 46123625075 (964ea81, scope=all): shards 1, 3, 4 and the ipa green, so the banner guard compiled and the Move-Text classes passed. Shard 2 was red on one test: `PlayerLandscapeBehaviourUITests/testLoadDifferentSubtitlesFromLandscapeDialog`, "Failed to terminate dev.brent.clipdeck". It failed in its first step (Open), which stops the previous test's app first, and that timed out after 66 s.
- The same error hit shard 2 in the loop branch's 46121764180 (`testControlsStayWhilePausedAndAutoHideWhilePlaying`). Both times it was the first or second launch after `AboutUITests/testSourceLinksAreShownAndOpenInSafari`. That test ends with Safari in the foreground, still loading GitHub pages, for the rest of the shard.
- Fix: the test terminates Safari when it ends. This is likely, not proven, from two failures in the same position; the next shard 2 run will show it.
