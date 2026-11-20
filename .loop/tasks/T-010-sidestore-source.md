---
id: T-010
title: Let SideStore find and install Clip Deck updates on its own
lane: backend
depends_on: [T-009, T-012]
status: testing
round: 1
base_sha: c694925819fda6869babb26d7d0b32ade9b5f450
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
- From T-009's review (e6138e1); T-010 edits release.yml, so fix these there: move GH_TOKEN from job level to only the steps that call gh, and add persist-credentials: false to checkout (third-party build steps shouldn't see a contents:write token); the manual-run error message at release.yml:68 ("push the tag" does nothing for an existing tag); escape or strip newlines in the rejected-version ::error:: at :48; optionally reject leading zeros in versions. The repo is PUBLIC (since 2026-11-20), so release asset URLs work without auth. Pre-releases aren't "latest", so /releases/latest only works once a plain vX.Y.Z exists; apps.json should point at explicit asset URLs.
- Depends on: T-009 (release workflow, versioned IPA) and T-012 (root `LICENSE`: all rights reserved + the LGPL-2.1 §6 clause, plus the FFmpeg notices inside the app).
- Hosting: Brent chose (2026-11-19) to make `bman7222/clip-deck` public, so publish `apps.json` as a release asset of this repo: `https://github.com/bman7222/clip-deck/releases/latest/download/apps.json`. No extra repo or token.
- The `LICENSE` file must have landed (T-012 done) before the orchestrator's secret scan, Brent's final confirmation and making the repo public. Only then is T-010 tested. The orchestrator makes the repo public, after a secret scan and a final confirmation from Brent, before T-010 is tested. Implementers and testers never change the repo's visibility.
- Check the source format against the official docs (AltStore "Make a Source" docs; SideStore's docs on sources) and cite them in the implementation notes. Don't invent keys.

### Out of scope
- Signing, TestFlight.
- A web page for the releases.

## Implementation notes (round 1) · sonnet
_by loop-backend · 2026-11-20_
- Changed: `scripts/make-source-json.py` (build from the GitHub releases API, or `--releases FILE`; `--check FILE`; stdlib only, Python 3.6+ syntax), `scripts/test-make-source-json.py` (fixture of release JSON -> expected apps.json, plus check failures and CLI round trip; run with plain `python`). `release.yml`: new last step "Update the SideStore source" (stable releases only: generate, `--check`, `gh release upload "$TAG" build/apps.json --clobber`), release notes now start with a `Build number: N` line (the script reads it). T-009 hardening: `GH_TOKEN` only on the 3 steps that call gh/the API (refusal, create, apps.json); `persist-credentials: false`; the existing-tag test now uses `gh api repos/$REPO/git/ref/tags/$TAG` (no git credentials needed); fixed manual-run message ("re-run that tag's own Release IPA run"); rejected version is printed with everything outside `A-Za-z0-9._-` replaced by `?` and cut at 60 chars; leading zeros rejected in release.yml and `build-ipa.sh`.
- Docs: `docs/INSTALL_ON_IPHONE.md` new section "Installing and updating from the source" (URL, the 404-until-a-stable-release warning, add steps with SideStore's App Sources / URL Schema pages, install-from-source-once rule), "Updating" and confirm list updated.
- Format sources (SideStore/SideStore @ 4f3d18d; 0.7.0-alpha 6032424 not re-diffed beyond StoreApp.swift, which was identical in the one diff I ran), all under `AltStore/Core/Model/`:
  - `Source.swift` CodingKeys: `name` required; `identifier` is decoded as groupID and ignored for identity (comment: source ID is the normalized source URL); `apps`, `news`, `subtitle`, `description`, `iconURL`, `website`, `tintColor` optional.
  - `StoreApp.swift` CodingKeys + init: `name`, `bundleIdentifier`, `developerName`, `localizedDescription`, `iconURL` are required (`decode`, not `decodeIfPresent`); `versions[]` optional (else the legacy flat keys); `marketplaceID` makes it a "notarized" app that then requires `buildVersion` (we set no marketplaceID).
  - `AppVersion.swift`: `version`, `date`, `downloadURL`, `size` (Int64) required; `buildVersion`, `localizedDescription`, `sha256`, `minOSVersion`, `maxOSVersion` optional.
  - `SideStore/Core/Operations/StandaloneOperations/FetchSourceOperation.swift:117-134`: dates must be ISO 8601 `2026-11-20T10:00:00Z` (full date-time with zone) or date only.
  - Docs: SideStore-Docs `docs/advanced/app-sources.mdx` ("fully compatible with AltStore Sources"; points at https://faq.altstore.io/developers/make-a-source; sidestore://source?url=... link) and `docs/advanced/url-schema.mdx`. I did not fetch the AltStore page itself; keys were verified against SideStore's code.
  - `VerifyAppOperation.swift`: at install SideStore checks the IPA against the source: downloaded bundle ID == source `bundleIdentifier` (if bundle-ID verification is on), `size` == IPA bytes, `sha256` if present, `version` == CFBundleShortVersionString, `buildVersion` == CFBundleVersion. So size/build/version in apps.json must be exact. That is why the script takes size and sha256 from the release asset (API `size`, `digest`) and the build number from the notes.
- FINDING (team-ID suffix): SideStore does NOT match by bundle ID for updates. `InstalledApp` keeps both `bundleIdentifier` (the ORIGINAL id, set from the source/IPA: `InstallAppOperation.swift:234 originalBundleIdentifier: context.bundleIdentifier`) and `resignedBundleIdentifier` (the suffixed one). The link to the source is the `installedApp.storeApp` relationship, assigned only when the install was started from a source app (`InstallAppOperation.swift:20,255`). `hasUpdate` (`InstalledApp.swift:~193`) then compares the installed `version` with `storeApp.latestSupportedVersion` by major.minor.patch semver. So the suffix does not matter, but an install via file import ("+" / Files share) has `storeApp == nil` (`isSideloaded`) and will never show updates. Consequence for Brent: his first install must come from the source (installing it over a file-imported copy works: the existing InstalledApp is found by the resigned ID, `InstallAppOperation.swift:222-226`, and gets the storeApp link). Documented in the guide. Not verified on a device.
- Decisions: pre-releases and drafts are excluded (rc tags would otherwise show as updates); a stable release lacking the `ClipDeck.ipa` asset or the `Build number:` line is skipped with a warning (so releases made before this task, none exist today, wouldn't appear). `iconURL` = raw.githubusercontent.com at the newest release tag, path `ios/ClipDeck/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024x1024 PNG, verified). `sha256` comes from the asset `digest` field when GitHub returns it. Versions are sorted newest first by `published_at`. `developerName` is "Brent" (as in LICENSE). `identifier` "dev.brent.clipdeck.source" (required by the AltStore format, ignored by SideStore).
- Gotchas: `/releases/latest/download/apps.json` 404s until a non-pre-release exists. apps.json lives only on the newest stable release: if an older stable version is published after a newer one, GitHub's "latest" is by creation date, so it works but is worth knowing. Pre-release runs do not touch apps.json. The apps.json step runs after the release is created, so a failure there leaves a release without a source (rerun is blocked by the never-overwrite check; fix by `gh release upload <tag> apps.json --clobber` after generating it locally with `python scripts/make-source-json.py --out apps.json`).
- Checked: `python scripts/test-make-source-json.py` -> all checks passed; `python -m py_compile` both scripts ok; release.yml parsed with PyYAML, every `run:` block `bash -n` ok, GH_TOKEN present only on 3 steps and not at job level; `bash -n scripts/build-ipa.sh` ok; version step run locally: `0.2.0`, `1.2.3-rc1` accepted; `01.2.3`, `1.x`, and a value with newline + `::set-output` rejected with a one-line message. Not run: the workflow itself and a real API fetch (no release exists yet).
- Tester, look at: the tag run (a stable-looking tag like v0.1.1 is needed to exercise the apps.json step; an rc tag skips it by design), the generated apps.json from the real release (`--check`, `curl -sL .../releases/latest/download/apps.json | python -m json.tool`, size equals the IPA bytes, buildVersion equals the plist CFBundleVersion, date format), the `digest` field present on the real asset, notes still render with the `Build number:` first line, and that the `gh api .../git/ref/tags/$TAG` existence check behaves for a manual dispatch.
