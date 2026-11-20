---
id: T-013
title: Tidy up the loose ends from the loop's reviews
lane: backend
depends_on: [T-005]
status: todo
round: 0
base_sha:
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
