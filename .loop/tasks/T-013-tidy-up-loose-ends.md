---
id: T-013
title: Tidy up the loose ends from the loop's reviews
lane: backend
depends_on: [T-005]
status: done
round: 2
base_sha: f88b3eb00bb8600726ef90681241e85698608624
issue: 13
spec:
model:
---

## Tidy up the loose ends from the loop's reviews

### What are we building?
The testers left a list of small "Could fix" items across T-004 to T-012 that were safe to defer. This task fixes the ones that change behaviour or could bite later, in one pass, before the branch is merged and v0.3.0 is released.

### Why?
Brent asked to "tie up the loose ends" before using the app day to day. A few of these items (folder names, release ordering, release recovery) could cause real trouble later.

### Done when
- AC-1 `FileStore.safeName` replaces only Unicode control characters (`generalCategory == .control`, i.e. Cc), not format characters (Cf: ZWJ, ZWNJ, soft hyphen, LRM/RLM), so names with those characters keep the same folder as before. Unit test with a ZWJ emoji name and a name with a newline. (T-005 C6)
- AC-2 When the user picks their own subtitle file, the embedded track chosen in the picker is no longer "required", so failing to write it only adds a warning. A unit test covers the `.subtitleNotSaved` warning path, e.g. through an injectable writer or a read-only destination. (T-005 C7, C8)
- AC-3 `scripts/make-source-json.py` orders versions by semantic version (newest first), not `published_at`. The fixture test gains the "v0.3.0 published, then v0.2.1 published later" case. (T-010 C1)
- AC-4 docs/INSTALL_ON_IPHONE.md "Cutting a release" documents recovery if the apps.json step fails: generate apps.json locally with the script and upload it with `gh release upload <tag> apps.json --clobber`. The version notes shown inside SideStore (make-source-json.py) say what's new / point to the release page, instead of telling the user to download and share the IPA. (T-010 C2, C3)
- AC-5 Both workflows use `actions/checkout@v5`, so the Node 20 deprecation warning is gone, and `persist-credentials: false` stays in release.yml. (T-010 C4)
- AC-6 `ErrorBanner` (DesignSystem/Components.swift) keeps its message as one accessibility element, but an action button such as "Try again" in `missing.error` is its own VoiceOver button. (T-006 C2)
- AC-7 Test-only tidy-ups: remove the redundant `as?` casts in ConversionPlanTests (warnings at :39/:216/:345); add a test proving the converter's AVIOInterruptCB fires (ConversionCore.run with the cancel flag set beforehand → CancellationError, no progress, empty folder). (T-004 C1, C2)
- AC-8 THIRD_PARTY_NOTICES.md libzvbi row: the ure.* cell also lists Iñaki García Etxebarrria and Michael H. Schimek, matching Other-Components.txt. (T-012 C1)

### How to check
- `python scripts/test-make-source-json.py` (local).
- CI: `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload -f scope=all` (the workflows change). All suites stay green. The new unit tests pass, and there are no `as?` warnings in the test target.
- Read the release.yml diff. Its next real run is the v0.3.0 release.

### Agent notes
- Depends on: T-005
- Source: the Test reports and HANDOFF "Could fix" entries of T-004, T-005, T-006, T-010, T-012; written by the orchestrator at Brent's request ("tie up the loose ends").
- One builder (loop-backend) may also touch the DesignSystem `ErrorBanner` for AC-6; keep its visual layout unchanged.
- Deliberately left out (device-only or low value): the coordinated read held while the upload sheet is idle (Brent checks on a device); an AX5 cut-off-label test for the expiry banner; the BGContinuedProcessingTask follow-up.

### Out of scope
- New features; any behaviour change beyond the items above; changes to the release format.

## Implementation notes (round 1) · sonnet
_by loop-backend · 2026-11-20_
- AC-1: `FileStore.safeName` now replaces only `generalCategory == .control` (Cc) with a space; Cf (ZWJ, ZWNJ, soft hyphen, LRM/RLM) is kept. Names the pre-T-005 code produced are unchanged (it replaced no control characters), only names with Cc characters differ. Test: `safeNameKeepsFormatCharactersAndOnlyReplacesControlCharacters` (ZWJ emoji, ZWNJ/soft hyphen/LRM, newline).
- AC-2: `PreparedVideo.plan(for:userPickedSubtitleFile:)` (default false). When true the chosen track is still extracted but `required` is nil, so a write failure only adds `.subtitleNotSaved`. `EpisodeImporter.stage` passes `subtitleFile != nil`. Without a picked file the chosen track stays required. Tests: `aPickedSubtitleFileMeansTheChosenTrackIsNoLongerRequired`, plus `aSubtitleThatCannotBeWrittenIsOnlyAWarningWhenNotRequired` and `aRequiredSubtitleThatCannotBeWrittenFailsTheConversion` (read-only subtitle folder, mode 0o555, through `MediaConverter.convert`).
- AC-3: versions sort by (major, minor, patch) newest first, publish time only breaks ties; `check_source` now checks order by version number. New test cases: v0.3.0 then later v0.2.1, and v0.10.0 vs v0.3.0.
- AC-4: INSTALL_ON_IPHONE.md has "If the apps.json step fails" (generate, check, `gh release upload <tag> apps.json --clobber`). Version notes in apps.json are now "Clip Deck X.Y.Z. What's new: <release page URL>" (html_url, else built from the repo and tag); the release body is no longer copied.
- AC-5: `actions/checkout@v5` in both workflows (v5.0.0 only moves to Node 24, needs runner >= 2.327.1, same inputs). `persist-credentials: false` kept in release.yml.
- AC-6: `ErrorBanner` uses `.accessibilityElement(children: .contain)` when it has an action (icon hidden, message and button separate elements, the caller's identifier stays on the group), and `.combine` as before without one. Layout unchanged.
- AC-7: removed the three redundant `as?` casts (typed throws); added `aSetCancelFlagStopsTheConverterThroughTheInterruptCallback` (ConversionCore.run with the flag set: CancellationError, 0 progress calls, empty folder).
- AC-8: THIRD_PARTY_NOTICES.md libzvbi `ure.*` cell lists "Iñaki García Etxebarrria; Michael H. Schimek" (spelling as in Other-Components.txt line 72).
- Files: ios/ClipDeck/Services/FileStore.swift, ios/ClipDeck/Services/EpisodeImporter.swift, ios/ClipDeck/DesignSystem/Components.swift, ios/ClipDeckTests/{ConversionPlanTests,EmbeddedSubtitleTests,MediaConverterTests}.swift, scripts/make-source-json.py, scripts/test-make-source-json.py, .github/workflows/{ios-simulator,release}.yml, docs/INSTALL_ON_IPHONE.md, THIRD_PARTY_NOTICES.md
- Checked: `python scripts/test-make-source-json.py` → all checks passed; py_compile; PyYAML loads both workflows. Swift not compiled (no Mac); CI needed.
- Tester, look at: CI compile of the new tests (typed-throws `return error`, `#require(try ...)`, read-only folder test), VoiceOver behaviour of ErrorBanner with an action, `make-source-json.py` was converted from CRLF to LF (the repo's .gitattributes says eol=lf).
- Gotchas: a hotfix published after a newer release becomes GitHub's "latest" and so owns the `latest/download/apps.json` address; not changed here.

## Test report (round 1)
_by loop-tester · 2026-11-20 17:45_

CI run 44819926161 (ios-simulator.yml, scope=all, headSha 28ad26f) finished green: both the simulator and ipa jobs succeeded. In the xcresult (iPhone 17 Pro, iOS 26.5), 251 of 251 test runs succeed, with 0 test issues, 0 build issues and 0 skips. That is the 245 tests that passed in T-005 plus the 5 new ones. Every known flake passed: AboutUITests/testAboutShowsVersionAndNoticeTextIntact, both PlayerLandscapeBehaviourUITests tests, and ClipExtractorTests.cutsExactAudioAndScreenshot.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `FileStore.safeName` replaces only Unicode control characters (`generalCategory == .control`, i.e. Cc), not format characters (Cf: ZWJ, ZWNJ, soft hyphen, LRM/RLM), so names with those characters keep the same folder as before. Unit test with a ZWJ emoji name and a name with a newline. | Pass | `EmbeddedSubtitleRuleTests/safeNameKeepsFormatCharactersAndOnlyReplacesControlCharacters` passes in 44819926161, and so do the older `safeName("A\nB\tC")` and `FileStoreTests/safeNamesAndUniquePaths`. Old vs new code: v0.2.0, the only release, was built before ee09056 (`git tag --contains ee09056` is empty). Its safeName did no Cc/Cf replacement. The new scalar loop is the identity for any name without a Cc scalar, so every such name, Cf included, maps to the same folder as in v0.2.0. A leading or trailing \n, \r or \t still trims to the old result. Only an interior Cc (or a non-whitespace Cc such as U+0000-001F or U+007F-009F) now becomes a space, as intended. |
| AC-2 When the user picks their own subtitle file, the embedded track chosen in the picker is no longer "required", so failing to write it only adds a warning. A unit test covers the `.subtitleNotSaved` warning path, e.g. through an injectable writer or a read-only destination. | Pass | These pass in 44819926161: `EmbeddedSubtitleImportTests/aPickedSubtitleFileMeansTheChosenTrackIsNoLongerRequired`, `EmbeddedSubtitleFixtureTests/aSubtitleThatCannotBeWrittenIsOnlyAWarningWhenNotRequired` (a read-only `Embedded/` folder gives 2 `.subtitleNotSaved` warnings and Episode.mp4 kept) and `aRequiredSubtitleThatCannotBeWrittenFailsTheConversion`. Traced: `stage` passes `subtitleFile != nil` (EpisodeImporter.swift:352). The only other `plan(for:)` caller, VideoImportModel.swift:181, only validates, and `required` changes `isRequired` only, never whether the call throws. |
| AC-3 `scripts/make-source-json.py` orders versions by semantic version (newest first), not `published_at`. The fixture test gains the "v0.3.0 published, then v0.2.1 published later" case. | Pass | `python scripts/test-make-source-json.py` prints "all checks passed". The builder's 0.10.0 case was published last, so a date sort would also put it first. I added a case with v0.10.0 published *before* v0.3.0 and v0.9.1, plus a check that `check_source` rejects 0.3.0 listed above 0.10.0. Mutations on scratch copies (sort by `published_at`, sort by version string, `check_source` comparing strings) each make the test exit 1. |
| AC-4 docs/INSTALL_ON_IPHONE.md "Cutting a release" documents recovery if the apps.json step fails: generate apps.json locally with the script and upload it with `gh release upload <tag> apps.json --clobber`. The version notes shown inside SideStore (make-source-json.py) say what's new / point to the release page, instead of telling the user to download and share the IPA. | Pass | The doc is at docs/INSTALL_ON_IPHONE.md:52-60. I ran the documented generate and `--check` commands for real against the public repo, writing to scratch: "wrote ...: 1 version(s), newest 0.2.0" and "ok". I did not run the upload. `gh release upload --help` confirms `--clobber` deletes and re-uploads an asset with the same name. In SideStore@4f3d18d, AppContentViewController.swift:66-67 shows `latestAvailableVersion.localizedDescription` in a `CollapsingMarkdownView`, which sets `dataDetectorTypes = .link` (CollapsingMarkdownView.swift:175-181), so "Clip Deck 0.2.0. What's new: https://github.com/.../releases/tag/v0.2.0" shows with a tappable link. MyAppsViewController.swift:388 shows the same text in the update cell. |
| AC-5 Both workflows use `actions/checkout@v5`, so the Node 20 deprecation warning is gone, and `persist-credentials: false` stays in release.yml. | Fail (partly) | checkout@v5 (SHA fbc6f39, `using: node24`) runs in both jobs, and the annotation no longer names it. In 44812195849 the warning named "actions/checkout@v4, actions/upload-artifact@v4". PyYAML confirms release.yml keeps `persist-credentials: false`, and GH_TOKEN is set only on the three gh steps, not at job level. The diff changes only the `uses:` line. **But both ios-simulator.yml jobs still carry the warning "Node.js 20 is deprecated … actions/upload-artifact@v4"**, so the warning is not gone (S1). release.yml has no upload-artifact, so its next run should be clean. That is unverified until v0.3.0. |
| AC-6 `ErrorBanner` (DesignSystem/Components.swift) keeps its message as one accessibility element, but an action button such as "Try again" in `missing.error` is its own VoiceOver button. | Unverified (code right; new UI assertion not yet run) | Layout: the 06-sync screenshot (SyncView's "Open Anki settings" banner, the same component with an action) from 44819926161 matches 44812195849 pixel for pixel below the status bar (PIL difference bbox = None). The code uses `.contain` with an action and `.combine` without one, and the icon is hidden with an action. No existing UI test exercises an action banner, including `missing.error` / "Try again". I added a MiningFlowUITests assertion: `app.buttons["Open Anki settings"]` exists, the message is a separate StaticText with exactly its own label, and tapping the button opens Anki settings. Under the old `.combine` the merged label is "<message>, <action>", so the assertion would fail. It runs in the next CI run. Brent: VoiceOver on a device. |
| AC-7 Test-only tidy-ups: remove the redundant `as?` casts in ConversionPlanTests (warnings at :39/:216/:345); add a test proving the converter's AVIOInterruptCB fires (ConversionCore.run with the cancel flag set beforehand → CancellationError, no progress, empty folder). | Pass | The 44812195849 log printed "conditional cast ... always succeeds" at ConversionPlanTests.swift:39/216/345 plus their macro expansions. The 44819926161 log has no Swift warning at all, and `-quiet` still prints warnings. `MediaConverterTests/aSetCancelFlagStopsTheConverterThroughTheInterruptCallback` passes. Traced why it proves the callback: without it, `avformat_open_input` succeeds and `session.run` calls `report(0, force: true)` (MediaConverter.swift:388) before the first `isCancelled` check (:592), so the "0 progress" expectation would fail. Swift mutation not run (CI only). |
| AC-8 THIRD_PARTY_NOTICES.md libzvbi row: the ure.* cell also lists Iñaki García Etxebarrria and Michael H. Schimek, matching Other-Components.txt. | Pass | Python check: "Iñaki García Etxebarrria" (U+00F1, U+00ED, triple r) and "Michael H. Schimek" are in both files, and both files are NFC. Source: Other-Components.txt:72 and :74. |

### Findings
**Should fix**
S1
Where: .github/workflows/ios-simulator.yml:60 and :91
Problem: AC-5 says the Node 20 deprecation warning is gone. In both jobs of 44819926161 it is still there, now only for `actions/upload-artifact@v4`, which is `using: node20`, as are v4 and v5.
Proof: Ran it: the check-run annotations of jobs 136577873211 and 136577873710 say "Node.js 20 is deprecated … actions/upload-artifact@v4". `action.yml` of upload-artifact v4/v5 is node20, and v6/v7 is node24.
Trigger: every ios-simulator.yml run.
Fix: `actions/upload-artifact@v6` (node24, needs runner >= 2.327.1; the run used 2.338.2) at both places. The inputs used (`name`, `path`, `if-no-files-found`, `retention-days`) are unchanged. If the orchestrator rules upload-artifact out of T-013's scope, AC-5 is otherwise met and this drops to Could fix.

**Could fix**
C1 scripts/make-source-json.py:168-174: `check_source` silently skips versions whose `version` is not X.Y.Z, so a malformed version escapes the order check and has no format error. Add a format check.
C2 docs/INSTALL_ON_IPHONE.md:55-57: the recovery commands use `python`. That is right on Brent's Windows machine; on macOS it would be `python3`.
C3 No UI test reaches the `missing.error` "Try again" banner. The tester's MiningFlowUITests assertion covers the same ErrorBanner code path through the Sync sheet.

### Tests added (test files only)
- scripts/test-make-source-json.py: v0.10.0 published before v0.3.0/v0.9.1, the icon tag, `check_source` rejecting string order, the notes text, `html_url` used.
- ios/ClipDeckUITests/MiningFlowUITests.swift: AC-6 assertion (the banner action is its own button, the message is a separate element, tapping it opens Anki settings). Not run yet.

```text
VERDICT: Fail
SPEC: AC-1, AC-2, AC-3, AC-4, AC-7, AC-8 met; AC-5 partly (checkout@v5 yes, Node 20 warning still from upload-artifact@v4); AC-6 code and layout right, new UI assertion pending
CHECKS_RUN: CI 44819926161 scope=all → simulator success (251/251, 0 issues, 0 Swift warnings), ipa success; python scripts/test-make-source-json.py → all checks passed (+3 mutations fail it); documented recovery generate+check against the live repo → ok; PyYAML workflow parse → ok
UNVERIFIED: VoiceOver on a device for ErrorBanner actions; release.yml's first checkout@v5 run (v0.3.0); the new MiningFlowUITests AC-6 assertion (next CI run)
REVIEWED_AT: 28ad26f2376e955c907e45256ec517d01d5b115d
```

## Fix round 2
_orchestrator · 2026-11-20 · round 1 failed on Sonnet; Brent chose to retry on Sonnet. Sent S1 (upload-artifact@v4 → @v6 at ios-simulator.yml:60 and :91) to the same loop-backend. The tester's uncommitted test edits (test-make-source-json.py, the MiningFlowUITests AC-6 assertion) must be kept._

## Implementation notes (round 2) · sonnet
_by loop-backend · 2026-11-20_
- S1: `actions/upload-artifact@v4` to `@v6` at ios-simulator.yml:60 and :91. Checked: v6 exists (releases list v7.0.x, v6 tag has `action.yml` with `using: 'node24'`) and still has the inputs used here (name, path, if-no-files-found, retention-days). release.yml has no other actions besides checkout@v5 (no upload-artifact). YAML loads with PyYAML.
- C1: `check_source` now reports a format error when a version's `version` is not X.Y.Z. Added the "malformed version" case to the "must fail" list in test-make-source-json.py (tester's cases kept untouched); the test passes.
- C2: INSTALL_ON_IPHONE.md says to type `python3` instead of `python` on a Mac.
- C3: no change. The tester's MiningFlowUITests assertion already covers the shared ErrorBanner code path; reaching `missing.error` "Try again" needs a failing relink flow, not cheap.
- Kept the tester's edits to scripts/test-make-source-json.py and MiningFlowUITests.swift. Nothing large written to disk.
- Checked: `python scripts/test-make-source-json.py` passes, py_compile ok. Next CI run should show no Node 20 warning in either ios-simulator.yml job.

## Test report (round 2)
_by loop-tester · 2026-11-20 18:22_

CI run 44833382185 (ios-simulator.yml, scope=all, headSha 356f2e7) is green. The simulator job (136623669454) and the ipa job (136623669800) both succeeded. In the xcresult, 251 of 251 test runs succeed, with 0 test issues, 0 build issues and 0 skips. Every known flake passed: AboutUITests/testAboutShowsVersionAndNoticeTextIntact, both PlayerLandscapeBehaviourUITests tests, and ClipExtractorTests.cutsExactAudioAndScreenshot. Round 2 (`git diff 28ad26f..356f2e7`) changes only ios-simulator.yml (upload-artifact @v4 to @v6, twice), make-source-json.py (the version format check), INSTALL_ON_IPHONE.md (the python3 note), and round 1's tester tests.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `FileStore.safeName` replaces only Unicode control characters (`generalCategory == .control`, i.e. Cc), not format characters (Cf: ZWJ, ZWNJ, soft hyphen, LRM/RLM), so names with those characters keep the same folder as before. Unit test with a ZWJ emoji name and a name with a newline. | Pass | `EmbeddedSubtitleRuleTests/safeNameKeepsFormatCharactersAndOnlyReplacesControlCharacters` passes in 44833382185. The code has not changed since round 1, and the round 1 trace still holds. |
| AC-2 When the user picks their own subtitle file, the embedded track chosen in the picker is no longer "required", so failing to write it only adds a warning. A unit test covers the `.subtitleNotSaved` warning path, e.g. through an injectable writer or a read-only destination. | Pass | These pass in 44833382185: `aPickedSubtitleFileMeansTheChosenTrackIsNoLongerRequired`, `aSubtitleThatCannotBeWrittenIsOnlyAWarningWhenNotRequired` and `aRequiredSubtitleThatCannotBeWrittenFailsTheConversion`. The code has not changed since round 1. |
| AC-3 `scripts/make-source-json.py` orders versions by semantic version (newest first), not `published_at`. The fixture test gains the "v0.3.0 published, then v0.2.1 published later" case. | Pass | `python scripts/test-make-source-json.py` prints "all checks passed" (exit 0), including round 1's stronger semver cases and the new "malformed version" case. Mutation on a scratch copy: removing the new `'version' must look like 1.2.3` check makes the test print "FAIL check should fail: malformed version" (exit 1). `build_versions` only outputs `TAG_RE` versions (no leading zeros), which is a strict subset of the new check, so release.yml's `--check` cannot start failing on a real release. |
| AC-4 docs/INSTALL_ON_IPHONE.md "Cutting a release" documents recovery if the apps.json step fails: generate apps.json locally with the script and upload it with `gh release upload <tag> apps.json --clobber`. The version notes shown inside SideStore (make-source-json.py) say what's new / point to the release page, instead of telling the user to download and share the IPA. | Pass | Round 1's evidence stands. Round 2 adds only "On a Mac, type `python3` instead of `python`" (docs/INSTALL_ON_IPHONE.md:60). The notes test ("Clip Deck 0.10.0. What's new: …/releases/tag/v0.10.0", `html_url` used) passes. |
| AC-5 Both workflows use `actions/checkout@v5`, so the Node 20 deprecation warning is gone, and `persist-credentials: false` stays in release.yml. | Pass | `gh api …/check-runs/136623669454/annotations` and `…/136623669800/annotations` each return only the notice "Due to capacity constraints, jobs targeting macOS arm64 runners may experience longer queue times." Neither has a Node.js 20 annotation. The full run log has no "Node.js 20", "node20" or "deprecated". Both jobs download `actions/checkout@v5` (fbc6f39) and `actions/upload-artifact@v6` (b7c566a). That SHA's action.yml has `using: 'node24'` and accepts every input used (name, path, if-no-files-found, retention-days). Both artifacts uploaded: simulator-results is 15.2 MB, ClipDeck-ipa is 4.8 MB. release.yml is unchanged in round 2: it uses only checkout@v5 and keeps `persist-credentials: false`. Its first real run (v0.3.0) is still to come. |
| AC-6 `ErrorBanner` (DesignSystem/Components.swift) keeps its message as one accessibility element, but an action button such as "Try again" in `missing.error` is its own VoiceOver button. | Pass (VoiceOver on a device unverified) | `MiningFlowUITests/testMakeACardFromSubtitleLine` passes in 44833382185 (32.5 s, `continueAfterFailure = false`). Its xcresult activities show each new step ran: "Waiting 5.0s for "Open Anki settings" Button to exist", "Checking existence of `StaticText (First Match)`" (label == the exact message), "Tap "Open Anki settings" Button", "Waiting 5.0s for "settings.url" Any to exist". So the action is its own button, the message is a separate StaticText without the button's title, and tapping the button opens Anki settings. I did not run the old `.combine` code against this assertion, because that would cost a CI dispatch. Under `.combine` the label is merged ("<message>, <action>"), so the exact-label StaticText query would not match. Components.swift is unchanged since round 1, when the layout was confirmed pixel-identical. |
| AC-7 Test-only tidy-ups: remove the redundant `as?` casts in ConversionPlanTests (warnings at :39/:216/:345); add a test proving the converter's AVIOInterruptCB fires (ConversionCore.run with the cancel flag set beforehand → CancellationError, no progress, empty folder). | Pass | `MediaConverterTests/aSetCancelFlagStopsTheConverterThroughTheInterruptCallback` passes in 44833382185. The run log has no Swift "warning:" in the test build. Its only "warning:" line is the IPA build's "All interface orientations must be supported…". That line is pre-existing: it also appears in 44819926161, and it is not from the test target. |
| AC-8 THIRD_PARTY_NOTICES.md libzvbi row: the ure.* cell also lists Iñaki García Etxebarrria and Michael H. Schimek, matching Other-Components.txt. | Pass | The file has not changed since round 1, where the check passed. |

Round 1 S1 is fixed (see AC-5). Round 1 C1 (check_source version format) is fixed and covered by a test. C2 (python3) is fixed. C3 is left as is, deliberately.

### Findings
None that are Must fix or Should fix.

**Could fix**
C1 scripts/make-source-json.py:166: `re.match(r"^\d+\.\d+\.\d+$", …)` accepts a trailing newline ("1.2.3\n"), because `$` matches before a final newline. Use `re.fullmatch` or `\Z`. This is cosmetic, since build output never contains one.

### Tests added (test files only)
None this round. Round 1's tests ran and pass.

```text
VERDICT: Pass
SPEC: AC-1..AC-8 met
CHECKS_RUN: CI 44833382185 scope=all → simulator success (251/251, 0 issues, 0 build issues, 0 skips), ipa success; annotations on both jobs → capacity notice only, no Node 20; python scripts/test-make-source-json.py → all checks passed (removing the new version check fails it)
UNVERIFIED: VoiceOver on a device for ErrorBanner actions; release.yml's first checkout@v5 run (v0.3.0)
REVIEWED_AT: 356f2e740f16d5fef450b7d8381be721e5bea83d
```
