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

## 2026-11-19 · loop-frontend · T-002 · round 1 (sonnet)
- Done: landscape subtitle panel (75/25 split from one constant, min 180 pt), `player.panelToggle` in the top bar, `player.sidePanel`, `player.panel.makeCard`; Make a Card holds the controls up while recording; "Show subtitle list" removed from the menus; UI tests added/updated
- Left: CI run (nothing compiled locally)
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckUITests/PlayerLandscapeUITests.swift, ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift, docs/DESIGN.md, docs/DEVELOPMENT.md
- Gotchas: landscape layout now ignores the safe area as a whole and bars/panel pad by the insets themselves

## 2026-11-19 19:50 · loop-tester · T-002 · round 1
- Done: verified CI run 44646676783 (headSha afb033a): ipa green, simulator red, 55/56. The AC-6 panel test passes (25 %/75 % widths, cue tap, panel Make a Card opens the editor). All T-001 landscape tests and MiningFlowUITests pass
- Verdict: Fail. Must fix: the new "Load different subtitles" test asserts `app.buttons["Show subtitle list"]` doesn't exist, but that query matches the panel toggle's label behind the dialog (fix applied in the test file, not run). Should fix: the trailing safe-area padding leaves ~156 pt in the panel, so the cue text column is ~48 pt (traced, not measured)
- Files: ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift (uncommitted: assert fix + new AC-3 and AC-4 tests)
- Gotchas: XCUITest subscript matches labels too, so with two buttons sharing a label, scope by identifier. In this run the landscape screenshots still come out rotated and cropped

## 2026-11-19 · loop-frontend · T-002 · round 2 (sonnet)
- Done: panel content width = max(25% of usable width, 180) plus the trailing inset on top; compact cue rows (time above text) only in the panel; Make a Card in a ViewThatFits with an icon-only fallback; width test now uses observed frames; card screenshot after card.save. Tester's test edits kept
- Left: CI run (nothing compiled locally)
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckUITests/PlayerLandscapeUITests.swift, docs/DESIGN.md
- Gotchas: Swift files here use CRLF; edit with newline preserved

## 2026-11-19 19:52 · loop-tester · T-002 · round 2
- Done: verified CI run 44648208663 (headSha e615c89). The ipa job is green. The simulator job passed 57 of 58; the one failure is the known ClipExtractorTests timeout flake, and the permission system denied the re-run. All 12 UI tests pass, including the round-1 AC-3/AC-4 tests and the fixed dialog test. Portrait screenshots match main 42740988540 except the clock
- Verdict: Blocked (verify-only). No Must or Should fix. The implementer's width asserts would also pass with the wrong rule. The tester tightened testSubtitlePanelOpensOnTheRight: it now asserts the exact rule max(25 % usable, 180) + inset, checks that cue.row.1 is ≥ 144 pt, and attaches frames plus debugDescription
- Files: ios/ClipDeckUITests/PlayerLandscapeUITests.swift (uncommitted, not run yet)
- Gotchas: this xcresult has no UI hierarchy. Frames only come out when a test attaches them (XCTAttachment(string: app.debugDescription)). The landscape app.screenshot() is still rotated and cropped

## 2026-11-19 21:12 · loop-tester · T-002 · round 2 addendum
- Done: verified CI run 44658198733 (headSha 9455f7f, the tightened test only). Both jobs green on the first attempt, 58/58. Measured frames: panel 249.3 pt (expected 249.5 = 187.5 + 62 inset), video 624.7 pt (71.5 %), cue row content 187.3 pt, so the text column is 163.3 pt (round 1: about 48). The panel's Make a Card shows its full label
- Verdict: Pass. No Must or Should fix. Unverified for Brent: how the split feels and how long real lines read on his iPhone
- Files: .loop/tasks/T-002-landscape-subtitle-panel.md (Round 2 addendum)
- Gotchas: XCUIElement.screenshot() on the panel gives a correct, unrotated landscape crop, unlike app.screenshot(). An XCTAttachment(string: app.debugDescription) gives every element's frame in the xcresult, and test-ios.sh exports it as .txt

## 2026-11-19 · orchestrator · T-002 · landed
- Done: T-002 passed after round 2 plus a verify-only pass. Squashed to dbe6201. CI 44658198733 green (58/58).
- Left: T-011 (resizable divider) is next on the landscape chain; its Agent notes carry Brent's usable-width rule.
- Gotchas: the round-1 builder's session ended mid-task; a fresh builder resumed from the task file without trouble. The tester can't run `gh run rerun` (permission denied), so the orchestrator asks Brent before any re-run.

## 2026-11-19 · loop-frontend · T-011 · round 1 (sonnet)
- Done: draggable divider handle (`player.panelHandle`, 44 pt, own DragGesture) resizing the landscape panel between 180 pt and 50 % of the usable width; fraction stored with @AppStorage (default 0.25), saved on drag end; double-tap/VoiceOver reset; drag holds the controls up
- Left: CI run (nothing compiled locally); the UI test `testPanelHandleResizesRemembersAndResets` is the first real check that press-and-drag drives the handle
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckUITests/PlayerLandscapeUITests.swift, docs/DESIGN.md, docs/DEVELOPMENT.md
- Gotchas: the test leaves the stored width at the default; UserDefaults survive between UI-test launches

## 2026-11-19 21:25 · loop-tester · T-011 · round 1
- Done: checked CI run 44660105956 (headSha 11b22d7). ipa green; simulator red because the UI test target doesn't compile (raw newlines in a string literal, PlayerLandscapeUITests.swift:229-231), so 0 tests ran. The drag, relaunch, reset and T-002 regressions are all unproven
- Verdict: Fail. Must fix: compile error (tester fixed it in the working tree, not run). Should fix: the handle's 44 pt hit area covers the panel's leading 32 pt for its full height, so taps there don't reach cue rows or Make a Card, and list scrolls that start there resize the panel instead. Could fix: a cancelled drag leaves the live state set (use @GestureState); a handle-test failure cascades into the T-002 width test
- Files: ios/ClipDeckUITests/PlayerLandscapeUITests.swift (uncommitted: compile fix, AC-5 label/value asserts, far-left 50 % max assert)
- Gotchas: an empty screenshots manifest plus TestCaseRuns = 0 in the xcresult means the test build failed. Read --log-failed before looking for attachments

## 2026-11-19 · loop-frontend · T-011 · round 2 (sonnet)
- Done: kept tester's compile fix and AC-5/AC-2 asserts; handle hit area moved 32 pt over the video (bars get 32 pt trailing padding while the panel is open); drag is @GestureState-based, minimumDistance 8, horizontal only; -uiTesting launches reset player.panelFraction unless -uiTestingKeepPanelWidth; new test for a cue-row tap 16 pt from the edge
- Left: CI run (nothing compiled locally)
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeck/App/ClipDeckApp.swift, ios/ClipDeckUITests/PlayerLandscapeUITests.swift
- Gotchas: GestureState needs `= nil` for an optional; the resize test's relaunch passes -uiTestingKeepPanelWidth

## 2026-11-19 22:05 · loop-tester · T-011 · round 2
- Done: verified CI run 44661143691 (headSha c0da745). ipa green; simulator 59/60. All round-1 findings are fixed. press(forDuration:thenDragTo:) drives the handle live on iOS 26.5 (recording: the edge moves 625 → 584 → 520 → 507). +120 pt gives content 307.3 pt (expected 307.5). The toggle and the bar's Make a Card are 12 pt clear of the handle. T-002's exact width holds (249.33 vs 249.5) even after the failed test left 0.41 stored, which proves the -uiTesting reset
- Verdict: Fail. Should fix: the grip capsule moved with the hit area and now sits 10 pt left of the panel edge, over the video, in a dark 35 % ink (AC-1). The handle test failed at the relaunch because of a test defect: when the player opens already in landscape the controls start up, and tapVideo hid them. The tester fixed this in the test file. Persistence, the 180/50 % limits and the reset are still unshown
- Files: ios/ClipDeckUITests/PlayerLandscapeUITests.swift (uncommitted: conditional tapVideo in launchWithPanelOpen; bar-clearance asserts plus landscape-05-panel-max attachments at 50 %)
- Gotchas: frames from the XCUITest recording work through headless Chrome CDP if Chrome opens the .mp4 URL directly (a file:// video from about:blank fails to load). The pre-existing T-001 behaviour: opening the player in landscape shows controls; rotating in hides them

## 2026-11-19 · loop-frontend · T-011 · round 3 (sonnet)
- Done: grip moved back onto the panel's leading edge (white capsule, dark outline + shadow); drag direction decided once per drag (origin + latch) so a resize is always saved; single tap on the handle toggles the controls (double-tap still resets)
- Left: CI run (nothing compiled locally)
- Files: ios/ClipDeck/Features/Player/PlayerView.swift
- Gotchas: handle stays one accessibility element, so no separate grip identifier; tester's test edits kept

## 2026-11-19 22:22 · loop-tester · T-011 · round 3
- Done: checked CI run 44665692227 (headSha 639a612). ipa green; simulator 59/60. Grip centre at 504.33 vs panel.minX 504.67 (recording frame). Width survives the relaunch (±4). The 180 pt minimum and 50 % maximum asserts pass. All three drags work with the new .onChanged. The round-2 relaunch fix works
- Verdict: Fail. Must fix: at the 50 % maximum the icon-only bottom row needs 464.3 pt (because of the 32 pt handle clearance) but the video column is 437.7 pt. The ZStack overflows, so the video and bars shift 13.67 pt left and the picture is cropped about 13.7 pt per side (PlayerLandscapeUITests.swift:187, video minX −13.67). This starts above about 46 % on this device. Could fix: the live and save drag latches disagree; the single tap on the handle has no test. AC-4's reset from a non-default width is still unshown
- Files: .loop/tasks/T-011-resizable-landscape-panel.md (Test report round 3); no test edits
- Gotchas: video crop can be measured from recording frames: picture height × 16/9 against the column width. A ZStack with one overflowing child (a bar) re-centres every layer, including the video

## 2026-11-19 23:04 · loop-frontend · T-011 · round 4 (opus)
- Done: the bars are now an overlay on the fixed-width video (leading-aligned, clipped), so they can never widen or shift the column. The bottom row has a third ViewThatFits option without the ±5 s skips (about 242 pt; the row gets about 320 pt at 50 %). A single drag latch (decided in onChanged) drives both the live resize and the save. New tests: a single tap on the handle toggles the controls, and controls start hidden when the player opens in landscape. Controls show on a real pause only (true → false), so landscape always starts hidden
- Left: CI run (nothing compiled locally)
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckUITests/PlayerLandscapeUITests.swift, docs/DESIGN.md
- Gotchas: launchWithPanelOpen now asserts the controls are hidden for 2 s and then always taps. An overlay sized by its base view can't resize that view, unlike a ZStack sibling

## 2026-11-19 23:16 · loop-tester · T-011 · round 4
- Done: verified CI 44672073767 (headSha 35dba5d). Both jobs green, 62/62, run-ios green. At 50 %: video {0,0,437,402} (the full column), back minX 74 (inset + 12), toggle and Make a Card maxX 393 vs handle 405, no ±5 s skips (still present at 41 %). The reset from 50 % runs and passes. The new single-tap and starts-hidden tests pass. A real pause (clip end) still brings the controls back with no tap
- Verdict: Pass. No Must or Should fix. Could fix: assert that the skips are gone at the max; attach a player.video element screenshot. T-001 AC-2's "stay visible while paused" should be reworded to "once shown …; entering landscape starts hidden"
- Files: .loop/tasks/T-011-resizable-landscape-panel.md (Test report round 4); no test edits
- Gotchas: all-green runs keep no screen recordings. Use the -frames attachments and the Activities timestamps

## 2026-11-19 · orchestrator · T-011 · landed
- Done: T-011 passed in round 4 (an extra round on Opus that Brent approved). Squashed to 3f38205. CI 44672073767 green (62/62). The landscape chain T-001 → T-002 → T-011 is complete.
- Left: open Could fix items for a future test pass: assert the skips are gone and video width = window − panel at the maximum; attach a player.video element screenshot.
- Gotchas: new rule (Brent): after any failed Sonnet round, ask him whether to retry on Sonnet or switch to Opus (models.ask_on_sonnet_fail).

## 2026-11-19 · loop-backend · T-012 · round 1 (sonnet)
- Done: FFmpegBuild 3.16.0 pinned in project.yml; make-test-media.sh (5 fixtures); test-ios.sh exports TEST_RUNNER_CLIPDECK_FIXTURES; CI installs ffmpeg; FFmpegInspector + FFmpegFixtureTests; LICENSE, THIRD_PARTY_NOTICES.md and bundled `Licenses/*.txt`; check-ipa-notices.sh in the ipa job; docs
- Left: CI run (nothing compiled); frontend builds the About screen (AC-7) from the `Licenses/` resources (contract in the task file)
- Files: ios/project.yml, scripts/{make-test-media,check-ipa-notices,test-ios,bootstrap}.sh, .github/workflows/ios-simulator.yml, ios/ClipDeck/Services/Media/FFmpegInspector.swift, ios/ClipDeckTests/FFmpegFixtureTests.swift, ios/ClipDeck/Resources/Licenses/, LICENSE, THIRD_PARTY_NOTICES.md, docs
- Gotchas: avcodec/avformat load AetherLibdav1d and AetherLibzvbi at launch, so six products are linked, not four; the binaries are committed in the package git repo (no checksums); only the native `aac` encoder exists (no aac_at)

## 2026-11-19 · loop-frontend · T-012 · round 1 (sonnet)
- Done: About and licences screen (`settings.about` row, `AboutView`, `LicenceText` loader with "Licence text missing" fallback), AboutUITests (`about-01-licences`), DESIGN.md row
- Left: CI run (nothing compiled)
- Files: ios/ClipDeck/Features/Settings/{AboutView,LicenceText,AnkiSettingsView}.swift, ios/ClipDeckUITests/AboutUITests.swift, docs/DESIGN.md
- Gotchas: row lives in the Anki settings sheet; XCUI may expose the 26 KB LGPL label oddly

## 2026-11-19 23:45 · loop-tester · T-012 · round 1
- Done: verified CI 44674913642 (headSha 4ba67bc). Both jobs green; 69/69 tests, including the 6 FFmpegFixtureTests and AboutUITests. All 5 fixtures were generated in CI (brew ffmpeg 9.0.2). The IPA holds the 6 frameworks plus Licenses/ (451,955 → 4,618,295 B). The notice check works in CI and against 7 synthetic IPAs. LICENSE wording matches Brent's choice. The LGPL text is identical to FFmpeg's
- Verdict: Fail. Should fix: DEVELOPMENT.md lacks CLIPDECK_FIXTURES and the ffmpeg prerequisite (AC-8; still says "no environment variables"). The notices have no FFmpeg/libzvbi copyright line (LGPL-2.1 §6; FFmpeg's is "Copyright (c) 2000-2026 the FFmpeg developers"). Could fix: deprecation warning FFmpegInspector.swift:112; pre-existing Info.plist says 1.0, not MARKETING_VERSION 0.1.0
- Files: ios/ClipDeckUITests/AboutUITests.swift (new testSourceLinksAreShownAndOpenInSafari), ios/ClipDeckTests/FFmpegFixtureTests.swift (fixture-3 audio 1.5 ±0.05 s): uncommitted, not run yet
- Gotchas: the about-01 test's `app.links[...]` scroll has no assert and ended at the list top, so links in a List may not be `links`; the new test queries descendants(.any) by identifier. Swift Testing passes record no measured values, so use tight bounds

## 2026-11-19 · loop-backend · T-012 · round 2 (opus)
- Done: all 4 round-1 findings. DEVELOPMENT.md: ffmpeg test prerequisite, env-var table (SIM_NAME, CLIPDECK_FIXTURES, TEST_RUNNER_CLIPDECK_FIXTURES), Fixtures paragraph. Copyright lines verified upstream: FFmpeg "2000-2026 the FFmpeg developers", dav1d 1.5.4 "2018-2025, VideoLAN and dav1d authors" (was 2018-2019), libzvbi v0.2.46 src/* holders + FFmpegBuild stub. FFmpegInspector deprecation fixed; Info.plist now uses MARKETING_VERSION / CURRENT_PROJECT_VERSION
- Left: CI run (nothing compiled); tester's link/Safari test and fixture-3 bounds run for the first time
- Files: docs/DEVELOPMENT.md, THIRD_PARTY_NOTICES.md, ios/ClipDeck/Resources/Licenses/{FFmpeg-NOTICE,Other-Components}.txt, ios/ClipDeck/Services/Media/FFmpegInspector.swift, ios/project.yml
- Gotchas: SIMCTL_CHILD_CLIPDECK_FIXTURES not documented (no code reads it in the app). FFmpegBuild's dav1d licence copy has an outdated year

## 2026-11-20 00:08 · loop-tester · T-012 · round 2
- Done: all 4 round-1 findings verified fixed. Copyright strings checked upstream (FFmpeg 2000-2026; dav1d 2018-2025 diff-identical; zvbi src/* + DVB + ure.c match). The cString warning is gone from both jobs. The IPA Info.plist says 0.1.0/1; check-ipa-notices passed. The tests passed in 44677264701 (UI launches 18 to 19, so the links/Safari test ran)
- Verdict: Blocked (verify-only). The simulator job went red only because the artifact upload hit a GitHub timeout, so there are no screenshots/xcresult. On-screen 0.1.0 and ©/ñ/í were not observable
- Files: ios/ClipDeckUITests/AboutUITests.swift (+testAboutShowsVersionAndNoticeTextIntact), ios/ClipDeckTests/FFmpegFixtureTests.swift (+missingFileErrorCarriesFFmpegMessage): uncommitted, not run
- Gotchas: a failed upload-artifact step makes the job red even when the tests pass; check the step list before reading it as a test failure

## 2026-11-20 00:25 · loop-tester · T-012 · round 2 addendum
- Done: read CI 44679269822 (ac3ba1a). The product is right on every point. About shows "Clip Deck, 0.1.0" (tree + screenshot). The links open Safari (about-02/03/04). The FFmpeg copyright line is shown. The Other-Components label is byte-identical to the UTF-8 file (©/ñ/í intact). describe() returns "No such file or directory". The fixture-3 bounds pass
- Verdict: Blocked (verify-only again). My new About test failed on two test defects: the LabeledContent label is the combined "Clip Deck, 0.1.0", and the element screenshot of the tall Text fails to render. The known ClipExtractor timeout flake also hit
- Files: ios/ClipDeckUITests/AboutUITests.swift (fixed predicate; app.screenshot instead of the element screenshot): uncommitted, not run
- Gotchas: on iOS 26 a LabeledContent row in a List is one StaticText labelled "<title>, <value>"; XCUIElement.screenshot() of a very tall Text fails ("Rendering screen failed"). xcresult attachments are plain PNG/text files in Data/data.<payloadRefId>

## 2026-11-20 00:39 · loop-tester · T-012 · round 2 addendum 2
- Done: CI 44681060076 (cb9c452) fully green: 72/72 tests, 0 issues, including the fixed About version/notice test, the links/Safari test, the describe() message test and the fixture-3 bounds. The ClipExtractor flake passed. The about-06 screenshot shows the © rendered correctly; check-ipa-notices passed
- Verdict: Pass. All ACs proven; no Must/Should fix open. Could fix: THIRD_PARTY_NOTICES.md ure.* copyright cell lists only CRL
- Files: none changed in this pass (the test fix was committed by the orchestrator in cb9c452)
- Left for Brent: Sideloadly install with the six frameworks; About at large Dynamic Type and dark mode

## 2026-11-20 · orchestrator · T-012 · landed
- Done: T-012 passed (round 2 on Opus + 2 verify-only passes). Squashed to 1489506. CI 44681060076 green (72/72). The FFmpeg libraries, CI fixtures, LICENSE and About screen are in.
- Left: T-004 (converter, model: opus) is next. Could fix: THIRD_PARTY_NOTICES.md libzvbi ure.* cell should also list Iñaki García Etxebarrria and Michael H. Schimek.
- Gotchas: Brent's backup fork bman7222/FFmpegBuild exists (tag 3.16.0 = 7de456f). The app still uses upstream. iOS 26 merges a row's label and value into one StaticText ("Clip Deck, 0.1.0"). XCUIElement.screenshot() of a very tall Text fails with "Rendering screen failed".

## 2026-11-20 02:31 · loop-backend · T-004 · round 1 (opus)
- Done: MediaProber/MediaProbe (AC-1); pure ConversionPlan with typed UnsupportedMediaError (AC-2); MediaConverter.convert (AC-3/AC-4): Task.detached sync core, an OSAllocatedUnfairLock cancel flag read by AVIOInterruptCB and the packet loop, throttled progress, edit lists, the remux.c pattern, hvc1, AAC-LC stereo transcode via swresample and an audio FIFO. ARCHITECTURE concurrency and timeline rules (AC-8). Pure plan/helper tests plus fixture tests: playable, tracks, duration, edit lists, hvc1, ClipExtractor, colour/beep sync, off-main, heartbeat, cancel
- Left: CI run (nothing compiled). T-006 builds EpisodeImporter on the contract in the task notes
- Files: ios/ClipDeck/Services/Media/{FFmpegSupport,MediaProbe,ConversionPlan,MediaConverter}.swift, ios/ClipDeckTests/{ConversionPlanTests,MediaConverterTests}.swift, docs/ARCHITECTURE.md
- Gotchas: these FFmpeg 8 headers have no avcodec_profile_name (use av_get_profile_name). The DOVI config is in codecpar->coded_side_data. The mp4 muxer has AVFMT_TS_NEGATIVE, so timestamps are kept and movenc writes the edit lists. mux.c rejects unset or non-increasing DTS (hence TimestampFixer). The tests take a fixture's "second 0" from the probe's video start

## 2026-11-20 02:50 · loop-tester · T-004 · round 1
- Done: read CI 44695949361 (1ecf97a). The ipa job is green: all 4 new Media files compiled for the device. The app target also compiled clean for the simulator (0 errors, 0 new warnings). The test target failed on 1 error, so 0 tests ran
- Verdict: Fail. Must fix: MediaConverterTests.swift:82 `allSatisfy(\.isText)` inside #expect ("call can throw, but it is not marked with 'try'"). Should fix: trapping Int64 `+` in TimestampFixer and nextAudioPTS (MediaConverter.swift:122,131-132,140,609) lets a malformed MKV crash the app. Should fix: ARCHITECTURE.md lost its `## Decisions` heading. Could fix: an audio decode error aborts the import; the probe can't be cancelled
- Files: ios/ClipDeckTests/MediaConverterTests.swift:82 (tester's fix `allSatisfy { $0.isText }`, uncommitted), .loop/tasks/T-004-mkv-converter.md (Test report round 1)
- Gotchas: a key-path argument inside #expect(x.allSatisfy(\.k)) doesn't compile; use a trailing closure. Removing `use_editlist` is not a useful mutation (movenc already defaults to 1); use `use_editlist=0`. xcresult Data/ files are zstd: `zstd -d` them, then grep the build log

## 2026-11-20 · loop-backend · T-004 · round 2 (opus)
- Done: all 5 round-1 findings.
  - Kept the tester's line-82 test fix.
  - TimestampFixer rejects |ts| > 2^60 as `.damagedFile`, finds the median by comparison and uses `&+`; the audio anchor is bounded too. Overflow tests cover .max/.min twice in a row.
  - `## Decisions` heading restored.
  - Audio decode errors are skipped like ffmpeg (DecodeErrorBudget: give up past 50 errors that are also over 10 % of packets) and reported in `Report.warnings`.
  - MediaProber.load is cancellable (shared `ConversionCancelFlag.interruptCallback()`), with 2 tests.
- Left: CI run (nothing compiled)
- Files: ios/ClipDeck/Services/Media/{MediaConverter,MediaProbe}.swift, ios/ClipDeckTests/{ConversionPlanTests,MediaConverterTests}.swift, docs/ARCHITECTURE.md
- Gotchas: the rebase mutation is `use_editlist=0`, not leaving the option out (movenc's default is already 1). Keep `#expect` free of top-level calls with key-path arguments, and of `inout` or mutating calls.

## 2026-11-20 03:25 · loop-tester · T-004 · round 2
- Done: read CI 44698930097 (60857c0, scope=tests). The simulator job is green: 144/144 test runs Success, 0 issues, 0 skips. Every T-004 test ran, including convertsToAPlayableMP4 × 4, both sync tests, the fixture-3 edit lists, the heartbeat, cancel, the overflow tests and probe cancel. All 5 round-1 findings are fixed
- Verdict: Pass. No Must or Should fix. Could fix: 3 test warnings ("conditional cast always succeeds", ConversionPlanTests.swift:39/216/345); no test isolates the AVIOInterruptCB (aSetCancelFlagStopsTheProbe also passes via the post-check at MediaProbe.swift:359); passing runs record no measured values
- Files: .loop/tasks/T-004-mkv-converter.md (Test report round 2); no test edits
- Gotchas: the xcresult has a `database.sqlite3`. Query TestCaseRuns/TestCases/TestIssues/Arguments with Python's sqlite3 to list every test and its arguments on Windows. Swift Testing passes keep no values, but per-test durations give upper bounds (the cancel test took 0.012 s in total)

## 2026-11-20 · orchestrator · T-004 · landed
- Done: T-004 passed in round 2 (Opus). Squashed to a2483ee. CI 44698930097 (scope=tests, 144/144) + 44702732605 (scope=ipa) green. The repo went public today, and the loop now runs in ci.mode: conservative.
- Left: T-006 (upload flow, fullstack, model: opus) is next. Could fix: remove the redundant `as?` casts at ConversionPlanTests :39/:216/:345; add a test proving the interrupt callback fires (ConversionCore.run with the flag already set); record measured values with Attachment.record so green runs keep them.
- Gotchas: deviations kept by default (Brent can override): H.264 yuvj420p allowed; an MKV with no audio converts video-only with a .noAudioTrack warning.

## 2026-11-20 03:48 · loop-backend · T-006 · round 1 (opus, backend half)
- Done: `EpisodeImporter`. Prepare: extension, iCloud start + a coordinated read held by `SourceAccess`, free space ≥ size + max(10 %, 200 MB), probe + default plan. Import/relink: stage in tmp/Converting/<uuid>, convert or copy, move with uniquePath, insert + save, roll back moved files/folders/models on failure. Launch sweep in ClipDeckApp; `-uiTesting -uiTestingMKV` seeds fixture 4 through the real importer; 20 unit tests; ARCHITECTURE "Importing episodes"; flag docs in CLAUDE.md/DEVELOPMENT.md
- Left: the frontend wires UploadEpisodeView and MissingFileView to the CONTRACT in the task file (pickers, audio picker, progress/Cancel, idle timer, background task), writes the MKV UI test and the rest of the AC-8 docs. Nothing compiled yet (CI only)
- Files: ios/ClipDeck/Services/{EpisodeImporter,SourceAccess}.swift, ios/ClipDeck/App/{ClipDeckApp,RootView}.swift, ios/ClipDeckTests/EpisodeImporterTests.swift, docs/ARCHITECTURE.md, docs/DEVELOPMENT.md, CLAUDE.md
- Gotchas: progress is a `@MainActor (Double) -> Void`; to cancel, cancel the task (CancellationError, nothing added, PreparedVideo stays open for a retry); call `prepared.close()` when the user picks another file. Tests hold a conversion with `EpisodeImporter.onConversionProgress` + `ConverterGate`

## 2026-11-20 09:06 · loop-frontend · T-006 · round 1 (opus, frontend half)
- Done: added `VideoImportModel`. It prepares the picked file in a kept task, holds the audio choice and checks its plan, and runs the import with the idle timer off, a background task and the J-5 expiry message. Added `ImportProgressView`. UploadEpisodeView and MissingFileView now go through `EpisodeImporter`: pickers use `[.movie, .item]`, with `upload.audioTrack`, `upload.preparing` and `upload.progress`/`upload.cancelConvert` (and the matching `missing.*` identifiers). Added MKVImportUITests (`mkv-01-player`, `mkv-02-card`) and updated DESIGN, PRODUCT_SPEC, README and DEVELOPMENT
- Left: CI run (nothing compiled)
- Files: ios/ClipDeck/Features/Library/{VideoImportModel,ImportProgressView,UploadEpisodeView,SubtitleBrowserView,LibraryView}.swift, ios/ClipDeck/Services/FileStore.swift (removed the unused videoExtensions), ios/ClipDeckUITests/MKVImportUITests.swift, docs/{DESIGN,PRODUCT_SPEC,DEVELOPMENT}.md, README.md
- Gotchas: a relink starts by itself once prepare is ready (default audio track). Import warnings show in an alert before the sheet closes. A refused pick replaces the previous file

## 2026-11-20 09:35 · loop-tester · T-006 · round 1
- Done: read CI 44750491956 (b0e466c, scope=all). ipa job green: everything compiles, with no new warnings. 162/165 test runs passed, including all 19 EpisodeImporterTests, both MKVImportUITests (mkv-01/mkv-02 look right), MiningFlowUITests and LaunchUITests. Reviewed the diff (paths, security scope, continuations, docs): no Must or Should fix
- Verdict: Blocked (verify-only). 3 UI tests the diff doesn't touch failed on taps/timing: AboutUITests/testAboutShowsVersionAndNoticeTextIntact, and in PlayerLandscapeBehaviourUITests ControlsStay… and OpenSubtitlesMenu…. All three passed in 44698930097. I added model tests for AC-3 to AC-6, which need one run
- Files: ios/ClipDeckTests/VideoImportModelTests.swift (new, 7 tests, not run yet), .loop/tasks/T-006-mkv-upload-flow.md (Test report round 1)
- Gotchas: those UI flakes aren't in Learned yet. No fixture has 2+ audio tracks, so the upload.audioTrack picker has never been rendered. Every mutation check costs a dispatch in conservative mode, so none were run

## 2026-11-20 10:02 · loop-tester · T-006 · round 1 addendum
- Done: read CI 44755434228 (41bf53a, scope=tests): simulator green, 172/172 Success, 0 issues. All 7 VideoImportModelTests passed (extension, picker types, space → Add disabled, idle timer on/restored, cancel/failure add nothing, relink via the model), which closes the model-level parts of AC-3 to AC-6
- Verdict: Pass. No Must or Should fix. Could fix: the coordinated read is held while the sheet sits idle; the ErrorBanner "Try again" may not be a separate VoiceOver button
- Files: .loop/tasks/T-006-mkv-upload-flow.md (Round 1 addendum); no test edits in this pass
- Gotchas (Learned candidates): AboutUITests/testAboutShowsVersionAndNoticeTextIntact and PlayerLandscapeBehaviourUITests testControlsStayWhilePausedAndAutoHideWhilePlaying / testOpenSubtitlesMenuKeepsControlsUpWhilePlaying failed once on taps/timing (44750491956) and passed on the re-run with no code change, so they're flaky

## 2026-11-20 · orchestrator · T-006 · landed
- Done: T-006 passed (1 round on Opus + 1 verify-only pass). Squashed to 428e97c. MKV import works end to end in CI: pick, convert, play, make a card.
- Left: T-005 (optional built-in subtitles) is held until last, as the spec says. Next in auto mode: T-003 (SideStore guide), then T-009, T-010, T-008. Could fix: the coordinated read is held while the sheet sits idle (check on a device); ErrorBanner hides "Try again" from VoiceOver as its own button.

## 2026-11-20 · loop-backend · T-003 · round 1 (sonnet)
- Done: wrote docs/INSTALL_ON_IPHONE.md (iloader + LocalDevVPN + SideStore, daily Shortcuts automation with LocalDevVPN "Enable" then SideStore "Refresh All Apps", expiry/data rules, limits, update-in-place) and pointers in README, DEVELOPMENT, ARCHITECTURE
- Left: tester checks the links; Brent confirms the unconfirmed labels listed at the end of the guide
- Files: docs/INSTALL_ON_IPHONE.md, README.md, docs/DEVELOPMENT.md, docs/ARCHITECTURE.md, .loop/tasks/T-003-install-past-7-days-guide.md
- Gotchas: docs-only, no CI needed. Facts sourced from SideStore-Docs @7e441d3, SideStore @4f3d18d, LocalDevVPN @17740a2 (see task notes)

## 2026-11-20 10:11 · loop-tester · T-003 · round 1
- Done: checked docs/INSTALL_ON_IPHONE.md against AC-1..AC-8 and the sources at the cited SHAs. All links return 200, and only doc files changed. The iloader, LocalDevVPN, trust, Developer Mode, "7 DAYS" and pairing-file steps match the docs
- Verdict: Fail. Must fix:
  1. The Shortcuts steps at :51-56 don't match Apple's guide. On iOS 27 you add the trigger via Edit > Automation and allow unattended runs via Privacy > Allow Running When Locked. On iOS 17-26, Run Immediately comes before Next.
  2. SideStore adds the team ID to the bundle ID by default (OperationContexts.swift:291). A Sideloadly copy is never refreshed, and the SideStore copy starts empty. README:87 invites that path.
- Should fix: :45 says nothing (Refresh All includes SideStore); the latest green run at :35 has no ClipDeck-ipa; recovery at :65 stops at the reinstall; the computer warning isn't prominent; T-010 isn't mentioned; the Refresh, Missed and Updating sections have no doc links
- Files: .loop/tasks/T-003-install-past-7-days-guide.md (Test report round 1); no test files
- Gotchas: "Refresh All" is confirmed in MyAppsViewController.swift:1980. The source tarballs are in %LOCALAPPDATA%\Temp\clip-deck-loop\T-003-r1. Python's `-I` flag ignores PYTHONIOENCODING, so call sys.stdout.reconfigure(encoding='utf-8')

## 2026-11-20 10:27 · loop-backend · T-003 · round 2 (opus)
- Done: rewrote docs/INSTALL_ON_IPHONE.md.
  - Shortcuts steps split into iOS 17-26 and iOS 27 from Apple's guide (Allow Running When Locked, optional Wait).
  - SideStore bundle ID is `dev.brent.clipdeck.<team ID>`, so the Sideloadly copy is separate. New "Moving from Sideloadly to SideStore" section; the app has no library export/import.
  - Added the SideStore-expired recovery path and a bold warning near the top.
  - README now recommends SideStore with Sideloadly as the alternative, and lists the guide under Documentation. Updated DEVELOPMENT (new "two icons" row) and ARCHITECTURE.
- Left: Brent's confirm list (Shortcuts labels on his iOS, overnight run while locked, one copy or two). Recommend a follow-up task "Export and import the library".
- Files: docs/INSTALL_ON_IPHONE.md, README.md, docs/DEVELOPMENT.md, docs/ARCHITECTURE.md, .loop/tasks/T-003-install-past-7-days-guide.md
- Gotchas: iloader's "Install SideStore (Stable)" installs `releases/latest` = 0.7.0-alpha, not develop. Code facts were checked at 4f3d18d, 0.7.0-alpha and 0.6.3. Apple's iOS 26 guide says "Ask Before Running › Don't Ask", not "Run Immediately".

## 2026-11-20 10:36 · loop-tester · T-003 · round 2
- Done: every round-1 finding (2 Must, 6 Should, all Could) is fixed, with evidence. I re-checked:
  - Apple's iOS 26 and iOS 27 Shortcuts pages, fetched today: they match :62-80.
  - SideStore 0.7.0-alpha (`releases/latest`, the one iloader Stable installs; sideload.rs:126-130) and 4f3d18d: team-ID suffix, Refresh All includes SideStore last, the + button, .ipa share-in.
  - Links: 16/16 return 200. Anchors: 15/15 resolve. Only docs changed.
- Verdict: Fail.
  - Must fix: the Moving section says the Sideloadly copy "still expires 7 days after" its install. iloader ("Maximum certificates reached … will revoke your existing certificates", en.json:78-79) and SideStore (free account = 1 cert, CodeSignValidator.swift:19) say setup can revoke Sideloadly's certificate, so that copy stops opening right away. Sync cards and write the list before setup step 1.
  - Should fix: warn that an iOS update can break the pairing file while Brent is away (install.mdx), and handle the case where only one Clip Deck icon appears in the Moving steps.
- Files: .loop/tasks/T-003-install-past-7-days-guide.md (Test report round 2); no test files
- Gotchas: the 0.7.0-alpha tag object is 193ae6e and its commit is 6032424. The tarball and the iloader files are in %LOCALAPPDATA%\Temp\clip-deck-loop\T-003-r2-test

## 2026-11-20 10:55 · loop-backend · T-003 · round 3 (opus)
- Done: rewrote "Moving from Sideloadly to SideStore" short.
  - Sync until "Everything is in Anki." before setup step 1, and expect the old copy to stop opening (one certificate per free account).
  - Re-add the episode in the SideStore copy. Delete the old copy only if there are two icons and the new one plays.
  - Added the iloader "Maximum certificates reached" note at step 4, a bold "iOS updates can break the pairing file" warning (top + refresh section) and the could-fix wording.
  - README "Pick one" and DEVELOPMENT :12/:69/:176 now say the two tools revoke each other's certificate on one Apple ID.
- Left: Brent's confirm list. The orchestrator can drop the export/import follow-up (Brent declined it).
- Files: docs/INSTALL_ON_IPHONE.md, README.md, docs/DEVELOPMENT.md, docs/ARCHITECTURE.md, .loop/tasks/T-003-install-past-7-days-guide.md
- Gotchas: Clip Deck's empty sync state reads "Everything is in Anki." (SyncView.swift:23), not "0 waiting". The Bash tool's heredocs choke on some multi-line text here, so write files with Write and then `cat >>`.

## 2026-11-20 10:44 · loop-tester · T-003 · round 3
- Done: all round-2 findings are fixed, with evidence. M1: sync before setup step 1 via :9 and Moving step 1, and the old copy is expected to stop opening. S1: an iOS-update warning at :7 and :52 that quotes install.mdx:73. S2: one icon means delete nothing. All the Could fix items are done too. The literal walk-through checks out: cards can't be lost, the only copy can't be deleted, and the iOS-update risk is warned about before a trip. "Everything is in Anki." is at SyncView.swift:23, and it counts pending and failed cards. Links: 15/15 return 200. Anchors: 18/18 resolve. Only docs changed.
- Verdict: Pass. No Must or Should fix. Could fix:
  - C1: no fallback if the Sideloadly copy has already expired at step 1.
  - C2: check that the source video and subtitles exist before setup.
  - C3: the flat "each revokes the other" (README:93, DEV:12/:176, guide :129) vs the guide's "will likely". The Sideloadly direction is only inferred.
  - C4: quote the "random times" half of install.mdx:73, and give the Automatic Updates path.
  - C5: the old copy uses an app slot.
- Files: .loop/tasks/T-003-install-past-7-days-guide.md (Test report round 3); no test files
- Gotchas: the iloader en.json and today's live install/faq pages are in %LOCALAPPDATA%\Temp\clip-deck-loop\T-003-r3-test

## 2026-11-20 · orchestrator · T-003 · landed
- Done: T-003 passed in round 3 (round 1 sonnet, rounds 2-3 opus; Brent chose Opus after the Sonnet fail). Squashed to 9a66a4a. Docs only, so no CI.
- Left: T-009 is next and carries T-003's Could fix items C1-C5. Brent declined an export/import task (he has 1 episode and will re-upload it).
- Gotchas: SideStore installs Clip Deck as dev.brent.clipdeck.<teamID>, and setting it up with the same free Apple ID revokes Sideloadly's certificate.

## 2026-11-20 · loop-backend · T-009 · round 1 (sonnet)
- Done: release.yml (tag v* / dispatch, validated version via env, notices check, plist check, sha256, notes with FFmpeg tag link, gh release create), build-ipa.sh optional version env vars, Getting the IPA now points to Releases, new "Cutting a release" section, T-003 C1-C5
- Left: tester runs the rc tag from the loop branch, cleans up with gh release delete --cleanup-tag
- Files: .github/workflows/release.yml, scripts/build-ipa.sh, docs/INSTALL_ON_IPHONE.md, README.md, docs/DEVELOPMENT.md
- Gotchas: prerelease versions (with -) are not marked latest; YAML and bash only syntax-checked locally

## 2026-11-20 10:53 · loop-tester · T-009 · round 1
- Done: checked release.yml run 44767085601 (tag v0.1.1-rc1, success). I downloaded the release, with and without auth. The IPA plist has 0.1.1-rc1, build 1 and dev.brent.clipdeck, the sha256 matches, the notes link FFmpegBuild 3.16.0, THIRD_PARTY_NOTICES and LICENSE (all 200), and the notices check passed in the log
- Done: ran the workflow's own run: blocks locally. Version validation, 16 cases. Overwrite refusal against the real repo ("Release v0.1.1-rc1 already exists"). --latest vs --prerelease flags. The plist check catches wrong values. build-ipa.sh against stub xcodebuild: unchanged args without the vars
- Verdict: Pass. Could fix only: GH_TOKEN at job level plus a persisted checkout token, a misleading "push the tag" hint, raw input in ::error::, leading zeros accepted, checkout not SHA-pinned
- Left: the orchestrator deletes release v0.1.1-rc1 (--cleanup-tag). A real workflow_dispatch can only run after merge. Brent installs from Safari with SideStore
- Files: .loop/tasks/T-009-github-release-ipa.md (Test report round 1); no repo test files (stub harnesses in %LOCALAPPDATA%\Temp\clip-deck-loop\T-009-r1)
- Gotchas: rc tags are published as pre-releases, so /releases/latest stays 404 until a plain vX.Y.Z tag is pushed. `gh release view --json` has no isLatest field

## 2026-11-20 · orchestrator · T-009 · landed
- Done: T-009 passed in round 1 (sonnet). Squashed to e6138e1. Release run 44767085601 on test tag v0.1.1-rc1 green; the test release and tag were deleted afterwards.
- Left: T-010 (SideStore source) is next and carries T-009's workflow hardening. No real release exists yet: Brent cuts the first one (e.g. v0.2.0) once the branch is merged, or the loop can tag one when he asks.

## 2026-11-20 · loop-backend · T-010 · round 1 (sonnet)
- Done: scripts/make-source-json.py (+ scripts/test-make-source-json.py), release.yml step that regenerates and uploads apps.json for stable releases, T-009 hardening (token scoping, persist-credentials, message, newline-safe error, no leading zeros), install guide section for the source
- Left: tester needs a stable-looking tag run to exercise the apps.json step; repo is public
- Files: scripts/make-source-json.py, scripts/test-make-source-json.py, .github/workflows/release.yml, scripts/build-ipa.sh, docs/INSTALL_ON_IPHONE.md
- Gotchas: SideStore links updates via installedApp.storeApp (set only when installed from the source), not by bundle ID, so the team-ID suffix is harmless but a file-imported copy never sees updates. Release notes now carry "Build number: N", which the script needs. /releases/latest/download/apps.json 404s until a non-pre-release exists.

## 2026-11-20 12:53 · loop-tester · T-010 · round 1
- Done: verified the real release v0.2.0 (run 44786901731, green; the apps.json step ran). The release is latest, not a pre-release, has 3 assets, and its notes start "Build number: 2". All links return 200 without auth
- Done: the anonymous apps.json passes json.tool and --check. The IPA's bytes, sha256, version 0.2.0, build 2 and dev.brent.clipdeck all equal apps.json, so SideStore's VerifyAppOperation checks (4f3d18d :56-163) would pass. The log confirms the hardening: GH_TOKEN on 3 steps only, auth removed after checkout. The local test script passes and catches all 4 mutations
- Verdict: Pass. Could fix only:
  - versions are sorted by publish date, not by version
  - no documented recovery if the apps.json step fails (a re-run is refused)
  - the in-app version notes tell you to share the IPA
  - checkout@v4 Node 20 warning
- Left: Brent checks on the phone: add the source, install from it over the current copy, get the update on the next release
- Files: .loop/tasks/T-010-sidestore-source.md (Test report round 1); no test files
- Gotchas: a SideStore source without a top-level "version" key is v1, so it needs no appPermissions. Adding "version": 2 would require declaring NSLocalNetworkUsageDescription. Scratch files are in %LOCALAPPDATA%\Temp\clip-deck-loop\T-010-r1

## 2026-11-20 · orchestrator · T-010 · landed
- Done: T-010 passed (1 round, sonnet). Squashed to 46fa8aa. First real release **v0.2.0** published (Brent's choice), with tag v0.2.0 pointing at the pre-squash commit 8d21225 (same tree). Source URL: https://github.com/bman7222/clip-deck/releases/latest/download/apps.json
- Left: T-008 (expiry banner) is next, then optional T-005. Open follow-ups (Could fix, no task yet): make-source-json.py should sort versions by semver rather than published_at; document the apps.json recovery (or attach it in gh release create); reword the version notes shown inside SideStore; actions/checkout v5.

## 2026-11-20 · loop-backend · T-008 · round 1 (sonnet, backend half)
- Done: `InstallExpiry` (profile parser, 48 h decision, Debug `-uiTestingExpiry`, banner/settings strings) and `ExpiryReminderStore` (last-dismissed local day in UserDefaults), 24 unit tests, `LSApplicationQueriesSchemes: [sidestore]` in project.yml
- Left: frontend banner, Anki settings row, UI test, docs for the launch flag
- Files: ios/ClipDeck/Services/InstallExpiry.swift, ios/ClipDeckTests/InstallExpiryTests.swift, ios/project.yml
- Gotchas: `sidestore://` confirmed in SideStore@4f3d18d AltStore/Info.plist; nothing compiled locally (CI only); UI-test launches must use the "uiTesting" defaults suite for the store; certificate expiry skipped (not cheap)

## 2026-11-20 · loop-frontend · T-008 · round 1 (sonnet, frontend half)
- Done: ExpiryBanner (X, swipe, Open SideStore with failure message), library wiring (read once, re-eval on scenePhase active), Anki settings expiry line, 3 UI tests, `-uiTestingKeepExpiryDismissal` flag, docs
- Left: CI run; tester to check element queries and screenshots; Brent taps Open SideStore once on device
- Files: ios/ClipDeck/Features/Library/ExpiryBanner.swift, LibraryView.swift, Features/Settings/AnkiSettingsView.swift, App/ClipDeckApp.swift, ios/ClipDeckUITests/ExpiryBannerUITests.swift, CLAUDE.md, docs/DEVELOPMENT.md
- Gotchas: new files need xcodegen (sources are folder-based, CI runs it); the suite-clearing in ClipDeckApp keeps the dismissal key only with the new flag

## 2026-11-20 13:31 · loop-tester · T-008 · round 1
- Done: read run 44788627149. The ipa job is green, and the IPA plist has LSApplicationQueriesSchemes ['sidestore'] and no profile. Simulator: 197 pass, 2 fail, both test-side: the launch wait was 10 s but sample seeding took about 17 s, and the Settings row is below the fold of a lazy Form. All 24 InstallExpiryTests passed, and every existing UI suite passed, including the known flakes.
- Verdict: Fail. S1: at AX-L the "Open SideStore" label truncates to "Open SideS..." (ExpiryBanner.swift:30-40), so AC-7's "wraps" is not met. Could fix C1-C6 are in the task file.
- Tests: fixed ExpiryBannerUITests (60 s launch wait, scroll to settings.expiry, @MainActor helpers, a relaunch without the flag shows the banner). Added swipe and open-fails tests. Next run: only_testing=ClipDeckUITests/ExpiryBannerUITests, scope=tests.
- Files: ios/ClipDeckUITests/ExpiryBannerUITests.swift, .loop/tasks/T-008-install-expiry-reminder.md
- Gotchas: the xcresult can be read on Windows through its database.sqlite3 (TestIssues, Activities, Attachments) plus screenshots/ui-tests/manifest.json. RootView's "Preparing sample episode…" can last about 17 s on CI, so wait at least 30 s after a seeded launch.

## 2026-11-20 · loop-frontend · T-008 · round 2 (sonnet)
- Done: banner wraps at accessibility sizes (icon and X in a top row, full-width message, wrapping "Open SideStore" label), scaled X glyph, removed LSApplicationQueriesSchemes from project.yml
- Left: CI rerun; tester re-checks expiry-02-large-text; C2/C4/C5/C6 not done
- Files: ios/ClipDeck/Features/Library/ExpiryBanner.swift, ios/project.yml
- Gotchas: no canOpenURL anywhere; failure of openURL is handled by its completion handler

## 2026-11-20 14:31 · loop-tester · T-008 · round 2
- Done: read run 44796687521 (scope=all, 8439051). Both jobs are green, and 201/201 tests pass with 0 issues, including all 5 ExpiryBannerUITests (relaunch reset, swipe, open-failed, settings scroll) and every earlier suite with the known flakes. The IPA plist has no LSApplicationQueriesSchemes and no profile.
- Screenshots: expiry-02-large-text shows the AX layout with "Open SideStore" fully visible and the toolbar clear, so S1 is fixed. expiry-03-open-failed shows the error text under the button.
- Verdict: Pass. Could fix only: C7 (the large-text test can't detect truncation; AX5 would show the button label wrap), plus C2/C4/C5/C6 from round 1.
- Files: .loop/tasks/T-008-install-expiry-reminder.md (Test report round 2); no test files changed
- Gotchas: scratch files are in %LOCALAPPDATA%\Temp\clip-deck-loop\T-008-r2. The xcresult database.sqlite3 (TestCaseRuns, Activities) gives per-test results on Windows.

## 2026-11-20 · orchestrator · T-008 · landed
- Done: T-008 passed in round 2 (sonnet). Squashed to 0adca02. CI 44796687521 green (201/201). Every required task is now done; only optional T-005 and blocked T-007 remain.
- Left: v0.2.0 was released before T-008, so the expiry banner reaches the phone only in the next release (e.g. v0.3.0). Open Could fix: C7 (a test that catches a cut-off label at AX5), C2, C4-C6.

## 2026-11-20 · loop-backend · T-005 · round 1 (sonnet, backend half)
- Done: Swift .srt/.ass writer (`SubtitleFileWriter`) fed by the converter's packet loop, `ConversionPlan` subtitle rules (default track, names, picture tracks unusable), importer options (`embeddedSubtitleStreams`, `chosenSubtitleStream`), `PreparedVideo.subtitleTracks`, staging in `Embedded/`, rollback with the video, about 40 tests
- Left: frontend upload row (`upload.embeddedSubtitle`), seed Episode 2, UI test, PRODUCT_SPEC; the contract is in the task file
- Files: ios/ClipDeck/Services/Media/SubtitleFileWriter.swift, ConversionPlan.swift, MediaConverter.swift, Services/EpisodeImporter.swift, FileStore.swift (safeName nonisolated), ios/ClipDeckTests/EmbeddedSubtitleTests.swift, docs/ARCHITECTURE.md
- Gotchas: nothing compiled (CI only); assumes Matroska ASS packets are ReadOrder,Layer,... and WebVTT packets are identifier, settings, payload lines; fixture cue times are checked as source + the video's first-frame time

## 2026-11-20 · loop-frontend · T-005 · round 1 (sonnet, frontend half)
- Done: `upload.embeddedSubtitle` picker + greyed unusable tracks + footer note, model options pass all usable streams, seed Episode 2 (fixture 1), UI test for embedded cues and picker list, docs
- Left: CI run; tester checks compile of `Int?` Picker tags and the new UI test; Brent checks a real MKV
- Files: ios/ClipDeck/Features/Library/UploadEpisodeView.swift, VideoImportModel.swift, ios/ClipDeck/App/RootView.swift, ios/ClipDeckUITests/MKVImportUITests.swift, docs/DESIGN.md, docs/PRODUCT_SPEC.md, CLAUDE.md
- Gotchas: ASS file name in the picker isn't hardcoded in the test (matches `2 *.ass`); nothing compiled

## 2026-11-20 15:00 · loop-tester · T-005 · round 1
- Done: read CI 44806223525 (61bb9a4). Both jobs fail to compile with parse errors only, at ConversionPlan.swift:95-96: the WebVTT doc comment holds real line breaks where `\n` was meant. No test ran. I traced the rest by hand and found no other compile error
- Done: FFmpeg n8.1 source shows Matroska ASS packets are ReadOrder,Layer,... (assumption 1 is right). WebVTT packets are the payload only, with identifier and settings in side data (assumption 3 is wrong → S1, 3+-line cues lose 2 lines)
- Verdict: Fail. M1 the parse error. S1 WebVTT. S2 unbounded language / byte length of the file name fails the whole import. C1-C5 are in the task file
- Tests: added ios/ClipDeckTests/EmbeddedSubtitleTesterTests.swift (AC-6 model, WebVTT payload, name limit and containment, fixture 3 on the MP4's AVFoundation clock). The WebVTT and name-limit tests fail until S1/S2 are fixed
- Gotchas: Swift stops at parse errors, so a clean parse may expose type errors CI hasn't shown. Next run should be scope=all (nothing has run yet). Scratch is in %LOCALAPPDATA%\Temp\clip-deck-loop\T-005-r1

## 2026-11-20 · loop-backend · T-005 · round 2 (sonnet)
- Done: fixed the parse error (webVTT doc comment), WebVTT packets kept as payload, subtitle file names capped (16-char language, 200 bytes), a failed write of a non-chosen track is now a warning, C1-C4 (stop decoding dropped tracks, safeName strips control characters, "format not supported" wording, DESIGN parenthesis)
- Left: CI run; tester re-checks all ACs (nothing ran in round 1)
- Files: Services/Media/ConversionPlan.swift, MediaConverter.swift, SubtitleFileWriter.swift, Services/EpisodeImporter.swift, FileStore.swift, Features/Library/UploadEpisodeView.swift (wording), ClipDeckTests/EmbeddedSubtitleTests.swift, docs/DESIGN.md
- Gotchas: the round-1 parse error came from a `\n` in a Python edit script; chosen-track write failure still fails the import by design

## 2026-11-20 16:07 · loop-tester · T-005 · round 2
- Done: read CI 44812195849 (5a71053). It compiles for the first time: the ipa job is green, and the simulator passes 245/246. Every T-005 test passes, including all tester tests (WebVTT payload, name limits, folder containment, AC-6 model, fixture 3 on the MP4 clock), MKVImportUITests embedded test (mkv-03 shows the 3 Japanese cues; mkv-04 lists `1 jpn SRT.srt` and `2 jpn Full.ass`), and all known flakes
- Done: M1, S1, S2 (names) and C1-C5 are fixed. The S2 warning path is traced only
- Verdict: Blocked, NEEDED: verify-only pass. The only failure is the builder's stale `EmbeddedSubtitleRuleTests.webVTTPacketsAreWrittenLikeSubRipWithEveryLine` expectation (it still expected the pre-S1 dropped lines). I fixed it in the test file. Run scope=tests only_testing=ClipDeckTests/EmbeddedSubtitleRuleTests
- Could fix: C6 safeName's controlCharacters includes Cf (ZWJ/ZWNJ/soft hyphen), which can orphan existing folders whose names contain them. C7 the chosen track is still "required" when the user's own file wins. C8 no test for `.subtitleNotSaved`
- Files: ios/ClipDeckTests/EmbeddedSubtitleTests.swift (expectation), .loop/tasks/T-005-mkv-embedded-subtitles.md
- Gotchas: scratch files are in %LOCALAPPDATA%\Temp\clip-deck-loop\T-005-r2. A full scope=all simulator run takes about 33 min

## 2026-11-20 16:18 · loop-tester · T-005 · round 2 addendum
- Done: verify-only run 44817982486 (141d94f, scope=tests, only EmbeddedSubtitleRuleTests) is green: 19/19 pass with 0 issues, including the deciding `webVTTPacketsAreWrittenLikeSubRipWithEveryLine`. The commit changes only that test file
- Verdict: Pass. AC-1..AC-7 are met using 44812195849 (ipa green, 245/246) plus this run
- Left: C6 (safeName strips Cf format characters), C7 and C8 go to the orchestrator's loose-ends pass. Brent checks a real MKV with ASS Full/Signs tracks
- Files: .loop/tasks/T-005-mkv-embedded-subtitles.md (Round 2 addendum)
- Gotchas: an only_testing run of one unit suite takes about 6 min end to end

## 2026-11-20 · orchestrator · T-005 · landed; T-013 planned
- Done: T-005 passed (2 sonnet rounds + 1 verify-only pass). Squashed to ee09056. Every feature task is done.
- Left: T-013 (tidy up loose ends, written by the orchestrator at Brent's request) is next. Then update CLAUDE.md status, ask Brent about merging to main, release v0.3.0, and give him the phone instructions.

## 2026-11-20 · loop-backend · T-013 · round 1 (sonnet)
- Done: AC-1..AC-8 (safeName Cc only, picked subtitle file makes chosen track non-required, semver ordering + SideStore notes + recovery doc, checkout@v5, ErrorBanner a11y, test tidy-ups + interrupt-callback test, notices row)
- Left: CI run for the Swift changes (nothing compiled locally); `python scripts/test-make-source-json.py` passes
- Files: FileStore.swift, EpisodeImporter.swift, Components.swift, 3 test files, make-source-json.py (+test), 2 workflows, INSTALL_ON_IPHONE.md, THIRD_PARTY_NOTICES.md
- Gotchas: `PreparedVideo.plan(for:userPickedSubtitleFile:)` new param; a later hotfix release would become GitHub "latest"

## 2026-11-20 17:45 · loop-tester · T-013 · round 1
- Done: read CI 44819926161 (28ad26f, scope=all). Both jobs are green: 251/251 pass with 0 issues, including the 5 new tests and every known flake. The 3 `as?` "always succeeds" warnings are gone, and there are no Swift warnings. The 06-sync banner screenshot matches the previous run pixel for pixel. The documented recovery generate+check commands work against the live repo, and SideStore shows the notes with a tappable link
- Verdict: Fail. S1: ios-simulator.yml still gives the Node 20 warning, from actions/upload-artifact@v4 (:60, :91); bump it to @v6. C1-C3 are in the task file
- Tests: test-make-source-json.py (v0.10.0 published before v0.3.0, check_source numeric order); MiningFlowUITests AC-6 assertion (the banner action is its own button), not run yet
- Files: scripts/test-make-source-json.py, ios/ClipDeckUITests/MiningFlowUITests.swift, .loop/tasks/T-013-tidy-up-loose-ends.md
- Gotchas: drive C: was at 0 MB free during this run (about 160 MB after I removed my own scratch). This run's simulator-results artifact is only 13.5 MB zipped, and the xcresult database.sqlite3 has per-test results

## 2026-11-20 · loop-backend · T-013 · round 2 (sonnet)
- Done: upload-artifact@v4 to @v6 (both jobs), check_source rejects non-X.Y.Z versions (+test), python3 note in the recovery doc
- Left: CI run to confirm the Node 20 warning is gone and the AC-6 UI assertion passes; C3 not done
- Files: .github/workflows/ios-simulator.yml, scripts/make-source-json.py, scripts/test-make-source-json.py, docs/INSTALL_ON_IPHONE.md
- Gotchas: tester's edits in test-make-source-json.py and MiningFlowUITests.swift kept

## 2026-11-20 18:22 · loop-tester · T-013 · round 2
- Done: read CI 44833382185 (356f2e7, scope=all). Both jobs are green: 251/251 pass with 0 issues and 0 skips, including every known flake and the round-1 tester's MiningFlowUITests AC-6 assertion (the xcresult activities show the button wait, the StaticText check, the tap and settings.url)
- Done: S1 is fixed. Neither job has a Node 20 annotation (capacity notice only), and both jobs run upload-artifact@v6 (node24). The local make-source-json test passes, and removing the new version check makes it fail
- Verdict: Pass. One Could fix: the version regex's `$` accepts a trailing newline
- Files: .loop/tasks/T-013-tidy-up-loose-ends.md (Test report round 2)
- Gotchas: run logs only become available after the whole run finishes. The simulator-results artifact is about 15 MB

## 2026-11-20 · orchestrator · T-013 · landed; goal complete
- Done: T-013 passed (2 sonnet rounds). All 12 buildable tasks are done; T-007 stays blocked (paid account). CLAUDE.md "Current status" updated.
- Left: Brent decides whether to merge loop/mkv-landscape-sideload into main, then release v0.3.0. Open Could fix: make-source-json.py version regex accepts a trailing newline (use re.fullmatch).

## 2026-11-20 22:03 · loop-planner · T-014..T-016 · planning
- Done: spec .loop/specs/subtitle-style.md (Proposed, decisions D-1..D-8 with recommended answers); planned T-014 (style value + placement + renderer, Debug seed flag), T-015 (portrait opener + sheet), T-016 (landscape card in place of the bottom bar); issues #15-#17
- Left: all three are blocked until Brent confirms D-1..D-8 (fonts, global scope, steps, position unit, portrait sheet, landscape card, default, aqua opener); if he accepts them, no task changes
- Files: .loop/specs/subtitle-style.md, .loop/tasks/T-014-subtitle-style-renderer.md, T-015-subtitle-style-menu-portrait.md, T-016-subtitle-style-menu-landscape.md, .loop/BOARD.md
- Gotchas: the ASS parser already strips all styles/tags, so the user style applies to ASS the same as to SRT. `SelectableText.sizeThatFits` returns the full width, so the line frame must be made to hug the text before frames can prove position. "Position" never "offset" (player.offset is timing). The landscape bar at panel 50% goes from about 245 to about 297 of about 320 pt

## 2026-11-20 22:20 · loop-planner · T-014..T-017 · replan after Brent's answers
- Done: spec Accepted (D-2..D-8 as recommended; D-1 "both": presets + "More fonts…" system picker with a fixed Hiragino cascade for Japanese). New T-017 (#18) picked font. T-015 preset rows show "Aa あア漢字". T-016 now depends on T-017 and has 13 controls. All four are todo; issues #15-#18 edited to match
- Left: build order T-014 → T-015 → T-017 → T-016
- Files: .loop/specs/subtitle-style.md, .loop/tasks/T-014..T-017, .loop/BOARD.md
- Gotchas: a picked font is stored by PostScript name and dropped to Sans on read if missing. Bold uses the family's bold face or none (no fake bold); the Japanese fallback follows Bold (W6, except Maru W4). Don't drive a selection inside the system picker in UI tests; seed `pickedFontName` instead

## 2026-11-20 · loop-frontend · T-014 · round 1 (sonnet)
- Done: AC-1..AC-7 written (nothing compiled): SubtitleStyle/SubtitleFont, pure SubtitlePlacement + SubtitleLineLayout, SelectableText hugsWidth/font, line drawn from the saved style, launch flags, player.topBar/bottomBar ids, unit + UI tests, docs
- Left: CI run (scope=all); T-015 can call `SubtitleStyle` mutators and write `style.json` to `player.subtitleStyle` (AppStorage string, PlayerView already observes it)
- Files: Features/Player/SubtitleStyle.swift, SubtitlePlacement.swift, PlayerView.swift, DesignSystem/Components.swift, App/ClipDeckApp.swift, ClipDeckTests/SubtitleStyleTests.swift, ClipDeckUITests/SubtitleStyleUITests.swift, CLAUDE.md, docs/ARCHITECTURE.md, docs/PRODUCT_SPEC.md
- Gotchas: the line is a video overlay placed by a Layout; font size keeps today's double Dynamic Type scaling so the default is identical; T-017 adds `pickedFontName` (decoding already ignores unknown fields) and extends `SubtitleStyle.uiFont`

## 2026-11-20 22:53 · loop-tester · T-014 · round 1
- Done: read CI 44860511457 (6fc17c1, scope=all). The ipa job is green. The simulator ran 295/298 with no Swift warnings, and all 4 SubtitleStyleUITests pass with frames that match the spec formula. Against 44836733690 (main's tree; main's only green run is pre-landscape), the default line is pixel-identical in portrait and 1 px (⅓ pt) shifted in landscape
- Fails: the builder's `landscapeInsetsAndThePanelHandleClearance` expected 752/75 where the spec formula gives 734.3/92.7 (fixed in the test). Known flake testControlsStayWhilePausedAndAutoHideWhilePlaying. AboutUITests/testSourceLinksAreShownAndOpenInSafari (Safari didn't launch; the diff doesn't touch it)
- Verdict: Blocked, NEEDED: verify-only pass with `-f scope=tests` and no only_testing (the deciding tests span both targets). No product finding above Could fix: C1 1 px landscape rounding, C2 line drawn over RecordingBadge, C3 step overflow from code
- Tests: SubtitleStyleTests.swift (fix), new SubtitleStyleTesterTests.swift (default font equivalence; hugged width keeps the same lines and is stable, via UIHostingController), new SubtitleStyleTesterUITests.swift (keep flag across relaunch; extreme-left line clear of the leading safe inset)
- Gotchas: the simulator-results artifact is now about 180 MB (screen recordings), so unzip only screenshots/ui-tests/*.png, *.txt, manifest.json and the xcresult database.sqlite3. Main run 44838534920 failed EpisodeImporterTests.copiesAnMP4… once; it passes here, so it may be a new flake

## 2026-11-20 23:32 · loop-tester · T-014 · round 1 addendum
- Done: verify-only run 44863556968 (b289a5b, scope=tests, full suite) is green: 308/308, 0 skipped. The corrected placement test, the default-font equivalence, the hugged-width test (no re-wrap or clip; stable), keep/clear across relaunch, and the extreme-left line clear of the leading safe inset (minX 78 ≥ back 74) all pass
- Done: both re-checks pass on unchanged app code (the PlayerLandscapeBehaviour flake; AboutUITests Safari). The Safari failure is a runner flake, added to CONTEXT.md Learned
- Verdict: Pass. AC-1..AC-7 met. Open Could fix: C1 (1 px landscape rounding). C2/C3 are carried into T-015
- Files: .loop/tasks/T-014-subtitle-style-renderer.md (Round 1 addendum), .loop/CONTEXT.md (Learned)
- Gotchas: this full scope=tests run took about 34 min; its artifact was about 135 MB

## 2026-11-20 · orchestrator · T-014 · landed
- Done: T-014 passed (1 sonnet round + 1 verify-only pass). Squashed to 93d3c08. CI 44860511457 + 44863556968 green.
- Left: T-015 (portrait style sheet) is next; it carries Could fix C2 (badge overlap) and C3 (step overflow).

## 2026-11-21 02:05 · loop-frontend · T-015 · round 1 (sonnet)
- Done: portrait style sheet (SubtitleStyleSheet.swift) + `player.subtitleStyle` Button after the subtitles button; DeckIconButtonStyle disabled look + Reduce Motion; C2 badge above the line; C3 overflow-safe step mutators (`clampedSum`); unit + UI tests; DESIGN/PRODUCT_SPEC (nothing compiled)
- Left: CI run (scope=all). T-017 adds "More fonts…" under the presets in the sheet. T-016 replaces the landscape opener's sheet with its card and must prove the 50% bar fit
- Files: Features/Player/SubtitleStyleSheet.swift, PlayerView.swift, SubtitleStyle.swift, DesignSystem/Components.swift, ClipDeckTests/SubtitleStyleTests.swift, ClipDeckUITests/SubtitleStyleUITests.swift, docs/DESIGN.md, docs/PRODUCT_SPEC.md
- Gotchas: landscape button currently opens the portrait sheet; sheet state is its own @AppStorage on `player.subtitleStyle`

## 2026-11-21 02:38 · loop-tester · T-015 · round 1
- Done: read CI 44878628011 (08f286b, scope=all). The ipa job is green. The simulator job ran 315/316: all 5 new SubtitleStyleUITests, 3 new unit tests and 14 landscape tests pass, and the 50% panel bar still fits (style button at x 246–290, Make a Card ends at 393, handle at 405). The 1 failure is EpisodeImporterTests.copiesAnMP4… `.timedOut`, a pre-existing flake (added to CONTEXT Learned)
- Verdict: Fail. S1: the 520 pt detent covers the bottom 8 pt of the video on iPhone 17 Pro (sheet top 334 pt against video maxY 342, measured in style-01). C1: Reset press-scales under Reduce Motion. C2: back is tappable while the sheet is open
- Tests: new ios/ClipDeckUITests/SubtitleStyleSheetTesterUITests.swift (12 controls below the video plus a sheet-top pixel check, which fails until S1 is fixed; labels and values; every limit; playback not paused). Not run yet
- Files: .loop/tasks/T-015-subtitle-style-menu-portrait.md (Test report round 1), .loop/CONTEXT.md (Learned)
- Gotchas: the simulator-results artifact was 148 MB. `unzip -x "*/Data/*"` keeps only the screenshots, manifest and database.sqlite3 (9 MB). The visible sheet top is about 20 pt higher than screen height minus the detent

## 2026-11-21 04:18 · loop-frontend · T-015 · round 2 (sonnet)
- Done: S1 first detent computed from the measured video maxY (window - videoMaxY - 8 - 20 rise, min 120; landscape .large only); C1 primary button skips press-scale under Reduce Motion; C2 back button hidden while the sheet is open (nothing compiled)
- Left: CI run; the tester's pixel check decides S1 (constant `systemSheetRise` = 20 is from the round-1 measurement)
- Files: Features/Player/SubtitleStyleSheet.swift, PlayerView.swift, DesignSystem/Components.swift, ClipDeckTests/SubtitleStyleTests.swift, docs/DESIGN.md
- Gotchas: SubtitleStyleSheet now takes `firstDetent: CGFloat?` (T-017/T-016 callers must pass it)

## 2026-11-21 04:57 · loop-tester · T-015 · round 2
- Done: read CI 44888942981 (89ae32f, scope=all). The ipa job is green; the simulator ran 319/320 with 0 build issues, and every earlier suite plus all known flakes pass. S1 is fixed on iPhone 17 Pro / iOS 26.5: the pixel check passes, and the sheet top is at 349.4 against the video's maxY of 342 (a 7.4 pt gap). C2 is fixed: no BackButton while the sheet is open, and the nav bar, title and video frames are unchanged. C1 is fixed by reading
- Fails: my own testUsingTheSheetDoesNotPausePlayback read the label after the 6 s sample had ended (Play at 209.4 s, read at 216.5 s). It's a test flaw; the test is rewritten to read with the sheet open
- Verdict: Fail on S2 (Should fix). `systemSheetRise = 20` is iOS 26's floating-sheet geometry (an 8 pt inset plus 12.6); iOS 17/18 and Home-button iPhones likely differ and could cover the video. Fix: measure the sheet's own global minY and correct the detent once. C3: Done is reported as Selected
- Files: ios/ClipDeckUITests/SubtitleStyleSheetTesterUITests.swift (rewritten playback test; back hidden/restored and no-jump asserts), .loop/tasks/T-015-subtitle-style-menu-portrait.md
- Gotchas: the player stays in the accessibility tree under the open sheet, so `player.*` can be read while it is open. On iOS 26 the sheet is a floating card at x 8–394 with an 8 pt bottom inset. The artifact was 195 MB zipped and 15 MB after unzipping without */Data/*

## 2026-11-21 05:16 · loop-frontend · T-015 · round 3 (opus)
- Done: S2: the first detent is measured, not assumed. A hidden UIKit probe behind the sheet reads its real top (UIKit convert includes iOS 26's ~0.96 sheet scale); after it settles, `SheetFit.correction` fixes the detent once (set and selection together), and the rise is cached in `player.styleSheetRise`. C3: Done gets `.accessibilityRemoveTraits(.isSelected)` (likely the checkmark symbol). Nothing compiled
- Left: CI run (scope=all). The tester's test now also asserts the sheet's top is 0 to 16 pt below the video via the new `subtitleStyle.sheet` container
- Files: Features/Player/SubtitleStyleSheet.swift, PlayerView.swift, ClipDeckTests/SubtitleStyleTests.swift, ClipDeckUITests/SubtitleStyleSheetTesterUITests.swift (gap check added), SubtitleStyleUITests.swift, docs/DESIGN.md
- Gotchas: `SubtitleStyleSheet(clearance: SheetClearance?)` replaces `firstDetent:` (T-016/T-017 callers). The round-2 tree shows iOS 26 draws the lower-detent sheet scaled about 0.96, so frames inside it are scaled too

## 2026-11-21 05:55 · loop-tester · T-015 · round 3
- Done: read CI 44893660834 (24a676d, scope=all). The ipa job is green; the simulator ran 325/326 with 0 build issues, and every earlier suite and known flake passes. The tester's rewritten playback test passes, reading "Pause" twice with the sheet open. C3 is fixed (Done is not Selected). All 7 SheetFit unit tests pass
- Fail: the builder's gap check in testEveryControlStartsBelowTheVideoAndIsLabelled (22.8 > 16). It's a test-hook flaw: XCUITest gives the `subtitleStyle.sheet` container the union of its children (Done's top, 364.8). The sheet itself is at 349.4, a 7.4 pt gap
- Evidence for S2: the first open (20 pt guess) has its sheet top at 349.33; a later launch's style-01-sheet has it at 350.0, matching a cached 20.6 rise. So the probe measures the scaled top and the cache works
- Verdict: Blocked, NEEDED: verify-only pass with `-f scope=tests -f only_testing=ClipDeckUITests/SubtitleStyleSheetTesterUITests`. No Must or Should fix. Could fix C1: a still mid-drag sample can be cached (it heals on the next open)
- Tests: SubtitleStyleSheetTesterUITests.swift (sheetTop helper for the gap check; new testAWrongSavedRiseIsCorrectedOnceTheSheetHasSettled seeds `-player.styleSheetRise` with an XML plist real 0)
- Gotchas: the artifact was about 149 MB. Attachments are mapped by screenshots/ui-tests/manifest.json, and the failure text is in the xcresult database.sqlite3 TestIssues table

## 2026-11-21 15:01 · loop-tester · T-015 · round 3 addendum
- Done: read verify run 44896666698 (859dd94, only SubtitleStyleSheetTesterUITests): 2/4 pass. Both failures are my sheetTop helper returning the container's union frame (364.8): the containing query includes the container itself, and my filter was `<=`
- Product evidence from the same run: with the 0 pt rise seed the sheet covered the video at 0.87 s (difference 213), then from 1.27 s it was uncovered, and it settled at 349.4 (7.4 pt gap). The default open is also at 349.4. S2 is proven end to end on iOS 26.5
- Verdict: Blocked, Brent's call. No Must or Should fix, and all ACs are decided by run evidence. Land as is, or approve a 5th dispatch (scope=tests, only_testing=ClipDeckUITests/SubtitleStyleSheetTesterUITests) to turn the fixed test green
- Files: ios/ClipDeckUITests/SubtitleStyleSheetTesterUITests.swift (sheetTop excludes the container by identifier and by a strict top; uncommitted), .loop/tasks/T-015-subtitle-style-menu-portrait.md (Round 3 addendum)
- Gotchas: XCUIElementQuery `containing(.any, identifier: X)` also returns the X element itself

## 2026-11-21 · orchestrator · T-015 · landed
- Done: T-015 passed (rounds: sonnet, sonnet, opus; 2 verify-only passes; 5 CI runs, the 5th approved by Brent). Squashed to fab9468.
- Left: T-017 (More fonts…) is next, then T-016 (landscape card).

## 2026-11-21 · loop-frontend · T-017 · round 1 (sonnet)
- Done: `pickedFontName` in SubtitleStyle (tolerant decode, missing font drops to Sans, closest-preset Hiragino cascade, real bold only); "More fonts…" row + UIFontPickerViewController sheet in SubtitleStyleSheet; SheetFit skips measuring while the picker is up; unit + UI tests; DESIGN/PRODUCT_SPEC (nothing compiled)
- Left: CI run (scope=all). T-016 can reuse `SystemFontPicker` (private in SubtitleStyleSheet.swift; make it internal) and `SubtitleStyle.pickedFamilyName`
- Files: Features/Player/SubtitleStyle.swift, SubtitleStyleSheet.swift, App/ClipDeckApp.swift, ClipDeckTests/SubtitleFontTests.swift, ClipDeckUITests/SubtitleFontUITests.swift, docs/DESIGN.md, docs/PRODUCT_SPEC.md
- Gotchas: `-uiTestingSubtitleStyle` now seeds via `SubtitleStyle.seeded(from:)` so an uninstalled name survives into the saved JSON

## 2026-11-21 18:12 · loop-tester · T-017 · round 1
- Done: read CI 44957727655 (59383f1, scope=all). The ipa job is green; the simulator ran 345/347 with 0 build issues. SubtitleFontTests 16/16 pass (Georgia → Serif; Latin is Georgia, Japanese is HiraMinProN-W3, or W6 with Bold; no LastResort; Zapfino keeps its face; missing → Sans; old JSON). 3/4 SubtitleFontUITests pass
- Fails: the builder's Cancel test looked for "Cancel", but the iOS 26 picker's dismiss button is an X labelled `close` (a test flaw, fixed). PlayerLandscapeBehaviourUITests/testOpenSubtitlesMenuKeepsControlsUpWhilePlaying is the known flake
- Screenshot: style-03 shows "元気ですか" in Hiragino Mincho, legible and not tofu, and the More fonts row aqua with "Georgia" and Georgia/Mincho samples. The sheet top is 349.4 against video maxY 342
- Verdict: Blocked, NEEDED: verify-only pass, `-f scope=tests -f only_testing=ClipDeckUITests` (the Cancel test, the sheet top after Cancel and on reopen, a preset clears the pick, the flake re-check). No Must or Should fix. Could fix C1: a bold-only family ignores Bold off
- Tests: ios/ClipDeckUITests/SubtitleFontUITests.swift (the close label), new ios/ClipDeckUITests/SubtitleFontTesterUITests.swift (4 tests); uncommitted
- Files: .loop/tasks/T-017-subtitle-picked-font.md (Test report round 1), .loop/CONTEXT.md (Learned: the picker's `close`)

## 2026-11-21 19:43 · loop-tester · T-017 · round 1 addendum
- Done: read verify run 44960788495 (803d088, ClipDeckUITests): 49/50. All the deciding tests pass. Cancel returns to the sheet (iOS 26 `close`). The sheet top is 349.41 before and after Cancel and 350.37 on reopen; with the picker opened early it is 350.05 after Cancel and on reopen (video maxY 342). A preset clears the picked font. The landscape flake re-check passes
- Close-ups: "元気ですか" is Hiragino Mincho, W6 with Bold and W3 without, and legible with the outline. The row sample is Georgia Latin with Mincho Japanese, matching the Serif preset
- Fail (unrelated): ExpiryBannerUITests/testOpenSideStoreWithoutSideStoreKeepsBannerAndExplains. The app sat on "Preparing sample episode…" for 94 s (the known sample-episode timing flake); it passed on the same app code in 44957727655
- Verdict: Blocked, NEEDED: re-run CI for ExpiryBannerUITests only; Pass if it is green. No Must or Should fix; C1 moves to T-016 or later
- Files: .loop/tasks/T-017-subtitle-picked-font.md (Round 1 addendum)

## 2026-11-21 · orchestrator · T-017 · landed
- Done: T-017 passed (1 sonnet round + 1 verify-only pass). Squashed to 31bc513.
- Left: T-016 (landscape card) is the last task; it carries T-017 C1 and the ExpiryBanner flake re-check.

## 2026-11-21 20:30 · loop-frontend · T-016 · round 1 (sonnet)
- Done: landscape style card `SubtitleStyleCard` replaces the bottom bar (13 controls, ViewThatFits 13 / 7+6 / 5+4+4), line pushed above it, controls kept up with the card and the font picker, closes on Done, video tap or rotation, Reduce Motion fade; landscape .large fallback removed; T-017 C1 bold-only note (nothing compiled)
- Left: CI run (scope=all); re-check ExpiryBannerUITests/testOpenSideStoreWithoutSideStoreKeepsBannerAndExplains; measure the 50% panel from the new SubtitleStyleCardUITests frames
- Files: Features/Player/SubtitleStyleCard.swift, PlayerView.swift, SubtitleStyleSheet.swift, SubtitleStyle.swift, ClipDeckTests/SubtitleFontTests.swift, ClipDeckUITests/SubtitleStyleCardUITests.swift, docs/DESIGN.md, docs/PRODUCT_SPEC.md
- Gotchas: the card's accessibility frame is the union of its controls; tests tap the video at x 0.3 (0.5 is the handle at 50%)

## 2026-11-21 20:39 · loop-tester · T-016 · round 1
- Done: read CI 44971851033 (ecc866e, scope=all). The ipa job is green (the app compiles). The simulator job failed at build time: SubtitleFontTests.swift:219 and :222 put a `mutating` call (`pickFont`) inside `#expect` ("cannot use mutating member on immutable value: '$0' is immutable"). 0 tests ran
- Fixed in test code (uncommitted): those two lines read into `let`s first. Added SubtitleStyleCardTesterUITests.swift with 3 tests: the ViewThatFits rows and the safe area at closed/25/50%, the line against the card's real top (union minY − 8), the rest place after closing, and per-tap Up evidence
- Verdict: Blocked, NEEDED: verify-only pass `-f scope=tests` (full suite). No Must or Should fix found by reading. Could fix C1 (Brent's call): with the card open, the first ~3 (1 row) to ~6 (2 rows) Up taps may not move the line, because T-014 pins it above the card. Could fix C2: a stale timing comment in the keep-up test
- Files: ios/ClipDeckTests/SubtitleFontTests.swift, ios/ClipDeckUITests/SubtitleStyleCardTesterUITests.swift (new), .loop/tasks/T-016-subtitle-style-menu-landscape.md
- Gotchas: Swift Testing `#expect(x.mutatingCall())` doesn't compile. A build-failure artifact is only about 46 KB (no screenshots); the errors are in the xcresult BuildIssues table

## 2026-11-21 21:30 · loop-tester · T-016 · round 1 addendum
- Done: read verify run 44972664549 (34ca7e6, scope=tests): 362/365. All 7 card tests except the bold-only one pass. Rows are 13 / 7+6 / 5+4+4, every control sits inside the column and the safe area, and the line ends 8 pt above the card's real top (314 vs 322; 262 vs 270). After a close the line rests exactly at its styled place. Portrait suites, landscape suites and the ExpiryBanner re-check all pass
- Fail: M1. `pickedFontIsAlwaysBold` relies on `.traitBold`, which ArialRoundedMTBold lacks, so the sheet says "This font has no bold weight." and 2 tests fail. Fix: detect bold by the weight trait or the face name (SubtitleStyle.swift:245/255/262), or drop the carried-over feature
- C1 numbers for Brent: with a one-row card, Up 1–3 don't move the line (measured), Up 4 does. With two rows, 6 taps show nothing (computed). With three rows, about 8–9
- Files: ios/ClipDeckUITests/SubtitleStyleCardTesterUITests.swift (bottom reference fixed; uncommitted), .loop/tasks/T-016-subtitle-style-menu-landscape.md (Round 1 addendum), .loop/CONTEXT.md (Learned)
- Gotchas: the card has a background, so XCUITest reports its real frame (unlike the T-015 sheet). The landscape bar's play button sits 1.8 pt above the row's bottom (Make a Card is taller). Extracting only screenshots and the DB cut the 213 MB artifact to 22 MB

## 2026-11-21 22:10 · loop-frontend · T-016 · round 2 (sonnet)
- Done: M1 one `isBoldFace` rule (trait, weight >= 0.3, or name) in boldFace/always-bold; C1 live preview: `SubtitlePlacement.frame(stepsFromObstruction:)` counts up steps from just above the open card (closed/portrait unchanged) with 4 unit tests; C2 comment fixed; DESIGN.md. Tester's test file kept (one assertion added). Nothing compiled
- Left: CI run; check the up-taps log and the ArialRoundedMTBold tests
- Files: Features/Player/SubtitleStyle.swift, SubtitlePlacement.swift, PlayerView.swift, ClipDeckTests/SubtitleStyleTests.swift, ClipDeckUITests/SubtitleStyleCardUITests.swift, SubtitleStyleCardTesterUITests.swift, docs/DESIGN.md
- Gotchas: at 50 % (card 184 pt, 3 rows) the 8 Up taps may hit the top-bar clamp near the end

## 2026-11-21 22:47 · loop-tester · T-016 · round 2
- Done: read CI 44976839046 (472e414, scope=all). ipa green; 272/272 unit; 44 UI pass, 0 fail. M1 fixed (both bold-only tests pass; Georgia/Zapfino/Hiragino unchanged). C1 works: Up 1–8 with the card open move 18.0–18.33 pt each (314 → 169.33); after Done the line rests at 370/333.67/297.67 as before. The per-width test ran in full (13 / 7+6 / 5+4+4, 200% line maxY 210 < card top 218)
- Blocked: the simulator job hit its 45-min timeout. SubtitleStyleCardUITests/testUpAndSize… hung on "App animations complete notification not received" (60 s per action), starting before the card opened, so it wasn't caused by the diff. The portrait SubtitleStyle*/SheetTester/StyleTester UI suites (15 tests) never ran. NEEDED: re-run `-f scope=tests -f only_testing=ClipDeckUITests`
- Could fix: C3 the live preview stops at the top-bar clamp after about 12/9/6 taps (1/2/3 rows); C4 the `isBoldFace` name fallback overrides a light weight trait (user-installed "Black…" families)
- Files: .loop/tasks/T-016-subtitle-style-menu-landscape.md (Test report round 2), .loop/CONTEXT.md (Learned)
- Gotchas: a timed-out job uploads only `Staging` (no database). The attachments are zstd blobs in Data/ (miniconda's `zstd -d` decodes them). Two `gh run watch` processes in parallel used up the 5000/hr API limit; watch with one

## 2026-11-21 23:29 · loop-tester · T-016 · round 2 addendum
- Done: read verify run 44982440176 (f71a426, ClipDeckUITests only, 60-min limit): success in 37.5 min, 60/60 UI tests, 0 issues. AC-6 (b) passes: at 25% the line is at maxY 207.7 (was held at 262 in round 1), so Up ×3 moves it 54.3 pt with a 2-row card. SubtitleStyleUITests 9/9, SheetTester 4/4, StyleTester 2/2; no other regressions. The animations-idle hang didn't recur
- Verdict: Pass (REVIEWED_AT f71a426). C3 (preview clamp) and C4 (bold name rule) are deferred to a follow-up task by Brent
- Files: .loop/tasks/T-016-subtitle-style-menu-landscape.md (Round 2 addendum)
- Gotchas: `gh run watch -i 60` keeps one watcher well under the API limit. The finished xcresult has database.sqlite3 (TestCaseRuns/TestCases/TestSuites/Attachments); attachment blobs are `Data/data.<xcResultKitPayloadRefId>`, zstd-compressed

## 2026-11-22 · orchestrator · T-016 · landed; T-018 planned
- Done: T-016 passed (2 sonnet rounds + 2 verify-only passes; 4 CI runs). Squashed to c713b66; the CI timeout (45 → 60 min) is its own commit.
- Left: T-018 (Brent's follow-up for C3 and C4) is the last task of the subtitle-style goal.

## 2026-11-22 · loop-frontend · T-018 · round 1 (sonnet)
- Done: card Up disables (value "Highest") when the next step wouldn't move the line (SubtitlePlacement.canStepUpWithCardOpen); isBoldFace trusts the weight trait over the name. Nothing compiled
- Left: CI run (scope=all, or unit + the new card UI test)
- Files: Features/Player/SubtitlePlacement.swift, SubtitleStyleCard.swift, SubtitleStyle.swift, PlayerView.swift, ClipDeckTests/SubtitleStyleTests.swift, SubtitleFontTests.swift, ClipDeckUITests/SubtitleStyleCardTesterUITests.swift, docs/DESIGN.md
- Gotchas: video/line sizes come from state set by onChange, so the first frame after opening may use stale sizes; unmeasured video keeps Up enabled

## 2026-11-22 03:14 · loop-tester · T-018 · round 1
- Done: read CI 44997338718 (45f32d4, scope=all). ipa green, simulator 374/377, 0 build issues. AC-2 passes: the 14/11/9-tap unit tests pass, and the card UI test dims Up after 13 taps, each moving > 1 pt, with value "Highest". The known flakes all passed
- Fail: M1. ArialRoundedMTBold reports weight trait 0.0 and no traitBold on iOS 26.5, so the new "trust the weight" rule makes it not bold. 3 tests fail (the new arialRounded test, plus the two existing bold-only tests from T-016). AC-3's premise ("bold by its weight trait") is false; it needs a decision: use the name when the weight is 0.0, or read OS/2 usWeightClass
- Could fix: C1 Down from a stored place past the clamp doesn't move the line; C2 the video and line sizes are measured only while a cue shows; C3 the builder's UI test bound `< 20` can't tell the top bar from the stored limit
- Tests: new ios/ClipDeckTests/SubtitleUpLimitTesterTests.swift (5) and ios/ClipDeckUITests/SubtitleUpLimitTesterUITests.swift (2: the 2/3-row cards, the stored percent, the clamp position, the portrait 90 % rule); uncommitted, not yet run
- Files: .loop/tasks/T-018-subtitle-style-limits-and-bold-rule.md (Test report round 1), .loop/CONTEXT.md (Learned)
- Gotchas: `python -I` ignores PYTHONIOENCODING; use sys.stdout.reconfigure(encoding="utf-8") when printing xcresult issues

## 2026-11-22 · loop-frontend · T-018 · round 2 (sonnet)
- Done: isBoldFace ignores a 0.0 weight (name decides); card Down jumps from above the clamp to one below the highest reachable step; tests and DESIGN.md updated. Nothing compiled
- Files: SubtitleStyle.swift, SubtitlePlacement.swift, SubtitleStyleCard.swift, PlayerView.swift, SubtitleFontTests.swift, SubtitleStyleTests.swift, SubtitleStyleCardTesterUITests.swift, docs/DESIGN.md

## 2026-11-22 04:10 · loop-tester · T-018 · round 2
- Done: read CI 45002423211 (b698119, scope=all). Both jobs green. Simulator 390/390 in 46 min, 0 issues, and every known flake passed. M1 is fixed: Arial Rounded counts as bold again, and both bold-only tests pass
- AC-1/2: Up dims at 13 / 10 / 7 taps (1 / 2 / 3 rows), always at the clamp 68.0 (top bar 60 + 8). Each tap moves the line ~18 pt and Down reads the stored percent. With a stored 85 %, the portrait sheet still goes to 90 %. AC-5: Down from 85 % moves the line 68.0 → 72.67, which is step 12, one below the dimming step 13
- Verdict: Pass, with no Must or Should fix. Could fix: C1, a stale portrait video size with no line showing now also sets the Down jump target. C2, a line taller than the room makes the first Down drop the stored place to 0
- Files: .loop/tasks/T-018-subtitle-style-limits-and-bold-rule.md (Test report round 2); no tests added
- Gotchas: in the artifact, `screenshots/ui-tests/<Attachments.uuid>.txt|png` are the exported attachments; join Attachments → Activities → TestCaseRuns in database.sqlite3 to find which test made each one

## 2026-11-22 · orchestrator · T-018 · landed
- Done: Pass in round 2 (Sonnet builder, Opus tester). Landed as df44e8b. CI 45002423211 (scope=all): ipa green, 390/390 tests. 2 of the 4 CI runs used
- Brent revised AC-3 after round 1 (a 0.0 weight lets the name decide) and added AC-5 (the first Down from above the reachable top jumps)
- Open Could fix, no later task on the board: C1, the video size is measured only while a line shows (fix: measure on videoScreen). C2, a line taller than the room makes the first Down drop to 0. Both go to Brent with the goal summary
- Goal subtitle-style: every task done (T-014, T-015, T-017, T-016, T-018)

## 2026-11-22 13:13 · loop-planner · T-019..T-033 · planning
- Done: turned the approved roadmap (.loop/specs/player-lookup-timeline.md) into 18 task files and issues #21-#38, board order T-019 → T-020 → T-021 → T-022 → T-023 → T-024a → T-024b → T-025 → T-032 → T-033 → T-026 → T-027 → T-028 → T-029a → T-029b → T-030a → T-030b → T-031. Split T-024 (Move-Text menu / Font menu cleanup), T-029 (formatted popup / move-resize-reset) and T-030 (tap-and-hold lookup / Use for a card) into a/b parts
- Left: 3 open questions block T-024a (Q3: centre overlay while Move-Text is open), T-029a (Q1: popup default position) and T-031 (Q2: editor Lookup toggle shared with the player's or its own). Everything else is todo; the first ready tasks are T-019, T-020, T-021, T-032 and T-026
- Files: .loop/tasks/T-019..T-033 (18 new), .loop/BOARD.md (new goal section first; earlier goals under History)
- Gotchas: T-022 seeds `upSteps: 9` (fractions only arrive in T-023). The dictionary fixture JSON must live outside every XcodeGen target (several index.json files in one bundle collide), so T-026 zips them in make-test-media.sh into build/fixtures/dictionaries. After T-020, config.yml `ci.artifacts` needs the new `simulator-results-*` names. UI tests take 34.8 of the 46 CI minutes (45002423211); unit tests are fast

## 2026-11-22 13:40 · loop-planner · T-024a,T-029a,T-029b,T-031 · replan after Brent's answers
- Done: Q1 (popup out of the way: portrait over the subtitle list just above the bottom safe area, landscape top-trailing 16 pt in; also the ↺📄 target), Q2 (editor keeps its own remembered Lookup setting) and Q3 (overlay hidden while Move-Text is open, back on Done) written into T-029a, T-029b, T-031 and T-024a. All four are todo, and the spec's section G lists the answers. Issues #21, #24, #26, #34, #35, #38 updated to match
- Privacy: removed every absolute local path with the user's name from .loop/ (the spec, T-019, and old task files T-002, T-003, T-012, T-018: scratch folders now read `%TEMP%\clip-deck-loop\...`)
- Files: .loop/specs/player-lookup-timeline.md, .loop/tasks/T-019, T-022, T-024a, T-029a, T-029b, T-031, T-002, T-003, T-012, T-018, .loop/BOARD.md
- Gotchas: the old paths are still in git history for the four committed task files; only the working tree is clean

## 2026-11-22 · loop-frontend · T-019 · round 1 (sonnet)
- Done: AppIcon.png replaced by a byte-for-byte copy of the new 1024 px icon; SHA-256 1aed1007...08f8 on both sides. Contents.json unchanged. Nothing compiled
- Files: ios/ClipDeck/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png

## 2026-11-22 14:52 · loop-tester · T-019 · round 1
- Done: read CI 45055876049 (8192e71, scope=all). AC-1 to AC-3 pass. The hashes and `cmp` are identical, and the PNG is 1024×1024 8-bit RGB with no tRNS. The ipa job is green with no AppIcon/actool warning. The IPA has AppIcon60x60@2x.png and Assets.car, and the decoded icon matches the new art (diff 2.49/255; the old placeholder scores 43.12)
- Blocked: the simulator run was 389/390. SubtitleStyleCardTesterUITests/testUpDisablesWhenTheLineCanNoLongerMoveUp lost Up tap 7: in the recording the line never moved and Up stayed enabled. Not caused by the PNG-only diff. NEEDED: re-run `-f scope=tests -f only_testing=ClipDeckUITests/SubtitleStyleCardTesterUITests`
- Files: .loop/tasks/T-019-new-app-icon.md (Test report round 1), .loop/CONTEXT.md (2 Learned lines: this flake, the 57/60-min job); no tests added
- Gotchas: IPA icons are Apple CgBI PNGs (BGRA, raw deflate) and must be decoded before viewing. This xcresult's screen recording blob in Data/ was a plain QuickTime file, not zstd. Without ffmpeg, frames come from headless Chrome over CDP (open a file:// page, seek, Page.captureScreenshot)

## 2026-11-22 16:10 · loop-tester · T-019 · round 1 addendum
- Done: read verify run 45069006816 (8192e71, SubtitleStyleCardTesterUITests only): 4/5. testUpDisablesWhenTheLineCanNoLongerMoveUp passed (Up dims after 13 taps). testFirstDownTap… failed at the known "Seeded show should appear" flake: the library was still empty after 66 s on a slow runner, and the test passed in 45055876049
- Verdict: Pass (REVIEWED_AT 8192e71). Across the two runs, all 390 tests pass on this SHA, and each run's single failure is a pre-existing flake. No run was all green on its own; for one, re-run only testFirstDownTap… (would be CI run 3 of 4)
- Files: .loop/tasks/T-019-new-app-icon.md (Round 1 addendum), .loop/CONTEXT.md (+1 Learned line)
- Gotchas: C: is low on space. I pruned the xcresult Data/ blobs from my %TEMP%\clip-deck-loop\T-019-r1 and -r1v downloads (now 37 MB and 3.6 MB)

## 2026-11-22 · orchestrator · T-019 · landed
- Done: Pass in round 1 (Sonnet builder, Opus tester). Landed as aa89224. CI 45055876049 (scope=all): ipa green, simulator 389/390 (a lost Up tap). Brent approved the re-check: verify run 45069006816 (SubtitleStyleCardTesterUITests only) passed that test, while the known "Seeded show should appear" flake failed in a test that passed in run 1. Every test has a pass on 8192e71. 2 of the 4 CI runs used
- Next: T-020 (split the simulator job, #22). The full job took 57 of its 60 minutes in 45055876049

## 2026-11-22 · loop-backend · T-020 · round 1
- Done: simulator job split into a plan job + 2-shard matrix (shard 1 = unit + 4 UI classes + launch screenshot, shard 2 = other UI classes via -skip-testing); test-ios.sh takes several only/skip values
- Left: CI proving run (scope=all, then only_testing=ClipDeckUITests/LaunchUITests); config.yml ci.artifacts needs simulator-results-1, simulator-results-2
- Files: .github/workflows/ios-simulator.yml, scripts/test-ios.sh, docs/DEVELOPMENT.md, CLAUDE.md, .loop/CONTEXT.md
- Gotchas: only_testing runs shard 1 alone (shard 2 absent); matrix not usable in job-level if, so a plan job builds the matrix

## 2026-11-22 18:17 · loop-tester · T-020 · round 1
- Done: read CI 45070921716 (dc157fa, scope=all). All 4 jobs green. AC-2 passes: shard 1 ran 344 tests (326 unit + 18 UI) and shard 2 ran 46 UI tests, and their union equals the 390 of 45002423211 exactly, with no overlap. `-skip-testing` works with `-only-testing ClipDeckUITests`. AC-1 and AC-5 pass (artifacts simulator-results-1/-2, same layout and the same 72 png / 52 txt exports)
- Fail: M1 (AC-3). Shard 2 took 41:13 against the 35-min limit (shard 1: 27:16). Shard 2 carries 60 % of the UI minutes and got a slow VM (12 min build vs 5.8, UI ×1.22). Fix: move SubtitleStyleUITests (4.0) to SHARD1_UI. Even an ideal two-way split is about 35-37 min on a VM that slow
- AC-4 unverified: needs `-f scope=tests -f only_testing=ClipDeckUITests/LaunchUITests`. Could fix: C1, a new test target would run in no shard; C2, DEVELOPMENT.md repeats the SHARD1_UI list
- Files: .loop/tasks/T-020-split-simulator-job.md (Test report round 1), .loop/CONTEXT.md (+1 Learned); no repo tests added. The test-ios.sh stub harness is in the tester's scratchpad
- Gotchas: Data/ pruned in %TEMP%\clip-deck-loop\T-020-r1 (14 MB left). Job times come from `gh run view <id> --json jobs`; xcresult Actions.started → first Activities.startTime gives the build+boot time

## 2026-11-22 · loop-backend · T-020 · round 2
- Done: three simulator shards (1: unit + 5 UI classes + launch shot; 2: 3 UI classes; 3: skip-list of everything else); docs name the workflow lists instead of repeating them
- Left: re-proving run scope=all, then the only_testing run; config.yml ci.artifacts -> simulator-results-1, -2, -3, ClipDeck-ipa
- Files: .github/workflows/ios-simulator.yml, docs/DEVELOPMENT.md, CLAUDE.md, .loop/CONTEXT.md
- Gotchas: shard 3 has no -only-testing, so unknown targets run there

## 2026-11-22 19:10 · loop-tester · T-020 · round 2
- Done: read CI 45083671012 (557d9d2, scope=all) and dispatched/read 45086461824 (scope=tests, only_testing=ClipDeckUITests/LaunchUITests; CI run 3 of 4). AC-2 passes: 342 + 20 + 28 = 390, identical to 45002423211, no overlap, and shard 3 (skip-only) ran no unit tests. AC-1, AC-4 (one job, one test, ipa skipped) and AC-5 pass. All three shards are under 35 min (20:23 / 28:28 / 27:41)
- Fail: S1 (Should fix, stale docs): workflow:14 says "(two shards)", and CONTEXT.md:31 lists only `-1`/`-2`. A one-word, behaviour-free fix
- Blocked part of AC-3 (green): 3 pre-existing UI failures (FontTester "Seeded show", About notice, a lost Done tap in SubtitleUpLimitTester). NEEDED `gh run rerun 45083671012 --failed`. Could fix: C3 (an empty SHARD2_UI makes shard 2 run everything), C4 (a whitespace-only only_testing runs all tests in one job)
- Files: .loop/tasks/T-020-split-simulator-job.md (Test report round 2), .loop/CONTEXT.md (+2 Learned); no repo tests added
- Gotchas: run 4 of 4 is left. A rerun of failed jobs shares the `ios-<ref>` concurrency group, so don't dispatch on the branch while it runs. Data/ pruned in %TEMP%\clip-deck-loop\T-020-r2 (37 MB left)

## 2026-11-22 · loop-backend · T-020 · round 3
- Done: stale "two shards" input text fixed, CONTEXT lists simulator-results-3, plan job trims only_testing and omits an empty shard 2
- Files: .github/workflows/ios-simulator.yml, .loop/CONTEXT.md
- Gotchas: jq not available locally, so the matrix expression was only read

## 2026-11-22 19:50 · loop-tester · T-020 · round 3
- Done: read CI 45087727557 (7c79c7c, scope=all, run 4 of 4). AC-1, AC-2 (342 + 20 + 28 = 390, identical to 45002423211, 0 overlap), AC-4 and AC-5 pass. All shards are under 35 min (26:43 / 18:01 / 29:27), and the launch step ran in shard 1. S1, C3 and C4 are fixed: I ran the plan step locally with a gojq-backed jq shim (it matches the real CI matrices), and mutants of the old code bring back both bugs
- Blocked: shard 2 failed on the known flake PlayerLandscapeBehaviourUITests/testControlsStayWhilePausedAndAutoHideWhilePlaying. The 6-s sample played to its end during a 6-s Play tap on a slow VM (slider 6,000, button "Play" at failure). Round 2's three flakes all passed. NEEDED: `gh run rerun 45087727557 --failed` (shard 2 only; this is beyond the budget, so Brent decides)
- Files: .loop/tasks/T-020-split-simulator-job.md (Test report round 3), .loop/CONTEXT.md (+1 Learned); no repo tests added
- Gotchas: no jq locally. `gh api rate_limit --jq '"v" as $x | <filter>'` runs real jq semantics (gojq sorts keys, so compare parsed JSON). Data/ pruned in %TEMP%\clip-deck-loop\T-020-r3 (20 MB left)

## 2026-11-22 20:05 · loop-planner · T-034 · planning change
- Done: added T-034 "Harden the known flaky tests" (#39, backend, depends on T-021), on the board right after T-021 so it runs before T-022. Scope: every flake in CONTEXT "Learned" plus T-021's new overlay timing tests. Done when: shared UI-test helpers, nothing lost (same test-name set as T-021's landing run), one green scope=all run (a rerun of only the failed job counts)
- Left: nothing blocks it. T-020's task file was not touched
- Files: .loop/tasks/T-034-harden-flaky-ui-tests.md, .loop/BOARD.md
- Gotchas: likely root cause of the "Seeded show should appear" flake and both unit-test timeouts: TestMediaFactory.waitUntilReady gives up after about 5 s (1,000 × 5 ms) and throws .timedOut. The seeder then seeds nothing, so a longer wait alone can't fix it. Traced from the code, not proven; the builder confirms it from the app output in the xcresult

## 2026-11-22 20:16 · loop-tester · T-020 · round 3 addendum
- Done: watched the approved re-run `gh run rerun 45087727557 --failed` (attempt 2, CI run 5). Shard 2 went green on 7c79c7c in 19:59 (20/20), and testControlsStayWhilePausedAndAutoHideWhilePlaying passed in 35 s. The run's conclusion is success with all jobs green
- Verdict: Pass. Every criterion is met. Final union 342 + 20 + 28 = 390, identical to 45002423211, all Success. Shard times 26:43 / 19:59 / 29:27
- Files: .loop/tasks/T-020-split-simulator-job.md (Round 3 addendum); no repo tests added
- Gotchas: after a rerun, the run has two `simulator-results-2` artifacts, so download the new one by ID (`gh api repos/{owner}/{repo}/actions/artifacts/<id>/zip`); `gh run download -n` is ambiguous. %TEMP%\clip-deck-loop\T-020-r3 is pruned (26 MB)

## 2026-11-23 · orchestrator · T-020 · landed
- Done: Pass in round 3 (Sonnet builder, Opus tester). Landed as 9f73098. CI 45087727557 (scope=all, final commit) was all green after Brent approved re-running shard 2 (CI run 5, one past the budget); 390/390 tests run once each; shards took 26:43, 19:59 and 29:27. AC-4 was proven by 45086461824 (one job, one test)
- Brent's decisions: three UI shards instead of two (after round 1's 41 min shard), Sonnet retries, and one full run on the final commit
- config.yml `ci.artifacts` is now simulator-results-1/-2/-3 + ClipDeck-ipa. After a re-run there are two artifacts with the same name, so download by artifact ID
- Planning change: Brent added T-034 (harden the known flaky tests, #39) after T-021, before T-022
- Open for Brent, not planned: xcodebuild `-retry-tests-on-failure` (hides real flakes)
- Next: T-021 (centred playback overlay, #23)

## 2026-11-23 · loop-frontend · T-021 · round 1
- Done: centred ⟲5 ⏯ 5⟳ overlay in both orientations (portrait has its own state, a video tap toggles it and no longer plays); bar play/pause aqua only while paused with value Playing/Paused; ±5 s and `skips:` removed; landscape bar now has 3 ViewThatFits variants with comments marking the T-024a/T-029b/T-030a spots
- Left: CI proof (nothing compiled locally); T-022 makes the line avoid the overlay band
- Files: ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckUITests/PlaybackOverlayUITests.swift (new), ios/ClipDeckUITests/PlayerLandscapeBehaviourUITests.swift, .github/workflows/ios-simulator.yml (PlaybackOverlayUITests -> SHARD1_UI), docs/DESIGN.md
- Gotchas: scrubber elapsed text has id `player.currentTime`; skips are tested from 0:00 (the 6 s clip would clamp them from 3 s)

## 2026-11-22 20:58 · loop-tester · T-021 · round 1
- Done: read CI 45094204439 (7034c69, scope=all). ipa and shards 2/3 green; every pre-existing test passed (398/401 runs; name set = T-020's plus 11 new tests and the rename). AC-1, AC-3 and AC-5 pass on run evidence: overlay centres within 0.2 pt of 25/50/75 % at column widths 874/624.7/504.7/437, white glyphs on exactly 50 % black circles (pixels), bar order from frames
- Fail: M1. Shard 1 red on 3 new tests (`testBarPlayPauseValuePortrait/Landscape`, `testOverlayHidesWhilePlayingAndStaysWhilePausedLandscape`). The app's UI froze during playback on that VM (recordings: elapsed stuck while the video played; idle waits 6.4/15 s), so the 6 s clip ended before each check. No app defect found, but the tests are new. Could fix: the style card at 50 % cuts the overlay row; no T-030a marker by the panel's Make a Card
- Files: .loop/tasks/T-021-playback-overlay-and-bars.md (Test report round 1), .loop/CONTEXT.md (+2 Learned), ios/ClipDeckUITests/PlaybackOverlayTesterUITests.swift (new, 10 tests, not yet run; commit it with round 2)
- Gotchas: Data/ pruned in %TEMP%\clip-deck-loop\T-021-r1 (42 MB). The xcresult's database.sqlite3 has the failure text (TestIssues) and step timings (Activities); recording frames came from headless Chrome over CDP with Node 26

## 2026-11-23 · loop-frontend · T-021 · round 2
- Done: M1 fixed with `-uiTestingSampleSeconds <n>` (overlay tests use a 30 s clip); AC-7 overlay hides while the landscape style card is open; T-030a marker at the side panel; tester's PlaybackOverlayTesterUITests kept (30 s clip where it plays) and put in SHARD2_UI
- Files: ios/ClipDeck/App/ClipDeckApp.swift, ios/ClipDeck/App/RootView.swift, ios/ClipDeck/Features/Player/PlayerView.swift, ios/ClipDeckUITests/PlaybackOverlayUITests.swift, ios/ClipDeckUITests/PlaybackOverlayTesterUITests.swift, .github/workflows/ios-simulator.yml, CLAUDE.md, docs/DESIGN.md
- Gotchas: paused skip tests still use the 6 s clip on purpose (end clamp)

## 2026-11-22 23:47 · loop-tester · T-021 · round 2
- Done: read CI 45110218499 (c1b6f0d, scope=all, CI run 2 of 4). All jobs green: 412/412 runs, 375 names (round 1's 364 plus 11 new), none lost, 0 issues. Shards took 21:47, 32:00 and 20:59. AC-1 to AC-7 pass on run evidence. M1 (clip end), C1 (AC-7: no overlay in all 12 card frames; 7034c69 had it in 5) and C2 (marker) are fixed. The 30 s seed costs 2–6 s of the 30 s "Seeded show" wait
- Fail: S1, DESIGN.md:95/:98 still say the landscape overlay is up with the style card open (and always under VoiceOver). S2, `testBarPlayPauseValueLandscape` reads the bar 0.64 s before its 3 s auto-hide; 5 of 17 past landscape Play taps had idle waits long enough to fail it (the same pattern is in checkSkipsAndPlayPause)
- Could fix: C1 stale "6 s" comments and the MKV doc comment now on `sampleSeconds`; C2 testScreenshotsDark stays light on CI; C3 shard 2 at 32:00 (6:40 was one test's 60 s idle stalls)
- Files: .loop/tasks/T-021-playback-overlay-and-bars.md (Test report round 2), .loop/CONTEXT.md (+3 Learned); no tests added
- Gotchas: evidence in %TEMP%\clip-deck-loop\T-021-r2 (Data/ pruned, 16 MB). Exported attachments map to tests through Attachments.uuid → Activities → TestCaseRuns in database.sqlite3; the step-timing scripts are idle.py, seed.py and tree.py in the session scratchpad

## 2026-11-23 · loop-frontend · T-021 · round 3
- Done: S1 DESIGN.md consistent (overlay hides for everyone with the Aa card open); S2 bar/overlay "Playing" reads made direct with bounded re-show; C1 comments (ClipDeckApp.swift comments only); C2 removed testScreenshotsDark and the KVC appearance code (it never went dark on CI)
- Files: docs/DESIGN.md, ios/ClipDeck/App/ClipDeckApp.swift (comments), ios/ClipDeckUITests/PlaybackOverlayUITests.swift, ios/ClipDeckUITests/PlaybackOverlayTesterUITests.swift
- Gotchas: test name set loses testScreenshotsDark

## 2026-11-23 00:20 · loop-tester · T-021 · round 3
- Done: confirmed the change from c1b6f0d to ec96444 is comments only in ClipDeckApp.swift (identical with comment lines removed), so 45110218499 (412/412, ipa) still covers the product. Read targeted CI 45114494368 (run 3 of 4): it compiled; all 12 PlaybackOverlayUITests passed; S2 fixed (readValue reads 0.08–0.27 s after Play, round 2 read at 2.36 s); S1 fixed (DESIGN.md:95/97/98 match `shown && !styleMenuOpen`); dropping testScreenshotsDark is fine against the ACs (dark mode stays Unverified)
- Blocked: the first 3 PlaybackOverlayTesterUITests failed at launch on a cold VM ("Seeded show should appear" ×2, "Failed to get background assertion" ×1). These are pre-existing flakes in tests round 3 left unchanged, and all 3 passed in 45110218499. NEEDED: commit the tester test, then dispatch the same targeted run (CI run 4 of 4); otherwise `gh run rerun 45114494368 --failed`
- Could fix: readValue exists/value/label are 3 queries (use `try? element.snapshot()`), and waitForExistence after a re-show uses about 1 s of the 3 s window; the tester class comment still says a 6 s video
- Files: .loop/tasks/T-021-playback-overlay-and-bars.md (Test report round 3), .loop/CONTEXT.md (+1 Learned), ios/ClipDeckUITests/PlaybackOverlayUITests.swift (+testBarValueIsReadAfterTheBarHidLandscape, exercises the readValue fallback, not yet run)
- Gotchas: T-034 AC-4 name set = 45110218499 minus testScreenshotsDark (plus the new test if committed). Evidence in %TEMP%\clip-deck-loop\T-021-r3 (Data/ pruned, 12 MB); readvalue.py is in the session scratchpad

## 2026-11-23 00:45 · loop-tester · T-021 · round 3 addendum
- Done: read the verify run CI 45117390680 (c971174 = ec96444 + the tester test; scope=tests, the overlay classes, CI run 4 of 4). It is green: 22/22 tests, 0 build issues, 16:39. The 3 tests that flaked in 45114494368 passed and ran to their checks. testBarValueIsReadAfterTheBarHidLandscape passed on the fallback path (the bar was gone 3.02 s after Play, readValue tapped the video, read "Playing"/"Pause" 1.1 s later)
- Verdict: Pass. AC-1 to AC-7 met; S1 and S2 fixed. The product code equals c1b6f0d, so 45110218499 (412/412, ipa) is the full-suite evidence. C1 (readValue makes 3 separate queries, and waits about 1 s after a re-show) and C2 (tester comment) stay Could fix, and T-034 can take C1
- Files: .loop/tasks/T-021-playback-overlay-and-bars.md (Round 3 addendum); no further test changes
- Gotchas: the T-034 AC-4 name set for the landed commit is 375 names: 45110218499 minus testScreenshotsDark, plus testBarValueIsReadAfterTheBarHidLandscape. In targeted runs the first test still meets a slow cold start (about 55 s this time). Evidence is in %TEMP%\clip-deck-loop\T-021-r3\verify (Data/ pruned)

## 2026-11-23 · orchestrator · T-021 · landed
- Done: Pass in round 3 (Sonnet builder, Opus tester). Landed as e845306. CI 45110218499 (scope=all, same app code): ipa green, 412/412. CI 45117390680 (both overlay classes, final commit): 22/22. All 4 CI runs used
- Brent's decisions: Sonnet retries; a Debug-only `-uiTestingSampleSeconds` flag (overlay tests use 30 s) instead of retry-and-skip; new AC-7 (the landscape overlay hides while the Aa card is open, for everyone, VoiceOver included); the tester's PlaybackOverlayTesterUITests in SHARD2_UI
- Open Could fix C1/C2 (readValue snapshot, a stale 6 s comment) moved to T-034's Agent notes, with the reused flag, the 375-name baseline and the auto-hide race cause
- Unverified for Brent: fade feel and readability on bright scenes, Reduce Motion, VoiceOver, landscape bar variant 3 (narrow phones), dark mode
- Next: T-034 (harden the known flaky tests, #39)

## 2026-11-23 · loop-backend · T-034 · round 1 (sonnet; entry written by the orchestrator)
- Done: a shared UITestSupport helper (launchSeeded with relaunch, tapStep with a stored-value check, readTogether, and others); the 17 seeded-show waits moved to it; TestMediaFactory uses a 60 s time deadline and the seeder tries twice (DEBUG only); About, the lost-tap tests and the PlayerLandscapeBehaviour clip tests hardened; T-021 C1/C2
- Left: the AC-2 seed cause is unconfirmed (no app stdout in the pruned xcresults); the AC-3 idle stall is not fixed (it starts after the landscape rotation; cause unknown)
- Files: ios/ClipDeckUITests/UITestSupport.swift (new), TestMediaFactory.swift, RootView.swift, 13 UI test files, docs/DEVELOPMENT.md, .loop/CONTEXT.md

## 2026-11-23 01:30 · loop-tester · T-034 · round 1
- Done: read CI 45119953687 (8d036e0, scope=all, CI run 1 of 4). It compiles (0 build issues); ipa and shard 2 green; 410/412 runs; the name union is exactly the 375-name landing set (AC-4). Shards took 29:33, 26:16 and 24:22. AC-2 seed cause confirmed: the old failures were a seed that threw (an empty library), and in this run a seed still running at 44 s (no "UITestSeeder failed") was rescued by launchSeeded's relaunch
- Fail: M1, PlaybackOverlayUITests/testBarValueIsReadAfterTheBarHidLandscape (shard 1). The idle stall started right after the rotation and the 30 s clip ended during the Play tap's 60 s idle wait. S1, AboutUITests launches twice (+70 s in one test). S2, testOpenSubtitlesMenu… still races the 3 s auto-hide (menu tap ends 1.8-3.3 s after Play). Shard 3's ExpiryBanner "Failed to terminate" at launch is pre-existing
- Files: .loop/tasks/T-034-harden-flaky-ui-tests.md (Test report round 1), .loop/CONTEXT.md (+2 Learned); no tests added
- Gotchas: the app's stdout is in the xcresult (Diagnostics blobs; see CONTEXT); the stalled app keeps idling its main run loop but never answers "animations idle" again. M1's fix may need Brent's call (a stall guard that relaunches is close to a retry). Evidence: %TEMP%\clip-deck-loop\T-034-r1 (Data/ pruned, 23 MB); scripts: %TEMP%\clip-deck-loop\tools-T-034

## 2026-11-23 02:31 · loop-backend · T-034 · round 2 (opus)
- Done: M1 traced to XCTest's UIView-animation ledger (one started UIView animation never reports a stop, right after a portrait-to-landscape player rotation; 6 of 375 rotations in 25 xcresults). It is not an app loop, and the view is not identified, so there is no product change. Added the setup stall guard `UITestSupport.rotateToLandscape` in all 17 setup rotations: a same-orientation probe (only XCTest's idle wait), and one terminate plus relaunch when over 50 s, logged as an activity, an `idle-stall-guard` attachment and stdout. test-ios.sh turns those into GitHub warnings "UI test idle stall". Added a DEBUG `-uiTesting` `UITestAnimationWatch` that prints animations stuck on a layer for 3 s or more. S1 (About launches once), S2 (re-show the bar before the menu tap), C1 (20 s clip) done
- Left: CI proof (not compiled). If the guard fires, the watch lines name the stuck animation, or show none, meaning its layer left the window; then fix the cause in PlayerView. Mid-test rotations (6) stay unguarded
- Files: ios/ClipDeckUITests/UITestSupport.swift + 10 UI test files, ios/ClipDeck/App/UITestAnimationWatch.swift (new), ios/ClipDeck/App/ClipDeckApp.swift, scripts/test-ios.sh, docs/DEVELOPMENT.md, CLAUDE.md, .loop/CONTEXT.md (+1 Learned)
- Gotchas: setting the orientation the device already has costs about 0.01 s and is just a "Wait for idle", a handy idle probe. stallscan.py and idlemap.py are now in %TEMP%\clip-deck-loop\tools-T-034. Test names unchanged (86 UI, 289 @Test)

## 2026-11-23 03:11 · loop-tester · T-034 · round 2
- Done: read CI 45132085072 (04ceed0, scope=all, CI run 2 of 4). All green on the first attempt: ipa 2:11, shards 23:23 / 28:07 / 21:30, 412/412 runs, 0 issues. The name union is the 375-name landing set (I rebuilt it from 45110218499). S1 and S2 are fixed, C1 is done, and every AC-2 test passed, round 1's failing overlay test included
- Verdict: Pass. AC-3 is met on its wording only: the cause is narrowed to a UIKit animation and not fixed. No stall occurred, so the guard never fired (0 activities, attachments or warnings). Its 40 probes took 0.01–0.38 s, and each probe sends a real animations-idle request. The relaunch branch is still unexercised
- Watch: it started in every `-uiTesting` process, and the Release IPA has none of its strings. 436 of 442 lines are Liquid Glass match-animation noise (Could fix C1). Its only `UIViewAnimationState` lines were a 0.35 s push held by a 20 s main-thread freeze, which cleared
- Files: .loop/tasks/T-034-harden-flaky-ui-tests.md (Test report round 2), .loop/CONTEXT.md (+1 Learned); no tests added
- Gotchas: evidence is in %TEMP%\clip-deck-loop\T-034-r2 (Data/ pruned, 29 MB: filtered app logs, gzipped full stdout, job logs, IPA). probes.py (rotation and probe timings, guard activities) is now in tools-T-034

## 2026-11-23 · orchestrator · T-034 · landed
- Done: Pass in round 2 (round 1 Sonnet, round 2 Opus by Brent's choice; Opus testers). Landed as d3c4fa2. CI 45132085072 (scope=all): every job green on the first attempt, 412/412 runs, 375 names (the T-021 landing set), shards 23:23 / 28:07 / 21:30. 2 of the 4 CI runs used
- Seed flake cause confirmed (a slow test video writer) and fixed. The idle stall is narrowed to a UIKit rotation animation that never stops; it is guarded (relaunch once, CI warning "UI test idle stall") and has a DEBUG diagnostic (UITestAnimationWatch), but no product fix. No stall happened in the proving run, so the guard's relaunch branch is unproven
- Could fix C1 (filter the Liquid Glass noise out of the watch) and C2 (6 unguarded mid-test rotations) moved to T-022's Agent notes
- Disk: C: has about 127 GB free now, so the "nearly full" warning is out of date
- Next: T-022 (subtitles avoid the overlay, #24)
