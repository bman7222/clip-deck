---
id: T-009
title: Publish each Clip Deck build as a GitHub Release
lane: backend
depends_on: []
status: done
round: 1
base_sha: d67566f09afb6be9bca08a034cf92a0be23580d1
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
- AC-7 The release notes include a link to the exact FFmpegBuild source tag the build uses (3.16.0 at the time of writing; read the pinned version from ios/project.yml) and point to `THIRD_PARTY_NOTICES.md` and the root `LICENSE`, as LGPL-2.1 requires for public binaries (review finding 8 in .loop/specs/mkv-import.review.md). If T-012 hasn't landed yet, the notes say "No third-party libraries bundled" instead, and this item is re-checked once T-012 lands.

### How to check
`workflow_dispatch` only works once the workflow file is on `main`, so check it with a tag on the loop branch:
1. `git push origin loop/mkv-landscape-sideload`, then `git tag v0.1.1-rc1 && git push origin v0.1.1-rc1`.
2. `gh run list --workflow release.yml --limit 3`; `gh run watch <id> --exit-status`; on failure `gh run view <id> --log-failed`.
3. `gh release view v0.1.1-rc1` lists `ClipDeck.ipa` and `ClipDeck.ipa.sha256`. `gh release download v0.1.1-rc1 -D <scratch>/rel`, then read `Payload/ClipDeck.app/Info.plist` from the zip with Python `zipfile` + `plistlib` and compare the versions (AC-4); check the SHA-256.
4. Clean up: `gh release delete v0.1.1-rc1 --cleanup-tag -y`.
5. `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload` stays green (`./scripts/test-ios.sh`, `./scripts/build-ipa.sh`).
Unverified for Brent: downloading the IPA on the iPhone from the private repo's release page and installing it with SideStore.

### Agent notes
- Carried over from T-003's final review (9a66a4a); T-009 edits docs/INSTALL_ON_IPHONE.md anyway, so fix these there: C1 if the Sideloadly copy has already expired, reinstall it with Sideloadly first so the cards can be synced (installing over the top keeps the data); C2 before setup, check you still have the episode's video and subtitle files in Files; C3 make the README/DEVELOPMENT wording "can revoke" match the guide's "will likely"; C4 quote all of install.mdx:73 ("at random times") and give the path Settings › General › Software Update › Automatic Updates; C5 the old copy uses one of the 3 app slots while installed. Also update "Getting the IPA" to point at Releases.
- Depends on: None (links into T-003's guide if present).
- Source: coordinator's plan for Brent's "reload without my computer" requirement.
- The repo is **private** today (`gh repo view --json visibility` → PRIVATE, checked 2026-11-19). Brent has chosen to make it public; the orchestrator does that before T-010 is tested. Don't change visibility in this task, and don't depend on it being public.
- Use the built-in `GITHUB_TOKEN`; no new secrets. The IPA is unsigned and contains no secrets.
- Keep the CI artifact upload in `ios-simulator.yml` as it is.

### Out of scope
- The SideStore/AltStore source JSON (T-010).
- Signing, TestFlight (T-007).
- Changing the repo's visibility.

## Implementation notes (round 1) · sonnet
_by loop-backend · 2026-11-20_
- Changed: new `.github/workflows/release.yml` (tags `v*` + workflow_dispatch `version`; top-level `permissions: contents: write`; version from tag/input goes through `env:` and is validated against `^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$`; early refusal if the release exists (or, for a manual run, the tag exists); build with `MARKETING_VERSION`=version, `CURRENT_PROJECT_VERSION`=run number; `check-ipa-notices.sh`; a Python check that the IPA Info.plist has the version, build number and `dev.brent.clipdeck`; `shasum` file; release notes with the FFmpegBuild tag URL read from `ios/project.yml` plus links to THIRD_PARTY_NOTICES.md and LICENSE at the tag; `gh release create ... --generate-notes --latest` with both assets). `scripts/build-ipa.sh` reads the two optional env vars (validated) and passes them to `xcodebuild archive`; unchanged without them. `ios-simulator.yml` untouched.
- Docs: `docs/INSTALL_ON_IPHONE.md` "Getting the IPA" now points at Releases (public repo, no login; SideStore file import) with a new "Cutting a release" section; C1-C5 done (C1/C2/C5 in the Moving section, C3 wording in README, DEVELOPMENT, guide, C4 full quote plus Settings > General > Software Update > Automatic Updates path); DEVELOPMENT.md links the release section.
- Files: .github/workflows/release.yml, scripts/build-ipa.sh, docs/INSTALL_ON_IPHONE.md, README.md, docs/DEVELOPMENT.md
- Checked: `bash -n scripts/build-ipa.sh` ok; release.yml parsed with PyYAML and every `run:` block passes `bash -n`; the awk that reads exactVersion from project.yml returns 3.16.0. Nothing Swift/xcodebuild can run here (CI only).
- Gotchas: pre-release versions (with `-`) get `--prerelease` instead of `--latest`, so rc tags never become "latest". `--target $GITHUB_SHA` creates the tag for manual runs; for tag pushes the tag already exists. Release notes are written with a heredoc (indentation is stripped by YAML). `--notes-file` plus `--generate-notes` appends GitHub's generated changelog.
- Tester, look at: the tag run `v0.1.1-rc1` from the loop branch (notes content, assets, plist versions, sha256, rerun on the same tag fails with the "already exists" message), a manual dispatch if possible after main has the file, an invalid tag like `v1.x` failing, and ios-simulator.yml still green.

## Test report (round 1)
_by loop-tester · 2026-11-20 10:53_

Evidence comes from release.yml run 44767085601 (push of tag v0.1.1-rc1 at 90f510e, run number 1, success), the release it published, and local runs. For the local runs, the workflow's `run:` blocks were pulled out with PyYAML and run under bash, against the real repo where they only read, or against stub `gh`/`xcodebuild`. Scratch files are in %LOCALAPPDATA%\Temp\clip-deck-loop\T-009-r1.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 A new workflow `.github/workflows/release.yml` runs on pushes of tags matching `v*` and on `workflow_dispatch` with a required `version` input (e.g. `0.2.0`, tagged `v0.2.0`). It has `permissions: contents: write`. | Pass (dispatch trigger Unverified) | The tag push started run 44767085601 (event push, headSha 90f510e). From the PyYAML parse: `on.push.tags: [v*]`, `workflow_dispatch.inputs.version` is `required: true, type: string`, and `permissions: {contents: write}`. I ran the dispatch branch of the version step locally: `0.2.0` gives VERSION=0.2.0 and TAG=v0.2.0, while `v0.2.0` and an empty value are rejected. A real dispatch can only run once the file is on main. |
| AC-2 It runs `./scripts/build-ipa.sh` with the version applied: `MARKETING_VERSION` = the version, `CURRENT_PROJECT_VERSION` = `github.run_number`. `scripts/build-ipa.sh` takes both from optional environment variables and passes them to `xcodebuild archive`; without them it behaves exactly as today. | Pass | The run log shows `MARKETING_VERSION: 0.1.1-rc1` in the build step env, and the IPA plist matches (AC-4). I also ran a stub xcodebuild that logs its args. With the vars unset or empty, the args are the same as before: no VERSION args, and `-quiet` comes right after `CODE_SIGN_IDENTITY=`. Both set gives `MARKETING_VERSION=0.1.1-rc1 CURRENT_PROJECT_VERSION=42`. `1.2.3; rm -rf /`, `1.2.3\nX=1`, `v1.2.3` and build `1a` are rejected before `rm -rf`. |
| AC-3 It creates the release with `gh release create` and uploads `ClipDeck.ipa` and `ClipDeck.ipa.sha256`, with generated notes and marked as latest. Running it again for an existing tag fails with a clear message and doesn't overwrite. | Pass (note) | `gh release view v0.1.1-rc1` shows both assets as uploaded (4733755 B and 79 B), and the body ends with the generated "**Full Changelog**" line. Overwrite refusal: I ran the real refusal step against the real repo. Push and dispatch both exit 1 with "::error::Release v0.1.1-rc1 already exists. Pick a new version; this workflow never overwrites a release." `v9.9.9` passes. With the release lookup stubbed out, a dispatch on the existing tag exits 1 with "Tag v0.1.1-rc1 already exists". Latest: a stub `gh` shows the create step passes `--latest` when PRERELEASE=false and `--prerelease` for `-rc` versions. That is why this rc is `isPrerelease: true` and `/releases/latest` returns 404. This is a deliberate reading of "marked as latest", since GitHub can't mark a pre-release as latest. The orchestrator should accept it. |
| AC-4 The IPA's `Info.plist` has `CFBundleShortVersionString` equal to the version and `CFBundleVersion` equal to the run number; the bundle ID stays `dev.brent.clipdeck`. | Pass | I downloaded the IPA and read it with zipfile + plistlib: CFBundleShortVersionString='0.1.1-rc1', CFBundleVersion='1' (the run number is 1), CFBundleIdentifier='dev.brent.clipdeck'. The workflow's own plist check passed in the run. Run locally on this IPA it exits 0 with the correct values and 1 with the wrong ones (expect 0.1.1, or build 2), so the check catches a version that wasn't applied. |
| AC-5 `ios-simulator.yml` is unchanged and still green. | Pass | `git diff d67566f..90f510e -- .github/workflows/ios-simulator.yml` is empty. The last green ios-simulator run is 44755434228 (41bf53a). The only code change since then is release.yml and build-ipa.sh (`git diff --stat 41bf53a..90f510e -- ios scripts .github`). Without the vars, build-ipa.sh passes exactly the same xcodebuild args (stub test), and the changed script ran successfully with `bash` on macos-latest in the release run. No new simulator run is needed. |
| AC-6 `docs/INSTALL_ON_IPHONE.md` (from T-003, or a new section if T-003 hasn't landed) explains how to cut a release (`git tag v0.2.0 && git push origin v0.2.0`) and how to install it from the phone: open the release page in Safari while signed in to GitHub, download `ClipDeck.ipa`, then Share › SideStore. While the repo is still private this needs a GitHub login; once it is public (T-010), no login is needed. | Pass | "Getting the IPA" and "Cutting a release (on the computer)" are in the guide. The repo is now PUBLIC (`gh repo view`), so "no GitHub login is needed" is correct. I confirmed this with an anonymous `curl -sIL` of the asset: 302, then 200, content-length 4733755, and the SHA-256 matches. Both anchors resolve on the rendered blob at 90f510e. /releases and the SideStore install page return 200. The quoted "This also occurs at random times because of Apple's software." is on the live page. T-003 C1-C5 are all in the diff. |
| AC-7 The release notes include a link to the exact FFmpegBuild source tag the build uses (3.16.0 at the time of writing; read the pinned version from ios/project.yml) and point to `THIRD_PARTY_NOTICES.md` and the root `LICENSE`, as LGPL-2.1 requires for public binaries. | Pass | The notes link https://github.com/superuser404notfound/FFmpegBuild/tree/3.16.0 (read from `ios/project.yml`:25 by awk, then validated), plus THIRD_PARTY_NOTICES.md and LICENSE at the tag. All of these links, and the INSTALL guide link, return 200 without auth. In the rendered release page HTML they are real `<a href>` links, `ClipDeck.ipa` shows as `<code>`, and "Third-party software" is an `<h3>`. The body JSON has no stray backslashes and no indentation. The notices check ran in the log ("ok:" ×3, "IPA notice check passed"). The IPA has Licenses/ and all 6 Aether* frameworks. |

### Findings
All findings are Could fix. There are no Must fix or Should fix findings.

Could fix
Where: .github/workflows/release.yml:29, :38
Problem: The `GH_TOKEN` (contents: write) is set at job level, so every step can read it, including `brew install xcodegen` and `xcodebuild archive`, which resolves and builds the third-party FFmpegBuild package. `actions/checkout` also leaves the token in .git/config (persist-credentials defaults to true). Only the refusal step and the create step need it.
Proof: Read it, release.yml:28-36 and the step list (PyYAML)
Trigger: a compromised build-time dependency could push to the repo during a release run
Fix: move `GH_TOKEN` into the `env:` of the two `gh` steps and add `with: persist-credentials: false` to checkout. The `git ls-remote` on a public repo works without credentials, or `gh api repos/$REPO/git/ref/tags/$TAG` can replace it.

Could fix
Where: .github/workflows/release.yml:68
Problem: A dispatch on an existing tag says "or push the tag to build that tag", but pushing a tag that already exists does nothing.
Proof: Ran it (stubbed release lookup)
Fix: say "or re-run that tag's own Release IPA run".

Could fix
Where: .github/workflows/release.yml:48
Problem: The rejected version is echoed raw inside `::error::`. A dispatch input that contains a newline can add workflow-command lines. Only users with write access can dispatch, and set-env is disabled, so the impact is cosmetic.
Proof: Ran it with `0.2.0\nX=1`, which is rejected and printed over two lines
Fix: print `${VERSION//$'\n'/ }`, or leave the value out of the message.

Could fix
Where: .github/workflows/release.yml:47, scripts/build-ipa.sh:20
Problem: Leading zeros are accepted (`v01.2.3` gives VERSION=01.2.3).
Proof: Ran it
Fix: `(0|[1-9][0-9]*)` per part, if wanted.

Could fix
Where: .github/workflows/release.yml:38
Problem: `actions/checkout@v4` isn't pinned to a SHA (same as ios-simulator.yml), and it logs a Node 20 deprecation warning in this run.
Fix: pin it to a SHA, and move to v5 when convenient.

Not caused by this change: the build logs "All interface orientations must be supported unless the app requires full screen" (project.yml orientations, not touched here).

```text
VERDICT: Pass
SPEC: AC-1 met (dispatch trigger first runs after merge to main), AC-2..AC-7 met; AC-3 "latest" applies to non-prerelease versions only, by design
CHECKS_RUN: release.yml run 44767085601 → success (tag v0.1.1-rc1, 90f510e, run #1); gh release view/download v0.1.1-rc1 → 2 assets, sha256 OK, plist 0.1.1-rc1 / 1 / dev.brent.clipdeck; anonymous curl of asset → 200, hash matches; 8 note/doc links → 200; local runs of the extracted workflow steps (version validation 16 cases, overwrite refusal against the real repo, create flags, plist check pass/fail); build-ipa.sh with stub xcodebuild (8 cases); ios-simulator.yml not re-run (unchanged; last green 44755434228)
UNVERIFIED: a real workflow_dispatch run (only possible once release.yml is on main); a non-prerelease tag actually becoming "Latest" on GitHub; Brent downloading the IPA in Safari on the iPhone and installing it with SideStore, including whether SideStore/iOS accept a "0.1.1-rc1" CFBundleShortVersionString
REVIEWED_AT: 90f510e1545945bd98803e7bf7b66790bd6e151c
```
