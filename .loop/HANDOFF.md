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
