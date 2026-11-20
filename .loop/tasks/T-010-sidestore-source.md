---
id: T-010
title: Let SideStore find and install Clip Deck updates on its own
lane: backend
depends_on: [T-009, T-012]
status: done
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

## Test report (round 1)
_by loop-tester · 2026-11-20 12:53_

Real release: tag v0.2.0 at 8d21225, Release IPA run 44786901731 (push, success, every step green, the apps.json step ran). Downloads and the SideStore sources are in %LOCALAPPDATA%\Temp\clip-deck-loop\T-010-r1.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `scripts/make-source-json.py` writes `apps.json` in the AltStore/SideStore source format (as documented in the official AltStore source docs that SideStore follows): source `name`, `identifier`, and one app with `name` "Clip Deck", `bundleIdentifier` `dev.brent.clipdeck`, `developerName`, `iconURL`, `localizedDescription`, and `versions` (newest first: `version`, `buildVersion`, `date`, `downloadURL`, `size`, `minOSVersion` "17.0", `localizedDescription` from the release notes). | Pass | The published apps.json (fetched anonymously) has every key. version 0.2.0, buildVersion "2", date 2026-11-20T17:51:20Z, minOSVersion 17.0, localizedDescription = the release notes without the Build line, sha256 included. Checked against SideStore@4f3d18d: StoreApp.swift:297-302 (required app keys), AppVersion.swift:95-106, Source.swift:146-151 (no `version` key, so v1 and the permission check at VerifyAppOperation.swift:111-115 is skipped; the IPA has NSLocalNetworkUsageDescription), FetchSourceOperation.swift:118-133 (date formats), StoreApp.swift:539 (latest = versions.first, so newest first matters). `python scripts/test-make-source-json.py` passes, and 4 mutations of a scratch copy (keep pre-releases, allow http, size+1, oldest first) each make it fail. |
| AC-2 `python scripts/make-source-json.py --check apps.json` validates the required keys and that every `downloadURL` is an absolute https URL; it is run in the workflow before publishing. | Pass | `--check` on the live apps.json → `ok`, exit 0. Bad input → exit 1 with a message: top-level list or string, non-object app or version, `size: true`, `https:///a.ipa`, uppercase or short sha256, a missing file, invalid JSON (unit test). Run log: "ok: build/apps.json" printed before `gh release upload`. |
| AC-3 `release.yml` (T-009) regenerates `apps.json` from the releases after each release and uploads it as an asset of the newest release, so it is always at `https://github.com/bman7222/clip-deck/releases/latest/download/apps.json`. `iconURL` points to a public copy of the 1024 px app icon. | Pass | Run 44786901731, step "Update the SideStore source (apps.json)": "wrote build/apps.json: 1 version(s), newest 0.2.0", then upload. `gh api .../releases/latest` → v0.2.0 (not a pre-release, not a draft) with assets apps.json, ClipDeck.ipa and ClipDeck.ipa.sha256. iconURL `curl -sIL` → 200 image/png. The downloaded file is a PNG, 1024x1024. Pre-releases skip the step by design, since they can't be "latest". |
| AC-4 `curl -sL <source URL> \| python -m json.tool` works without any login, and each `downloadURL` returns the IPA without a login (`curl -sIL` → 200). | Pass | No auth (curl, GH_TOKEN unset): the source URL → 200 and json.tool exit 0. downloadURL `https://github.com/bman7222/clip-deck/releases/download/v0.2.0/ClipDeck.ipa` → 302 → 200, content-length 4733749. The anonymously downloaded IPA is 4733749 bytes (= size) with SHA-256 10275d01…b606a (= sha256, = the .sha256 file, = the asset digest). Its Info.plist has CFBundleShortVersionString 0.2.0 (= version), CFBundleVersion 2 (= buildVersion = run number 2) and CFBundleIdentifier dev.brent.clipdeck (= bundleIdentifier). Every check VerifyAppOperation.swift:56-163 runs would pass. |
| AC-5 `docs/INSTALL_ON_IPHONE.md` explains adding the source in SideStore (linking SideStore's docs for the exact steps) and installing updates from it. | Pass | The section "Installing and updating from the source" covers the URL, the 404 warning, the add steps, the update steps and the install-from-source-once rule. The SideStore App Sources, URL Schema and FAQ links all return 200, and their content matches (app-sources.mdx, url-schema.mdx). "Sources tab, + top left" matches Sources.storyboard:178 (leftBarButtonItem systemItem="add"). The storeApp link claim matches InstallAppOperation.swift:222-255 and InstalledApp.swift:189-197. |
| Release (orchestrator ask) | Pass | `gh release view v0.2.0`: name "Clip Deck 0.2.0", isPrerelease false, isDraft false, the body starts with "Build number: 2". The FFmpegBuild 3.16.0 tree, THIRD_PARTY_NOTICES.md, LICENSE, INSTALL_ON_IPHONE.md and changelog links all return 200 without auth. (`gh release view` has no isLatest field; the `/releases/latest` API showed it.) |
| T-009 hardening carried in | Pass | Log: checkout `persist-credentials: false`, and "Removing auth" unsets extraheader right after the fetch (log :117-118). `GH_TOKEN: ***` appears only in the env of "Refuse to overwrite", "Create the release" and "Update the SideStore source" (log :172, :321, :342), not in the build step env (:211-219). YAML: no `${{ }}` inside any `run:`, and inputs only reach scripts through env. The tag check `gh api repos/$REPO/git/ref/tags/$TAG` is an exact match: v0.2.0 → exit 0; v0.2 and v0.9.9 → exit 1. Version regex: 0.2.0, 10.0.1, 1.2.3-rc1 and 0.0.0 are accepted. 01.2.3, 1.02.3, 1.2.03, 1.2, 1.2.3- and v1.2.3 are rejected. A newline + `::warning::` value prints as `1.2.3???warning??x` on one line. |

### Findings
Could fix
Where: scripts/make-source-json.py:90 (with release.yml:136 `--latest` for every stable tag)
Problem: versions are ordered by published_at, not by version number. A later-published older version (e.g. a 0.2.1 hotfix after 0.3.0) becomes versions[0]. SideStore's latest = versions.first (StoreApp.swift:539), so new installs get 0.2.1, iconURL points at v0.2.1, and `--latest` also moves /releases/latest to it.
Proof: Ran it: fixture v0.3.0 (Dec 1) + v0.2.1 (Dec 2) → `['0.2.1', '0.3.0']`, icon tag v0.2.1 (tools/order.py in the scratch folder).
Trigger: only when publishing versions out of order. Today's releases are linear.
Fix: sort by (major, minor, patch) from TAG_RE. Optionally pass `--latest=false` when the tag isn't the highest version.

Could fix
Where: .github/workflows/release.yml:131-149; docs/INSTALL_ON_IPHONE.md "Cutting a release"
Problem: apps.json is uploaded after the release is created and marked latest. If that step fails, /releases/latest/download/apps.json returns 404 (the source breaks for SideStore), and a re-run is refused by the never-overwrite check. The manual recovery (`python scripts/make-source-json.py --out apps.json` + `gh release upload <tag> apps.json --clobber`) is only in the task notes, not in docs/. There is also a ~2 s 404 window on every release (create 17:51:20, upload 17:51:22).
Proof: Read it: release.yml:67-70 + step order; timings from run 44786901731.
Fix: put the recovery commands in "Cutting a release", or build apps.json from the local IPA (size/sha256) and attach it in `gh release create`.

Could fix
Where: scripts/make-source-json.py:76
Problem: the per-version localizedDescription shown inside SideStore says "download `ClipDeck.ipa` and share it to SideStore". That wording is for the release page, not for someone already updating in SideStore.
Fix: trim the first paragraph or keep only the Third-party section and changelog.

Could fix
Where: .github/workflows/release.yml:38
Problem: the run warns that "Node.js 20 is deprecated … actions/checkout@v4". This was there before the change.
Fix: move to actions/checkout@v5 (SHA-pinned) with the next workflow edit.

```text
VERDICT: Pass
SPEC: AC-1 met, AC-2 met, AC-3 met, AC-4 met, AC-5 met
CHECKS_RUN: release.yml run 44786901731 (tag v0.2.0) → success; python scripts/test-make-source-json.py → all checks passed; mutation of a scratch copy x4 → test fails each time; --check on live apps.json → ok; anonymous curl of source/IPA/icon/notes links → 200; IPA plist/size/sha256 vs apps.json → all equal; py_compile → ok. Not run: ./scripts/test-ios.sh and ./scripts/run-ios.sh (macOS only; no Swift, test or UI change; build-ipa.sh's one-line regex change was exercised by the release run).
UNVERIFIED: (Brent, on the phone) adding the source in SideStore, installing Clip Deck from it over the current copy with data kept, and seeing an update when the next stable release ships.
REVIEWED_AT: 8d2122549e0a058358c61e9bd6f1b6953e94de62
```
