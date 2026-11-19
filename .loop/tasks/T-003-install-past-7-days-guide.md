---
id: T-003
title: Write the SideStore guide so Clip Deck refreshes itself without a computer
lane: backend
depends_on: []
status: todo
round: 0
base_sha:
issue: 3
spec:
model:
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
