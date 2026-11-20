---
id: T-011
title: Drag the divider to resize the landscape subtitle panel
lane: frontend
depends_on: [T-002]
status: done
round: 4
base_sha: e534523b507dae0cedc50db33395ab73cdb935c7
issue: 11
spec:
model: opus
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

## Implementation notes (round 1) · sonnet
_by loop-frontend · 2026-11-19_
- Changed: `PlayerView` stores the panel width as `@AppStorage("player.panelFraction")` (default 0.25 = `panelFraction`). Effective fraction is clamped to [180 pt / usable width, 0.5] of the usable width (full width minus both insets); the trailing inset is still added on top. New `panelHandle(usable:fraction:)`: a 44 pt wide clear hit area on the panel's leading edge (overlay on the panel, offset -12 so it clears the panel toggle) with a small capsule grip, its own `DragGesture` (global coordinates, so the moving handle does not skew the translation), `onTapGesture(count: 2)` to reset (spring animation). During the drag a `@State` live fraction drives the layout; the stored value is written once in `onEnded`. Dragging cancels the hide timer, `dragPanelFraction != nil` is in `keepsControlsUp`, and `restartHideTimer()` runs when the drag ends. VoiceOver: element "Subtitle panel width", value "N percent", adjustable action +-5 %, custom action "Reset subtitle panel width". Identifier `player.panelHandle`.
- Test: `PlayerLandscapeUITests.testPanelHandleResizesRemembersAndResets` (double-tap to default, drag 120 left and assert wider, relaunch and assert width kept within 4 pt, drag far right and assert content stops at 180 pt, double-tap and assert 25 % within 2 %, which leaves the default behind). Attaches `landscape-05-panel-resized` (panel element screenshot) and `landscape-05-panel-resized-frames` (frames + `app.debugDescription`). Orientation reset is the existing `tearDown`.
- Docs: DESIGN.md (two places), DEVELOPMENT.md identifier list.
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckUITests/PlayerLandscapeUITests.swift, docs/DESIGN.md, docs/DEVELOPMENT.md
- Checked: nothing compiled (Windows, no Mac); read through only. CI needed.
- Tester, look at: whether `XCUIElement.press(forDuration:thenDragTo:)` on `player.panelHandle` really drives the SwiftUI DragGesture on iOS 26 (the main risk); the 32 pt strip of the panel's leading edge under the handle now eats taps on cue rows' left edge; the handle's frame width (>= 44); the "far right" drag ends 2 pt inside the screen; panel-content min 180 +-4 pt.
- Gotchas: the layout's `.animation` is scoped to `showSidePanel`, so live drag is unanimated and only the reset animates (via `withAnimation`). Stored fraction is clamped at read time, so a value saved on a larger screen still fits a smaller one.

## Test report (round 1)
_by loop-tester · 2026-11-19 21:25_

CI run 44660105956 (headSha 11b22d7): the ipa job is green (the Release archive compiles PlayerView). The simulator job is red because the UI test target does not compile, so **no test ran**. The xcresult's TestCaseRuns table has 0 rows, the screenshot manifest is empty, and run-ios was skipped. Nothing in this change has run yet.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 With the panel open, the divider shows a grip (a small rounded bar on the panel's leading edge) with at least a 44 pt wide touch area (`player.panelHandle`). | Fail (not run) | The code has a 5×44 capsule in a 44 pt clear area (PlayerView.swift:220-252). The frame assert in `testPanelHandleResizesRemembersAndResets` never ran (build failed, run 44660105956) |
| AC-2 Dragging it left or right resizes the panel and the video live; the panel stays between 180 pt and 50 % of the screen width. The video keeps its aspect ratio and stays to the left of the panel. | Fail (not run) | Traced: `clampedPanelFraction` keeps the fraction in [180/usable, 0.5]; onChanged drives a @State fraction. Still unknown whether `press(forDuration:thenDragTo:)` drives the DragGesture on iOS 26. Tester added a far-left drag that asserts 50 % ± 2 % (not run) |
| AC-3 The width is saved as a fraction of the screen width with `@AppStorage` (default 0.25), so it survives relaunch and fits other screen sizes; on each screen it is clamped to the limits. | Fail (not run) | `@AppStorage("player.panelFraction")`, written once in onEnded, clamped when read. The relaunch assert never ran |
| AC-4 Double-tapping the handle animates back to 0.25. | Fail (not run) | `onTapGesture(count: 2)` → `withAnimation(.spring)`. Not run |
| AC-5 VoiceOver: the handle is an adjustable element "Subtitle panel width", value as a percentage; swipe up/down changes it by 5 %; a custom action resets it. | Fail (not run) | Read: label, value "N percent", adjustable ±0.05, named action. Tester added label and value asserts (25 % and 50 %), not run. VoiceOver swipe up/down is Unverified (Brent) |
| AC-6 `PlayerLandscapeUITests` gains a test ... Attaches `landscape-05-panel-resized`. Orientation is reset in `tearDown`. | Fail | The test exists but does not compile (PlayerLandscapeUITests.swift:229-231 at 11b22d7). No `landscape-05*` attachment exists, so the frames and the element screenshot could not be measured |
| T-001/T-002 tests still pass (regression) | Fail (not run) | The UI test target failed to build, so 0 tests ran |

Not done: the revert-to-fail check on the main new test. It can only run in CI, and the test has never run green. The panel toggle's close tap is covered by `testPanelClosesAndSurvivesRotation`, which did not run this round. Traced: the toggle's right edge and the handle's left edge are both at videoWidth − 12, so they touch but do not overlap.

### Findings

**Must fix: the UI test target doesn't compile**
Where: ios/ClipDeckUITests/PlayerLandscapeUITests.swift:229-231 (at 11b22d7), in `attachFrames`
Problem: a single-line string literal contains two raw newlines (`"panel \(panel.frame)` / blank / `\(app.debugDescription)")`). The build stops with "unterminated string literal", so the simulator job runs no unit or UI tests.
Proof: Ran it. `gh run view 44660105956 --log-failed` shows `PlayerLandscapeUITests.swift:229:44: error: unterminated string literal` and `:231:24`, then "Testing cancelled because the build failed". The xcresult's TestCaseRuns table has 0 rows.
Trigger: any CI run.
Fix: **the tester already applied this in the working tree (uncommitted, not run)**: `XCTAttachment(string: "panel \(panel.frame)\n\n\(app.debugDescription)")`. Keep it. Nothing compiles locally, so check every literal before pushing.

**Should fix: the handle covers the panel's leading 32 pt at full height**
Where: ios/ClipDeck/Features/Player/PlayerView.swift:189, 220-232 (overlay `.leading`, `.frame(width: 44)`, `.frame(maxHeight: .infinity)`, `.contentShape`, `.offset(x: -12)`)
Problem: the hit area spans x = panel.minX − 12 to panel.minX + 32, from the top of the panel to the bottom. Compact cue rows start their text at x = 12 (4 pt outer and 8 pt inner padding in CueRow). As a result:
- A tap on the time label or on the first ~20 pt of any line does nothing.
- A double tap there resets the width.
- The leading ~24 pt of the panel's Make a Card does nothing (the panel has 8 pt of padding).
- A vertical scroll that starts in the strip does not scroll the cue list. The handle's `DragGesture(minimumDistance: 2)` takes the touch, resizes the panel by the finger's sideways wobble, and saves that width.
At the default content width of 187 pt, the strip is 17 % of the panel. The Agent notes ask that the handle not fight the cue list's scrolling.
Proof: Traced it, from the overlay geometry above and CueRow's `.padding(.horizontal, compact ? Spacing.s : …)` plus the outer `Spacing.xs`. Not measured, because no test ran.
Trigger: scrolling or tapping the subtitle list near its left edge, where the left thumb naturally lands.
Fix: keep the 44 pt touch area but move most of it over the video. For example, offset it by −32 so only 12 pt (the row padding) overlaps the panel. While the panel is open, give the top and bottom bars about 32 pt of trailing padding so `player.panelToggle` and `player.makeCard` stay clear of the handle. Or limit the hit area to a band around the grip. Add a UI test that taps `cue.row.1` about 16 pt from its leading edge and asserts that it seeks.

**Could fix: a cancelled drag leaves the live state set**
Where: ios/ClipDeck/Features/Player/PlayerView.swift:231-246
Problem: SwiftUI does not call `onEnded` when a gesture is cancelled, for example by a system gesture, an incoming call, or a rotation mid-drag. `dragPanelFraction` and `dragStartFraction` then stay non-nil. The controls never auto-hide (`keepsControlsUp`, line 385), the width is not saved, and the next drag starts from the stale start fraction, so the panel jumps.
Proof: Read it.
Fix: hold the live translation in `@GestureState`, which resets on cancel, or clear the state on rotation or disappear.

**Could fix: a failure in the handle test spills into the T-002 test**
Where: ios/ClipDeckUITests/PlayerLandscapeUITests.swift (test order)
Problem: XCTest runs tests alphabetically, so `testPanelHandleResizesRemembersAndResets` runs before `testSubtitlePanelOpensOnTheRight`. If the handle test fails after its drag, the stored fraction stays off the default. The exact-width T-002 test then fails as well, which hides the real cause.
Proof: Read it.
Fix: reset `player.panelFraction` in a teardown block. Or have `-uiTesting` reset it unless a keep-width flag is passed, and pass that flag in the relaunch step.

### Tester's test edits (uncommitted, not run)
- PlayerLandscapeUITests.swift: the compile fix above.
- After the first double-tap, the test asserts the handle's label "Subtitle panel width" and value "25 percent" (AC-5).
- After the 180 pt check, it drags far left and asserts three things: panel content = 50 % ± 2 % of the usable width, value "50 percent", and the video still at minX 0 (the AC-2 maximum). The final double-tap reuses `usable`.

```text
VERDICT: Fail
SPEC: AC-1..AC-6 not shown (no test ran: UI test target build error); AC-6 test fails to compile
CHECKS_RUN: CI 44660105956 (headSha 11b22d7): ipa (build-ipa.sh) green; simulator (test-ios.sh) red at build, 0 tests run; run-ios skipped
UNVERIFIED: drag feel on Brent's iPhone; VoiceOver swipe up/down and the reset action on a device
REVIEWED_AT: 11b22d723b499ad3b8da15e8667fcb501aef11ee (+ tester's uncommitted test edits)
```

## Fix round 2
_orchestrator · 2026-11-19 · sent the round-1 Test report findings to loop-frontend (sonnet): Must fix (UI test compile error, already fixed by the tester), Should fix (handle overlaps cue rows and steals list scrolls), and both Could fix items (cancelled drag, stored-width reset robustness)._

## Implementation notes (round 2) · sonnet
_by loop-frontend · 2026-11-19_
- Must fix (UI test did not compile): kept the tester's edits (single-line `"panel \(panel.frame)\n\n\(app.debugDescription)"` literal, AC-5 label/value asserts, AC-2 50 % assert); read the whole test file first. All new string literals are single-line.
- Should fix (handle ate cue-row taps): the handle is now offset by `-panelHandleClearance` (32 pt), so its 44 pt area covers 32 pt of the video and only 12 pt (the rows' own padding) of the panel. While the panel is open the bars (and the subtitle line, which shares `barInsets`) get 32 pt trailing padding instead of 0, so the toggle and Make a Card stay clear. `DragGesture(minimumDistance: 8)`; only a mostly horizontal drag resizes (checked at the start in `updating`, and again in `onEnded`). New test `testCueRowEdgeTapSeeksWithHandlePresent` taps `cue.row.1` 16 pt from its leading edge and asserts `player.subtitle` appears.
- Could fix 1 (cancelled drag): `dragPanelFraction`/`dragStartFraction` removed; a `@GestureState panelDragX: CGFloat?` holds the translation and resets itself on cancel. The live fraction is derived from the stored fraction minus the translation; `keepsControlsUp` uses `panelDragX != nil`, so the existing `onChange(of: keepsControlsUp)` restarts the hide timer on cancel too. The stored value is still written once, in `onEnded`.
- Could fix 2 (stored width vs test order): `ClipDeckApp.init` removes `player.panelFraction` on every `-uiTesting` launch unless `-uiTestingKeepPanelWidth` is passed; the relaunch step of the resize test passes it (`launchWithPanelOpen(keepWidth: true)`).
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeck/App/ClipDeckApp.swift, ios/ClipDeckUITests/PlayerLandscapeUITests.swift
- Checked: nothing compiled (Windows); re-read every edit and literal.
- Tester, look at: that the handle still drives from `press(forDuration:thenDragTo:)` with the offset hit area; `player.panelToggle` / `player.makeCard` frames vs the handle (toggle maxX should be 32 + 12 pt left of the video edge); the existing T-002 tests (toggle maxX <= video maxX still holds); the subtitle line now has 32 pt more trailing inset while the panel is open.

## Test report (round 2)
_by loop-tester · 2026-11-19 22:05_

CI run 44661143691 (headSha c0da745). The ipa job is green. The simulator job is red: 59 of 60 tests pass. The only failure is `testPanelHandleResizesRemembersAndResets`, at the relaunch step (`launchWithPanelOpen` line 226, "Controls show the panel button"). The cause is a **test defect**. On the relaunch the device is already in landscape, so the player opens paused with the controls already up. The video tap then hid them. The screen recording 9109A0EE….mp4 shows this: controls visible at t = 24.8–25.7 s, the tap at 25.56 s, gone from 25.9 s on. The failure hierarchy shows only `player.video`. Everything before the relaunch passed. Nothing after it ran: the remembered width, the 180 pt minimum, the 50 % maximum, and the reset from a non-default width.

Measured from `landscape-05-panel-resized-frames` (window 874 × 402, inset 62, usable 750):
- After the 120 pt left drag, the panel is 369.3 pt, so content is 307.3 pt (expected 187.5 + 120 = 307.5), fraction 41 % (the handle's value reads "41 percent"). The video is 504.7 pt at minX 0, and video plus panel = 874.
- The handle frame is x 472.7–516.7 (44 pt): 32 pt over the video and 12 pt over the panel. Cue rows start at 504.7 and their text at 516.7, so the touch area ends exactly where the text starts.
- `player.panelToggle` maxX is 460.7, 12 pt clear of the handle. The bar's Make a Card spans 406.3–460.6 (icon only at 41 %).
- At the default width (`landscape-03-panel-frames`), the toggle maxX is 580.7 and the handle minX is 592.7, again 12 pt clear. The bar's Make a Card keeps its full label (162 pt).

The drag is live. In recording frames the panel's leading edge moves 625 → 584.3 (t = 14.8 s) → 520.3 (14.9 s) → 507 (15.0 s) during the press-and-drag at 14.42–15.18 s, so `press(forDuration:thenDragTo:)` does drive the SwiftUI DragGesture on iOS 26.5. The panel element screenshot (07FBF10A….png, 369 pt) shows the full-label panel Make a Card and readable compact rows.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 With the panel open, the divider shows a grip (a small rounded bar on the panel's leading edge) with at least a 44 pt wide touch area (`player.panelHandle`). | Fail | Touch area: Pass, 44 pt measured (frames attachment; `handle.frame.width >= 44` assert passed). Grip: it is no longer on the panel's leading edge. Its centre is 10 pt left of the edge, over the video (recording frame crop at t = 15.5 s). See Should fix |
| AC-2 Dragging it left or right resizes the panel and the video live; the panel stays between 180 pt and 50 % of the screen width. The video keeps its aspect ratio and stays to the left of the panel. | Partly shown | Live resize and left/right placement: Pass (mid-drag frames above; content 307.3 vs 307.5; video minX 0; widths sum to 874). The 180 pt and 50 % limits come after the relaunch and did not run |
| AC-3 The width is saved as a fraction of the screen width with `@AppStorage` (default 0.25), so it survives relaunch and fits other screen sizes; on each screen it is clamped to the limits. | Not shown | The relaunch step failed on the test defect before measuring. Default 0.25: Pass (25 percent, and T-002's exact width 249.33 vs 249.5) |
| AC-4 Double-tapping the handle animates back to 0.25. | Not shown | The only double-tap that ran started from the default, so it proves nothing. The reset from 50 % did not run |
| AC-5 VoiceOver: the handle is an adjustable element "Subtitle panel width", value as a percentage; swipe up/down changes it by 5 %; a custom action resets it. | Partly shown | Label "Subtitle panel width" and value "25 percent" asserts passed; the value follows the width ("41 percent" in the frames). The adjustable swipes and the reset action were read in code only. Unverified (Brent, VoiceOver on a device) |
| AC-6 `PlayerLandscapeUITests` gains a test ... Orientation is reset in `tearDown`. | Fail (test defect, fixed by tester) | `testPanelHandleResizesRemembersAndResets` failed at line 226 on the relaunch (see above). The tester fixed it in the working tree, not run yet |
| Round-1 Must fix: UI tests compile | Pass | The test target built, and 60 tests ran |
| Round-1 Should fix: handle covers the cue rows | Pass | Handle ends at panel.minX + 12 (measured). `testCueRowEdgeTapSeeksWithHandlePresent` passed: tap at row.minX + 16 = 520.7, 4 pt clear of the handle. With round 1's −12 offset, the handle would span 492.7–536.7 and cover that point (traced from the measured frames; the revert run was not done, CI only) |
| Round-1 Could fix: cancelled drag | Pass (read) | `@GestureState panelDragX` resets on cancel; `keepsControlsUp` uses it |
| Round-1 Could fix: test order | Pass | Ran it. The failed handle test left 0.41 stored. The next test, `testSubtitlePanelOpensOnTheRight`, launched with `-uiTesting` only and measured 249.33 pt (expected 249.5) with the handle value "25 percent", so the reset works |
| T-001/T-002 regressions | Pass | All 8 PlayerLandscapeBehaviourUITests tests, `testControlsAppearOnTapInLandscape`, `testSubtitlePanelOpensOnTheRight` (exact width), MiningFlowUITests, LaunchUITests, and all unit tests pass. The ClipExtractor flake did not occur |

### Findings

**Should fix: the grip moved off the panel's leading edge, onto the video**
Where: ios/ClipDeck/Features/Player/PlayerView.swift:232-241 (`Capsule` overlay centred in the 44 pt area, then `.offset(x: -Self.panelHandleClearance)`)
Problem: moving the touch area 32 pt over the video also moved the grip. The capsule's centre is now at panel.minX − 10 (492.2–497.2 when the edge is at 504.7), so it sits on the video, not on the panel's leading edge as AC-1 says. It is drawn in `Theme.ink` at 35 % opacity, a colour picked for the light panel. On the flat light-blue sample it shows as a dark bar. Over the dark scenes and black letterbox of a real episode, a dark ink at 35 % is close to invisible, and the grip is the only sign that the divider can be dragged.
Proof: Ran it. Recording frame at t = 15.5 s, cropped around the divider (scratch `%TEMP%\clip-deck-loop\T-011-r2\frames\crop1550.png`): the bar sits about 11 pt left of the white panel edge, on the video. The frames attachment gives handle x 472.7–516.7.
Trigger: open the panel over any dark video.
Fix: keep the hit area where it is, but put the grip back on the panel edge, for example `.overlay(alignment: .leading) { Capsule()….offset(x: Self.panelHandleClearance - 2.5) }` inside the 44 pt area. Or draw the grip in the panel. Then make it legible on both sides: a light grip with a subtle dark outline or shadow, or a grip on the panel background.

**Could fix: a resize that ends with a mostly vertical motion is thrown away**
Where: ios/ClipDeck/Features/Player/PlayerView.swift:244-251
Problem: `updating` latches on once a drag is horizontal (`state != nil || …`), so the panel resizes live. But `onEnded` checks again with `abs(dx) > abs(dy)` against the final translation. A drag that goes sideways and then drifts down further than it moved sideways snaps back unsaved.
Proof: Read it.
Fix: make the end check match the latch, for example save whenever `abs(dx) >= 8` (the minimum distance), or drop the vertical check in `onEnded`.

**Could fix: the trailing 32 pt of the video no longer toggles the controls**
Where: same overlay; the handle owns its full-height 44 pt area and only has a double-tap gesture
Problem: a single tap in the video's rightmost 32 pt, top to bottom, is swallowed. It doesn't show or hide the controls, and it doesn't reach the video. This is the cost of moving the touch area off the cue rows. It's acceptable, but worth knowing.
Proof: Traced it (measured handle frame against `player.video` 0–504.7).
Fix: optional. Pass single taps through (`.onTapGesture { toggleControls() }` on the handle), or limit the full-height area to a band around the grip.

Pre-existing (T-001, not in this diff, not a T-011 finding): opening the player with the device already in landscape shows the controls straight away, because `onChange(of: model?.isPlaying)` sees nil → false while `isLandscape` is true. Rotating into landscape starts with them hidden. This is what the relaunch step tripped over. Brent may or may not want that difference.

### Tester's test edits (uncommitted, not run)
- PlayerLandscapeUITests.swift `launchWithPanelOpen`: tap the video only when `player.panelToggle` isn't already showing within 2 s. This fixes the relaunch failure.
- After the far-left (50 %) step, assert that the bar's `player.panelToggle` and `player.makeCard` exist and that their maxX ≤ the handle's minX. The test also attaches `landscape-05-panel-max` and `landscape-05-panel-max-frames`, covering the tightest bar layout. My estimate: at 50 % the bottom row needs about 330 pt of the 319 pt available, so it may overflow by about 5 pt per side but still stay clear of the handle.

```text
VERDICT: Fail
SPEC: AC-1 touch area met, grip not on the panel edge (Should fix); AC-2 live resize met, limits not shown; AC-3, AC-4 not shown (test defect at relaunch, fixed by tester); AC-5 label/value met, swipes unverified; AC-6 test failed on a test defect
CHECKS_RUN: CI 44661143691 (headSha c0da745): ipa (build-ipa.sh) green; simulator (test-ios.sh) red, 59/60 (testPanelHandleResizesRemembersAndResets at the relaunch, test defect); run-ios skipped after the failure
UNVERIFIED: drag feel on Brent's iPhone; VoiceOver swipe up/down and the reset action; grip legibility over real (dark) video
REVIEWED_AT: c0da7459e760dde09e8d70223a675cb35f8dfbbf (+ tester's uncommitted test edits)
```

## Fix round 3
_orchestrator · 2026-11-19 · sent the round-2 Test report findings to loop-frontend (sonnet): Should fix (the grip moved off the panel edge, and it is hard to see) plus both Could fix items (a drag drifting down at the end snaps back; the handle swallows video taps). This is the last round before Blocked._

## Implementation notes (round 3) · sonnet
_by loop-frontend · 2026-11-19_
- Should fix (grip off the panel edge): the 44 pt hit area stays at -32 pt. The grip is now an overlay at the leading side of that area with `.padding(.leading, 32 - 2.5)`, so its centre sits on the panel's leading edge line (the area is shifted by the same -32 offset). It is a 5 x 40 white capsule with a 1 pt black 50 % outline and a soft shadow, so it reads over dark video and the light panel. No separate grip identifier: the handle stays a single accessibility element (`.children: .ignore`), so I rely on the panel element screenshot and the frames.
- Could fix 1 (resize thrown away on a final vertical drift): the direction is decided once per drag. `onChanged` records `panelDragOrigin` (the drag's `startLocation`) and `panelDragResizes` (horizontal at the first event), re-deciding whenever the start location differs, so a stale value from a cancelled drag can't leak. `onEnded` saves whenever that latch says it was a resize, whatever the final translation. The `updating` latch (state non-nil once horizontal) uses the same first-event test, so live and saved decisions agree.
- Could fix 2 (single tap on the video's rightmost 32 pt swallowed): added `.onTapGesture { toggleControls() }` after the double-tap gesture on the handle (double first, so the double-tap still wins; a single tap there waits for the double-tap window, so it responds a moment later than a tap on the video).
- Tester's test edits (launchWithPanelOpen taps only if the toggle isn't visible; 50 % asserts and attachments) are untouched.
- Files: ios/ClipDeck/Features/Player/PlayerView.swift
- Checked: nothing compiled (Windows); re-read the edit.
- Tester, look at: grip centre vs panel minX in the panel element screenshot / recording; a single tap on the video's right edge strip toggles the controls; double-tap still resets; drags still work after the `.onChanged` was added to the gesture chain (compile risk: `.updating(...).onChanged {}.onEnded {}`).

## Test report (round 3)
_by loop-tester · 2026-11-19 22:22_

CI run 44665692227 (headSha 639a612). The ipa job is green. The simulator job is red: 59 of 60 tests pass. The only failure is `testPanelHandleResizesRemembersAndResets` at PlayerLandscapeUITests.swift:187, "Video stays on the left at the maximum": `player.video` minX is **−13.67**, expected 0 ± 1. This is a product defect, not a test defect (see Must fix). Every step before line 187 passed: the relaunch fix (the 2 s wait found the toggle at +1.07 s, so there was no tap), the remembered width, the 180 pt minimum, 50 % ± 2 %, and "50 percent". The steps after it did not run: the bar-clearance asserts, `landscape-05-panel-max`, and the reset from a non-default width. The ClipExtractor flake did not occur. Since the test failed, run-ios was skipped.

Evidence comes from the screen recording 4855D591….mp4. Frames were taken at the xcresult activity times, with t = 0 at the recording start. The frames are rotated, at 3 px/pt. Frames and scripts are in `%TEMP%\clip-deck-loop\T-011-r3\frames` and `T-011-r3-scripts`.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 With the panel open, the divider shows a grip (a small rounded bar on the panel's leading edge) with at least a 44 pt wide touch area (`player.panelHandle`). | Pass | The handle frame is 472.7–516.7 (44 pt; frames attachment EECED67A….txt; the `>= 44` assert passed). Grip at t = 19.0 s (41 %): a white capsule with a dark outline, outline centres at x = 501.67 and 507.0, so its centre is at 504.33. `panel.minX` is 504.67, so the grip is within 0.4 pt of the edge. It is visible over the blue video (f019.00.png, grip-f019.png). How it reads over dark video is Unverified (Brent) |
| AC-2 Dragging it left or right resizes the panel and the video live; the panel stays between 180 pt and 50 % of the screen width. The video keeps its aspect ratio and stays to the left of the panel. | **Fail** | The resize and its limits work: +120 pt gives content 307.3 pt (41 %); far right gives panel minX 632.33, so content is 179.67 pt (asserts 178/179 passed); far left gives 50 % (asserts 185/186 passed). **At the 50 % maximum the video is not fully visible.** `player.video` minX is −13.67 (assert 187). The picture is drawn 261.7 pt tall, which is 16:9 at 465 pt wide, inside a 437.7 pt column, so about 13.7 pt is cut off each side. At 41 % (283.7 pt tall at 504.7 wide) and at 180 pt (355.3 at 632.3) the picture is exact. The back button moved from x = 74.0 to 60.33, inside the 62 pt safe-area inset (f044.60 vs f019.00) |
| AC-3 The width is saved as a fraction of the screen width with `@AppStorage` (default 0.25), so it survives relaunch and fits other screen sizes; on each screen it is clamped to the limits. | Pass | The relaunch with `-uiTestingKeepPanelWidth` passed `XCTAssertEqual(panel.frame.width, widerWidth, accuracy: 4)` (line 167). The default 25 % came from the first double-tap ("25 percent" assert passed). The clamp on read is in code; this run used one screen size only |
| AC-4 Double-tapping the handle animates back to 0.25. | Not shown | The only double-tap that ran started from the default. The reset from 50 % (lines 200-203) comes after the failure. Reset from a non-default width is unproven |
| AC-5 VoiceOver: the handle is an adjustable element "Subtitle panel width", value as a percentage; swipe up/down changes it by 5 %; a custom action resets it. | Partly shown | The label, "25 percent" and "50 percent" asserts passed. "41 percent" appears in the frames. The adjustable swipes and the reset action are only in code. Unverified (Brent) |
| AC-6 `PlayerLandscapeUITests` gains a test ... Orientation is reset in `tearDown`. | Fail | `testPanelHandleResizesRemembersAndResets` fails at line 187 because of the Must fix below. `landscape-05-panel-resized` (A14EAF2E….png plus frames) is attached; `landscape-05-panel-max` is not |
| Round-2 Should fix: grip off the panel edge | Pass | Centre at 504.33 vs edge 504.67 (above). It is a light grip with an outline, so it is no longer dark ink over the video |
| Round-2 Could fix: a drag drifting down at the end is lost | Pass for drags | All three drags saved: 41 %, then kept across the relaunch, then 180 pt, then 50 %. The new `.onChanged` in the chain compiles and does not break dragging. See the Could fix on the latch mismatch |
| Round-2 Could fix: a single tap on the video's right 32 pt is swallowed | Unverified (no test) | No test taps the handle once. Indirect evidence: during and after the double-tap (16.66–17.07 s), `player.back` stays on screen in every 0.1 s frame from 16.5 to 18.0 s, and is still present in the 19.0 s hierarchy. So the double-tap did not also fire the single-tap toggle |
| Round-2 test fix (relaunch tap) | Pass | The relaunch step went straight to the toggle tap |
| T-001/T-002 regressions | Pass | The other 59 tests pass, including `testSubtitlePanelOpensOnTheRight`, `testCueRowEdgeTapSeeksWithHandlePresent`, all PlayerLandscapeBehaviourUITests, MiningFlowUITests, LaunchUITests, and all unit tests |

### Findings

**Must fix: at the 50 % maximum the bottom bar overflows the video column, so the video is cropped and shifted left**
Where: ios/ClipDeck/Features/Player/PlayerView.swift:165-168 (`barInsets` trailing = `panelHandleClearance` 32 pt), 170-196 (ZStack of `videoScreen` plus the bars, `.frame(width: videoWidth)`), 362-373 (`bottomRow`; its icon-only fallback is the last `ViewThatFits` option, so it is used even when it doesn't fit)
Problem: the icon-only bottom row needs 346.3 pt: transport 74→342 = 268, two 8 pt spacings, the 8 pt minimum Spacer, and Make a Card at 54.3. Add 12 + 12 inner padding, the 62 pt leading inset and the 32 pt handle clearance, and the bars need 464.3 pt. At 50 % the video column is 437.7 pt. The ZStack takes the overflowing child's width (464.3) and is centred in its 437.7 frame. So the video layer and both bars move 13.67 pt left and are clipped on both sides:
- the picture is scaled to about 465 pt wide and loses about 13.7 pt at each edge, so the video is not fully visible;
- the back button sits at x = 60.3, inside the 62 pt safe-area inset;
- the toggle's and bar Make a Card's right edges are at 406.4, 0.7 pt inside the handle area (minX 405.67), so the tester's clearance asserts at lines 196-197 would also fail.
On this 874 pt iPhone this happens whenever the panel fraction is above about 46.4 %. On narrower iPhones the threshold is lower. It comes from combining the 50 % maximum with round 2's 32 pt trailing clearance. Before that change, trailing was 0 and the row fitted.
Proof: Ran it. CI 44665692227, TestIssues: `XCTAssertEqualWithAccuracy failed: ("-13.666666666666666") is not equal to ("0.0") +/- ("1.0") - Video stays on the left at the maximum` (line 187). Recording frame f044.60 (t = 44.6 s, after the far-left drag): the picture is 70.0–331.3 pt tall (261.7), the back button's left edge is at 60.33 (74.0 at 41 % in f019.00), and the bar buttons end at 406.4.
Trigger: drag the panel to (or near) its maximum while the controls are up.
Fix: keep the video's size independent of the bars, and make the bars fit:
1. Lay the bars over the video so they can't widen the column: an `.overlay` on `videoScreen`, or give the bars `.frame(width: videoWidth)` with a `.frame(maxWidth:)` that can't grow.
2. Give the bottom row a fallback that fits about 343 pt of content (437.7 − 62 − 32): for example a third `ViewThatFits` option without the ±5 s skip buttons, or a smaller Spacer and spacing.
Alternatively, Brent could approve capping the maximum where the bars still fit, but that changes AC-2's 50 %. The existing test (line 187 plus the clearance asserts) decides this. Optionally also assert `player.back.frame.minX >= inset + 12 - 1` at the maximum.

**Could fix: the live latch and the save latch can disagree**
Where: ios/ClipDeck/Features/Player/PlayerView.swift:252-264
Problem: `updating` sets the live translation once any event is horizontal (`state != nil || |dx| > |dy|`, checked on every event). `onChanged` decides `panelDragResizes` from the first event only. A drag whose first event (at 8 pt) is mostly vertical and then turns sideways resizes live, but is not saved, so the panel snaps back on release. This is the opposite case of the round-2 Could fix. The implementation note says both use "the same first-event test", but they don't. A stale `panelDragOrigin` left by a cancelled drag only matters if the next drag starts at exactly the same point.
Proof: Read it.
Fix: decide once, in one place. For example, in `updating` only set `state` when the first-event latch is true. Or store the start direction in `@GestureState` and read it in both places.

**Could fix: no test covers the new single tap on the handle**
Where: ios/ClipDeckUITests/PlayerLandscapeUITests.swift
Problem: the `.onTapGesture { toggleControls() }` on the handle is never tapped once in a test. Only indirect evidence exists: the double-tap did not toggle the controls.
Fix: add a test step that taps `player.panelHandle` at its normalized x 0.25 (over the video), asserts `player.back` disappears, taps again, and asserts it returns.

```text
VERDICT: Fail
SPEC: AC-1 met (grip centre 0.4 pt from panel.minX); AC-2 fails at the 50 % max (video cropped and shifted 13.67 pt); AC-3 met (relaunch keeps the width ±4); AC-4 not shown (reset from non-default after the failure); AC-5 label/value met, swipes unverified; AC-6 test fails at line 187
CHECKS_RUN: CI 44665692227 (headSha 639a612): ipa (build-ipa.sh) green; simulator (test-ios.sh) red, 59/60 (testPanelHandleResizesRemembersAndResets line 187); run-ios skipped after the failure
UNVERIFIED: drag feel on Brent's iPhone; VoiceOver swipe up/down and reset action; grip legibility over dark video; single tap on the handle strip toggling the controls (no test)
REVIEWED_AT: 639a6127e126ef9cd56c7aeb42cdee929307bd88
```

## Blocked
_orchestrator · 2026-11-19 · max_fix_rounds (3) reached. Remaining Must fix: at the 50% maximum the bottom bar is wider than the video column, so the video shifts left by 13.7 pt and is cropped (AC-2). Waiting for Brent._

## Fix round 4
_orchestrator · 2026-11-19 · Brent approved one extra round past max_fix_rounds, on Opus. A fresh loop-frontend (opus) gets the round-3 Test report._
- Also Brent's decision (from the tester's T-001 note): in landscape the controls always start **hidden**. That includes opening the player while the phone is already in landscape, which today shows them at once. The orientation reset should not depend on how landscape was entered.

## Implementation notes (round 4) · opus
_by loop-frontend · 2026-11-19 23:04_
- Must fix (bars widened the video column at 50 %): (a) the ZStack is gone. `videoScreen` now gets `.frame(width: videoWidth)` first, and the bars are an `.overlay(alignment: .leading)` on that fixed-width video, so they can't change its size or position. The bars' VStack is `VStack(alignment: .leading)` with `.frame(width: videoWidth, alignment: .leading)` plus `.clipped()`. If a bar still can't fit, it keeps its leading edge (player.back stays at inset + 12) and is clipped on the trailing side, not re-centred. (b) `bottomBar`'s `ViewThatFits` has a third option, `bottomRow(model, iconOnly: true, skips: false)`. It drops the ±5 s skip buttons (`transportButtons(..., skips:)`) and keeps play/pause, offset, subtitles and the icon-only Make a Card. The scrubber row is unchanged. That row needs about 242 pt (44 + 60 + 44 + 2 × 8, then 8 + 8 Spacer + 8 + 54.3). At 50 % on the 874 pt iPhone the row gets 319.7 pt (437.7 − 62 − 32 − 24). The full-label and icon-only options still come first, so the default and 41 % layouts are unchanged. All identifiers are kept.
- Could fix (latch mismatch): there is now one latch. `@GestureState panelDrag: PanelDrag?` ({start, x}) only tracks the drag and resets on cancel. `onChanged` decides `panelDragResizes` once, from the first event of each start location. The live resize (`liveResizeX`: needs `panelDrag` non-nil, the latch true and `panelDragOrigin == panelDrag.start`) and the save in `onEnded` (latch true for that start) both read that same latch, so they can't disagree. After a cancelled drag a stale latch can only apply if the next drag starts at the exact same point, and even then the live resize and the save read the same value. `keepsControlsUp` uses `panelDrag != nil`, as before.
- Single tap on the handle: new `testHandleSingleTapTogglesControls`. It taps `player.panelHandle` at normalized (0.25, 0.5), 11 pt into the area over the video, and asserts `player.back` disappears (3 s, which covers the double-tap wait). It waits 0.6 s, taps again, asserts `player.back` returns, and asserts the panel width is unchanged (±1).
- Brent's decision (controls start hidden in landscape): `onChange(of: model?.isPlaying)` now brings the controls up only on a real pause (`wasPlaying == true`, `playing == false`). The model appearing paused (nil → false) no longer shows them, so opening in landscape starts hidden, just like rotating in. Pausing, the clip ending and a finished Make a Card segment still bring them back (true → false). Portrait is unaffected (the branch needs `isLandscape`).
- Tests: `launchWithPanelOpen` now asserts `XCTAssertFalse(toggle.waitForExistence(timeout: 2))` and then always taps the video. This covers both its first launch (rotated in) and the relaunch (opened in landscape), and replaces the tester's "tap only if not showing". New `testControlsStartHiddenWhenOpenedInLandscape`: rotate at the library, open the episode, assert `player.back` and `player.makeCard` stay away for 3 s, tap, and assert the controls appear. In `testPanelHandleResizesRemembersAndResets` at the maximum I added `back.frame.minX == inset + 12 (±1)`. The existing video minX 0 and clearance asserts are untouched. I checked PlayerLandscapeBehaviourUITests: every test there opens in portrait, rotates, and then taps the video, so none relied on the controls showing at launch. No change there.
- Docs: DESIGN.md landscape paragraph (controls start hidden however landscape starts, the bars never widen the video column, skips drop near the maximum, a single tap on the handle toggles the controls).
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckUITests/PlayerLandscapeUITests.swift, docs/DESIGN.md
- Checked: nothing compiled (Windows, no Mac). I re-read every edit, and every string literal is single-line. The diff adds no non-ASCII characters to the UI test file.
- Tester, look at:
  - `landscape-05-panel-max-frames`: video minX 0 and width 437.7, back minX 74, the bottom row without "Back 5 seconds" or "Forward 5 seconds", and toggle / Make a Card maxX about 393.7 against handle minX about 405.7.
  - The recording at 50 %: is the picture exactly 437.7 wide (246.2 tall)?
  - The bars' fade-in and fade-out still animate, now inside an overlay.
  - The relaunch step's new "starts hidden" assert.
  - Gotchas: the onEnded/GestureState ordering is no longer relied on. If onEnded runs after the GestureState reset, the panel may flash at the old width for one frame before the save; not seen in rounds 2-3.

## Test report (round 4)
_by loop-tester · 2026-11-19 23:16_

CI run 44672073767 (headSha 35dba5d): both jobs are green. The ipa job passed. The simulator job ran 62/62 tests with 0 TestIssues, then run-ios passed. The ClipExtractor flake did not occur. All tests passed, so XCUITest kept no screen recordings. Layout evidence comes from the `-frames` attachments (`app.debugDescription`), the element screenshots, and the xcresult Activities timeline. Scratch: `%TEMP%\clip-deck-loop\T-011-r4\ci`.

Measured at the 50 % maximum (`landscape-05-panel-max-frames`, C5B9E344….txt; window 874 × 402, inset 62, usable 750):
- `player.video` is {0, 0, 437, 402}, exactly the column (874 − panel 437). Panel content is 375 = 50 % of 750.
- `player.back` minX is 74 = inset + 12. `player.panelToggle` and the bar's `player.makeCard` both end at maxX 393.0. `player.panelHandle` minX is 405.0, so both are 12 pt clear.
- The bottom row is play/pause 74, offset 134, subtitles 194, Make a Card 338.7 (icon only). The file has no "Back 5 seconds" or "Forward 5 seconds" element. At 41 % (`landscape-05-panel-resized-frames`) the skips are still there (gobackward.5 at 74, goforward.5 at 178), so the third `ViewThatFits` option only kicks in near the maximum.
- The picture is not cropped. `PlayerLayerView` is an `AVPlayerLayer` backing layer with `.resizeAspect`, and its view frame now equals the 437 pt column. In round 3 the crop came from that view being 464 pt wide at minX −13.67. No recording exists to show the picture itself (all tests passed).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 With the panel open, the divider shows a grip (a small rounded bar on the panel's leading edge) with at least a 44 pt wide touch area (`player.panelHandle`). | Pass | Handle 44 × 402 in both frames attachments, and the `>= 44` assert passed. The grip is on the panel edge in the `landscape-05-panel-max` element shot (0A933BC3….png). The grip code is unchanged since round 3, where its centre measured 0.4 pt from the edge |
| AC-2 Dragging it left or right resizes the panel and the video live; the panel stays between 180 pt and 50 % of the screen width. The video keeps its aspect ratio and stays to the left of the panel. | Pass | Every assert in `testPanelHandleResizesRemembersAndResets` passed. +120 pt widens the panel. Far right stops at 180 ± 4. Far left stops at 50 % ± 2 % ("50 percent"). The round-3 Must fix assert passed too: video minX 0 at the maximum (frames: video 0–437, the full column). Back minX = inset + 12 (asserted, measured 74). The toggle and Make a Card are clear of the handle (asserted, measured 393 vs 405) |
| AC-3 The width is saved as a fraction of the screen width with `@AppStorage` (default 0.25), so it survives relaunch and fits other screen sizes; on each screen it is clamped to the limits. | Pass | The relaunch assert passed (±4 pt). Default "25 percent" asserted. Clamp on read: code only, one screen size in CI |
| AC-4 Double-tapping the handle animates back to 0.25. | Pass | **Now runs from a non-default width.** Activities show the double tap at 749.65, after the 50 % step. The asserts that follow passed: 25 % ± 2 % of usable, and `defaultWidth` ± 2. The spring animation is in code (`withAnimation(.spring)`); there is no recording to see it |
| AC-5 VoiceOver: the handle is an adjustable element "Subtitle panel width", value as a percentage; swipe up/down changes it by 5 %; a custom action resets it. | Pass (label/value), Unverified (swipes, reset action) | Label, "25 percent" and "50 percent" asserts passed. "41 percent" appears in the frames. The swipe up/down and the named reset action need VoiceOver on a device (Brent) |
| AC-6 `PlayerLandscapeUITests` gains a test ... Attaches `landscape-05-panel-resized`. Orientation is reset in `tearDown`. | Pass | The test passed (46.0 s). It attaches `landscape-05-panel-resized`, `landscape-05-panel-max` and their frames. `tearDown` resets to portrait |
| Round-3 Must fix: the bars widened and shifted the video at 50 % | Pass | Above. The same line-187 assert that failed in run 44665692227 (−13.67) now passes against the new code. That failing run is the revert-to-fail evidence for this fix |
| Round-3 Could fix: one shared drag latch | Pass (read + run) | `liveResizeX` and `onEnded` both read `panelDragResizes` for the same `startLocation`. `updating` only records the drag. All three drags resized live and saved |
| Round-3 Could fix: test for a single tap on the handle | Pass | `testHandleSingleTapTogglesControls` passed. The tap at handle (0.25, 0.5) at 700.95 hid `player.back` within 1.05 s. The second tap at 703.01 brought it back. Panel width unchanged ±1 |
| Brent's decision (fix round 4): landscape controls always start hidden, also when opened in landscape | Pass | `testControlsStartHiddenWhenOpenedInLandscape` passed: the device rotated at the library (654.05), the player opened, `player.back` stayed absent for the full 3 s (660.46–663.49) and so did `player.makeCard`, then a tap showed them. On the relaunch step of the resize test (already in landscape) the 2 s "toggle stays hidden" wait ran its full 2.03 s, and the tap followed. Run 44661143691 showed the old code bringing the controls up here, so this test would fail on the old code |
| A real pause still shows the controls (T-001 AC-2) | Pass | `testControlsStayWhilePausedAndAutoHideWhilePlaying`: after the sample played to its end (true → false), `player.back` reappeared within the 10 s wait with no tap in the Activities (494.13 → 496.16), then stayed past 3 s |
| Bars still fade as an overlay | Unverified (no recording) | Read: the `if shown` block keeps `.transition(.opacity)` inside the `.overlay`, and `.animation(.easeInOut(duration: 0.2), value: shown)` is applied outside it, so the fade still applies. No passing test keeps a recording. Brent can see it on the device |
| T-001/T-002 regressions | Pass | All 8 PlayerLandscapeBehaviourUITests, `testControlsAppearOnTapInLandscape`, `testSubtitlePanelOpensOnTheRight` (exact width), `testCueRowEdgeTapSeeksWithHandlePresent`, MiningFlowUITests, LaunchUITests and all unit tests pass. The portrait `03-player` screenshot matches main's baseline pixel for pixel except the status-bar clock (diff bbox 170,79–275,117) |

T-001 wording to update (not a defect): T-001 AC-2 says the controls "stay visible while paused". Under Brent's decision that is still true once they are shown: `keepsControlsUp` includes `!isPlaying`, and a real pause or the clip ending brings them back. But a paused player that has just entered landscape now shows no controls until a tap, which matches T-001 AC-1 ("hidden until the user taps") better than before. Suggested AC-2 wording: "Once shown, they stay visible while paused …; pausing or reaching the end brings them back. Entering landscape (by rotating or by opening the player already in landscape) always starts hidden." DESIGN.md already says this.

### Findings

**Could fix: the test doesn't assert that the ±5 s skips drop out at the maximum**
Where: ios/ClipDeckUITests/PlayerLandscapeUITests.swift:186-199
Problem: the third `ViewThatFits` option is only proven by the frames attachment (no "5 seconds" element at 50 %). No assert would catch it if the order or widths changed so that the skips came back and were clipped.
Proof: Ran it (the frames file shows no skips at 50 %, and skips present at 41 %).
Fix: at the maximum, `XCTAssertFalse(app.buttons["Back 5 seconds"].exists)`, plus a `player.video.frame.width == window.width - panel.frame.width` assert.

**Could fix: no visual proof of the uncropped picture or the fade at the maximum**
Where: ios/ClipDeckUITests/PlayerLandscapeUITests.swift `attachFrames`
Problem: passing tests keep no recording, and only the panel element is screenshotted. The uncropped picture is proven by frame plus layer gravity, not by pixels.
Fix: also attach `app.descendants(matching: .any)["player.video"].screenshot()` (element screenshots come out unrotated).

```text
VERDICT: Pass
SPEC: AC-1, AC-2, AC-3, AC-4, AC-6 met; AC-5 label/value met, swipes and reset action unverified (device)
CHECKS_RUN: CI 44672073767 (headSha 35dba5d): ipa (build-ipa.sh) green; simulator (test-ios.sh) green 62/62, 0 issues; run-ios green
UNVERIFIED: drag feel on Brent's iPhone; VoiceOver swipe up/down and the reset action; grip legibility over dark video; the bars' 0.2 s fade (no recording on passing tests); opening in landscape with no controls feels right
REVIEWED_AT: 35dba5d30ecb7290c2eb82398fa0c5eecca99e33
```
