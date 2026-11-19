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
