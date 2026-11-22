---
id: T-020
title: Split the simulator job
lane: backend
depends_on: []
status: todo
round: 0
base_sha:
issue: 22
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Run the UI tests in two parallel CI jobs so a full run takes about half as long

### What are we building?
One simulator job runs all 390 tests, and on the last run (CI 45002423211) it took 46 of its 60 minutes. This goal adds many UI tests, so the job would soon time out. After this task the UI tests run in two parallel jobs, and a full run finishes in under 35 minutes per job.

### Why?
Every task in this goal needs a green full CI run. Faster runs make each loop round quicker, and no task fails on the timeout instead of on its code.

### Done when
- AC-1 `.github/workflows/ios-simulator.yml` runs `ClipDeckUITests` in two parallel simulator jobs (a matrix with `fail-fast: false` is fine). `ClipDeckTests` and the "Launch in simulator and screenshot" step run in one of them. The ipa job is unchanged.
- AC-2 No test is lost or run twice. Shard 1 is an explicit list of UI test classes. Shard 2 is every other UI class (`-skip-testing` the shard-1 classes), so a new class always runs somewhere. In the proving run, the jobs together run every test of the last single-job run exactly once (390: 326 unit + 64 UI, from CI 45002423211), plus any test the diff adds.
- AC-3 With `-f scope=all` every job is green, and each simulator job takes under 35 minutes of wall time, build included.
- AC-4 The `scope` and `only_testing` inputs keep working. `scope=tests` runs only the simulator jobs, and `scope=ipa` runs only the ipa job. A non-empty `only_testing` runs just that filter in a single job, and the other shard is skipped, not failed.
- AC-5 Each simulator job uploads its own artifact. The names are unique and start with `simulator-results` (for example `simulator-results-1` and `simulator-results-2`), and the contents are the same as today (screenshots, xcresult). docs/DEVELOPMENT.md (Tests/CI) and CLAUDE.md ("Verifying changes") describe the jobs, the shard rule and the artifact names.

### How to check
1. The orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`. Watch with `gh run watch <id> -i 60 --exit-status`.
2. `gh run view <id> --json jobs -q '.jobs[] | "\(.name) \(.conclusion) \(.startedAt) \(.completedAt)"'` gives the time of each job.
3. `gh run download <id> -p 'simulator-results*' -D <scratch>`. Count the test cases in each xcresult (`database.sqlite3`, the TestCaseRuns table, joined to TestCases and TestSuites), and compare the union with the 390 tests of 45002423211.
4. One extra run, `-f scope=tests -f only_testing=ClipDeckUITests/LaunchUITests`, proves AC-4: one job runs one test.

### Agent notes
- Depends on: none. Source: spec "CI capacity" (T-020) and section G default 8.
- `scripts/test-ios.sh` takes only one `-only-testing` value today (lines 25-26). Extend it to take several `-only-testing` and `-skip-testing` values, for example through space-separated `ONLY_TESTING`/`SKIP_TESTING` env vars. `./scripts/test-ios.sh ClipDeckTests` must keep working.
- UI class durations in 45002423211, in minutes: About 4.4, SubtitleStyle 4.0, SubtitleStyleCardTester 3.7, PlayerLandscapeBehaviour 3.6, PlayerLandscape 2.9, SubtitleFontTester 2.8, SubtitleStyleCard 2.8, ExpiryBanner 2.3, SubtitleUpLimitTester 2.0, SubtitleStyleSheetTester 1.5, SubtitleFont 1.3, MKVImport 1.2, SubtitleStyleTester 1.2, MiningFlow 0.7, Launch 0.3. That's 34.8 for the UI tests; the unit tests are fast. Balance the shards from these numbers. New UI classes from later tasks land in shard 2 automatically.
- Both jobs need ffmpeg, the fixtures from `scripts/make-test-media.sh`, and `TEST_RUNNER_CLIPDECK_FIXTURES`. Keep `concurrency` and the 60-minute `timeout-minutes` on each job.
- Don't edit `.loop/config.yml`, which the orchestrator owns. Say in your notes that `ci.artifacts` needs the new names, and add a CONTEXT "Learned" line with the job and artifact names.
- The known flakes and the artifact-upload timeout are in CONTEXT "Learned". Re-run before treating either as a failure.

### Out of scope
- Sharing build products between jobs, test plans, parallel simulators inside one job, DerivedData caching.
- Changing any test.
