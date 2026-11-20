---
id: T-003
title: Write the SideStore guide so Clip Deck refreshes itself without a computer
lane: backend
depends_on: []
status: done
round: 3
base_sha: 8d69c320e3c22639c2c5553f63c19599ad7f6528
issue: 3
spec:
model: opus
---

## Write the SideStore guide so Clip Deck refreshes itself without a computer

### What are we building?
With a free Apple ID, a sideloaded Clip Deck stops opening after 7 days ("Clip Deck is no longer available"), and Sideloadly can only re-sign it from a computer. This task adds a guide, `docs/INSTALL_ON_IPHONE.md`, for SideStore: a one-time setup with the computer, then refreshing on the phone itself through SideStore's local VPN app, with an iOS Shortcuts automation that refreshes every day, so Clip Deck keeps working while Brent is away from his computer for weeks.

### Why?
Brent is staying on the free Apple ID and may be away from his computer for more than 2 weeks. Hosting the app somewhere doesn't help, because the 7-day limit comes from the signing certificate. On-device refresh is the free way around it.

### Done when
- AC-1 `docs/INSTALL_ON_IPHONE.md` opens with why apps expire: free Apple ID signing lasts 7 days; at most 3 sideloaded apps (SideStore itself is one, Clip Deck another); hosting or uptime services can't extend it.
- AC-2 **One-time setup (with the computer):** install SideStore with the official installer; create and import the pairing file; install the local VPN app SideStore currently uses; sign in with the free Apple ID; turn on Developer Mode and trust the profile; install Clip Deck from `ClipDeck.ipa` (Files app › share › SideStore, or SideStore's + button).
- AC-3 **Refresh on the phone:** turn on the VPN app, then Refresh All in SideStore. Explain that this needs internet and that refreshing SideStore also refreshes SideStore itself.
- AC-4 **Automatic refresh:** step by step, an iOS Shortcuts personal automation (daily, at a time the phone is usually on Wi-Fi, set to run without asking) that turns on the VPN and runs SideStore's refresh action. Include how to check it worked (SideStore's per-app days-left count).
- AC-5 **If a refresh is missed:** Clip Deck's videos, subtitles and cards stay on the phone while the app is not deleted; refreshing in SideStore makes it open again with everything intact. If SideStore itself has expired too, the pairing file and the computer are needed to reinstall SideStore; nothing in Clip Deck is lost as long as Clip Deck isn't deleted. Never delete the app to "fix" it.
- AC-6 **Updating Clip Deck:** install the new `ClipDeck.ipa` over the old one through SideStore with the same bundle ID `dev.brent.clipdeck`, which keeps the data. Get the IPA from the `ClipDeck-ipa` CI artifact for now; mention that T-009/T-010 add phone-only downloads.
- AC-7 Every SideStore step links to the official docs (docs.sidestore.io / sidestore.io). Button names, the VPN app's name, the Shortcuts action name and pairing-file steps are written as "check in the SideStore docs" unless confirmed there. A short "Brent, please confirm" list at the end names each step the writer couldn't confirm.
- AC-8 README "Install on your iPhone" and DEVELOPMENT.md troubleshooting ("Sideloaded app won't open") point to the guide; ARCHITECTURE.md "Deployment" mentions SideStore on-device refresh as the personal-use path. Sideloadly stays documented as the first-install alternative.

### How to check
Docs only; CI isn't needed unless a non-doc file changes.
1. Read `docs/INSTALL_ON_IPHONE.md` against AC-1 to AC-7.
2. Links: for each external URL, `curl -s -o /dev/null -w "%{http_code}\n" -L <url>` returns 200 (note any site that blocks bots).
3. `grep -n "INSTALL_ON_IPHONE" README.md docs/DEVELOPMENT.md docs/ARCHITECTURE.md` finds the links.
Unverified for Brent: doing the setup on his PC and iPhone, and that the automation refreshes while he's away.

### Agent notes
- Depends on: None
- Source: Brent's goal item 3 and his follow-up: "reload it without me having to connect to my computer… I might be away from my computer for over 2 weeks"; he stays on the free Apple ID.
- The planner could not confirm SideStore's current setup flow online. The VPN app and installer have changed names over time (WireGuard, then StosVPN, then LocalDevVPN; the installer has also changed). Read docs.sidestore.io (web fetch if available) and write what it says today; never invent labels.
- Point out the risk: if both SideStore and Clip Deck expire (no refresh for 7 days), the fix needs the computer. Recommend the daily automation plus a manual refresh before travelling.
- Keep the TestFlight / paid-account path as one short "Later: paid account" paragraph linking to T-007's future section; no step-by-step.
- No jailbreaks, no certificate resellers.

### Out of scope
- CI release publishing and the SideStore source (T-009, T-010).
- The in-app expiry banner (T-008).
- TestFlight (T-007).

## Implementation notes (round 1) · sonnet
Docs only. Added `docs/INSTALL_ON_IPHONE.md`; pointers in README.md ("Install on your iPhone"), docs/DEVELOPMENT.md (troubleshooting row) and docs/ARCHITECTURE.md ("Deployment"). Sideloadly stays as the first-install alternative. No code, config or CI files changed.

Sources (read with `gh api`; refs are commit SHAs on the default branch, 2026-11-20):
- Installer is **iloader** (iloader.app), "Install SideStore (Stable)"; Windows needs iTunes; Wi-Fi required, not mobile; passcode required. SideStore/SideStore-Docs @ 7e441d3: docs/installation/prerequisites.mdx, docs/installation/install.mdx.
- VPN app is **LocalDevVPN** (App Store id6755608044). StosVPN and WireGuard are named as old; docs say switch to LocalDevVPN. SideStore-Docs @ 7e441d3: prerequisites.mdx, troubleshooting/common-issues.mdx; SideStore/SideStore @ 4f3d18d README.md.
- Trust profile / Developer Mode / "7 DAYS" counter first-refresh steps, iOS 18 "Allow & Restart": install.mdx.
- Pairing file: replace flow (Delete Stored Pairing, Manage Pairing File > Place): docs/advanced/pairing-file.mdx. The docs do not describe a separate create/import step on first install.
- Limits (3 apps incl. SideStore, 10 App IDs per week): docs/faq.mdx; error 3013 in docs/troubleshooting/error-codes.mdx. Same-bundle-ID reinstall keeps data: faq.mdx "Can I transfer my AltStore/Sideloadly apps?".
- Shortcuts action **"Refresh All Apps"** (also "Install IPA"): SideStore/SideStore @ 4f3d18d, AltStore/Intents/App Intents/RefreshAllAppsIntent.swift (title) and AppShortcuts.swift.
- Shortcuts action **"LocalDevVPN"** with Operation Enable/Disable/Toggle: jkcoxson/LocalDevVPN @ 17740a2, LocalDevVPN/VPNShortcuts.swift.
- URL scheme `sidestore://install?url=...`: docs/advanced/url-schema.mdx. Not used in the guide (T-009/T-010 territory).

Not confirmed (listed in the guide's "Brent, please confirm"): the literal "Refresh All" button label; Files share > SideStore and the + button label; whether iloader places the pairing file at install; that both Shortcuts actions run while locked.

Checks: `git diff --stat` shows only the 4 doc files plus .loop state; no external URLs curl-checked (no network step run by me; tester should). Repo links use bman7222/clip-deck from the git remote.
Tester: verify the doc against AC-1 to AC-7, curl the external links, and grep for INSTALL_ON_IPHONE in the three docs.

## Test report (round 1)
_by loop-tester · 2026-11-20 10:11_

Reviewed `git diff 8d69c32..HEAD` (8644303). Only README.md, docs/ARCHITECTURE.md, docs/DEVELOPMENT.md, docs/INSTALL_ON_IPHONE.md and this task file changed: no code, config or CI file. Sources read at the cited SHAs with `gh api`: SideStore-Docs@7e441d3 and SideStore@4f3d18d tarballs, plus LocalDevVPN@17740a2 VPNShortcuts.swift. Copies are in C:\Users\Brent\AppData\Local\Temp\clip-deck-loop\T-003-r1. Also fetched Apple's Shortcuts User Guide pages for iOS 26 and iOS 27.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 why apps expire: 7 days; 3 apps incl. SideStore; hosting can't extend | Pass | guide :9-11; faq.mdx "What limitations" (3 apps incl. itself, 10 App IDs/week) |
| AC-2 one-time setup: installer, pairing file, VPN app, Apple ID, Dev Mode + trust, install IPA | Pass | guide :18-29 match prerequisites.mdx and install.mdx: iloader, "Install SideStore (Stable)", LocalDevVPN, "Developer App", iOS 18 "Allow & Restart", "7 DAYS". The docs have no step for creating the pairing file, so it rightly sits in the confirm list. The Sideloadly/bundle ID gap is under M2 |
| AC-3 refresh: VPN on, Refresh All, needs internet, Refresh All covers SideStore itself | Fail | :41-44 are fine. :45 "Refreshing SideStore also refreshes SideStore itself" is a tautology (S1) |
| AC-4 automation step by step, run without asking, VPN + refresh, check days left | Fail | Action names are right: RefreshAllAppsIntent.swift title "Refresh All Apps"; VPNShortcuts.swift title "LocalDevVPN", Operation "Enable". The Shortcuts app steps at :51-56 contradict Apple's guide (M1) |
| AC-5 missed refresh, data kept, SideStore expired needs computer, never delete | Fail | The content is at :64-66, but the recovery stops after reinstalling SideStore (S3) and the computer warning isn't prominent (S4) |
| AC-6 update over old with same bundle ID; IPA from ClipDeck-ipa artifact; T-009/T-010 | Fail | Updating in place matches the code for apps SideStore installed. But the "latest green run" has no ClipDeck-ipa (S2), T-010 is not mentioned (S5), and the installed bundle ID isn't `dev.brent.clipdeck` (M2) |
| AC-7 every SideStore step links docs; unconfirmed labels hedged; confirm list | Fail | Setup and pairing are linked. The Refresh, Missed and Updating sections and the limits line have no doc link (S6). The Shortcuts app steps are unconfirmed and not on the list (M1) |
| AC-8 README, DEVELOPMENT, ARCHITECTURE pointers; Sideloadly kept | Pass | `grep -n INSTALL_ON_IPHONE` finds README.md:87, DEVELOPMENT.md:175 and ARCHITECTURE.md:199. All relative links resolve. The README wording is under M2 |
| Links | Pass | `curl -sIL` returns 200 for docs.sidestore.io (root, prerequisites, install, pairing-file), sidestore.io, iloader.app, github.com/bman7222/clip-deck/actions and /releases, and apps.apple.com LocalDevVPN id6755608044. /releases exists, and the guide's "After T-009 ... will have" is honest. The live docs contain the same iloader / LocalDevVPN / "7 DAYS" / "Delete Stored Pairing" / "Manage Pairing File" text |
| Phone readability | Pass with S4 | No tables; steps are 1-2 lines; :28-29 are the longest |

### Findings

Must fix (M1)
Where: docs/INSTALL_ON_IPHONE.md:51-56 (Automatic daily refresh)
Problem: The Shortcuts app steps aren't taken from any cited source, aren't on the confirm list, and don't match Apple's current guide.
- On iOS 17-26, "Run Immediately" vs "Run After Confirmation" is chosen on the trigger screen before Next. "Ask Before Running" is the iOS 16 label. Step 5 instead puts the choice after the actions, behind a second Next.
- Apple's iOS 27 guide (the version served as current on 2026-11-20) has no Automation-tab "+" flow. You add a trigger to a shortcut: "Tap Edit, then Automation. Choose a trigger, such as Time of Day". Running unattended is "Privacy > Allow Running When Locked", which the guide never mentions.

If the automation stays ask-first, it never runs at 03:00. Clip Deck, and then SideStore, expire while Brent is away: the exact failure this guide exists to prevent.
Proof: Ran it: `curl -sL https://support.apple.com/guide/shortcuts/create-a-new-personal-automation-apdfbdbd7123/ios` (redirects to add-automations…/10.0/ios/27) and …/9.0/ios/26, then extracted the text.
Trigger: Brent is on iOS 27, or on iOS 17-26 and follows steps 3-5 in order.
Fix: Write the steps separately for iOS 26 and iOS 27, or link Apple's page for each version. Say explicitly that the automation must run without confirmation and must be allowed to run while locked (iOS 27: Privacy > Allow Running When Locked). Add "the Shortcuts app steps on your iOS version" to "Brent, please confirm".

Must fix (M2)
Where: docs/INSTALL_ON_IPHONE.md:31, :70, :74 and README.md:87
Problem: SideStore@4f3d18d does not install Clip Deck as `dev.brent.clipdeck`. With default settings it appends the team ID:
- `appendTeamID = true` (SideStore/Core/Operations/OperationContexts.swift:291)
- `parentID = "\(targetBundleIdentifier).\(team.identifier)"` (FetchProvisioningProfilesOperation.swift:149-150)
- `customizeInfoPlist` defaults to false (AltStore/Core/Extensions/UserDefaults+AltStore.swift:563)

So a Clip Deck already installed with Sideloadly, which README:87 still calls "the simple first install", is a different app from the SideStore copy. SideStore never refreshes it, and installing through SideStore (step 10) gives a second Clip Deck with an empty library. The FAQ ("Can I transfer my AltStore/Sideloadly apps?") says the data stays, which conflicts with the code, so neither can be stated as fact. Following README, then Sideloadly, then this guide leaves the library in an app that expires while Brent is away. Updates through SideStore are fine: they resolve to the same `<id>.<TEAMID>`.
Proof: Traced it at the file:line references above (tarball in the scratch folder).
Trigger: Clip Deck is installed with Sideloadly first, then SideStore is set up.
Fix:
- Say SideStore only refreshes apps installed through SideStore.
- If a Sideloadly copy already holds your library, don't delete it. After step 10, check whether there are two Clip Deck icons and which one has the library.
- Drop or qualify ":31 bundle ID is dev.brent.clipdeck"; SideStore may show `dev.brent.clipdeck.<team ID>`.
- Add "does the SideStore copy keep the Sideloadly library?" to the confirm list.
- README: present Sideloadly as the alternative to SideStore, not its first step.

Should fix (S1)
Where: docs/INSTALL_ON_IPHONE.md:45
Problem: "Refreshing SideStore also refreshes SideStore itself" says nothing. The point (AC-3) is that Refresh All, and the Shortcuts action, also refresh SideStore. So SideStore can't expire as long as the daily refresh succeeds.
Proof: Traced it: InstalledApp.swift:403-412, fetchAppsForRefreshingAll appends SideStore last ("Refresh AltStore last since it causes app to quit"). RefreshAllAppsIntent.swift:186-190 uses it.
Fix: "Refresh All (and the Shortcuts action) refreshes SideStore too. It goes last, so SideStore closes for a moment. This keeps SideStore itself from expiring."

Should fix (S2)
Where: docs/INSTALL_ON_IPHONE.md:35
Problem: The step says "open the latest green iOS simulator run, and download the ClipDeck-ipa artifact". The latest green run, 44755434228 (scope=tests), has only `simulator-results`. ClipDeck-ipa is in 44702732605 and expires 2026-12-20; the artifact is kept 30 days (ios-simulator.yml:95). Loop-branch runs also carry unmerged code.
Proof: Ran it: `gh api repos/bman7222/clip-deck/actions/runs/<id>/artifacts`.
Fix: "the latest green run on `main` that lists ClipDeck-ipa under Artifacts (kept 30 days)".

Should fix (S3)
Where: docs/INSTALL_ON_IPHONE.md:65
Problem: The "SideStore expired too" path stops at "reinstall SideStore with iloader and replace the pairing file". It doesn't say how to get Clip Deck back. The FAQ says to refresh SideStore first, and that refresh can make apps with an old group ID disappear from My Apps.
Proof: Read it: faq.mdx, "Why do I need to refresh SideStore first thing after login?" and "Can I transfer…".
Fix: Add the next steps. Refresh SideStore (7 DAYS), then refresh Clip Deck. If Clip Deck isn't in My Apps, install ClipDeck.ipa again through SideStore with the same Apple ID. Don't delete Clip Deck.

Should fix (S4)
Where: docs/INSTALL_ON_IPHONE.md:3 vs :65
Problem: The key warning isn't prominent. The top says it works "even if you are away from the computer for weeks". The only "if SideStore itself expires you need the computer" line is the second bullet of the ninth section. "Refresh before you travel" sits alone at :60.
Fix: Add one bold line to the short version: if no refresh succeeds for 7 days, SideStore expires too and only the computer can fix it, so check the counters and refresh by hand before you travel.

Should fix (S5)
Where: docs/INSTALL_ON_IPHONE.md:36
Problem: AC-6 asks to mention that T-009/T-010 add downloads from the phone. Only T-009 (Releases) is mentioned; T-010 (the SideStore source) is missing.
Fix: Add one line: after T-010, Clip Deck appears as a SideStore source, so updates come from the phone.

Should fix (S6)
Where: docs/INSTALL_ON_IPHONE.md:38-70
Problem: AC-7 asks that every SideStore step link the docs. The Refresh, Missed and Updating sections and the limits line have no link.
Fix: Link install (the "7 DAYS" counter), troubleshooting/common-issues ("Ensure LocalDevVPN and Wi-Fi are both connected"), faq (limits, transfer/update), and the pairing-file page from :65.

Could fix
- "Refresh All" is confirmed in the source: MyAppsViewController.swift:1980 `setTitle(NSLocalizedString("Refresh All"…))`. State it as fact at :41 and DEVELOPMENT.md:175, and drop it from the confirm list.
- Step 8 leaves out install.mdx's "If you receive a prompt asking to revoke or create a new signing certificate, tap 'Yes' or 'Refresh Now'". It also doesn't say that SideStore then closes to the Home Screen.
- Automation reliability (add to the confirm list):
  - RefreshAllAppsIntent asks to continue in the foreground after about 27 s (RefreshAllAppsIntent.swift:144-171).
  - The LocalDevVPN action returns right after `startVPN` (VPNShortcuts.swift:90-97). An optional "Wait 5 seconds" between the two actions may help.
- :10 "A paid account lifts these": the FAQ only says a paid account removes the 3-app limit and gives 365 days.
- Wi-Fi while travelling: the phone needs Wi-Fi at least once every 6 days. SideStore@4f3d18d has an opt-in cellular refresh (SideStore/Core/Shortcuts/CellularRefreshManager.swift) that the docs don't cover yet.
- README "## Documentation" list doesn't include INSTALL_ON_IPHONE.md.
- :21: the docs recommend the iTunes version from Apple over the Microsoft Store one.

```text
VERDICT: Fail
SPEC: AC-1, AC-2, AC-8 met; AC-3, AC-4, AC-5, AC-6, AC-7 partly
CHECKS_RUN: commands.build/test/run not run (Swift, macOS-only; docs-only task, no CI by orchestrator decision); git diff --name-only 8d69c32..HEAD → docs + README + task file only; grep INSTALL_ON_IPHONE → 3 hits; curl -sIL on 8 guide URLs + App Store link → all 200; relative links → all resolve; gh api source reads at 7e441d3 / 4f3d18d / 17740a2; gh api run artifacts for 44755434228, 44702732605; Apple Shortcuts guide iOS 26/27 fetched
UNVERIFIED: Brent: the full setup on PC + iPhone; the automation actually refreshing overnight while locked; labels on his iOS version; whether a Sideloadly-installed copy and a SideStore copy coexist
REVIEWED_AT: 8644303
```

## Fix round 2
_orchestrator · 2026-11-20 · round 1 failed on Sonnet; Brent chose to switch to Opus (ask_on_sonnet_fail). A fresh loop-backend (opus) gets the round-1 Test report: 2 Must fix (Shortcuts automation steps for iOS 26/27; SideStore installs as dev.brent.clipdeck.<teamID>, a separate app from the Sideloadly copy) plus 6 Should fix._

## Implementation notes (round 2) · opus
_by loop-backend · 2026-11-20 10:27_

Docs only: docs/INSTALL_ON_IPHONE.md (rewritten), README.md, docs/DEVELOPMENT.md, docs/ARCHITECTURE.md. No code, config or CI changes, and no CI run.

Sources (all re-read by me):
- **iloader "Stable" = SideStore `releases/latest` = 0.7.0-alpha** (193ae6e, 2026-09-15). Source: nab138/iloader@7364ae6 src-tauri/src/sideload.rs:129. So I checked every code fact at three refs: develop 4f3d18d, 0.7.0-alpha and 0.6.3 (4deda92).
- **Bundle ID gets the team ID.**
  - 4f3d18d: OperationContexts.swift:291 `appendTeamID = true`; FetchProvisioningProfilesOperation.swift:149-150; `customizeInfoPlist` and `customizeAppId` default false (UserDefaults+AltStore.swift:563, :567).
  - 0.7.0-alpha: OperationContexts.swift:261 and FetchProvisioningProfilesOperation.swift:143 (`customizeAppId` false at :443).
  - 0.6.3: the team ID is appended unconditionally (AltStore/Operations/FetchProvisioningProfilesOperation.swift:230-234).
  - Updates resolve to the same ID when the team matches (4f3d18d FetchProvisioningProfilesOperation.swift:120-140).
- **Refresh All includes SideStore, last.** InstalledApp.swift:403-412 (4f3d18d), :332 (0.7.0-alpha), AltStoreCore/Model/InstalledApp.swift:334 (0.6.3).
- **Labels.**
  - "Refresh All" button: MyAppsViewController.swift:1980 (4f3d18d), :1796 (0.7.0), :1699 (0.6.3).
  - "Refresh All Apps" intent: RefreshAllAppsIntent.swift:107 and AppShortcuts.swift.
  - The 27 s foreground request: RefreshAllAppsIntent.swift:144-171 (4f3d18d), :145 (0.7.0).
  - **+** is the leftBarButtonItem `systemItem="add"` → `sideloadApp` (AltStore/iOS/Main.storyboard at 4f3d18d and 0.7.0). In 0.7.0 it opens the .ipa picker directly. Develop first shows "Install App › Choose from Files" (InstallAppDialog.swift:55), so the guide just says "pick the file".
  - .ipa share-in: Info.plist CFBundleDocumentTypes com.apple.itunes.ipa; AppDelegate.swift:336.
- **Cellular refresh is opt-in.** SideStore/Core/Shortcuts/CellularRefreshManager.swift, `isCellularRefreshEnabled` false (4f3d18d :585, 0.7.0 :452). It's not in 0.6.3 and not in the docs.
- **LocalDevVPN action.** jkcoxson/LocalDevVPN@17740a2 VPNShortcuts.swift: title "LocalDevVPN", summary "(operation) LocalDevVPN", default `.enable`, and `perform` returns right after `startVPN` (hence the optional Wait).
- **SideStore-Docs@7e441d3.**
  - install.mdx: the revoke/"Refresh Now" prompt and the return to the Home Screen.
  - prerequisites.mdx: Wi-Fi, passcode, iTunes from Apple recommended.
  - faq.mdx: limits, $99 = no 3-app limit + 365 days, "Can I transfer my AltStore/Sideloadly apps?", "refresh SideStore first".
  - common-issues.mdx: "Ensure LocalDevVPN and Wi-Fi are both connected".
  - pairing-file.mdx.
- **Apple Shortcuts guide** (fetched 2026-11-20; copies in %LOCALAPPDATA%\Temp\clip-deck-loop\T-003-r2 and …\T-003-r1):
  - iOS 26 (9.0) "Create a new personal automation": Automation › + › Create Personal Automation › trigger › Next › actions › Next › Done.
  - iOS 26 "Enable or disable a personal automation": turn off Ask Before Running › Don't Ask.
  - iOS 27 (10.0) "Add automations": shortcut › Edit › Automation › trigger; Edit › Info button › Privacy › Allow Running When Locked; "You also may need to set individual actions to run automatically".
  - Apple's iOS 26 pages never mention "Run Immediately". The guide offers it when the screen shows it, falls back to Apple's Ask Before Running wording, and puts both on the confirm list.
- **App has no library export/import.** No fileExporter, backup or export code in ios/. ios/project.yml:89-90 `UIFileSharingEnabled`/`LSSupportsOpeningDocumentsInPlace` expose only Documents/Videos and Documents/Subtitles in Files. SwiftData (default store) and Library/CardMedia (FileStore.swift:19) are not exposed.
- **IPA.** ios-simulator.yml:95 `retention-days: 30`; it triggers only on push to main or on dispatch (:6-10). The last main runs are from 2026-11-10, so the guide says "newest green run that lists ClipDeck-ipa" and explains main vs loop/ branches.

Findings:
- **M1:** separate iOS 17-26 and iOS 27 steps that follow Apple's pages and link them, with run-without-asking / Allow Running When Locked, the optional Wait and a check. The labels go on the confirm list.
- **M2:**
  - Bundle ID is now `dev.brent.clipdeck.<team ID>`, verified at all 3 refs.
  - A "Moving from Sideloadly to SideStore" section covers syncing cards first, writing down episodes and offsets, two icons, re-importing (old videos are visible in Files), and when to delete the Sideloadly copy.
  - It states plainly that there's no export/import.
  - The FAQ-vs-code conflict is on the confirm list and not asserted.
  - README now has SideStore as recommended and Sideloadly as the alternative, plus a "pick one" note. The guide also has a notice near the top.
- **S1:** Refresh All refreshes SideStore too, last.
- **S2:** newest green run listing ClipDeck-ipa, kept 30 days, main vs loop branches.
- **S3:** full recovery after SideStore expires: iloader reinstall, pairing, refresh SideStore first, refresh Clip Deck, reinstall the IPA with the same Apple ID if it's missing.
- **S4:** bold warning near the top.
- **S5:** T-010 line.
- **S6:** doc links in every section.
- **Could fix, all done:** Refresh All as fact; the revoke prompt and Home Screen close; 27 s note; paid-account wording; 6 days on Wi-Fi plus the opt-in cellular note; README Documentation entry; iTunes from Apple. Also added a DEVELOPMENT troubleshooting row for "Two Clip Deck icons".

Checked: `curl -sL -o /dev/null -w %{http_code}` on all 16 external URLs in the guide and README returned 200. `grep -n INSTALL_ON_IPHONE` finds README.md:52,84,93,111, DEVELOPMENT.md:175,176 and ARCHITECTURE.md:199. The anchors #getting-the-ipa and #moving-from-sideloadly-to-sidestore match their headings.

Tester, look closely at:
- the iOS 17-26 step 3/step 6 wording against what you know of iOS 26;
- whether "a separate app with its own library" is stated too firmly given the FAQ conflict (it's hedged in the paragraph that follows and on the confirm list);
- "at least every 6 days" (a safety margin, not a documented number).

Follow-up for the orchestrator to raise with Brent: a task "Export and import the library" (back up shows, episodes, offsets and pending cards, with optional media, to a file in Files, and restore it into another install). It's the only safe way to move from a Sideloadly copy to a SideStore copy, or to recover after a delete.

## Test report (round 2)
_by loop-tester · 2026-11-20 10:36_

Reviewed `git diff 8644303..HEAD -- docs README.md` (e071866) and read all of docs/INSTALL_ON_IPHONE.md the way Brent would on his phone. `git diff --name-only 8644303..HEAD`: only README.md, docs/{INSTALL_ON_IPHONE,DEVELOPMENT,ARCHITECTURE}.md and this task file changed, so no code, config or CI. I fetched or re-read every source myself. Copies are in C:\Users\Brent\AppData\Local\Temp\clip-deck-loop\T-003-r2-test:
- Apple's Shortcuts guide, fetched today: iOS 26 "Create a new personal automation" and "Enable or disable…", and iOS 27 "Add automations".
- The SideStore 0.7.0-alpha tarball: tag object 193ae6e, commit 6032424. It is `releases/latest`, per `gh api` (published 2026-09-15).
- SideStore develop 4f3d18d, from the round-1 tarball.
- nab138/iloader@7364ae6: sideload.rs, account.rs and src/locales/en.json.
- The live docs.sidestore.io pages and the sideloadly.io FAQ.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 why apps expire | Pass | :13-15. Matches live faq ("including itself", 10 App IDs) |
| AC-2 one-time setup | Pass (see M1) | :21-32 match live install.mdx ("Install SideStore (Stable)", "Developer App", "Allow & Restart", "7 DAYS", "Refresh Now") and prerequisites (Wi-Fi, passcode, Microsoft Store note). The + is the My Apps leftBarButtonItem `systemItem="add"` → `sideloadApp:` (Main.storyboard:718-720 at both refs); at 0.7.0 it opens the .ipa picker directly (MyAppsViewController.swift:921-929). .ipa share-in: Info.plist:30-32 `com.apple.itunes.ipa`; AppDelegate.swift:249. Setup step 4 doesn't mention iloader's "Maximum certificates reached" prompt (M1) |
| AC-3 refresh on the phone | Pass | :44-49. "Refresh All": MyAppsViewController.swift:1796 (0.7.0) and :1980 (4f3d18d). SideStore is refreshed last: InstalledApp.swift:330-339 (0.7.0) and :405-412 (4f3d18d). The common-issues quote is on the live page |
| AC-4 automatic refresh | Pass | :53-86 against Apple's pages fetched today. iOS 26 create: Automation › + › Create Personal Automation › trigger › Next › … › Next › Done. iOS 26 enable: "Turn off Ask Before Running, then tap Don't Ask". iOS 27: "Tap Edit, then Automation"; "Tap Edit, then [img alt='the Info button']"; "Tap Privacy then enable Allow Running When Locked"; "You also may need to set individual actions to run automatically". Actions: RefreshAllAppsIntent.swift:107 "Refresh All Apps" and the 27 s deadline at :144; LocalDevVPN VPNShortcuts.swift:43/:53/:83. Both have `openAppWhenRun = false`. Labels are on the confirm list (:137, :143) |
| AC-5 missed refresh | Pass (see S1) | :95-102. Re-installing gives the same ID: 0.7.0 FetchProvisioningProfilesOperation.swift:133-153 builds `targetBundleIdentifier + "." + team.identifier` with the same team. live faq has "refresh SideStore first" |
| AC-6 updating | Pass | :106-108. The ID really is `dev.brent.clipdeck.<team>`, not the AC's `dev.brent.clipdeck`; that deviation is correct (see r1 M2). IPA: ios-simulator.yml:93-95 (ClipDeck-ipa, 30 days); `gh run list` shows no main runs on the list, and ClipDeck-ipa is in loop-branch runs, so the :38 wording fits. T-009 is at :39, T-010 at :40 |
| AC-7 doc links, hedged labels, confirm list | Pass | Every section that has a SideStore doc links it (:14, :19, :31, :48, :98, :100, :108, :131). Labels confirmed only in code are cited, and the rest are on the confirm list (:137-143) |
| AC-8 pointers, Sideloadly kept | Pass (wording in M1) | `grep -n INSTALL_ON_IPHONE` → README:52, 84, 93, 111; DEVELOPMENT:175, 176; ARCHITECTURE:199. Sideloadly is the alternative (README:86-91, guide :130) |
| Links | Pass | `curl -sIL` returns 200 for all 16 external URLs. The only non-200 lines are the pre-existing `localhost:8765` AnkiConnect examples in DEVELOPMENT.md, which aren't links in this diff. All 15 relative links and anchors resolve (script: bad: 0) |

### Round-1 findings
- **M1 (Shortcuts steps): fixed.** :62-80 follow Apple's iOS 26 and iOS 27 pages and link them. "Run without asking" and "Allow Running When Locked" are explicit. The labels are on the confirm list (:137).
- **M2 (bundle ID): fixed.**
  - 0.7.0-alpha (what Stable installs; iloader sideload.rs:126-130 → `releases/latest/download/SideStore.ipa`): OperationContexts.swift:261 `appendTeamID = true`; FetchProvisioningProfilesOperation.swift:143; `customizeAppId` false (UserDefaults+AltStore.swift:443), which UserCustomizationOperation.swift:23 guards.
  - 4f3d18d: :291, FetchProvisioningProfilesOperation.swift:146-153, UserDefaults+AltStore.swift:563/:567.
  - The FAQ conflict is hedged (:114, :139). README now lists SideStore first.
  - The new Moving section brings up M1 below.
- **S1: fixed** (:49).
- **S2: fixed** (:38).
- **S3: fixed** (:97-102).
- **S4: fixed** (:5).
- **S5: fixed** (:40).
- **S6: fixed** (links above).
- **Could fix: all done.**
  - Refresh All is stated as fact (:45).
  - Revoke prompt and Home Screen close (:30).
  - 27 s (:86).
  - Paid-account wording (:131).
  - Wi-Fi and cellular (:90-91): `isCellularRefreshEnabled` is false at 0.7.0 (UserDefaults+AltStore.swift:452), and the docs don't cover it.
  - README Documentation entry (:111).
  - iTunes from Apple (:24).

### Findings

Must fix (M1)
Where: docs/INSTALL_ON_IPHONE.md:112, :118, :126 (and setup step 4 at :26); README.md:93; docs/DEVELOPMENT.md:176
Problem: The "Moving from Sideloadly to SideStore" plan assumes the Sideloadly copy keeps opening while you move: ":112 it still expires 7 days after you last installed it from the computer", ":118 with the Sideloadly copy still working", ":126 Until then, it holds your only library". The sources say that setting up SideStore with the same free Apple ID revokes the certificate Sideloadly signed with, and iOS then won't open the Sideloadly copy at all.
- iloader@7364ae6 src/locales/en.json:78-79: "Maximum certificates reached" / "iloader will revoke your existing certificates and generate a new one." This is the prompt behind account.rs:224-261 `MaxCertsBehavior::Prompt`.
- SideStore 0.7.0 CodeSignValidator.swift:19: "a free account is limited to 1 active certificate".
- OCSPValidator.swift:70: "AMFI flags the cert as revoked and doesn't let app opens".
- SideStore-Docs advanced/alternative.mdx:53: you can't sign in "without revoking AltStore's certificate" unless you import it first.
- install.mdx: "If you receive a prompt asking to revoke … tap 'Yes'". The guide repeats this at :30.

So the 7-day claim is contradicted by sources, not just unsourced. The section doesn't say that steps 1-2 must happen **before setup step 1 (iloader)**. "Before you switch" reads as "before step 10", because step 3 says "Then: … (setup step 10)". Cards still waiting to sync would then be stuck in an app that won't open. The data stays on disk, but opening it again means re-signing with Sideloadly on the computer, which can in turn revoke SideStore's certificate. README:93 "Pick one" doesn't say the two fight over the certificate on one Apple ID.
Proof: Read it, at the file:line references above (copies in T-003-r2-test\ss070, iloader-account.rs and the T-003-r1 docs tarball).
Trigger: Brent has Clip Deck from Sideloadly with cards waiting to sync, and follows the setup section before (or while) doing the Moving steps.
Fix:
- In Moving, say that steps 1-2 come **before setup step 1**: sync until Sync to Anki shows nothing waiting, and write the list.
- Replace :112's 7-day sentence: "Setting up SideStore with the same Apple ID can revoke the certificate Sideloadly used (iloader may show 'Maximum certificates reached'; SideStore may ask to revoke). From then on the Sideloadly copy may not open, but its data stays on the phone. Don't delete it."
- Mention the iloader prompt at setup step 4.
- Reword :126 so it doesn't promise the old copy still opens.
- README:93: "Use one per Apple ID; using both makes each revoke the other's certificate."
- Add to the confirm list: "Does the Sideloadly copy still open after setup? Can Files still show its Videos folder?"

Should fix (S1)
Where: docs/INSTALL_ON_IPHONE.md:5 and :88-91 (travel guidance)
Problem: The guide never says that an iOS update can break the pairing file. SideStore's install page says: "Your pairing file may expire if you update or reset your iPhone … This also occurs at random times because of Apple's software." If the phone updates iOS while Brent is away, perhaps automatically overnight, refreshes fail, and both apps expire with no computer to fix them. This is the exact failure the guide exists to prevent, and the bold warning at :5 doesn't cover it.
Proof: Read it, install.mdx:76 (SideStore-Docs@7e441d3; the same text is on the live page).
Trigger: An iOS update installs during a trip.
Fix: In the bold warning or the travel section: "Don't update iOS while you're away from the computer, and turn off automatic iOS updates (check where on your iOS version). An update can break the pairing file, and only iloader on the computer can replace it. After any update, check the counters the next morning."

Should fix (S2)
Where: docs/INSTALL_ON_IPHONE.md:123 and :126
Problem: Step 3 says "You now have **two Clip Deck icons**" as fact, and step 6 says to delete the Sideloadly copy. The confirm list (:139) admits there might be only one, which is the FAQ's "data still intact" case. In that case "the Sideloadly copy" and the SideStore copy are the same app, and following step 6 literally would delete the only library. A second copy is likely: Sideloadly's FAQ implies it keeps the IPA's ID unless you change it, and SideStore appends the team ID. But it is unconfirmed, and the cost of being wrong is the whole library.
Proof: Read it, guide :123, :126, :139; sideloadly.io/faq ("If you manually set a custom bundle ID earlier, use the same ID again").
Trigger: SideStore's install lands on the existing app.
Fix: After step 3: "If you see only **one** Clip Deck and it still has your library, stop here: the move is done. Don't delete anything."

Could fix
- :66: Apple's iOS 26 page says that for a first automation you just tap Automation, with no + ("If this is your first automation: Tap Automation"). Say "(if you already have automations)" after **+**.
- :70 "Tap Next or Done": Apple says Next, then a summary, then Done. Write "Tap Next, then Done."
- :114: link "SideStore's FAQ" to docs.sidestore.io/docs/faq, as the other sections do.
- :90 "needs at least one successful refresh every 6 days": it's a safety margin, so "aim for" reads better than "needs".

```text
VERDICT: Fail
SPEC: AC-1..AC-8 met; one Must fix (Moving section: the certificate is revoked during setup) and two Should fix (iOS update breaks pairing; one-icon case)
CHECKS_RUN: commands.build/test/run not run (macOS-only; docs-only, conservative CI, no run by orchestrator decision); git diff --name-only 8644303..HEAD → docs + README + task file only; grep INSTALL_ON_IPHONE → 7 hits in 3 files; curl -sIL → 16/16 external URLs 200; relative links/anchors → 15/15 resolve; Apple Shortcuts iOS 26 (create, enable) + iOS 27 (add) fetched and text-compared; gh api SideStore releases/latest = 0.7.0-alpha (tag 193ae6e → 6032424), tarball read; 4f3d18d re-read; iloader@7364ae6 sideload.rs:126-130, account.rs:224-261, en.json:78-79; live docs.sidestore.io label strings; sideloadly.io/faq; gh run list for ClipDeck-ipa. No test files apply (docs only), so no mutation check
UNVERIFIED: Brent: full setup on PC + iPhone; whether iloader shows "Maximum certificates reached" and the Sideloadly copy stops opening; one or two Clip Deck icons; Shortcuts labels on his iOS; overnight locked run; Files access to the old copy's Videos
REVIEWED_AT: e071866
```

## Fix round 3
_orchestrator · 2026-11-20 · sent the round-2 Test report to the same loop-backend (opus). Brent's decision: no export/import task; he has only 1 episode and will re-upload it, so the Moving section can be short ("sync cards to Anki first, then set up SideStore, then re-add your episodes"). This is the last normal round._

## Implementation notes (round 3) · opus
_by loop-backend · 2026-11-20 10:55_

Docs only: docs/INSTALL_ON_IPHONE.md, README.md, docs/DEVELOPMENT.md, docs/ARCHITECTURE.md. No code, config or CI changes.

Sources I re-checked myself:
- iloader@7364ae6 src/locales/en.json:78-79 (fetched with `gh api`): "Maximum certificates reached" / "iloader will revoke your existing certificates and generate a new one."
- SideStore 0.7.0-alpha (193ae6e):
  - SideStore/Core/Certificates/CodeSignValidator.swift:19 "a free account is limited to 1 active certificate";
  - OCSPValidator.swift:70 "AMFI flags the cert as revoked and doesn't let app opens".
- SideStore-Docs@7e441d3:
  - installation/install.mdx:73 "Your pairing file may expire if you update or reset your iPhone";
  - advanced/alternative.mdx:53.
- App UI: SyncView.swift:23. The empty state is "Everything is in Anki." (not "0 waiting"), and the library's sync button is the circling-arrows icon (LibraryView.swift:46-48, 63-67).

Findings:
- **M1 (certificate revoked during setup):** the "Moving from Sideloadly to SideStore" section is rewritten short, per Brent's decision (no export/import, re-upload).
  1. Before setup step 1, sync until "Everything is in Anki."
  2. Expect the old copy to stop opening (one active certificate; the iloader prompt quoted).
  3. After setup, install through SideStore and re-add the episode(s) and subtitles.
  4. Delete the old copy only with two icons and the new one playing; with one icon, delete nothing.
  - Also:
    - Removed the "still expires 7 days after…" sentence.
    - Setup step 4 mentions the iloader "Maximum certificates reached" prompt.
    - The top "Already have Clip Deck from Sideloadly?" line says to read Moving before step 1.
    - README:93 "Pick one" says using both on the same free Apple ID makes each revoke the other's certificate.
    - The guide's Alternatives line says the same.
    - DEVELOPMENT.md:12 (the Sideloadly-only "Installing" line; :26 is about env vars, so I took the brief's ":26" to mean this line) and :69 now say SideStore or Sideloadly, one per Apple ID.
    - DEVELOPMENT.md:176 is replaced by a "Sideloadly copy stopped opening after SideStore setup" row.
    - The ARCHITECTURE deployment bullet now notes the mutual revocation and Brent's no-export decision.
    - The confirm list gains "Does the Sideloadly copy still open after setup?" and drops the Files cross-copy item (no longer used).
- **S1 (iOS updates break pairing):** added a second bold block in the top warning that quotes install.mdx: turn off automatic iOS updates before a trip, don't update while away, check the counters after any update. There's a matching bullet in "Refresh on the phone" that links the Pairing file page.
- **S2 (one-icon case):** Moving step 4: "If you see only one Clip Deck, don't delete anything." I also softened guide :36 and ARCHITECTURE to "most likely a separate app".
- **Could fix:**
  - :66 now says + only if you already have automations (Apple iOS 26);
  - :70 "Tap Next, then Done";
  - the FAQ link in the Moving section;
  - "Aim for at least one successful refresh every 6 days".

Checked:
- `curl -sL` on every external URL in the four docs: all 200. The only non-URL hit is the pre-existing `http://<that…` placeholder in DEVELOPMENT.md.
- In-page and cross-file anchors (#getting-the-ipa, #moving-from-sideloadly-to-sidestore) match the headings.
- `grep -n INSTALL_ON_IPHONE` still finds README, DEVELOPMENT and ARCHITECTURE.

Tester, look at:
- the Moving section on a phone-width read;
- README:93's flat "each one revokes the other's certificate" (worded as the brief asked; the guide hedges it with "will likely").

## Test report (round 3)
_by loop-tester · 2026-11-20 10:44_

I reviewed `git diff e071866..HEAD -- docs README.md` (8f72f8e), then read all of docs/INSTALL_ON_IPHONE.md top to bottom and followed it literally, as Brent would on his phone. `git diff --name-only 8d69c32..HEAD` lists only README.md, docs/{INSTALL_ON_IPHONE,DEVELOPMENT,ARCHITECTURE}.md and this task file, so no code, config or CI file changed. The working tree has only the orchestrator's .loop/BOARD.md and .loop/HANDOFF.md edits. Fresh downloads are in C:\Users\Brent\AppData\Local\Temp\clip-deck-loop\T-003-r3-test: iloader@7364ae6 en.json, SideStore-Docs@7e441d3 install.mdx, and the live install and faq pages. The SideStore 0.7.0 sources were re-read from T-003-r2-test\ss070.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 why apps expire | Pass | :13-17, unchanged since round 2 |
| AC-2 one-time setup | Pass | :19-36. Step 4 (:28) now carries the iloader prompt. Its wording matches en.json:78-79: "Maximum certificates reached" / "iloader will revoke your existing certificates and generate a new one." |
| AC-3 refresh on the phone | Pass | :44-52. The new :52 bullet covers iOS updates and links the Pairing file page |
| AC-4 automatic refresh | Pass | :54-94. The round-2 Could fix items are applied at :69, :73 and :93 |
| AC-5 missed refresh | Pass | :96-105, unchanged |
| AC-6 updating | Pass | :107-111, unchanged. The `.<team ID>` deviation was accepted in round 2 |
| AC-7 doc links, hedged labels, confirm list | Pass | Moving now links the FAQ (:125). The confirm list (:136-142) adds "Does the Sideloadly copy still open after setup?" and keeps "One Clip Deck or two" |
| AC-8 pointers, Sideloadly kept | Pass | `grep -n INSTALL_ON_IPHONE` finds README:52, 84, 93, 111; DEVELOPMENT:12, 175, 176; ARCHITECTURE:199. Sideloadly is still documented (README:86-91, guide :129) |
| Links | Pass | `curl -sIL` on all 17 external URLs in the four docs returns 200 for 15. The 2 that don't are the pre-existing `http://<that` placeholder and `localhost:8765` in DEVELOPMENT.md, which this diff doesn't touch. A relative-link and anchor script checked 18 links and found 0 bad, including #moving-from-sideloadly-to-sidestore at guide :9 and :28, README:93 and DEVELOPMENT:176 |

### Round-2 findings
- **M1 (certificate revoked during setup): fixed.**
  - Line :9 sits above the setup and says "Before setup step 1, read [Moving…] and sync your cards".
  - Moving step 1 (:117) is explicitly "Before setup step 1".
  - The removed sentence "still expires 7 days after…" is gone.
  - :118-121 say the old copy will stop opening and its files stay on the phone. They cite the 1-certificate comment (CodeSignValidator.swift:19 "a free account is limited to 1 active certificate", re-read) and the iloader prompt (en.json:78-79, fetched again today).
  - Setup step 4 (:28) repeats the warning at the exact moment the revoke happens.
  - README:93, DEVELOPMENT:12/:176 and guide :129 warn that the tools revoke each other.
- **S1 (iOS updates and the pairing file): fixed.**
  - The bold block at :7 quotes install.mdx:73. The live page has the same sentence: "Your pairing file may expire if you update or reset your iPhone, iPad, or iPod touch."
  - It says to turn off automatic updates before a trip, not to update while away, and to check after any update.
  - :52 repeats this in the refresh section.
- **S2 (one icon): fixed.** :123 says "If you see only **one** Clip Deck, don't delete anything." It deletes the old copy only with two icons *and* the new one playing the episode. DEVELOPMENT:176 says the same.
- **Could fix: all applied.**
  - :69 tap **+** only if you already have automations.
  - :73 "Tap Next, then Done".
  - :125 FAQ link.
  - :93 "Aim for…".
- **Brent's decision (no export/import, re-upload):** reflected at :115 and :122 and in ARCHITECTURE:200.

### Safety walk-through (following the text literally)
- **(a) Cards waiting for Anki:** Brent can't lose them without being warned first.
  - Line :9 is the first instruction after the warnings, and it sends him to Moving step 1 before setup step 1.
  - Step 1 names the right control: the circling-arrows button at top right. LibraryView.swift:46-48 puts `arrow.triangle.2.circlepath` in `.topBarTrailing`.
  - Step 1's end state is right. SyncView.swift:23 shows `"Everything is in Anki."` only when `waiting.isEmpty`, and `waiting` = pending **or failed** (SyncView.swift:84, Models.swift:63), so a failed card keeps that text away.
  - Setup step 4 warns again before the revoke.
- **(b) Deleting his only copy:**
  - :98 says "Never delete Clip Deck".
  - :123 needs two icons plus the new copy playing the episode, which also proves the video was re-added from somewhere. With one icon, delete nothing.
  - So following the text can't delete the only library or the only video. (See C2 about checking for the source file first.)
- **(c) Stranded by an iOS update:**
  - The bold block at the top (:7) tells him, before any trip, to turn off automatic updates and not update while away.
  - :52 repeats it, and :5 covers the general "7 days without a refresh means you need the computer".
  - What's left is a pairing file that breaks at random, which the guide can't prevent (C4: say so).

### Findings

No Must fix. No Should fix.

Could fix (C1)
Where: docs/INSTALL_ON_IPHONE.md:117
Problem: If the Sideloadly copy has already expired when Brent starts, step 1 ("open the Sideloadly Clip Deck … sync") can't be done, and the guide doesn't say how to get it open.
Proof: Read it. :117 has no fallback. README:91 covers re-installing with Sideloadly.
Trigger: Brent switches more than 7 days after his last Sideloadly install.
Fix: "If it won't open, install it again with Sideloadly first (README). Installing over the top keeps your cards."

Could fix (C2)
Where: docs/INSTALL_ON_IPHONE.md:117 and :122
Problem: Step 3 says "add your episode(s) and subtitles again", but nothing has Brent check, before setup, that he still has the video and subtitle files outside Clip Deck. Once the old copy is revoked, nobody has confirmed whether Files still shows its On My iPhone › Clip Deck folder (project.yml:89-90 turn on file sharing, so it shows while the app works). The old pointer to that folder was removed in this round. This isn't a loss path, because :123 still blocks deletion and re-signing with Sideloadly recovers the files, but it's an avoidable detour.
Proof: Read it, guide :117 and :122, project.yml:89-90.
Trigger: Brent's only copy of the episode is inside the Sideloadly Clip Deck.
Fix: Add to step 1: "Check that you still have the episode's video and subtitle files in Files (outside Clip Deck)."

Could fix (C3)
Where: README.md:93, docs/DEVELOPMENT.md:12 and :176, docs/INSTALL_ON_IPHONE.md:129 (flat "each one revokes the other's certificate") against guide :28 and :120 ("will likely")
Problem: The SideStore direction has sources: CodeSignValidator.swift:19 (1 active certificate on a free account, auto-revoked) and iloader en.json:78-79. The Sideloadly-revokes-SideStore direction is only inferred from that 1-certificate rule. The Sideloadly FAQ (r2-test\sideloadly.txt) never mentions revoking. The flat wording is supported as an inference and errs toward caution, so it's safe. It just doesn't match the guide's own hedge.
Proof: Read it, at the files above. `grep -i revok sideloadly.txt` finds no hits.
Fix (optional): "can revoke" in the flat places, or leave it as is.

Could fix (C4)
Where: docs/INSTALL_ON_IPHONE.md:7
Problem: install.mdx:73 goes on: "This also occurs at random times because of Apple's software." The guide quotes only the update half. It also doesn't say where to turn off automatic updates (Settings › General › Software Update › Automatic Updates).
Fix: Add the random-break sentence ("check the counters every few days while away"), plus the Settings path.

Could fix (C5)
Where: docs/INSTALL_ON_IPHONE.md:123
Problem: The round-2 note that the old copy uses one of the 3 app slots while it's installed was removed. With SideStore, the new Clip Deck and the old one, that is 3 apps, so another sideloaded app would hit the limit.
Fix: Add a half-sentence to step 4.

```text
VERDICT: Pass
SPEC: AC-1..AC-8 met; round-2 M1, S1, S2 and all Could fix items fixed; safety walk-through (a)/(b)/(c) passes
CHECKS_RUN: commands.build/test/run not run (macOS-only; docs-only task, conservative CI, no run by orchestrator decision); git diff --name-only 8d69c32..HEAD → docs + README + task file only; grep INSTALL_ON_IPHONE → 8 hits in 3 files; curl -sIL → 15/15 real external URLs 200 (2 pre-existing placeholders); relative links/anchors → 18/18 resolve; iloader@7364ae6 en.json:78-79 fetched; install.mdx@7e441d3:73 + live install page text matched; SideStore 0.7.0 CodeSignValidator.swift:19, OCSPValidator.swift:70 re-read; SyncView.swift:23/:84, Models.swift:63, LibraryView.swift:46-51/78 read. Docs only: no test files apply, so no mutation check
UNVERIFIED: Brent: full setup on PC + iPhone; whether iloader shows "Maximum certificates reached" and the Sideloadly copy stops opening; one or two Clip Deck icons; Shortcuts labels on his iOS; overnight locked run; whether a revoked copy's folder still shows in Files
REVIEWED_AT: 8f72f8e
```
