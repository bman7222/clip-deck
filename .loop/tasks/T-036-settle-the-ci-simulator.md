---
id: T-036
title: Let the CI simulator settle before the UI tests start
lane: backend
depends_on: []
status: done
round: 2
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
- CI: run 46137995899 (12aee3a, scope=all): shards 1, 2, 4 and the IPA green, no early-boot failure in any shard (tests started 660 s after boot). Shard 3: one failure, `MoveTextTesterUITests.testOpeningTheCardPausesPlaybackAndDoneResumesLandscape` "The card opens while the video plays".

## Fix round 2 · orchestrator
- Cause (screen recording + UI snapshots of run 46137995899): not boot churn. The landscape bars were on screen 42–44 s into the test, but each element query took 1–2.5 s on that runner, so `openCardWhilePlaying` lost the race against the 3 s auto-hide on all three tries: its first try saw ✥A mid-fade (`isHittable` false) and skipped the tap, and its 2 s existence waits missed the 3 s window.
- Fix: `UITestSupport.tapBarButtonWhilePlaying` (the T-034 S2 loop from PlayerLandscapeBehaviourUITests, moved and shared): polls every 0.05 s after a video tap and taps the button where its snapshot was read, with no hittable check, so a bar that hid in between only costs one try. MoveTextTesterUITests (2 callers) and PlayerLandscapeBehaviourUITests use it; both local copies deleted.
- CI: run 46144815509 (9d3eccc, scope=tests): all four shards green; the IPA was green in round 1 and round 2 changes only UI tests.

## Test report (round 2)
_by loop-tester · 2026-11-28_

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 boot before xcodegen/fixtures/build; already-booted sim never waits | Pass | scripts/test-ios.sh:22-27 boot precedes xcodegen; `BOOTED_AT` is set only when `simctl boot` succeeds, and the wait is guarded by `-n "$BOOTED_AT"` (no unset use under `set -u`) |
| AC-2 tests start no earlier than SETTLE_SECONDS after boot; default 660 on CI, else 0; prints the wait | Pass | Ran the default expression: CI unset -> 0, CI=x -> 660; CI 46137995899 log "Letting the simulator settle for 167s more (boot to tests: 660s)" |
| AC-3 exit status, result bundle, screenshot export, guard warnings unchanged; full CI green | Pass | Diff leaves the tail untouched; FILTER and `-resultBundlePath` are only on `test-without-building`; `bash -n` OK; round 1 shards 1,2,4 + IPA green, round 2 run 46144815509 all four shards green |
| Round 2: shard 3 flake fixed | Pass | `UITestSupport.tapBarButtonWhilePlaying` checks `opened.exists` first each try, so an open menu or card is never tapped away; 3 callers updated, both local copies removed; run 46144815509 green |

### Findings
Could fix: scripts/test-ios.sh:~51. A build-for-testing failure ends with "Tests FAILED", which is slightly misleading. The exit status is correct.

```text
VERDICT: Pass
SPEC: AC-1, AC-2, AC-3 met
CHECKS_RUN: bash -n scripts/test-ios.sh -> ok; default SETTLE_SECONDS expression -> 0 / 660; CI 46137995899 and 46144815509 (read by the orchestrator, not re-run)
UNVERIFIED: a local run with an already-booted simulator (needs a Mac)
REVIEWED_AT: bfa7972
```
