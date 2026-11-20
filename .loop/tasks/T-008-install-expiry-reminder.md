---
id: T-008
title: Remind me once a day to refresh in SideStore before the app expires
lane: fullstack
depends_on: []
status: done
round: 2
base_sha: b24ac7f61a97c57b552e49bd89ef194f2633955b
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

## Implementation notes (round 1, backend) · sonnet
_by loop-backend · 2026-11-20_
- Changed: `InstallExpiry` (nonisolated enum) and `ExpiryReminderStore` in `ios/ClipDeck/Services/InstallExpiry.swift`; tests in `ios/ClipDeckTests/InstallExpiryTests.swift` (24 tests: wrapped/unwrapped plist, extra keys, empty/garbage, truncated, malformed, missing key, wrong type, non-dict plist, file read, missing/nil/empty/corrupt file, 48 h boundary +-1 s, last day, expired, nil expiry, dismissed today/yesterday, Tokyo midnight, New York DST fall-back and spring-forward, store persistence, override parsing, Debug override, strings). `LSApplicationQueriesSchemes: [sidestore]` added to `ios/project.yml` (the scheme is confirmed, below).
- Not done on purpose: certificate expiry. `DeveloperCertificates` holds DER certs and reading notAfter needs an X.509 parser (Security's SecCertificateCopyValues is macOS only), so it isn't cheap. On a free account the profile and certificate expire together, so ExpirationDate is the right date.
- SideStore URL scheme: confirmed in SideStore@4f3d18d `AltStore/Info.plist` `CFBundleURLTypes` ("SideStore General", `CFBundleURLSchemes` = `sidestore`; a second type `sidestore-$(PRODUCT_BUNDLE_IDENTIFIER)` is for backups). `AppDelegate.application(_:open:)` sends non-file URLs to `URLHandler.shared.handle`. `sidestore://` with no host is not a documented action, so it just brings SideStore to the front (iOS launches the app before the handler runs; an unknown URL is ignored). Documented actions are in docs/advanced/url-schema.mdx. Not tested on a device; Brent should tap the button once.
- Checked: nothing compiled (Windows, no Mac). CI only. Files read for conventions: AppConfig.swift, AnkiSettings.swift, ClipDeckApp.swift.

### CONTRACT for the frontend
- Expiry: `InstallExpiry.currentExpiry()` -> `Date?` (real profile date; in Debug builds `-uiTestingExpiry <ISO-8601>` wins; nil on simulator/TestFlight/App Store). Read it once at launch, not per render.
- Decide: `InstallExpiry.shouldShowBanner(now:expiry:lastDismissedDay:calendar:)` -> Bool (pure). Easier: `let store = ExpiryReminderStore(defaults:)`; `store.shouldShowBanner(now: Date(), expiry: expiry)`.
- Dismiss: `store.recordDismissal()` (stores "yyyy-MM-dd" of the local day under UserDefaults key `installExpiry.lastDismissedDay`; hides until the next local day). Re-evaluate `now` when the app returns to the foreground (scenePhase active) so a banner reappears the next day.
- UI tests: `ClipDeckApp` clears the "uiTesting" UserDefaults suite on launch, so build the store with `ExpiryReminderStore(defaults: UserDefaults(suiteName: "uiTesting") ?? .standard)` when `LaunchFlags.isUITesting`, otherwise a dismissal would leak between runs.
- Strings: `InstallExpiry.bannerText(expiry:now:)` -> "Clip Deck stops opening on Fri 21 Nov at 14:02. Open SideStore and tap Refresh All." (after expiry: "Clip Deck's signing ran out on Fri 21 Nov at 14:02. Open SideStore and tap Refresh All."). `InstallExpiry.settingsText(expiry:)` -> "This install expires: Fri 21 Nov 2026 at 14:02". Both use English text, 24 h time, the device time zone. Button label "Open SideStore"; dismiss VoiceOver label "Dismiss until tomorrow".
- SideStore: `InstallExpiry.sideStoreURL` (`sidestore://`). Call `openURL`/`UIApplication.shared.open` and handle false. `LSApplicationQueriesSchemes` is now in project.yml, so `UIApplication.shared.canOpenURL(InstallExpiry.sideStoreURL)` works if you want to hide the button when SideStore is missing. Run `xcodegen generate` (CI does).
- Docs still to write (frontend half): `-uiTestingExpiry` in CLAUDE.md and docs/DEVELOPMENT.md.
- Tester, look at: the parser against a real SideStore-installed profile (Brent, on device); `String(format: "%04d")` day stamps; the DST tests (dates built in UTC, calendars fixed per test).
- Gotchas: tests are `@MainActor` because the module defaults to MainActor; the pure `InstallExpiry` enum is `nonisolated`. `ExpiryReminderStore` is MainActor.

## Implementation notes (round 1, frontend) · sonnet
_by loop-frontend · 2026-11-20_
- Changed: new `Features/Library/ExpiryBanner.swift` (sunflower banner, calendar icon, text from `InstallExpiry.bannerText`, "Open SideStore" button, 44 pt X with VoiceOver "Dismiss until tomorrow", horizontal swipe, slide-out or fade with Reduce Motion, also an accessibility action). `LibraryView` reads `InstallExpiry.currentExpiry()` once (`@State`), uses `ExpiryReminderStore` on the "uiTesting" suite under `-uiTesting`, re-evaluates on appear and when scenePhase becomes active, and puts the banner above the tab picker (it pushes content down, so it cannot cover the toolbar's Sync/Upload). `AnkiSettingsView` shows `InstallExpiry.settingsText` (`settings.expiry`) when a date is known. `ClipDeckApp`: new `-uiTestingKeepExpiryDismissal` flag preserves only the dismissal key when the suite is cleared (needed, otherwise relaunch always resets it). UI tests in `ClipDeckUITests/ExpiryBannerUITests.swift` (3 tests; screenshots `expiry-01-banner`, `expiry-02-large-text`). Flag documented in CLAUDE.md and docs/DEVELOPMENT.md.
- Open SideStore: uses `openURL` with a completion handler; on false it shows "SideStore isn't installed on this iPhone. Open it from the Home Screen instead." (`library.expiryBanner.openError`). Button is not hidden via canOpenURL.
- Checked: nothing compiled (Windows, no Mac); CI only. Not run: all new UI tests, `withAnimation(completion:)` (iOS 17 API, matches deployment target).
- Tester, look at: whether the banner is found as `otherElements["library.expiryBanner"]` (container with children; if XCUITest exposes it differently, adjust the query); swipe dismissal by hand (not UI-tested); the relaunch test; large-text screenshot; the banner is dismissed state-wise only after the 0.22 s animation completes.
- Gotchas: relaunch test needs `-uiTestingKeepExpiryDismissal`; tests assume the run isn't within the same instant as local midnight.

## Test report (round 1)
_by loop-tester · 2026-11-20 13:31_

CI run 44788627149 (scope=all, SHA d898c19). The ipa job passed. The simulator job failed: 197 tests passed and 2 failed, both in ExpiryBannerUITests, and both because of test-side bugs (details below). All 24 InstallExpiryTests passed. MiningFlowUITests, MKVImportUITests (2), PlayerLandscapeUITests (6), PlayerLandscapeBehaviourUITests (8, including both known flakes), AboutUITests (3) and LaunchUITests all passed. The xcresult was read through its database.sqlite3; scratch files are in %LOCALAPPDATA%\Temp\clip-deck-loop\T-008-r1.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 (backend) A `nonisolated` parser reads `embedded.mobileprovision` from the app bundle: it takes the XML plist between `<?xml` and `</plist>` inside the signed file and returns `ExpirationDate`, or nil when the file is missing or unreadable. Unit tests use byte data built in the test (plist wrapped in junk bytes), a missing file and a corrupt file. No real profile is committed. | Pass | 11 parser tests passed in 44788627149: wrapped, unwrapped, extra keys, empty/garbage, truncated, malformed, missing key, wrong type, non-dict, file read, missing/nil/empty/corrupt file. The diff contains no .mobileprovision file, and the unsigned IPA has none either. |
| AC-2 (backend) A pure function decides whether to show the banner, with "now", the expiry date and the last-dismissed day injected: show when expiry is 48 hours away or less (including the last day and after expiry) and it hasn't been dismissed on today's local calendar day; otherwise hide. Unit tests cover: 3 days left (hidden), 47 h left (shown), dismissed today (hidden), dismissed yesterday (shown again), expired (shown), past midnight in the local time zone. | Pass | threeDaysLeftIsHidden, boundaryAt48Hours (48 h shown, 48 h + 1 s hidden, 47 h shown), lastDayAndExpiredAreShown, dismissedTodayHiddenYesterdayShown, midnightInLocalTimeZoneRollsTheDay (Tokyo), both DST tests, storeRecordsDismissalAndPersists: all passed in 44788627149. |
| AC-3 (frontend) The library shows the banner (`library.expiryBanner`) in the Pending (sunflower) colour with a calendar icon, the local date and time, and the SideStore instruction. A 44 pt X button (`library.expiryBanner.dismiss`, spoken "Dismiss until tomorrow") and a horizontal swipe both dismiss it with a short slide-out (Reduce Motion: fade). The dismissal day is saved in UserDefaults. | Partly: banner, X and persistence pass; swipe unverified (test added); Reduce Motion unverified | Screenshot expiry-01-banner shows the sunflower banner, calendar icon, "Sat 21 Nov at 18:15" and the instruction. In testBannerShowsDismisses… the label, width >= 44 and height >= 44 asserts ran and passed; after the X tap the banner was gone, and on relaunch with the keep flag it stayed hidden (xcresult activities 485-528, no issues). The only issue in that test is the launch wait (see M1). Swipe: new testHorizontalSwipeDismissesButShortDragDoesNot, not run yet. |
| AC-4 (frontend) If SideStore's URL scheme is confirmed (see notes), the banner has an "Open SideStore" button (`library.expiryBanner.openSideStore`) that opens it; if opening fails, nothing breaks and the text instruction remains. If not confirmed, text only. | Partly: the button exists; the false path is unverified (test added); a real open is for Brent | The scheme is cited (SideStore@4f3d18d AltStore/Info.plist). The button-exists assert passed in 44788627149. False path: new testOpenSideStoreWithoutSideStoreKeepsBannerAndExplains (no SideStore on the simulator, so openURL returns false), not run yet. The IPA Info.plist has LSApplicationQueriesSchemes ['sidestore']. |
| AC-5 Anki settings shows "This install expires: <date>" whenever a date is known. | Unverified (test fixed) | testFarExpiry… failed at :53 because the row sits below the fold of a lazy Form and the test never scrolled (the hierarchy at the failure shows only rows down to "Notes"). Fixed in the test file: it now scrolls to the row. Not run yet. |
| AC-6 A Debug-only `-uiTestingExpiry <ISO-8601 date>` launch argument overrides the expiry date. A UI test launches with a date 1 day ahead, sees the banner, attaches `expiry-01-banner`, taps the X, and the banner is gone; with a date 10 days ahead, no banner. The flag is documented in CLAUDE.md and DEVELOPMENT.md. | Behaviour passes; test red (M1, fixed by tester) | The override is inside `#if DEBUG` (InstallExpiry.swift:57-59), and currentExpiryUsesOverrideInDebug passed. 1 day: banner, screenshot, X, gone (all asserts passed). 10 days: no banner (:49 passed). Docs are in CLAUDE.md:40-42 and DEVELOPMENT.md:89-92. |
| AC-7 At a large Dynamic Type size the banner wraps and doesn't cover the Sync or Upload buttons. | Fail | testLargeText… passed: no frame intersection, and Sync, Upload and X are hittable. But the expiry-02-large-text screenshot (AX-L) shows the button label truncated to "Open SideS..." instead of wrapping (S1). |

### Findings
Must fix
Where: ios/ClipDeckUITests/ExpiryBannerUITests.swift:13 and :52-53 (test code; the tester has already fixed both, so no implementer action is needed beyond letting CI confirm)
Problem: (M1) `launch()` waited 10 s for the "Clip Deck" nav bar, but RootView shows "Preparing sample episode…" until the seed finishes, and that took about 17 s on CI. (M2) `staticTexts["settings.expiry"]` was queried without scrolling. The row is under "About and licences", below the fold of a lazy Form, so it doesn't exist until it is scrolled into view.
Proof: Ran it. In 44788627149, the hierarchy attachment at the first failure shows only the ActivityIndicator "Preparing sample episode…". Issue E04B139C: "No matches found for … settings.expiry", and the listed elements stop at "Notes".
Trigger: any CI run.
Fix (done by tester): nav bar wait raised to 60 s (the large-text banner wait too); the test scrolls with swipeUp up to 12 times (same as AboutUITests) and queries `descendants(matching: .any)["settings.expiry"]`.

Should fix
Where: ios/ClipDeck/Features/Library/ExpiryBanner.swift:30-40
Problem: (S1) At accessibility text sizes the "Open SideStore" button label truncates ("Open SideS...") instead of wrapping, so AC-7's "the banner wraps" is not met, and VoiceOver users at big sizes see a clipped action.
Proof: Ran it. Screenshot expiry-02-large-text (UICTContentSizeCategoryAccessibilityL) from run 44788627149.
Trigger: Settings > Accessibility > Larger Text at the AX sizes.
Fix: let the label wrap. For example, give the button an explicit label `Text("Open SideStore").multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)`, or at accessibility sizes move the icon above the text (`dynamicTypeSize.isAccessibilitySize`) to give the column more width. Re-check expiry-02-large-text.

Could fix
- C1 ios/project.yml:93-94: `LSApplicationQueriesSchemes: [sidestore]` goes against the task note ("don't add LSApplicationQueriesSchemes"), and nothing calls `canOpenURL`. It is harmless (the IPA plist has it), but it is either dead config or the button should use it.
- C2 ios/ClipDeck/Features/Settings/AnkiSettingsView.swift:86-91: the expiry line is at the very bottom of a long Form, so Brent has to scroll to find it. Consider moving it to the top section.
- C3 ios/ClipDeck/Features/Library/ExpiryBanner.swift:52: the X glyph has a fixed 16 pt size and doesn't scale with Dynamic Type (the 44 pt hit area is fine).
- C4 ios/ClipDeck/App/ClipDeckApp.swift:14-19: `-uiTestingKeepExpiryDismissal`, like the existing `-uiTesting`, is not inside `#if DEBUG`. This is pre-existing and not reachable on a sideloaded install (no launch arguments), and it only touches the "uiTesting" suite. Without the flag the reset is unchanged, and all other UI tests passed.
- C5 ios/ClipDeckTests/InstallExpiryTests.swift:103-109: `bundleWithoutProfileGivesNil` silently asserts nothing if `Bundle(url:)` returns nil.
- C6 The banner sits outside the scroll view. In landscape at AX sizes it could take most of the height. Not tested.

Review notes (no finding):
- Parser bounds: the `range(of:in:)` search starts at `start.lowerBound`, and `subdata` stays inside the found ranges. No force-unwraps, and the garbage, truncated and corrupt cases pass.
- scenePhase: the banner re-evaluates on `.active` and on appear.
- openURL false path: it sets a message and leaves the banner and text in place (now covered by a test).
- Layout: the simulator has no profile, so existing tests never see the banner, and all 197 other tests passed.
- The revert-to-fail check for the new tests was not done, because it would cost a CI dispatch (ci_only). The swipe test fails by construction if the DragGesture is removed: the banner stays and `waitForNonExistence` returns false.

Tests added/edited by tester (test files only): ios/ClipDeckUITests/ExpiryBannerUITests.swift
- fixed: the launch wait (60 s), Settings scroll and query, and @MainActor on the helpers (removes the Swift 6 warnings in the CI log)
- added to testBannerShowsDismisses…: a relaunch without the keep flag shows the banner again (the suite reset still works)
- new: testHorizontalSwipeDismissesButShortDragDoesNot (AC-3), testOpenSideStoreWithoutSideStoreKeepsBannerAndExplains (AC-4 false path, screenshot expiry-03-open-failed)

```text
VERDICT: Fail
SPEC: AC-1 met, AC-2 met, AC-3 partly (swipe/Reduce Motion unverified), AC-4 partly (false path unverified), AC-5 unverified (test fixed), AC-6 met in behaviour (test red, fixed), AC-7 not met (button truncates)
CHECKS_RUN: CI 44788627149: ipa success; simulator failure (197 pass, 2 fail: ExpiryBannerUITests testBannerShowsDismissesAndStaysHiddenToday :13, testFarExpiryShowsNoBannerAndSettingsShowsDate :53); IPA Info.plist LSApplicationQueriesSchemes = ['sidestore'], no embedded profile
UNVERIFIED: Brent: real expiry in Anki settings after a SideStore install, and that it moves after Refresh; tapping Open SideStore on device; Reduce Motion fade; dark mode; landscape at large text
REVIEWED_AT: d898c192c56707c8fd06b8a7fbc1f61e4353b61c (plus tester's test-file edits in the working tree)
```

## Fix round 2
_orchestrator · 2026-11-20 · round 1 failed on Sonnet; Brent chose to retry on Sonnet (ask_on_sonnet_fail). Sent the round-1 Test report to the same loop-frontend (sonnet): Should fix S1 (the "Open SideStore" label is cut off at AX sizes) plus the Could fix items. The tester already fixed both test failures in ExpiryBannerUITests.swift._

## Implementation notes (round 2) · sonnet
_by loop-frontend · 2026-11-20_
- S1: `ExpiryBanner` split into icon / message / closeButton parts. "Open SideStore" is now an explicit `Text` label with `.fixedSize(horizontal: false, vertical: true)` and no lineLimit, so it wraps. At accessibility sizes (`dynamicTypeSize.isAccessibilitySize`) the icon and X share a top row and the message and button use the full width below. The X stays a 44 x 44 frame. The banner is still above the tab picker, outside the nav bar, so it can't cover Sync or Upload. Identifiers are unchanged. Check expiry-02-large-text again.
- C1: removed `LSApplicationQueriesSchemes` from ios/project.yml (nothing calls canOpenURL).
- C3: the X glyph size is now `@ScaledMetric`; the hit area stays 44 pt.
- Left alone: C2 (moving the settings row; the tester's test already scrolls to it, so a move is optional), C4 (pre-existing pattern, not reachable on a sideloaded install), C5 (backend test), C6 (landscape at AX sizes untested; banner is not in the scroll view).
- Kept the tester's edits and the 2 new tests in ExpiryBannerUITests.swift untouched.
- Checked: nothing compiled (Windows); CI only.

## Test report (round 2)
_by loop-tester · 2026-11-20 14:31_

CI run 44796687521 (workflow_dispatch, scope=all, SHA 8439051). Both jobs passed, and all 201 tests in the xcresult passed with 0 issues: 24 InstallExpiryTests and 5 ExpiryBannerUITests, plus every earlier suite. The earlier suites were AboutUITests 3, PlayerLandscapeBehaviourUITests 8 (with both known flakes), PlayerLandscapeUITests 6, MKVImportUITests 2, MiningFlowUITests 1, LaunchUITests 1, ClipExtractorTests 2 and the unit suites. The log ends with "Tests passed". The run-ios launch screenshot shows the library with no banner, as expected with no profile. Scratch files are in %LOCALAPPDATA%\Temp\clip-deck-loop\T-008-r2. The diff reviewed was d898c19..8439051 (ExpiryBanner.swift, project.yml, and the round-1 tester's test edits).

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 (backend) A `nonisolated` parser reads `embedded.mobileprovision` from the app bundle: it takes the XML plist between `<?xml` and `</plist>` inside the signed file and returns `ExpirationDate`, or nil when the file is missing or unreadable. Unit tests use byte data built in the test (plist wrapped in junk bytes), a missing file and a corrupt file. No real profile is committed. | Pass | 11 parser tests passed in 44796687521 (unchanged since round 1). The IPA has no .mobileprovision, and the repo has none either. |
| AC-2 (backend) A pure function decides whether to show the banner, with "now", the expiry date and the last-dismissed day injected: show when expiry is 48 hours away or less (including the last day and after expiry) and it hasn't been dismissed on today's local calendar day; otherwise hide. Unit tests cover: 3 days left (hidden), 47 h left (shown), dismissed today (hidden), dismissed yesterday (shown again), expired (shown), past midnight in the local time zone. | Pass | threeDaysLeftIsHidden, boundaryAt48Hours, lastDayAndExpiredAreShown, dismissedTodayHiddenYesterdayShown, midnightInLocalTimeZoneRollsTheDay, both DST tests and storeRecordsDismissalAndPersists all passed in 44796687521. |
| AC-3 (frontend) The library shows the banner (`library.expiryBanner`) in the Pending (sunflower) colour with a calendar icon, the local date and time, and the SideStore instruction. A 44 pt X button (`library.expiryBanner.dismiss`, spoken "Dismiss until tomorrow") and a horizontal swipe both dismiss it with a short slide-out (Reduce Motion: fade). The dismissal day is saved in UserDefaults. | Pass (Reduce Motion fade unverified) | expiry-01-banner shows the sunflower banner, calendar icon, "Sat 21 Nov at 19:04" and the instruction. In testBannerShowsDismisses… the label asserts passed, and so did the width/height >= 44 asserts. After the tap the banner was gone. A relaunch with the keep flag showed no banner, and a relaunch without it showed the banner again (activities in run 179, no issues). testHorizontalSwipeDismissesButShortDragDoesNot passed: a drag of about 36 pt did not dismiss, a drag of about 200 pt did, and Sync stayed hittable. |
| AC-4 (frontend) If SideStore's URL scheme is confirmed (see notes), the banner has an "Open SideStore" button (`library.expiryBanner.openSideStore`) that opens it; if opening fails, nothing breaks and the text instruction remains. If not confirmed, text only. | Pass (a real open is for Brent) | The scheme is cited in the round-1 notes. testOpenSideStoreWithoutSideStoreKeepsBannerAndExplains passed: the app stayed in the foreground, the banner and its instruction text remained, and the openError text appeared. Screenshot expiry-03-open-failed shows "SideStore isn't installed on this iPhone. Open it from the Home Screen instead." under the button. |
| AC-5 Anki settings shows "This install expires: <date>" whenever a date is known. | Pass | testFarExpiryShowsNoBannerAndSettingsShowsDate passed. It found no banner at 10 days, swiped once, found `settings.expiry`, and the "This install expires:" prefix assert passed (run 180, no issues). |
| AC-6 A Debug-only `-uiTestingExpiry <ISO-8601 date>` launch argument overrides the expiry date. A UI test launches with a date 1 day ahead, sees the banner, attaches `expiry-01-banner`, taps the X, and the banner is gone; with a date 10 days ahead, no banner. The flag is documented in CLAUDE.md and DEVELOPMENT.md. | Pass | Runs 179 and 180 passed. The override is `#if DEBUG` only, and currentExpiryUsesOverrideInDebug passed. Both flags are documented in CLAUDE.md and docs/DEVELOPMENT.md. |
| AC-7 At a large Dynamic Type size the banner wraps and doesn't cover the Sync or Upload buttons. | Pass | testLargeTextBannerWrapsWithoutCoveringSyncOrUpload passed: no frame intersection, and Sync, Upload and X are hittable. Screenshot expiry-02-large-text (AX-L) shows the AX layout: the icon and X sit on a top row, the message wraps over 4 lines at full width, and "Open SideStore" is fully visible (it fits on one line at AX-L). The toolbar is clear. |

Round-1 findings:
- S1 (label truncated at AX sizes): fixed. See expiry-02-large-text. The X keeps its fixed 44x44 frame in both layouts (ExpiryBanner.swift:31), and the 44 pt size was measured at the default size in run 179.
- M1 (the launch wait) and M2 (the settings scroll), both test-side: fixed, and both tests pass.
- C1: fixed. The IPA's Payload/ClipDeck.app/Info.plist no longer has LSApplicationQueriesSchemes, and nothing in the repo uses it or canOpenURL. C3: fixed (`@ScaledMetric` glyph). C2, C4, C5 and C6 are still open as Could fix.

### Findings
Could fix
- C7 ios/ClipDeckUITests/ExpiryBannerUITests.swift:83-96: the large-text test can't detect a truncated label, so this round's evidence for "wraps" is the screenshot, and AX-L is not big enough to make "Open SideStore" itself wrap. A run at AX5 (UICTContentSizeCategoryAccessibilityXXXL) would show the button label wrapping.
- C2, C4, C5 and C6 from round 1 are unchanged.

Review notes (no finding): `Group { if/else }` switches view identity when the text size changes, but all `@State` is on ExpiryBanner itself, so `openFailed`, `dragX` and `fade` survive. The non-AX layout still uses `Spacer` with the X at the trailing edge, and expiry-01 looks right. "◀ Safari" in the expiry-01 status bar is left over from AboutUITests' Safari link test, which runs just before (harmless). I did not do the revert-to-fail check because it would cost a CI dispatch. The swipe and open-failed tests both depend on the behaviour, as described in round 1.

Tests added by tester this round: none.

```text
VERDICT: Pass
SPEC: AC-1 met, AC-2 met, AC-3 met (Reduce Motion fade unverified), AC-4 met (false path; real open on device unverified), AC-5 met, AC-6 met, AC-7 met
CHECKS_RUN: CI 44796687521 scope=all: simulator success (201/201 tests, 0 issues, "Tests passed"; run-ios launch screenshot fine), ipa success (Info.plist has no LSApplicationQueriesSchemes, no embedded profile)
UNVERIFIED: Brent: real expiry date in Anki settings after a SideStore install and that it moves after Refresh All; tapping Open SideStore on device; Reduce Motion fade; dark mode; landscape at AX sizes; button wrap at AX5
REVIEWED_AT: 8439051ca8cc438cf1ff0485dcc7701af45c4b9c
```
