---
id: T-010
title: Let SideStore find and install Clip Deck updates on its own
lane: backend
depends_on: [T-009, T-012]
status: todo
round: 0
base_sha:
issue: 10
spec:
model:
---

## Let SideStore find and install Clip Deck updates on its own

### What are we building?
SideStore can follow a "source": a small `apps.json` file listing an app's versions and download links. It then shows updates and installs them from the phone. After this task, every release (T-009) also publishes an up-to-date `apps.json` at a fixed public address. Brent adds that address to SideStore once and gets updates from then on without his computer or a GitHub login.

### Why?
With releases alone, Brent still has to find the release page, download the IPA and share it into SideStore. A source makes updating one tap, which matters when he's away for weeks.

### Done when
- AC-1 `scripts/make-source-json.py` writes `apps.json` in the AltStore/SideStore source format (as documented in the official AltStore source docs that SideStore follows): source `name`, `identifier`, and one app with `name` "Clip Deck", `bundleIdentifier` `dev.brent.clipdeck`, `developerName`, `iconURL`, `localizedDescription`, and `versions` (newest first: `version`, `buildVersion`, `date`, `downloadURL`, `size`, `minOSVersion` "17.0", `localizedDescription` from the release notes).
- AC-2 `python scripts/make-source-json.py --check apps.json` validates the required keys and that every `downloadURL` is an absolute https URL; it is run in the workflow before publishing.
- AC-3 `release.yml` (T-009) regenerates `apps.json` from the releases after each release and uploads it as an asset of the newest release, so it is always at `https://github.com/bman7222/clip-deck/releases/latest/download/apps.json`. `iconURL` points to a public copy of the 1024 px app icon.
- AC-4 `curl -sL <source URL> | python -m json.tool` works without any login, and each `downloadURL` returns the IPA without a login (`curl -sIL` → 200).
- AC-5 `docs/INSTALL_ON_IPHONE.md` explains adding the source in SideStore (linking SideStore's docs for the exact steps) and installing updates from it.

### How to check
1. Locally: `python scripts/make-source-json.py --check <generated apps.json>` passes; a broken file fails.
2. Cut a test release as in T-009 (`git tag v0.1.1-rc2 && git push origin v0.1.1-rc2`); `gh run watch <id> --exit-status`.
3. Once the orchestrator has made the repo public: AC-4's two `curl` checks without any GitHub login (before that they return 404, which is expected).
4. Clean up the test release (`gh release delete v0.1.1-rc2 --cleanup-tag -y`) and regenerate `apps.json` so it doesn't point at the deleted build.
Unverified for Brent: adding the source in SideStore and installing an update from it.

### Agent notes
- Depends on: T-009 (release workflow, versioned IPA) and T-012 (root `LICENSE`: all rights reserved + the LGPL-2.1 §6 clause, plus the FFmpeg notices inside the app).
- Hosting: Brent chose (2026-11-19) to make `bman7222/clip-deck` public, so publish `apps.json` as a release asset of this repo: `https://github.com/bman7222/clip-deck/releases/latest/download/apps.json`. No extra repo or token.
- The `LICENSE` file must have landed (T-012 done) before the orchestrator's secret scan, Brent's final confirmation and making the repo public. Only then is T-010 tested. The orchestrator makes the repo public, after a secret scan and a final confirmation from Brent, before T-010 is tested. Implementers and testers never change the repo's visibility.
- Check the source format against the official docs (AltStore "Make a Source" docs; SideStore's docs on sources) and cite them in the implementation notes. Don't invent keys.

### Out of scope
- Signing, TestFlight.
- A web page for the releases.
