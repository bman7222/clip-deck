---
id: T-020
title: Split the simulator job
lane: backend
depends_on: []
status: done
round: 3
base_sha: e7717eead7533464bae33bb495c50788b6a24c12
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
- AC-1 `.github/workflows/ios-simulator.yml` runs `ClipDeckUITests` in three parallel simulator jobs (a matrix with `fail-fast: false` is fine; Brent changed this from two to three on 2026-11-22 after round 1). `ClipDeckTests` and the "Launch in simulator and screenshot" step run in one of them. The ipa job is unchanged.
- AC-2 No test is lost or run twice. Shards 1 and 2 are explicit lists of UI test classes. Shard 3 is every other UI class (`-skip-testing` the shard-1 and shard-2 classes), so a new class always runs somewhere. In the proving run, the jobs together run every test of the last single-job run exactly once (390: 326 unit + 64 UI, from CI 45002423211), plus any test the diff adds.
- AC-3 With `-f scope=all` every job is green, and each simulator job takes under 35 minutes of wall time, build included.
- AC-4 The `scope` and `only_testing` inputs keep working. `scope=tests` runs only the simulator jobs, and `scope=ipa` runs only the ipa job. A non-empty `only_testing` runs just that filter in a single job, and the other shard is skipped, not failed.
- AC-5 Each simulator job uploads its own artifact. The names are unique and start with `simulator-results` (for example `simulator-results-1`, `-2` and `-3`), and the contents are the same as today (screenshots, xcresult). docs/DEVELOPMENT.md (Tests/CI) and CLAUDE.md ("Verifying changes") describe the jobs, the shard rule and the artifact names.

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

## Implementation notes (round 1)
_by loop-backend · 2026-11-22_
- Changed: new `plan` job (ubuntu, jq) emits the matrix. No only_testing: shard 1 = `ClipDeckTests` + AboutUITests, SubtitleStyleCardTesterUITests, PlayerLandscapeUITests, SubtitleFontTesterUITests (about 13.8 UI min) and the launch screenshot; shard 2 = `ClipDeckUITests` with `-skip-testing` of those four (about 21 UI min). Non-empty only_testing: matrix has just shard 1 with that filter (shard 2 is absent, not failed), no screenshot step as before. `simulator` job is a `fail-fast: false` matrix, 60 min timeout and concurrency kept, artifacts `simulator-results-1` / `simulator-results-2`. ipa job untouched. `scope` gates both `plan` and `simulator`, so scope=ipa skips them.
- `test-ios.sh`: positional args (several allowed) plus `ONLY_TESTING` / `SKIP_TESTING` space-separated env vars become repeated `-only-testing` / `-skip-testing`. `./scripts/test-ios.sh ClipDeckTests` unchanged.
- Files: .github/workflows/ios-simulator.yml, scripts/test-ios.sh, docs/DEVELOPMENT.md, CLAUDE.md, .loop/CONTEXT.md.
- Checked: nothing runnable here (no Mac); only read through the YAML and shell. `bash -n` on test-ios.sh below.
- Tester, look at: the plan job output (matrix JSON in its log); that `-only-testing ClipDeckUITests -skip-testing ClipDeckUITests/X` skips X on this Xcode (if skip is ignored, tests run twice: count the xcresult union against 390); per-job time (shard 1 carries the unit tests, so it is the longer one if the unit tests exceed about 10 min); the `matrix.screenshot` boolean `if`.
- Gotchas: `ci.artifacts` in .loop/config.yml must become `[simulator-results-1, simulator-results-2, ClipDeck-ipa]` (orchestrator). The matrix context isn't allowed in job-level `if`, hence the plan job.

## Test report (round 1)
_by loop-tester · 2026-11-22 18:17_

Run under test: CI 45070921716 (dc157fa, `scope=all`). Conclusion success. Jobs: plan 0:03, ipa 2:02, simulator (shard 1) 27:16 (21:14:00 → 21:41:16), simulator (shard 2) 41:13 (21:14:01 → 21:55:14). Artifacts are in `%TEMP%\clip-deck-loop\T-020-r1` (xcresult Data/ pruned; database.sqlite3 and screenshots kept).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `.github/workflows/ios-simulator.yml` runs `ClipDeckUITests` in two parallel simulator jobs (a matrix with `fail-fast: false` is fine). `ClipDeckTests` and the "Launch in simulator and screenshot" step run in one of them. The ipa job is unchanged. | Pass | 45070921716: the two shards started 1 s apart and ran in parallel (`fail-fast: false`, workflow:66-67). Shard 1's xcresult has all 326 ClipDeckTests runs and shard 2's has none. The launch step ran in shard 1 (`screenshots/launch-20261122-213931.png`, the empty library) and was skipped in shard 2. `git diff e7717ee dc157fa` has no hunk in the ipa job, and ipa was green. |
| AC-2 No test is lost or run twice. Shard 1 is an explicit list of UI test classes. Shard 2 is every other UI class (`-skip-testing` the shard-1 classes), so a new class always runs somewhere. In the proving run, the jobs together run every test of the last single-job run exactly once (390: 326 unit + 64 UI, from CI 45002423211), plus any test the diff adds. | Pass | Plan log matrix: shard 1 `only` = ClipDeckTests + the 4 classes of `SHARD1_UI` (workflow:45); shard 2 `only` = ClipDeckUITests, `skip` = the same 4. xcresult TestCaseRuns: shard 1 has 344 (326 unit + About 3, SubtitleStyleCardTester 5, PlayerLandscape 6, SubtitleFontTester 4), and shard 2 has 46 across the other 11 classes. The union is 390, multiset-equal to 45002423211 (by target and test identifier): 0 in both shards, 0 missing, 0 extra, all 390 Success. The diff adds no tests. Revert check: base `test-ios.sh` given the shard env vars passes no `-only-testing`/`-skip-testing` at all (stub harness), so both shards would run all 390 and the count would show 780. |
| AC-3 With `-f scope=all` every job is green, and each simulator job takes under 35 minutes of wall time, build included. | **Fail** | All 4 jobs green. Shard 1 took 27:16, but shard 2 took **41:13** (its "Unit and UI tests" step ran 21:15:11 → 21:54:51). See M1. |
| AC-4 The `scope` and `only_testing` inputs keep working. `scope=tests` runs only the simulator jobs, and `scope=ipa` runs only the ipa job. A non-empty `only_testing` runs just that filter in a single job, and the other shard is skipped, not failed. | Unverified | No run with `only_testing` on this SHA yet. Partial evidence: (a) the stub harness shows `ONLY_TESTING` → one `-only-testing` per word, surrounding whitespace dropped and `*` kept literal; (b) `plan` (workflow:34) uses the exact `if` that skipped the simulator job in the scope=ipa run 44702732605, and `simulator` needs `plan`; (c) the ipa `if` is unchanged and skipped ipa under scope=tests in 45069006816. Note: with `only_testing`, shard 2 is left out of the matrix, so no job appears at all rather than a "skipped" one. That meets "not failed". |
| AC-5 Each simulator job uploads its own artifact. The names are unique and start with `simulator-results` (for example `simulator-results-1` and `simulator-results-2`), and the contents are the same as today (screenshots, xcresult). docs/DEVELOPMENT.md (Tests/CI) and CLAUDE.md ("Verifying changes") describe the jobs, the shard rule and the artifact names. | Pass | Artifacts: `simulator-results-1` (11 MB), `simulator-results-2` (15 MB), `ClipDeck-ipa`. Each has `screenshots/ui-tests` + `TestResults-*.xcresult`, the same layout as 45002423211's `simulator-results`. The exports sum to 32+40 = 72 png and 26+26 = 52 txt, which matches the baseline's 72/52. The launch png is in shard 1. Docs: DEVELOPMENT.md:126-139 and CLAUDE.md:29. After M1's rebalance, DEVELOPMENT.md:129-130 must be updated (see C2). |

### Findings

Must fix
Where: .github/workflows/ios-simulator.yml:45 (`SHARD1_UI`)
Problem: AC-3 fails. Shard 2 ran 41:13, over the 35-minute limit. Shard 2 carries 20.9 of the 34.7 UI-minutes of 45002423211 (60 %), while shard 1's extra fixed work is only about 3.5 min (unit tests, `run-ios.sh` 2:44, a bigger upload). In this run shard 2 also got a slower VM: xcodebuild start → first UI test took 12:05 (shard 1: 5:48), and its UI tests took 25.7 min against 21.0 in 45002423211 (×1.22). Non-test overhead was 15.5 min.
Proof: Ran it. `gh run view 45070921716 --json jobs` (job and step times); xcresult Actions/Activities times (shard 2: invocation 21:16:41, first UI activity 21:28:40, last 21:54:21).
Trigger: any `scope=all` run where shard 2 gets an average or slow runner. Every new UI class from this goal also lands in shard 2, so it only gets heavier.
Fix: make shard 2 the lighter shard. For example, add `SubtitleStyleUITests` (4.0) to `SHARD1_UI`, giving 17.8 vs 16.9 UI-min. At 45002423211's pace that projects to about 29 min for shard 1 and 25 min for shard 2. Update the minutes in the workflow comment (lines 31-32) and the class list in DEVELOPMENT.md:129-130. Warning: at shard 2's pace in this run, even an ideal two-way split lands at about 35-37 min. If the re-proving run still misses 35 on a slow runner, the planner/Brent should decide (a third shard, or judge the bound on a typical runner) rather than trying another rebalance.

Could fix
Where: .github/workflows/ios-simulator.yml:46-55
Problem: a new test target (a third testable in the scheme) would run in neither shard. Shard 1 is `-only-testing ClipDeckTests` + classes, and shard 2 is `-only-testing ClipDeckUITests`. Before this change, every testable in the scheme ran. Nothing is lost today: project.yml:128-133 has only these two.
Proof: Read it.
Trigger: adding a new test bundle to the scheme; its tests silently never run in CI.
Fix: give shard 2 no `-only-testing`, only `-skip-testing ClipDeckTests` plus the shard-1 classes, so everything not in shard 1 lands in shard 2.

Could fix
Where: docs/DEVELOPMENT.md:129-130, 134
Problem: the doc repeats the `SHARD1_UI` class names, so every rebalance has to edit it too, and it says the ipa job is "unchanged" (changelog wording in a reference doc).
Proof: Read it.
Trigger: the next rebalance (M1) leaves the doc stale unless it is edited too.
Fix: point to `SHARD1_UI` in the workflow instead of listing the classes, and describe the ipa job plainly.

```text
VERDICT: Fail
SPEC: AC-1 met, AC-2 met, AC-3 not met (shard 2 41:13 > 35 min), AC-4 unverified (needs the only_testing run), AC-5 met
CHECKS_RUN: CI 45070921716 (dc157fa, scope=all) → success: plan, ipa (build-ipa.sh) green; shard 1 (test-ios.sh + run-ios.sh) 344/344, shard 2 (test-ios.sh) 46/46, 0 build or test issues; xcresult union vs 45002423211 → identical 390; `bash -n scripts/test-ios.sh` → ok; stub-xcodebuild harness on test-ios.sh (new vs base) → new passes all cases, base drops the env filters; lint: none configured
UNVERIFIED: AC-4. Needs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=tests -f only_testing=ClipDeckUITests/LaunchUITests` (expect: plan + simulator (shard 1) only, ipa skipped, 1 test). Nothing for Brent to check by hand.
REVIEWED_AT: dc157fa40939dafc6d17e5c549b830e5cc94282f
```

## Fix round 2
Round 1 failed AC-3 (shard 2 took 41:13). Brent chose a Sonnet retry and **three UI shards** instead of rebalancing two (AC-1, AC-2 and AC-5 updated). Aim for about 12 UI-minutes per shard, using the per-class minutes from the round 1 Test report, with ClipDeckTests and the launch screenshot in the lightest shard. Also fold in C1 (a new test target must still run somewhere) and C2 (docs shouldn't repeat the class lists that change on every rebalance).

## Implementation notes (round 2)
_by loop-backend · 2026-11-22_
- Changed: three shards. Shard 1 = ClipDeckTests + SubtitleStyleCardTester, SubtitleFontTester, SubtitleUpLimitTester, SubtitleFont, MiningFlow (UI about 10.5 min) + launch screenshot. Shard 2 = About, SubtitleStyle, PlayerLandscapeBehaviour (about 12.0). Shard 3 = no -only-testing; `-skip-testing` of ClipDeckTests and those 8 classes (PlayerLandscape, SubtitleStyleCard, ExpiryBanner, SubtitleStyleSheetTester, MKVImport, SubtitleStyleTester, Launch = about 12.2 now, plus every future class and target). only_testing: shard 1 alone as before, other shards absent.
- Findings: M1 (shard 2 over 35 min) -> three shards. C1 (new target unrun) -> shard 3 skips instead of only-testing. C2 (docs repeat lists, "unchanged" wording) -> docs name only `SHARD1_UI`/`SHARD2_UI`; the ipa job is described plainly. The workflow timing comment is updated.
- Files: .github/workflows/ios-simulator.yml, docs/DEVELOPMENT.md, CLAUDE.md, .loop/CONTEXT.md.
- Artifacts: `simulator-results-1`, `simulator-results-2`, `simulator-results-3`, `ClipDeck-ipa`.
- Tester, look at: the union is still 390 once each (shard 3 must not run ClipDeckTests, and its skip list must work with no -only-testing); shard 1 time (unit tests + 10.5 UI min + screenshot); the AC-4 run.

## Test report (round 2)
_by loop-tester · 2026-11-22 19:10_

Judged against the current task file (three shards). Runs under test, both on 557d9d2:
- **45083671012** (`scope=all`, CI run 2 of 4): conclusion failure. plan 0:03 ✓, ipa 2:21 ✓, simulator (shard 1) **20:23** ✗, (shard 2) **28:28** ✗, (shard 3) **27:41** ✓. All three shards started at 23:31:14Z.
- **45086461824** (`scope=tests`, `only_testing=ClipDeckUITests/LaunchUITests`, CI run 3 of 4, dispatched by me after 45083671012 finished): success.

Artifacts are in `%TEMP%\clip-deck-loop\T-020-r2`. I pruned the xcresult Data/ blobs and kept database.sqlite3 and the exports. The scratch tools I used are `compare_n.py` (N-shard union vs the 390 baseline), `select_model.py` (a model of xcodebuild's only/skip rules) and `fails.py`, in the tester scratchpad `tools` folder.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `.github/workflows/ios-simulator.yml` runs `ClipDeckUITests` in three parallel simulator jobs (a matrix with `fail-fast: false` is fine; Brent changed this from two to three on 2026-11-22 after round 1). `ClipDeckTests` and the "Launch in simulator and screenshot" step run in one of them. The ipa job is unchanged. | Pass | 45083671012: shards 1, 2 and 3 all started 23:31:14Z and ran side by side (`fail-fast: false`, workflow:75). ClipDeckTests: all 326 runs are in shard 1's xcresult and none in shards 2 or 3. In the plan log matrix, only shard 1 has `"screenshot":true`. Shard 3 went green and skipped the launch step, so the `if` is false there. In shard 1 the step was skipped this time because its tests failed (`if: matrix.screenshot` carries the implicit `success()`, the same as base). It ran in shard 1 in 45070921716 with the same step and flag; `git diff dc157fa 557d9d2` changes only the plan script. ipa: no hunk in `git diff e7717ee 557d9d2`, and ipa was green. |
| AC-2 No test is lost or run twice. Shards 1 and 2 are explicit lists of UI test classes. Shard 3 is every other UI class (`-skip-testing` the shard-1 and shard-2 classes), so a new class always runs somewhere. In the proving run, the jobs together run every test of the last single-job run exactly once (390: 326 unit + 64 UI, from CI 45002423211), plus any test the diff adds. | Pass | Plan log: shard 1 `only` = ClipDeckTests + `SHARD1_UI` (5 classes), shard 2 `only` = `SHARD2_UI` (3 classes), shard 3 `only` = "" and `skip` = ClipDeckTests + all 8 listed classes. xcresult TestCaseRuns: 342 (326 unit + 16 UI) + 20 + 28 = 390, multiset-equal to 45002423211 by target and test ID, with 0 overlap, 0 missing and 0 extra. All 15 UI classes appear, each in exactly one shard. Each shard's real test list is identical to the model's prediction from the matrix. Mutation check through that model: if the shard-2 loop stops adding to `skip3`, the compare reports 20 duplicates (exit 1); if `skip3` doesn't start with ClipDeckTests, it reports 289 duplicated unit-test IDs (exit 1). The diff adds no tests. |
| AC-3 With `-f scope=all` every job is green, and each simulator job takes under 35 minutes of wall time, build included. | Partly: time Pass, green **Blocked** | Time: 20:23, 28:28 and 27:41, all under 35 (round 1: 41:13). Shard 2's 28:28 includes an 8.6-min stall, where `PlayerLandscapeBehaviourUITests/testLoadDifferentSubtitlesFromLandscapeDialog` took 517 s (baseline 25 s) because every action waited 60 s for "dev.brent.clipdeck to idle" (CONTEXT Learned, 44976839046). Green: no. Three UI tests failed, none caused by this CI-only diff (no app or test code changed): (1) shard 1 `SubtitleFontTesterUITests/testCancellingThePickerLeavesTheSheetTopAndTheCachedRiseAlone`, "Seeded show should appear" after 60 s of waiting (a known flake, Learned); (2) shard 2 `AboutUITests/testAboutShowsVersionAndNoticeTextIntact` (a known flake on a very slow VM: launch 19.8 s, one tap 11.6 s); (3) shard 1 `SubtitleUpLimitTesterUITests/testUpDimsExactlyWhenTheLineReachesTheTopBarWithTwoAndThreeRowCards`, "Done closes the card (panel-25)". That one is a lost tap: the first Done in the same test closed the card in 1.1 s, and at failure the UI hierarchy still shows `subtitleStyle.card` with `subtitleStyle.done` in place. It passed in 45002423211 and in 45070921716 (shard 2). NEEDED: re-run below. |
| AC-4 The `scope` and `only_testing` inputs keep working. `scope=tests` runs only the simulator jobs, and `scope=ipa` runs only the ipa job. A non-empty `only_testing` runs just that filter in a single job, and the other shard is skipped, not failed. | Pass | 45086461824: plan matrix `{"include":[{"shard":1,"only":"ClipDeckUITests/LaunchUITests","skip":"","screenshot":false}]}`. Jobs: plan ✓, `simulator (shard 1)` ✓ (5:54), ipa **skipped**, and no shard 2 or 3 job, so nothing failed. Step env `ONLY_TESTING: ClipDeckUITests/LaunchUITests`. The xcresult has exactly 1 TestCaseRun, `LaunchUITests/testEmptyLibraryOffersUpload()`, Success. Run conclusion success. `scope=ipa` wasn't run on this SHA: `plan` and `simulator` both carry the exact `if` that skipped the simulator job under scope=ipa in 44702732605, and `simulator` needs `plan`. |
| AC-5 Each simulator job uploads its own artifact. The names are unique and start with `simulator-results` (for example `simulator-results-1`, `-2` and `-3`), and the contents are the same as today (screenshots, xcresult). docs/DEVELOPMENT.md (Tests/CI) and CLAUDE.md ("Verifying changes") describe the jobs, the shard rule and the artifact names. | Pass | 45083671012 artifacts: `simulator-results-1` (118 MB), `simulator-results-2` (173 MB), `simulator-results-3` (8 MB), `ClipDeck-ipa` (6 MB). Each simulator artifact has `screenshots/ui-tests` (manifest + exports) and one `TestResults-*.xcresult`, the same layout as before. The larger sizes come from screen recordings attached to the failed tests. DEVELOPMENT.md:126-139 and CLAUDE.md:29 describe the three jobs, the `SHARD1_UI`/`SHARD2_UI`/skip rule and all four artifact names. See S1 for the stale input description in the workflow itself. |

Round 1 findings: **M1 fixed** (the slowest shard went from 41:13 to 28:28, even with an 8.6-min stall). **C1 fixed**: shard 3 has no `-only-testing` (stub harness: 9 `-skip-testing`, 0 `-only-testing`), and in the real run it ran exactly the 28 tests outside the lists and no unit tests. **C2 fixed**: the docs name `SHARD1_UI`/`SHARD2_UI` instead of copying the class lists, and describe the ipa job plainly.

### Findings

Should fix (S1)
Where: .github/workflows/ios-simulator.yml:14 (also .loop/CONTEXT.md:31)
Problem: stale docs. The `scope` input description says `tests = simulator jobs only (two shards)`, but there are now three. The same goes for CONTEXT "How to verify" (line 31), which still says to download `simulator-results-1`/`-2` with no `-3`. The Learned line 64 is correct.
Proof: Read it. `grep -n "two shards" .github/workflows/ios-simulator.yml` → line 14.
Trigger: anyone who dispatches from the GitHub "Run workflow" form, or reads `gh workflow view`, is told there are two shards.
Fix: say "(three shards)", or drop the count, in workflow:14, and add `-3` in CONTEXT.md:31. It's a description string only and changes no job, so a YAML parse is enough to check it. It needs no new CI run of its own.

Could fix (C3)
Where: .github/workflows/ios-simulator.yml:52-56, 62
Problem: if `SHARD2_UI` is ever emptied (the docs say to rebalance by moving names between the two lists), `only2` becomes "" and shard 2 is planned with `only:""`, `skip:""`, so it runs every test (all 390, a full duplicate of shards 1 and 3).
Proof: Ran it. plan.sh with `SHARD2_UI=""` and a jq stub gives `o2=[]`, and test-ios.sh with both env vars empty passes no filter.
Trigger: a future rebalance that moves the last class out of `SHARD2_UI`.
Fix: leave the shard-2 entry out of the matrix when `only2` is empty, or fail the plan step with a message.

Could fix (C4)
Where: .github/workflows/ios-simulator.yml:57
Problem: a whitespace-only `only_testing` (for example a stray space typed in the form) passes `[ -n ]`. It plans a single job whose filter is empty after word-splitting, so that job runs all 390 tests with no screenshot. That took 46-57 min before the split, close to the 60-min timeout.
Proof: Ran it. plan.sh with `ONLY_TESTING="  "` gives the one-job matrix, and test-ios.sh with `ONLY_TESTING="  "` passes no `-only-testing`.
Trigger: dispatching with `only_testing` set to spaces.
Fix: test the word-split value, for example `set -- $ONLY_TESTING; if [ $# -gt 0 ]`.

Note, not a finding: shard 3 takes every new UI class from this goal, and it had about 7 min of headroom here (27:41). Shard 1 has the most room (20:23), so a later task that adds classes should move some into `SHARD1_UI`.

```text
VERDICT: Fail
SPEC: AC-1 met, AC-2 met, AC-3 partly (all shards under 35 min; not all green, blocked by 3 pre-existing UI flakes), AC-4 met, AC-5 met
CHECKS_RUN: CI 45083671012 (557d9d2, scope=all) → failure: plan ✓, ipa ✓ (build-ipa.sh + notice check), shard 1 340/342, shard 2 19/20, shard 3 28/28, 0 build issues; xcresult union vs 45002423211 → identical 390, 0 overlap; model vs real shard lists → identical; mutation via model → caught (20 and 289 duplicates); CI 45086461824 (557d9d2, scope=tests, only_testing=ClipDeckUITests/LaunchUITests) → success, 1/1, ipa skipped, only shard 1; local: workflow YAML parses (PyYAML), plan step run with jq stub (empty, single, whitespace, quote inputs), test-ios.sh stub harness per shard (filters as expected, exit 65 propagates); lint: none configured
UNVERIFIED: AC-3 "every job green": NEEDED `gh run rerun 45083671012 --failed` (re-runs shards 1 and 2 on 557d9d2, not a new dispatch; the failed tests were SubtitleFontTesterUITests/testCancellingThePickerLeavesTheSheetTopAndTheCachedRiseAlone, SubtitleUpLimitTesterUITests/testUpDimsExactlyWhenTheLineReachesTheTopBarWithTwoAndThreeRowCards and AboutUITests/testAboutShowsVersionAndNoticeTextIntact). It would also show the launch step running in shard 1. scope=ipa is not re-run on this SHA (same expression as 44702732605). Nothing for Brent to check by hand.
REVIEWED_AT: 557d9d2f410418ec836e44edc90d8fc35879f4fa
```

## Fix round 3
Round 2 failed only on S1 (the stale "two shards" wording at workflow:14, and the artifact list at CONTEXT.md:31) plus three flaky UI tests. Brent chose a Sonnet retry, then one full scope=all run on the final commit (CI run 4 of 4). That run proves the final workflow and re-checks the flaky tests for AC-3.

## Implementation notes (round 3)
_by loop-backend · 2026-11-22_
- S1: the `scope` input text now says "three shards"; CONTEXT.md line 31 lists `simulator-results-1`/`-2`/`-3`.
- C3: the plan job leaves shard 2 out of the matrix when `SHARD2_UI` is empty. C4: `only_testing` is whitespace-trimmed in the plan job, so a whitespace-only value counts as empty. The shard lists are untouched.
- Files: .github/workflows/ios-simulator.yml, .loop/CONTEXT.md.
- Checked: `bash -n scripts/test-ios.sh` ok; the workflow YAML parses (PyYAML, three jobs, matrix fail-fast false); `bash -n` on the extracted plan script ok; the trim pipeline gives "" for "" and "   ", and "A/B C/D" for "  A/B   C/D ". jq isn't installed here, so the new jq expression was read, not run.

## Test report (round 3)
_by loop-tester · 2026-11-22 19:50_

Run under test: **45087727557** (7c79c7c, `scope=all`, CI run 4 of 4). Conclusion **failure**, from one known flaky UI test. Jobs: plan 0:03 ✓, ipa 1:58 ✓ (build, notice check, upload), simulator (shard 1) **26:43** ✓ (00:15:57 → 00:42:40Z, including the launch step's 4:01), (shard 2) **18:01** ✗ (00:15:56 → 00:33:57Z), (shard 3) **29:27** ✓ (00:15:57 → 00:45:24Z). Artifacts are in `%TEMP%\clip-deck-loop\T-020-r3`, with the xcresult Data/ blobs pruned (20 MB left; database.sqlite3 and the exports kept). Round 3 changed only the plan step and the `scope` description (`git diff 557d9d2 7c79c7c`), and `ios/` is untouched since base.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `.github/workflows/ios-simulator.yml` runs `ClipDeckUITests` in three parallel simulator jobs (a matrix with `fail-fast: false` is fine; Brent changed this from two to three on 2026-11-22 after round 1). `ClipDeckTests` and the "Launch in simulator and screenshot" step run in one of them. The ipa job is unchanged. | Pass | 45087727557: the three shards started 00:15:56-57Z and ran side by side (`fail-fast: false`, workflow:77). ClipDeckTests: all 326 runs are in shard 1's xcresult and none in shards 2 or 3. The launch step ran in shard 1 on this SHA (success, 00:38:02 → 00:42:03) and produced `screenshots/launch-20261123-004111.png`, which I viewed: the empty library with "Upload episode". It was skipped in shards 2 and 3. ipa: no hunk in `git diff e7717ee 7c79c7c`, and all ipa steps were green. |
| AC-2 No test is lost or run twice. Shards 1 and 2 are explicit lists of UI test classes. Shard 3 is every other UI class (`-skip-testing` the shard-1 and shard-2 classes), so a new class always runs somewhere. In the proving run, the jobs together run every test of the last single-job run exactly once (390: 326 unit + 64 UI, from CI 45002423211), plus any test the diff adds. | Pass | The plan log's matrix (real jq on CI) is byte-identical to round 2's (45083671012; `cmp`, 827 bytes). xcresult TestCaseRuns: 342 (326 unit + 16 UI, 5 classes) + 20 (3 classes) + 28 (7 classes) = 390, multiset-equal to 45002423211 by target and test ID (`compare_n.py` exit 0), with 0 overlap, 0 missing and 0 extra. The diff adds no tests. |
| AC-3 With `-f scope=all` every job is green, and each simulator job takes under 35 minutes of wall time, build included. | Time Pass; green **Blocked** (pre-existing flake) | Time: 26:43, 18:01 and 29:27, all under 35. Shard 3's 29:27 includes about 7 min of the known "Wait for dev.brent.clipdeck to idle" 60 s stall: `SubtitleStyleCardUITests/testPresetChipsSelectAndAPickedFontShowsItsNameOnMoreFonts` took 442 s (round 2 33.6, baseline 17.2) and passed. Green: plan, ipa, and shards 1 and 3 are green. Round 2's three flaky tests all **passed** here: SubtitleFontTester `testCancellingThePicker…` (56 s), SubtitleUpLimitTester `testUpDimsExactly…` (97 s) and About `testAboutShowsVersionAndNoticeTextIntact` (85 s). Shard 2 failed on 1 of 20: `PlayerLandscapeBehaviourUITests/testControlsStayWhilePausedAndAutoHideWhilePlaying()`, "Playing: controls hide on their own" (PlayerLandscapeBehaviourUITests.swift:44). This test is on the CONTEXT Learned flake list (line 47). It passed in 45002423211, 45070921716 and 45083671012, and the latter ran the identical shard-2 filter. The cause is the runner's timing, not this change. The VM was slow (app launch 17.8 s, seeded show 15.2 s), and the Play tap alone took 6.0 s, as long as the 6-second sample. The UI hierarchy at failure (00:25:51) shows the position slider at `value: 6,000` and `player.playPause` labelled `Play`: the clip had played to its end and stopped, and the player shows the controls again on stop (by design, test lines 47-48). `ios/` is unchanged since base. NEEDED: re-run below. |
| AC-4 The `scope` and `only_testing` inputs keep working. `scope=tests` runs only the simulator jobs, and `scope=ipa` runs only the ipa job. A non-empty `only_testing` runs just that filter in a single job, and the other shard is skipped, not failed. | Pass | Real run: 45086461824 on 557d9d2 (one job, 1 test, ipa skipped, no other shard). Round 3 changed that path only by the trim. I ran the extracted 7c79c7c plan script locally with a `jq` shim that evaluates the exact filter in gh's built-in gojq (`--arg` → `as $name` bindings). The shim's output equals the real CI matrices of 45087727557 and 45086461824 as parsed JSON (gojq only sorts keys). With `only_testing=ClipDeckUITests/LaunchUITests`, 7c79c7c gives the same one-entry matrix as 45086461824. The `scope` `if`s are unchanged since round 2 (`plan`/`simulator`: `scope != 'ipa'`; ipa: `scope != 'tests'`). |
| AC-5 Each simulator job uploads its own artifact. The names are unique and start with `simulator-results` (for example `simulator-results-1`, `-2` and `-3`), and the contents are the same as today (screenshots, xcresult). docs/DEVELOPMENT.md (Tests/CI) and CLAUDE.md ("Verifying changes") describe the jobs, the shard rule and the artifact names. | Pass | Artifacts: `simulator-results-1` (9.7 MB), `-2` (118 MB, which includes the failed test's screen recording), `-3` (8.3 MB) and `ClipDeck-ipa` (6.3 MB). Each simulator artifact has `screenshots/ui-tests` (manifest + exports) and one `TestResults-*.xcresult`. The exports have 29 + 21 + 20 = 70 png, which is the baseline's 72 minus the failed test's two screenshots after line 44 (`landscape-05-autohidden`, `landscape-07-ended`). docs/DEVELOPMENT.md and CLAUDE.md are unchanged since round 2 (`git diff --quiet 557d9d2 7c79c7c -- scripts docs CLAUDE.md`) and still accurate. S1: workflow:14 now says "(three shards)", and CONTEXT.md:31 (working tree) lists `-1`/`-2`/`-3`. |

Round 2 findings:
- **S1 fixed.** Workflow:14 says "three shards", and CONTEXT.md:31 names all three artifacts. A grep for stale shard wording finds only workflow:29, which is accurate history ("two shards took 27 and 41 min in CI 45070921716").
- **C3 fixed (ran it).** With `SHARD2_UI=""` or `"   "`, the plan gives shards 1 and 3 only; shard 3 skips ClipDeckTests + the 5 shard-1 classes. Through `test-ios.sh` with the stub xcodebuild, that's 6 `-only-testing` / 6 `-skip-testing`. Mutant (557d9d2's jq branch with the same empty list): shard 2 appears with `only:""`, `skip:""`, and gets 0 filters, which is an unfiltered full run. The current code removes that.
- **C4 fixed (ran it).** `only_testing` set to `"   "`, or to tab + newline + space, gives the normal three-shard matrix (6 / 3 / 9-skip filters). Mutant (no trim line): one job with `only:"   "` and 0 filters. Edge values keep their content: `"  A/B   C/D "` → `A/B C/D`, and `Foo"Bar`, `*`, `-n`, `a\b` and `…/testX()` pass through literally. `ONLY_TESTING` comes in through `env`, not `${{ }}` inside the script, so the input can't inject shell.

### Findings
None of my own. The failing test is pre-existing (see AC-3), and the diff can't touch it.

Note, not a finding: shard 3 ran 29:27 here with about 7 min of idle stall (27:41 in round 2). Shard 1 has the most headroom left for later tasks' new classes (26:43 with the 4-min launch step).

```text
VERDICT: Blocked
SPEC: AC-1 met, AC-2 met, AC-3 partly (all shards under 35 min; shard 2 red on one pre-existing flaky test, round 2's three flakes passed), AC-4 met, AC-5 met
CHECKS_RUN: CI 45087727557 (7c79c7c, scope=all) → failure: plan ✓ (matrix byte-identical to round 2), ipa ✓ (build-ipa.sh + check-ipa-notices.sh), shard 1 342/342 + run-ios.sh ✓, shard 2 19/20, shard 3 28/28, 0 build issues; xcresult union vs 45002423211 → identical 390, 0 overlap; local: workflow YAML parses (PyYAML), `bash -n` on test-ios.sh and the extracted plan step; plan step run with a gojq-backed jq shim (calibrated against 2 real CI matrices) for empty, single, whitespace, tab/newline, quote/glob/dash/backslash inputs and empty/whitespace SHARD2_UI; two mutants (C3 jq revert, C4 trim removal) reproduce the round 2 bugs; matrices → test-ios.sh stub harness (filter counts as expected); lint: none configured
UNVERIFIED: AC-3 "every job green". NEEDED: re-run CI, `gh run rerun 45087727557 --failed`, which re-runs only simulator (shard 2) on 7c79c7c with the same matrix (about 18 min; don't dispatch on the branch while it runs, because of the shared `ios-<ref>` concurrency group). The test to watch is PlayerLandscapeBehaviourUITests/testControlsStayWhilePausedAndAutoHideWhilePlaying. This is beyond the 4-run budget, so Brent decides. Nothing for Brent to check by hand.
REVIEWED_AT: 7c79c7ceb453f6c7ef7d82b6530aac35afa65992 (+ working-tree .loop/CONTEXT.md)
```

### Round 3 addendum
_by loop-tester · 2026-11-22 20:16_

Brent approved re-running only the failed job (CI run 5, past the 4-run budget): `gh run rerun 45087727557 --failed`. Attempt 2 re-ran `simulator (shard 2)` alone on 7c79c7c (job 137421879998, run_attempt 2), from 00:54:42 to 01:14:41Z = **19:59**. Its step env was the same plan output: `ONLY_TESTING: ClipDeckUITests/AboutUITests ClipDeckUITests/SubtitleStyleUITests ClipDeckUITests/PlayerLandscapeBehaviourUITests`, `SKIP_TESTING:` empty. The log says "Tests passed", and the launch step was skipped as expected. The run's conclusion is now **success**, and all five jobs are green: plan, ipa and shards 1 and 3 from attempt 1, shard 2 from attempt 2.

I downloaded the attempt-2 artifact by ID (`simulator-results-2`, id 14781669376, 11.4 MB) to `%TEMP%\clip-deck-loop\T-020-r3\simulator-results-2-attempt2` and pruned its Data/. Its xcresult has 20 TestCaseRuns, all Success, with 0 build and 0 test issues. The test list is identical to attempt 1's shard 2. `PlayerLandscapeBehaviourUITests/testControlsStayWhilePausedAndAutoHideWhilePlaying()` passed in 35.2 s, and the About tests and `testOpenSubtitlesMenuKeepsControlsUpWhilePlaying` passed too. The final union (attempt-1 shards 1 and 3, attempt-2 shard 2) is 342 + 20 + 28 = 390, all Success, multiset-equal to 45002423211, with 0 overlap, 0 missing and 0 extra (`compare_n.py` exit 0).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-3 With `-f scope=all` every job is green, and each simulator job takes under 35 minutes of wall time, build included. | Pass | 45087727557 (scope=all, 7c79c7c) concluded success after attempt 2, with every job green. Shard times: 26:43, 19:59 (attempt 2; 18:01 in attempt 1) and 29:27, all under 35. The only red in attempt 1 was the known runner-timing flake explained in the round 3 report. It passed on re-run with the identical filter. |

AC-1, AC-2, AC-4 and AC-5 stay Pass as reported in round 3. Findings: none open.

```text
VERDICT: Pass
SPEC: AC-1 met, AC-2 met, AC-3 met, AC-4 met, AC-5 met
CHECKS_RUN: CI 45087727557 attempt 1 (7c79c7c, scope=all) → plan, ipa, shard 1 (342/342 + run-ios.sh), shard 3 (28/28) green; shard 2 19/20 (known flake). Attempt 2 (`gh run rerun --failed`, CI run 5, approved by Brent) → shard 2 20/20 in 19:59, run conclusion success. Final union vs 45002423211 → identical 390, all Success, 0 overlap, 0 build issues. Local plan-step and test-ios.sh checks as in the round 3 report. Lint: none configured.
UNVERIFIED: None. Nothing for Brent to check by hand.
REVIEWED_AT: 7c79c7ceb453f6c7ef7d82b6530aac35afa65992 (+ working-tree .loop/CONTEXT.md)
```
