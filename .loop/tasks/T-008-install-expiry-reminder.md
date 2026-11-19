---
id: T-008
title: Remind me once a day to refresh in SideStore before the app expires
lane: fullstack
depends_on: []
status: todo
round: 0
base_sha:
issue: 8
spec:
model:
---

## Remind me once a day to refresh in SideStore before the app expires

### What are we building?
A sideloaded Clip Deck gives no warning before it stops opening. After this task the app reads its own expiry date from the signing profile embedded in the install. From 48 hours before that date, the library shows a small yellow banner at most once a day: "Clip Deck stops opening on Fri 21 Nov at 14:02. Open SideStore and tap Refresh All." An X button or a swipe dismisses it for the rest of the day. Builds without a profile (simulator, TestFlight, App Store) never show it.

### Why?
If SideStore's automatic refresh silently fails while Brent is away from his computer, he only finds out when the app won't open. A daily nudge gives him time to refresh on the phone first.

### Done when
- AC-1 (backend) A `nonisolated` parser reads `embedded.mobileprovision` from the app bundle: it takes the XML plist between `<?xml` and `</plist>` inside the signed file and returns `ExpirationDate`, or nil when the file is missing or unreadable. Unit tests use byte data built in the test (plist wrapped in junk bytes), a missing file and a corrupt file. No real profile is committed.
- AC-2 (backend) A pure function decides whether to show the banner, with "now", the expiry date and the last-dismissed day injected: show when expiry is 48 hours away or less (including the last day and after expiry) and it hasn't been dismissed on today's local calendar day; otherwise hide. Unit tests cover: 3 days left (hidden), 47 h left (shown), dismissed today (hidden), dismissed yesterday (shown again), expired (shown), past midnight in the local time zone.
- AC-3 (frontend) The library shows the banner (`library.expiryBanner`) in the Pending (sunflower) colour with a calendar icon, the local date and time, and the SideStore instruction. A 44 pt X button (`library.expiryBanner.dismiss`, spoken "Dismiss until tomorrow") and a horizontal swipe both dismiss it with a short slide-out (Reduce Motion: fade). The dismissal day is saved in UserDefaults.
- AC-4 (frontend) If SideStore's URL scheme is confirmed (see notes), the banner has an "Open SideStore" button (`library.expiryBanner.openSideStore`) that opens it; if opening fails, nothing breaks and the text instruction remains. If not confirmed, text only.
- AC-5 Anki settings shows "This install expires: <date>" whenever a date is known.
- AC-6 A Debug-only `-uiTestingExpiry <ISO-8601 date>` launch argument overrides the expiry date. A UI test launches with a date 1 day ahead, sees the banner, attaches `expiry-01-banner`, taps the X, and the banner is gone; with a date 10 days ahead, no banner. The flag is documented in CLAUDE.md and DEVELOPMENT.md.
- AC-7 At a large Dynamic Type size the banner wraps and doesn't cover the Sync or Upload buttons.

### How to check
CI only:
1. `git push origin loop/mkv-landscape-sideload`, then `gh workflow run ios-simulator.yml --ref loop/mkv-landscape-sideload`.
2. `gh run list --branch loop/mkv-landscape-sideload --workflow ios-simulator.yml --limit 3`; `gh run watch <id> --exit-status`; on failure `gh run view <id> --log-failed`.
3. `./scripts/test-ios.sh` and `./scripts/build-ipa.sh` jobs pass; `gh run download <id> -n simulator-results -D <scratch>/ci` and read `screenshots/ui-tests/*expiry-01*`.
Unverified for Brent: after installing through SideStore, Anki settings shows the real expiry date (about 7 days out), and the date moves forward after a refresh.

### Agent notes
- Depends on: None. Wording should match T-003's guide; if T-003 has landed, use its names for SideStore's refresh button.
- Source: Brent's decision 2026-11-19: once a day at most, from 48 h before expiry; X plus swipe; dismiss hides it for the rest of that day; still once a day on the last day and after expiry; say to refresh in SideStore.
- SideStore URL scheme: the planner could not confirm one. Check SideStore's official source (its Info.plist `CFBundleURLTypes` on GitHub, or docs.sidestore.io). Use it only if confirmed there; cite the source in the implementation notes. Use `openURL` and handle a false result; don't add `LSApplicationQueriesSchemes`.
- `Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision")`. No Security/CMS decoding; the plist is stored in clear inside the CMS envelope.
- Backend part in `Services/` (e.g. `InstallExpiry.swift`); banner in `Features/Library/` built from `DesignSystem` pieces (colour carries meaning per DESIGN.md: sunflower = waiting/attention).

### Out of scope
- Local notifications.
- Refreshing the app from inside Clip Deck.
- TestFlight build expiry (TestFlight shows its own).
