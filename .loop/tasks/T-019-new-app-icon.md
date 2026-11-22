---
id: T-019
title: New app icon
lane: frontend
depends_on: []
status: done
round: 1
base_sha: e894569ba9cde441a2f095afbc6f034cdcf059a3
issue: 21
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Show the new Clip Deck icon on the home screen

### What are we building?
Clip Deck still uses its placeholder icon. After this task the app uses Brent's new 1024 px icon on the home screen. The SideStore source picks it up at the next release, because it reads the same file.

### Why?
The app should look finished on the home screen and in SideStore.

### Done when
- AC-1 `ios/ClipDeck/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` is a byte-for-byte copy of `clip-deck-temp-files/clip-deck_app_icon_1024.png` (a folder next to the repo; the orchestrator passes the full path to the builder). That file is 1024×1024, 8-bit RGB with no alpha (the planner checked it on 2026-11-22). Record the SHA-256 of both files in the implementation notes.
- AC-2 `Contents.json`, the file name and the path don't change, so `scripts/make-source-json.py` (`ICON_PATH`, line 27) keeps pointing at the new art.
- AC-3 The CI ipa job builds with no actool warning or error about the app icon. The IPA contains `Payload/ClipDeck.app/AppIcon60x60@2x.png` and `Assets.car`.
- AC-4 Every existing test still passes.

### How to check
CI only (`ci_only: true`):
1. The orchestrator pushes `loop/player-lookup-timeline`, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`.
2. `gh run list --branch loop/player-lookup-timeline --workflow ios-simulator.yml --limit 3`, then `gh run watch <id> -i 60 --exit-status`. On failure, `gh run view <id> --log-failed`.
3. `gh run download <id> -n ClipDeck-ipa -D <scratch>`. List the IPA (for example `python -I -c "import zipfile,sys; print('\n'.join(n for n in zipfile.ZipFile(sys.argv[1]).namelist() if 'AppIcon' in n))" <ipa>`), extract `AppIcon60x60@2x.png` and look at it: it must show the new art. Search the ipa job log for "AppIcon".
- Unverified for Brent: the icon on his home screen after a Sideloadly install, and in SideStore after the next release.

### Agent notes
- Depends on: none. Source: spec "Fix 1: App icon" (T-019).
- Copy the file as it is and don't re-encode it: re-saving can add an alpha channel, which Apple's tooling rejects for app icons. The same folder also has `clip-deck_app_icon.png` and `deckerd_temp.png`; don't use either.
- No dark or tinted variants. None exist today, and Brent didn't ask for them.
- Nothing to regenerate: the asset catalog already holds a single 1024 universal image, and iOS makes the smaller sizes from it.

### Out of scope
- Dark or tinted icon variants, a launch screen, using the icon inside the app.
- Tagging a release (the orchestrator does that when Brent says so).

## Implementation notes (round 1)
- Changed: replaced `ios/ClipDeck/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` with a byte-for-byte `cp` of the new 1024 px icon (no re-encoding). `Contents.json`, file name and path are untouched, so `scripts/make-source-json.py` ICON_PATH still points at it.
- SHA-256 of the source file: 1aed1007344e5290d123ed0eda5c3dd44e52ba9661517455ca25452fe71808f8
- SHA-256 of AppIcon.png after copy: 1aed1007344e5290d123ed0eda5c3dd44e52ba9661517455ca25452fe71808f8 (identical). The old placeholder was f515a55c7eff44d8831a4b1c135958edfc63ce81ea1c7d986c985a57d5eae026.
- Checked: hashes match; Contents.json unchanged. No code changed, nothing compiled (CI only).
- Tester: run CI ipa job, confirm no actool AppIcon warning, `AppIcon60x60@2x.png` and `Assets.car` in the IPA, and that the extracted icon shows the new art.

## Test report (round 1)
_by loop-tester · 2026-11-22 14:52_

Reviewed `git diff e894569..8192e71`: the only product change is `AppIcon.png` (6,699 → 614,661 bytes); the rest is `.loop/`. CI run 45055876049 (ios-simulator.yml, scope=all, workflow_dispatch) checked out 8192e71. Artifacts are in `%TEMP%\clip-deck-loop\T-019-r1\`.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `AppIcon.png` is a byte-for-byte copy of `clip-deck-temp-files/clip-deck_app_icon_1024.png`, 1024×1024, 8-bit RGB with no alpha; SHA-256 of both recorded | Pass | Ran `sha256sum` on both: 1aed1007…08f8 on both sides, and `cmp` says the files are identical. The committed blob (`git show 8192e71:<path> \| sha256sum`) matches too. I parsed the PNG chunks myself: IHDR 1024×1024, bit depth 8, colour type 2 (RGB), not interlaced, no tRNS, all CRCs valid, nothing after IEND. The builder recorded the hashes in the implementation notes. |
| AC-2 `Contents.json`, the file name and the path don't change, so `make-source-json.py` `ICON_PATH` (line 27) keeps pointing at the new art | Pass | `git diff e894569 --name-status` shows only `AppIcon.png` under `ios/`. `Contents.json` still holds one universal 1024 `AppIcon.png`. `scripts/make-source-json.py:27` is that same path, and `:119` builds `iconURL` from `<newest tag>/ICON_PATH`, so SideStore picks up the new art at the next tag. Ran `python -I -B scripts/test-make-source-json.py` locally → "all checks passed". |
| AC-3 the ipa job builds with no actool warning or error about the app icon; the IPA contains `Payload/ClipDeck.app/AppIcon60x60@2x.png` and `Assets.car` | Pass | ipa job 137310861738 passed in 2m3s. The log's only warning is "All interface orientations must be supported…", which was already there: the same line is in the ipa job of 45002423211. The log has no "AppIcon" or actool line. The `ClipDeck-ipa` artifact contains `AppIcon60x60@2x.png` (120×120), `AppIcon76x76@2x~ipad.png` (152×152) and `Assets.car` (1,453,128 B, up from 38,440). `Info.plist` has `CFBundleIconName` = AppIcon. Apple stores these PNGs in its CgBI format, so I decoded them first: they show the new art (`%TEMP%\clip-deck-loop\T-019-r1\ipa\icons\AppIcon60x60@2x.view.png`). Checked against the source scaled down to the same size, the mean RGB difference is 2.49/255 at 120 px and 1.97/255 at 152 px. The placeholder icon in 45002423211's IPA scores 43.12/255 on the same check, so the check does tell old art from new. |
| AC-4 Every existing test still passes | Unverified (needs a re-run) | Simulator job 137310862004: 389/390. ClipDeckTests passed 326/326 and ClipDeckUITests 63/64. Every test listed as a known flake passed. The one failure is the lost tap described under Pre-existing below; the change didn't cause it. |
| (How to check) Icon on Brent's home screen after a Sideloadly install, and in SideStore after the next release | Unverified (Brent) | Needs a real device and a release tag. |

### Findings
No Must fix, Should fix or Could fix.

Other checks with nothing to report:
- **Metadata (the repo is public).** The PNG carries sRGB, gAMA, pHYs, tEXt `Software=Paint.NET 5.2` and an eXIf block that holds only the resolution and `Software`. There is no author, GPS or date.
- **Docs.** None mention a placeholder icon, so none are stale.
- **Size.** The IPA grows from 4.89 MB to 6.33 MB because `Assets.car` keeps the 1024 art. AC-1 requires a byte-for-byte copy, so that growth is expected and isn't a finding.

### Pre-existing (not caused by this change)
**1. Lost Up tap in a T-018 UI test.** `SubtitleStyleCardTesterUITests/testUpDisablesWhenTheLineCanNoLongerMoveUp()` failed with: "XCTAssertLessThan failed: ("205.33333333333334") is not less than ("204.33333333333334") - Up tap 7 moves the line by more than 1 pt".

The test's screen recording (pulled from the xcresult, frames every 0.05–0.25 s) shows a lost tap:
- Each of Up taps 1–6 moves the line about 18 pt, at 25.25, 26.5, 27.75, 29.0, 30.25 and 31.5 s into the recording.
- After that the line stays put until the recording ends at 34.5 s, even though tap 7 was sent at about 32.6–32.9 s.
- Up stays at full brightness (enabled) the whole time. If the action had run and the line really were at its limit, Up would have dimmed to "Highest".

So the tap never reached the button's action. Other evidence points the same way:
- In the same build, the sibling test `testUpTapsWithTheCardOpenRecordWhereTheLineIs` passed with 8 Up taps, each moving the line by more than 1 pt.
- The failing test itself passed in 45002423211.
- The diff contains no Swift and no layout changes.

This test is not on the Learned flake list yet.

**2. CI time headroom.** Testing took 53 min, and the simulator job took 57 of its 60 minutes.

**3. Launch step skipped.** "Launch in simulator and screenshot" (`./scripts/run-ios.sh`) was skipped because the test step failed. It screenshots the app, not the home screen, so it adds nothing for this task.

```text
VERDICT: Blocked
SPEC: AC-1 met, AC-2 met, AC-3 met, AC-4 not yet proven (389/390; the 1 failure is a pre-existing lost-tap flake unrelated to the icon)
CHECKS_RUN: CI 45055876049 (scope=all, 8192e71): ipa job green (build-ipa.sh + check-ipa-notices.sh), simulator job red (test-ios.sh 389/390; run-ios.sh skipped); local python -I -B scripts/test-make-source-json.py → all checks passed; sha256sum/cmp → identical; PNG header/chunk parse → 1024×1024 RGB 8-bit, no alpha
UNVERIFIED: AC-4 until SubtitleStyleCardTesterUITests passes on 8192e71; Brent: home-screen icon after Sideloadly, SideStore icon after the next release
NEEDED: re-run CI: gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=tests -f only_testing=ClipDeckUITests/SubtitleStyleCardTesterUITests (5 tests; all other 389 already passed on this SHA)
REVIEWED_AT: 8192e71107d5933c72c102487f086f327aded976
```

### Round 1 addendum
_by loop-tester · 2026-11-22 16:10_

Verify-only run 45069006816 used scope=tests and only_testing=ClipDeckUITests/SubtitleStyleCardTesterUITests. The checkout log shows 8192e71, the same SHA as before. The simulator job took 14m32s and passed 4 of the 5 tests. Results are in `%TEMP%\clip-deck-loop\T-019-r1v\`.

- **Round 1's failure now passes.** `testUpDisablesWhenTheLineCanNoLongerMoveUp` passed in 72.8 s. Up dimmed after 13 taps, the same count as T-018's run 45002423211.
- **The sibling test's log confirms what tap 7 should do.** It records maxY 205.33 after Up 6 and 187.33 after Up 7. In round 1, maxY stayed at 205.33 after tap 7, which confirms that tap was lost.
- **A different test failed, at a known flake.** `testFirstDownTapMovesTheLineWhenTheStoredPlaceIsAboveTheClamp` failed with "XCTAssertTrue failed - Seeded show should appear". This is the "Seeded show should appear" flake already listed in Learned.
  - The failure comes inside `launchLandscape`, before the test touches the player.
  - The UI hierarchy captured at the failure shows the library still saying "Your library is empty" after 66.6 s of waiting.
  - The runner was slow throughout: app launches took 5.7–31.1 s in this run, against 4.4–7.1 s in 45055876049. One existence query alone took 30.2 s.
  - The same test passed on 8192e71 in 45055876049, in 24.4 s.
  - A PNG change can't affect library seeding.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-4 Every existing test still passes | Pass | Every one of the 390 tests has a passing run on 8192e71. 389 passed in 45055876049, and the remaining one (`testUpDisablesWhenTheLineCanNoLongerMoveUp`) passed in 45069006816. Each run's single failure is a pre-existing CI flake (a lost tap; a sample library that wasn't ready yet). Both failures happen at steps the PNG-only diff can't reach, and the other run passed each of those tests. |

AC-1 to AC-3 stay Pass as in round 1. No run on 8192e71 was all green on its own: the Pass for AC-4 rests on the two runs together, the same way T-016's round 2 addendum combined two runs. If a single fully green run is wanted, the cheapest is `-f scope=tests -f only_testing=ClipDeckUITests/SubtitleStyleCardTesterUITests/testFirstDownTapMovesTheLineWhenTheStoredPlaceIsAboveTheClamp` (it would be CI run 3 of 4).

```text
VERDICT: Pass
SPEC: AC-1 met, AC-2 met, AC-3 met, AC-4 met (all 390 tests pass on 8192e71 across 45055876049 + 45069006816; each run's single failure is a pre-existing CI flake)
CHECKS_RUN: CI 45055876049 (scope=all): ipa green, simulator 389/390 (lost-tap flake); CI 45069006816 (SubtitleStyleCardTesterUITests only): 4/5 (known "Seeded show should appear" flake); local test-make-source-json.py pass; sha256/cmp identical
UNVERIFIED: Brent: the icon on the home screen after a Sideloadly install, and in SideStore after the next release
REVIEWED_AT: 8192e71107d5933c72c102487f086f327aded976
```
