# Handoff log
<!-- Append-only. One entry per agent run, newest at the bottom. Format: references/state-format.md -->

## 2026-11-19 17:39 · loop-planner · T-001..T-008 · round 0
- Done: planned T-001..T-008 (GitHub issues #1-#8); wrote spec .loop/specs/mkv-import.md (Proposed: convert MKV to MP4 on import with an LGPL FFmpeg build)
- Left: T-001, T-002, T-003 are todo. T-004..T-006 blocked on MKV spec approval; T-007 on the paid Apple account decision; T-008 on whether Brent wants an expiry reminder
- Files: .loop/specs/mkv-import.md, .loop/tasks/T-001..T-008, .loop/BOARD.md
- Gotchas: landscape panel ratio chosen as 75/25 (1/8 ≈ 106 pt is too narrow); arthenica/ffmpeg-kit is retired, don't use it; landscape UI tests must reset orientation in tearDown; ios-simulator.yml only runs on non-main branches via `gh workflow run`

## 2026-11-19 18:05 · loop-planner · T-001..T-011 · replan
- Done: applied Brent's decisions. MKV spec Accepted (option A + all defaults), so T-004/T-005/T-006 are now todo. T-003 rewritten as a SideStore on-device refresh guide (docs/INSTALL_ON_IPHONE.md). T-008 unblocked (shown at most once a day from 48 h before expiry, X + swipe, refresh in SideStore). New: T-009 GitHub Release of the IPA (#9), T-010 SideStore source apps.json (#10, blocked), T-011 drag-to-resize landscape panel (#11)
- Left: T-010 blocked because the repo is PRIVATE (public repo vs separate public release repo); T-007 blocked on a paid account (future path)
- Files: .loop/specs/mkv-import.md, .loop/tasks/T-002,T-003,T-004,T-007,T-008 (edited), T-009..T-011 (new), .loop/BOARD.md; issues #2-#8 edited/commented, #9-#11 created
- Gotchas: a new workflow_dispatch workflow can't be started until it's on main, so test release.yml with a `v*` tag push on the loop branch and delete the test release afterwards; SideStore labels, VPN app name and URL scheme are unconfirmed, so cite docs.sidestore.io or the SideStore source

## 2026-11-19 18:20 · loop-planner · T-004,T-005,T-006,T-009,T-010 · replan 2
- Done: built-in MKV subtitles are now optional and delivered last. T-004 gained AC-6 (an MKV with no subtitle tracks, or only picture ones, converts with no error or warning; tested). T-006 no longer depends on T-005 and uses the normal subtitle-file import. T-005 is now fullstack, depends on T-006, and owns the Embedded subtitles picker. Spec updated to match. T-010 unblocked: Brent chose to make the repo public
- Left: only T-007 is blocked (paid account). The orchestrator makes the repo public, after a secret scan and Brent's final confirmation, before T-010 is tested
- Files: .loop/specs/mkv-import.md, .loop/tasks/T-004, T-005, T-006, T-009, T-010, .loop/BOARD.md; issues #4, #5, #6, #9, #10 edited (+ comments on #4, #5, #6, #10)
- Gotchas: T-005's frontmatter title is quoted because it contains a colon; T-006 should shape EpisodeImporter so T-005 can add subtitle-extraction options without changing its callers much

## 2026-11-19 · loop-frontend · T-001 · round 1
- Done: landscape full-screen player with tap-to-show overlay controls, 3 s auto-hide, `player.back`, `player.video`; new PlayerLandscapeUITests
- Left: CI compile + UI tests (nothing compiled locally); T-002 fills the empty trailing slot in `topBar`
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckUITests/PlayerLandscapeUITests.swift, docs/DESIGN.md, docs/DEVELOPMENT.md
- Gotchas: overlay is kept in the hierarchy at opacity 0 (not removed) so Menus survive auto-hide; controls hidden = accessibilityHidden

## 2026-11-19 18:45 · loop-planner · T-012,T-004,T-006,T-005 · arch-review revision
- Done: resolved all 9 /architecture-review findings (review at 7f76886). Saved the review as .loop/specs/mkv-import.review.md with a "Resolved in" line per finding. Revised the spec (package FFmpegBuild 3.16.0, @concurrent core, timeline rule, allow-list, staging + launch sweep, idle timer, iCloud/space, LGPL in-app notices, 5 Homebrew-generated fixtures). Split T-004: new T-012 (#12, fullstack: package, CI fixtures, notices, About screen) comes before T-004 (converter, opus). T-006 and T-005 revised; issues #4, #5, #6 edited and commented
- Left: open question for Brent: app licence before the repo goes public (recommended MIT); blocks making the repo public, so T-010 testing. T-009 still needs a release-notes link to the FFmpegBuild source tag (its file was outside this revision's scope)
- Files: .loop/specs/mkv-import.md, .loop/specs/mkv-import.review.md, .loop/tasks/T-012 (new), T-004, T-005, T-006, .loop/BOARD.md
- Gotchas: SWIFT_APPROACHABLE_CONCURRENCY makes nonisolated async run on the caller's actor, so use @concurrent; OSAllocatedUnfairLock, not Atomic/Mutex (iOS 18); fixtures reach tests through TEST_RUNNER_CLIPDECK_FIXTURES and reach the app through launchEnvironment; T-012 must not touch the PlayerLandscape* UI tests (T-001 is in test)

## 2026-11-19 · orchestrator · T-009
- Done: added AC-7 (release notes link the FFmpegBuild source tag + THIRD_PARTY_NOTICES.md) from architecture review finding 8
- Left: Brent to choose the app licence before the repo goes public (gates T-010 testing)

## 2026-11-19 18:20 · loop-tester · T-001 · round 1
- Done: verified CI run 44635551739 (headSha 135af0e): ipa green, simulator red. `PlayerLandscapeUITests` fails at "Controls start hidden". Unit tests + MiningFlowUITests pass. Portrait screenshots are pixel-identical to main run 42740988540 except the clock
- Verdict: Fail. Must fix: overlay kept with opacity 0 + accessibilityHidden is still visible to XCUITest (even the always-hidden trailing spacer shows in the tree). Render it only while shown. Should fix: menu-open not in keepsControlsUp; portrait chip +8 pt; landscape chip/subtitle ignore horizontal safe area
- Files: ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift (new, uncommitted), ios/ClipDeckUITests/PlayerLandscapeUITests.swift (tearDown MainActor + screenshot before assert, uncommitted)
- Gotchas: the xcresult screen recording (.mp4) can be read on Windows with headless Chrome drawing frames to a canvas (no ffmpeg here). XCUITest ignores SwiftUI accessibilityHidden for existence queries in this setup

## 2026-11-19 · loop-frontend · T-001 · round 2
- Done: overlay now removed from the view tree when hidden (XCUITest fix); subtitles menu open keeps controls up; portrait chip padding restored; landscape chip and subtitle respect safe-area insets; icon-only Make a Card when the side list is open
- Left: CI run; nothing compiled locally
- Files: ios/ClipDeck/Features/Player/PlayerView.swift
- Gotchas: menu-open flag relies on a simultaneous tap gesture on the Menu; it clears on menu action, next video tap, or rotation

## 2026-11-19 19:00 · loop-planner · T-012,T-010 · licence + stereo decisions
- Done: Brent's licence (all rights reserved + LGPL-2.1 §6 clause) went into T-012 as AC-5: a plain-words root LICENSE flagged as not legal advice, bundled in the app. The IPA check (AC-6) and the About screen (AC-7) include it; docs are now AC-8. T-010 depends on T-009 and T-012: LICENSE first, then the secret scan, Brent's confirmation, and making the repo public. Spec and review record both decisions; stereo downmix is marked decided by Brent
- Left: T-009 still needs the release-notes FFmpegBuild source link (orchestrator's edit)
- Files: .loop/tasks/T-012, T-010, .loop/specs/mkv-import.md, .loop/specs/mkv-import.review.md, .loop/BOARD.md; issues #12, #10 edited, comments on #12, #10, #4
- Gotchas: T-012's AC numbers shifted (check script is now AC-6, About screen AC-7, docs AC-8); the review file references the new numbers

## 2026-11-19 18:45 · loop-tester · T-001 · round 2
- Done: verified CI run 44637588062 (headSha be4118f): ipa green, simulator red, 52/53 pass. All round-1 findings fixed; AC-7 test passes now and failed on round-1 code (revert evidence). Portrait screenshots identical to main except the clock
- Verdict: Fail. Should fix: when the episode plays to its end, PlayerModel.isPlaying stays true (only set in the periodic tick), so landscape controls never return and would auto-hide while stopped. Could fix: subtitleMenuOpen sticks if the menu is dismissed by tapping outside
- Files: ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift (uncommitted: new menu-open test; end-of-video asserts now follow AC-2 wording)
- Gotchas: in landscape, XCUITest app.screenshot() is rotated and cropped to the leftmost ~400 pt; use the failing test's screen recording. Headless Chrome renders one recording frame per run reliably (fresh --user-data-dir, --timeout=10000, no virtual-time-budget)

## 2026-11-19 · loop-frontend · T-001 · round 3
- Done: PlayerModel observes didPlayToEndTime so isPlaying turns false at the end of the video (controls return in landscape, button shows Play)
- Left: CI run; menu-dismissed-by-outside-tap still keeps controls up until next video tap (documented)
- Files: ios/ClipDeck/Features/Player/PlayerModel.swift
- Gotchas: nothing compiled locally; observer token removed in tearDown

## 2026-11-19 18:48 · loop-tester · T-001 · round 3
- Done: verified CI run 44639515011 (headSha 11ee5f0): ipa green, simulator red, 53/54 pass. End-of-video fix works (controls return on their own, Play shown, stay up). Portrait screenshots identical to main except the clock
- Verdict: Fail. Should fix: the subtitles menu's simultaneous TapGesture never fires on iOS 26, so while playing the controls auto-hide 3 s after play under the open menu, and the menu then closes (recording DC2CAA09….mp4, t=13.2–15.0 s). AC-2 menu-open case fails
- Files: ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift (uncommitted: menu appearance wait 2 s → 5 s; XCUITest snapshots lag during playback)
- Gotchas: Chrome --screenshot fires at page load, before a video seek finishes; extract recording frames over CDP instead (aiohttp + Runtime.evaluate returning canvas data URLs). Gestures attached to a SwiftUI Menu (and to the bar around it) don't fire on iOS 26

## 2026-11-19 · loop-frontend · T-001 · round 4 (opus)
- Done: landscape subtitles control is now a Button plus `confirmationDialog(isPresented:)`, and its presented state is counted in keepsControlsUp. Portrait keeps its original Menu. Removed the subtitleMenuOpen and TapGesture hacks and the bar restart gestures. The skip buttons call restartHideTimer() directly
- Left: CI run (nothing compiled locally)
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift (tester's 5 s wait kept, plus a dialog-closes assert), docs/DESIGN.md
- Gotchas: the dialog is attached to the landscape root, not inside the ViewThatFits rows or the removable overlay. Its actions are found with app.buttons[label]

## 2026-11-19 19:14 · loop-tester · T-001 · round 4
- Done: verified CI run 44642425777 (headSha 60e2fed). Attempt 1: ipa green, simulator 53/54 (ClipExtractorTests timed out in TestMediaFactory, a pre-existing flake). Attempt 2 (re-run of the failed job): 54/54, run-ios green. Portrait identical to main except the clock; the portrait Menu is textually identical to base
- Verdict: Blocked. The landscape dialog opens and survives the 3 s mark while playing (round-3 symptom gone), but the dialog sits on the root and the 6 s sample ends before the screenshot, so CI has not yet shown the controls staying up. No Must/Should fix found. Could fix: Make a Card no longer restarts the countdown
- Files: ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift (uncommitted: the menu test now watches player.back while the dialog is open; not run yet)
- Gotchas: XCUITest keeps screen recordings only for failing tests. The xcresult database.sqlite3 (Activities/TestCaseRuns tables) gives per-step timestamps and per-test results on Windows without xcresulttool

## 2026-11-19 19:23 · loop-tester · T-001 · round 4 addendum
- Done: verified CI run 44644572562 (headSha 4e13857, stricter menu test only). Both jobs green on the first attempt: 54/54 tests, run-ios passed
- Verdict: Pass. With the dialog open and the video playing, player.back stayed present at 825.7, 826.8 and 827.7 s, after the 3 s mark (~825.0) and before the sample ended (~828.0). No Must/Should fix. Could fix: Make a Card does not restart the countdown; the dialog's "Load different subtitles" has no test
- Files: .loop/tasks/T-001-landscape-fullscreen-player.md (Round 4 addendum)
- Gotchas: XCUITest can see the bar elements behind the landscape confirmationDialog

## 2026-11-19 · orchestrator · T-001 · landed
- Done: T-001 passed in round 4 (Opus builder, an extra round Brent approved). Squashed to ab238b4 on loop/mkv-landscape-sideload. CI 44644572562 green (54/54).
- Left: T-002 next. The T-001 Could fix (Make a Card doesn't restart the hide timer, plus a test for "Load different subtitles") was moved into T-002's Agent notes.
- Gotchas: CI only runs on this branch through `gh workflow run`. ClipExtractorTests.cutsExactAudioAndScreenshot can time out on CI (pre-existing); re-run once. XCUITest landscape screenshots come out rotated and cropped; use the xcresult and the screen recording.
