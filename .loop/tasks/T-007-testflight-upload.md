---
id: T-007
title: Upload a build to TestFlight from GitHub Actions
lane: backend
depends_on: [T-003]
status: blocked
round: 0
base_sha:
issue: 7
spec:
model:
---

## Upload a build to TestFlight from GitHub Actions

### What are we building?
With a paid Apple Developer account, Clip Deck can go to TestFlight instead of being re-signed every week. This task adds a manual GitHub Actions workflow that builds a signed Release version and uploads it to App Store Connect, using an API key kept in GitHub secrets. Brent then installs and updates it from the TestFlight app on his iPhone, with no App Store listing and no PC.

### Why?
TestFlight builds last 90 days, update from the phone, and need no Sideloadly, Developer Mode or weekly refresh. It only makes sense if Brent buys the $99/year account.

### Done when
- AC-1 `.github/workflows/testflight.yml` runs only on `workflow_dispatch`. Its first step fails with one clear message listing any missing secret: `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`.
- AC-2 `scripts/upload-testflight.sh` runs `xcodegen generate`, archives Release with `DEVELOPMENT_TEAM=$APPLE_TEAM_ID`, `CURRENT_PROJECT_VERSION=$GITHUB_RUN_NUMBER`, automatic signing and `-allowProvisioningUpdates` with `-authenticationKeyPath/-authenticationKeyID/-authenticationKeyIssuerID`, then `-exportArchive` with an ExportOptions.plist (`method` app-store-connect, `destination` upload, `teamID`). The key is decoded into the runner's temp folder, never printed, and deleted at the end.
- AC-3 Info.plist (via `ios/project.yml`) gains `ITSAppUsesNonExemptEncryption: false`. A `PrivacyInfo.xcprivacy` declares the required-reason APIs the app uses (at least UserDefaults `CA92.1`; file timestamp `C617.1` if used), no tracking, no collected data.
- AC-4 `ios-simulator.yml` and the unsigned IPA from `scripts/build-ipa.sh` are unchanged and still green.
- AC-5 `docs/DEVELOPMENT.md` "TestFlight" section (linked from the T-003 guide): enroll; register the bundle ID `dev.brent.clipdeck` and create the App Store Connect app record; create an App Store Connect API key with the role automatic signing needs; set the four secrets with `gh secret set`; run `gh workflow run testflight.yml --ref main`; add himself as an internal tester; install TestFlight.
- AC-6 Brent runs the workflow and the build appears in TestFlight and installs on his iPhone.

### How to check
`workflow_dispatch` workflows can only be started once the file is on `main`. Until then, test with a temporary extra trigger on tags `testflight-*` (remove it before landing) or after merging.
1. Without secrets: start the workflow; `gh run watch <id>` fails in the first step with the missing-secrets message.
2. `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload`; `./scripts/test-ios.sh` and `./scripts/build-ipa.sh` jobs green.
3. With secrets (Brent): `gh workflow run testflight.yml --ref main`; `gh run watch <id> --exit-status` green; build visible in App Store Connect › TestFlight within about 30 min; installs via TestFlight. Unverified until Brent does this.

### Agent notes
- Depends on: T-003 (the guide this section hangs from).
- Blocked: needs a paid Apple Developer account; Brent is staying on the free account for now (decided 2026-11-19). This is the optional future path; the current path is SideStore (T-003, T-009, T-010).
- No secrets in the repo, xcconfig or logs. `*.p8` is already git-ignored.
- App icon is already RGB without alpha (1024×1024), which App Store Connect requires; keep it that way.
- `NSAllowsArbitraryLoads` is fine for internal TestFlight; leave it.
- If T-004 has landed, the IPA contains LGPL FFmpeg; TestFlight internal testing is distribution to the team, so `THIRD_PARTY_NOTICES.md` must ship. Mention this in the docs.
- Bundle ID must be free in Apple's system; if `dev.brent.clipdeck` is taken, report it rather than changing it.

### Out of scope
- App Store submission, screenshots, metadata, App Review.
- External TestFlight testers.
- fastlane or match.
