---
id: T-009
title: Publish each Clip Deck build as a GitHub Release
lane: backend
depends_on: []
status: todo
round: 0
base_sha:
issue: 9
spec:
model:
---

## Publish each Clip Deck build as a GitHub Release

### What are we building?
Today the installable `ClipDeck.ipa` only exists as a CI artifact that expires after 30 days and has to be unzipped on a computer. After this task, pushing a version tag (or running the workflow by hand) builds the unsigned IPA and publishes it as a GitHub Release with a version number. Brent can open the release on his phone, download the IPA and hand it to SideStore.

### Why?
Brent may be away from his computer for weeks. A release page he can reach from the phone lets him install updates without a PC, and it gives every build a clear version.

### Done when
- AC-1 A new workflow `.github/workflows/release.yml` runs on pushes of tags matching `v*` and on `workflow_dispatch` with a required `version` input (e.g. `0.2.0`, tagged `v0.2.0`). It has `permissions: contents: write`.
- AC-2 It runs `./scripts/build-ipa.sh` with the version applied: `MARKETING_VERSION` = the version, `CURRENT_PROJECT_VERSION` = `github.run_number`. `scripts/build-ipa.sh` takes both from optional environment variables and passes them to `xcodebuild archive`; without them it behaves exactly as today.
- AC-3 It creates the release with `gh release create` and uploads `ClipDeck.ipa` and `ClipDeck.ipa.sha256`, with generated notes and marked as latest. Running it again for an existing tag fails with a clear message and doesn't overwrite.
- AC-4 The IPA's `Info.plist` has `CFBundleShortVersionString` equal to the version and `CFBundleVersion` equal to the run number; the bundle ID stays `dev.brent.clipdeck`.
- AC-5 `ios-simulator.yml` is unchanged and still green.
- AC-6 `docs/INSTALL_ON_IPHONE.md` (from T-003, or a new section if T-003 hasn't landed) explains how to cut a release (`git tag v0.2.0 && git push origin v0.2.0`) and how to install it from the phone: open the release page in Safari while signed in to GitHub, download `ClipDeck.ipa`, then Share › SideStore. While the repo is still private this needs a GitHub login; once it is public (T-010), no login is needed.

### How to check
`workflow_dispatch` only works once the workflow file is on `main`, so check it with a tag on the loop branch:
1. `git push origin loop/mkv-landscape-sideload`, then `git tag v0.1.1-rc1 && git push origin v0.1.1-rc1`.
2. `gh run list --workflow release.yml --limit 3`; `gh run watch <id> --exit-status`; on failure `gh run view <id> --log-failed`.
3. `gh release view v0.1.1-rc1` lists `ClipDeck.ipa` and `ClipDeck.ipa.sha256`. `gh release download v0.1.1-rc1 -D <scratch>/rel`, then read `Payload/ClipDeck.app/Info.plist` from the zip with Python `zipfile` + `plistlib` and compare the versions (AC-4); check the SHA-256.
4. Clean up: `gh release delete v0.1.1-rc1 --cleanup-tag -y`.
5. `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload` stays green (`./scripts/test-ios.sh`, `./scripts/build-ipa.sh`).
Unverified for Brent: downloading the IPA on the iPhone from the private repo's release page and installing it with SideStore.

### Agent notes
- Depends on: None (links into T-003's guide if present).
- Source: coordinator's plan for Brent's "reload without my computer" requirement.
- The repo is **private** today (`gh repo view --json visibility` → PRIVATE, checked 2026-11-19). Brent has chosen to make it public; the orchestrator does that before T-010 is tested. Don't change visibility in this task, and don't depend on it being public.
- Use the built-in `GITHUB_TOKEN`; no new secrets. The IPA is unsigned and contains no secrets.
- Keep the CI artifact upload in `ios-simulator.yml` as it is.

### Out of scope
- The SideStore/AltStore source JSON (T-010).
- Signing, TestFlight (T-007).
- Changing the repo's visibility.
