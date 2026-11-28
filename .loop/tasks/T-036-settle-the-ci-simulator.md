---
id: T-036
title: Let the CI simulator settle before the UI tests start
lane: backend
depends_on: []
status: testing
round: 1
base_sha: f9ff1cef624376575a0c212c0545c038ff772c39
issue: 41
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Let the CI simulator settle before the UI tests start

### What are we building?
`scripts/test-ios.sh` boots the simulator first, builds with `build-for-testing`, waits until the simulator has been up for `SETTLE_SECONDS` (660 on CI, 0 locally), then runs `test-without-building`.

### Why?
Every early-run flake today came 7–10 min after the simulator booted, which is 0.7–2.7 min into testing, because xcodebuild boots it only 6–7 min before the tests start:
- the Apple Intelligence banner over the Move-Text card (46102226923, 46118672166);
- "Failed to terminate dev.brent.clipdeck" (46128345124 shard 3, 1.8 min in);
- "Failed to get screenshot: Timed out" (46130387082, 2.7 min in).

### Done when
- AC-1 The simulator boots before xcodegen, the fixtures and the build. A simulator that was already booted (a local machine) doesn't wait.
- AC-2 The tests start no earlier than `SETTLE_SECONDS` after the boot, which defaults to 660 when `CI` is set and 0 otherwise. The script prints how long it waited.
- AC-3 The exit status, the result bundle, the screenshot export and the guard warnings work as before. A full CI run is green.

### Agent notes
- Brent (2026-11-28): fix the T-027 and T-028 failures. This is the shared cause, kept on its own branch. T-035's banner guard stays as the safety net.

## Implementation notes (round 1) · orchestrator
- scripts/test-ios.sh: picks and boots the simulator before xcodegen, the fixtures and the build (`BOOTED_AT` is set only if this boot succeeded, so an already booted local simulator never waits); `build-for-testing`, then sleeps until `SETTLE_SECONDS` after the boot (660 on CI, 0 locally), then `test-without-building` with the same result bundle and filters. Exit status, screenshot export and guard warnings are unchanged.
- docs/DEVELOPMENT.md: `SETTLE_SECONDS` row. Checked: `bash -n`, the default (660 with CI=true, 0 without).
