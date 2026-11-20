# Install Clip Deck on your iPhone and keep it alive (SideStore)

Short version: set up SideStore once with the computer. After that, a daily Shortcuts automation refreshes Clip Deck on the phone, so it keeps opening while you're away from the computer.

> **If no refresh works for 7 days, SideStore expires too, and only the computer can bring it back.** Before you travel, refresh by hand and check that every counter in SideStore › My Apps says 7.
>
> **iOS updates can break the pairing file**, and then every refresh fails. SideStore's [Install](https://docs.sidestore.io/docs/installation/install) page says: "Your pairing file may expire if you update or reset your iPhone, iPad, or iPod touch. … This also occurs at random times because of Apple's software." Only iloader on the computer can replace it. So before a trip, turn off automatic iOS updates (Settings › General › Software Update › Automatic Updates) and don't update while you're away. Because it can also happen at random times, check the counters every few days, not just after an update.

**Already have Clip Deck from Sideloadly?** Before setup step 1, read [Moving from Sideloadly to SideStore](#moving-from-sideloadly-to-sidestore) and sync your cards.

Official docs: <https://docs.sidestore.io> (site: <https://sidestore.io>).

## Why the app expires

- With a free Apple ID, an app is signed for **7 days**. After that, iOS won't open it.
- A free Apple ID allows **3 sideloaded apps at once**, and SideStore counts as one of them. It also allows **10 new App IDs per week**. See the [SideStore FAQ](https://docs.sidestore.io/docs/faq).
- The 7 days come from the signing certificate. Hosting the file or using an uptime service **can't** extend it. Only re-signing helps, and SideStore re-signs on the phone.

## One-time setup (needs the computer, about 30 min)

Use this as a checklist next to the official [Prerequisites](https://docs.sidestore.io/docs/installation/prerequisites) and [Install](https://docs.sidestore.io/docs/installation/install) pages.

The phone must be on Wi-Fi (mobile data won't work) and must have a passcode.

1. **iPhone:** install **LocalDevVPN** from the [App Store](https://apps.apple.com/app/localdevvpn/id6755608044). Open it and tap Connect. Allow the VPN configuration and enter your passcode.
2. **Windows:** install iTunes [from Apple](https://www.apple.com/itunes/download/win64) (the docs recommend this over the Microsoft Store version). Then install **iloader** from <https://iloader.app>.
3. Plug in the iPhone with USB and tap Trust.
4. **iloader:** sign in with your free Apple ID, select your iPhone, and choose **Install SideStore (Stable)**. If iloader says "Maximum certificates reached" and offers to revoke your existing certificates, accept it. That will likely stop a Sideloadly-installed Clip Deck from opening (see [Moving from Sideloadly](#moving-from-sideloadly-to-sidestore)).
5. **iPhone:** open Settings › General › **VPN & Device Management**. Under "Developer App", tap your Apple ID and trust it. On iOS 18 and later, the button is "Allow & Restart" and asks for your passcode.
6. Open Settings › Privacy & Security, scroll to the bottom, and turn on **Developer Mode**. The phone restarts.
7. Open LocalDevVPN and tap Connect. Then open SideStore and sign in with the same Apple ID.
8. In SideStore › **My Apps**, tap the **7 DAYS** counter beside SideStore to refresh it. If SideStore asks to revoke or create a signing certificate, tap "Yes" or "Refresh Now". SideStore then closes to the Home Screen and is back a few seconds later. Do this before you install anything else.
9. **Pairing file:** SideStore needs it to talk to the phone. If SideStore later shows a pairing or connection error, replace it with iloader ([Pairing file](https://docs.sidestore.io/docs/advanced/pairing-file)): Delete Stored Pairing, trust the phone, then Manage Pairing File › Place.
10. **Install Clip Deck:** get `ClipDeck.ipa` onto the phone (see [Getting the IPA](#getting-the-ipa)). In SideStore › My Apps, tap **+** at the top left and pick the file. Another way: in the Files app, share the file to SideStore.

SideStore signs Clip Deck under its own bundle ID: `dev.brent.clipdeck` plus your team ID (for example `dev.brent.clipdeck.ABCDE12345`). A Sideloadly copy most likely has a different ID, which makes it a separate app.

## Getting the IPA

- **From the phone (normal way):** open the [Releases page](https://github.com/bman7222/clip-deck/releases) in Safari and tap the newest release. The repo is public, so no GitHub login is needed. Download `ClipDeck.ipa` (ignore `ClipDeck.ipa.sha256`, that is only a checksum). Then either tap the download in Files and share it to **SideStore**, or in SideStore › My Apps tap **+** and pick the file (SideStore's file import).
- **Without a release:** open the [Actions page](https://github.com/bman7222/clip-deck/actions), pick a green **iOS simulator** run that lists **ClipDeck-ipa** under Artifacts, and download it (this needs a GitHub login). The download is a zip: tap it in Files to unzip it and get `ClipDeck.ipa`. Artifacts are kept for 30 days, and runs on a `loop/…` branch are work in progress.
- **From the SideStore source (updates on their own):** see [Installing and updating from the source](#installing-and-updating-from-the-source). Use it for the very first install too, so SideStore links the installed app to the source.

### Cutting a release (on the computer)

```bash
git tag v0.2.0 && git push origin v0.2.0
```

The **Release IPA** workflow builds the unsigned IPA and publishes it as release `v0.2.0` with `ClipDeck.ipa` and `ClipDeck.ipa.sha256` (a few minutes). Or run it by hand: Actions › Release IPA › Run workflow, version `0.2.0` (no `v`; the workflow creates the tag). The version must look like `1.2.3` or `1.2.3-rc1`; a version with `-` is published as a pre-release. The number shown in the app is the version, and the build number is the workflow run number. It never overwrites: reusing an existing version fails with a clear message, so pick the next one. The release notes link to the exact FFmpeg source this build uses (read from `ios/project.yml`) and to `THIRD_PARTY_NOTICES.md` and `LICENSE`.

## Installing and updating from the source

Every stable release also publishes a SideStore source file, `apps.json`. Add it once and SideStore lists Clip Deck, shows when a newer version exists and installs it from the phone. No computer and no GitHub login are needed.

Source address (copy this into SideStore):

```
https://github.com/bman7222/clip-deck/releases/latest/download/apps.json
```

> **This address returns 404 until the first stable release exists.** GitHub's "latest" ignores pre-releases, and a version with `-` in it (like `0.2.0-rc1`) is a pre-release. Cut a plain `v0.2.0`-style release first (see [Cutting a release](#cutting-a-release-on-the-computer)); pre-releases are never listed in the source.

**Add the source (once):**
1. Connect LocalDevVPN. In SideStore, open the **Sources** tab and tap **+** (top left), paste the address above and add it. SideStore's own page on this: [App Sources](https://docs.sidestore.io/docs/advanced/app-sources). Tapping `sidestore://source?url=https://github.com/bman7222/clip-deck/releases/latest/download/apps.json` in Safari does the same ([URL Schema](https://docs.sidestore.io/docs/advanced/url-schema)).
2. Open the new source, tap Clip Deck and install it (**Get** or **Free**).

**Update:** SideStore shows an update for Clip Deck (Sources and My Apps) once a newer stable release is out. Tap **Update**. Releases may take a minute after the workflow turns green. Pull to refresh the Sources tab if it does not show up.

**Important: install from the source at least once.** SideStore links an installed app to a source only when it was installed from that source. A copy added with "+" and a file, or shared from Files, is "sideloaded" and never shows updates. If your current copy came from a file, install again from the source; it installs over the same app (same Apple ID, same ID), so your videos and cards stay. Don't delete the app first.

If an install from the source fails with a size, checksum, version or bundle ID mismatch, the release's IPA and the source disagree. Don't retry in a loop; use the file import from the release page instead and tell the developer.

## Refresh on the phone

1. Open LocalDevVPN and tap **Connect**.
2. Open SideStore › My Apps and tap **Refresh All**. To refresh one app, tap its days-left counter instead.
3. The counters go back to 7.

- A refresh needs Wi-Fi with LocalDevVPN connected. If either is off, the refresh fails ([Common issues](https://docs.sidestore.io/docs/troubleshooting/common-issues): "Ensure LocalDevVPN and Wi-Fi are both connected").
- Refresh All, and the Shortcuts action below, refresh **SideStore too**. SideStore goes last, so it closes for a moment. As long as the daily refresh works, SideStore never expires.
- **After an iOS update, check that a refresh still works.** An update can break the pairing file, and fixing it needs iloader on the computer ([Pairing file](https://docs.sidestore.io/docs/advanced/pairing-file)). Don't update iOS while you're away.

## Automatic daily refresh (Shortcuts)

The automation turns on the VPN and then refreshes everything. It **must run without asking**. If it waits for you to confirm, it never runs at night, and both apps expire while you're away.

Actions it uses (same on every iOS version):
- **LocalDevVPN** (from LocalDevVPN). It reads "Enable LocalDevVPN", and Enable is the default.
- **Wait**, 5 seconds (optional). Gives the VPN time to connect, because the LocalDevVPN action returns as soon as it starts the VPN.
- **Refresh All Apps** (from SideStore).

Pick a time when the phone is usually on Wi-Fi, for example 03:00 at home while it charges.

### iOS 17 to 26

Apple's guide: [Create a personal automation](https://support.apple.com/guide/shortcuts/create-a-new-personal-automation-apdfbdbd7123/9.0/ios/26) and [Run without asking](https://support.apple.com/guide/shortcuts/enable-or-disable-a-personal-automation-apd602971e63/9.0/ios/26).

1. Shortcuts › **Automation** tab. If you already have automations, tap **+** (top right). Then tap Create Personal Automation (if you see it).
2. Choose **Time of Day**. Set the time and choose Repeat › **Daily**.
3. If this screen offers **Run Immediately**, choose it instead of Run After Confirmation. Tap Next.
4. Choose New Blank Automation. Add the three actions above in order.
5. Tap Next, then Done.
6. Open the automation again. If it shows **Ask Before Running**, turn it off and tap **Don't Ask**. Apple's iOS 26 guide uses these words.

### iOS 27

Apple's guide: [Add automations](https://support.apple.com/guide/shortcuts/add-automations-apdfbdbd7123/10.0/ios/27). On iOS 27, the automation lives on a shortcut.

1. Shortcuts › create a new shortcut, for example "Refresh SideStore". Add the three actions above in order.
2. In the shortcut, tap **Edit**, then **Automation**. Choose **Time of Day**, set the time, and choose Daily.
3. Tap **Edit**, then the **Info** button (ⓘ) › **Privacy**. Turn on **Allow Running When Locked**. This is what lets it run without asking.
4. To check that it's on: Shortcuts › Automation lists it under Turned On.

### Check it worked

- Run it once by hand while the phone is unlocked, and allow anything it asks for. Apple notes that some actions may need their own permission to run automatically.
- The next morning, the counters in SideStore › My Apps should say 6 or 7. Check them for the first few days.
- If the refresh takes longer than about 27 seconds, SideStore asks to continue in the foreground. A locked phone may stop there, so a low counter means you should refresh by hand.

### Wi-Fi while travelling

- Aim for at least one successful refresh every 6 days (7 days is the hard limit). If it isn't on Wi-Fi at the automation time, refresh by hand whenever you have Wi-Fi.
- Newer SideStore builds have an opt-in setting for refreshing over mobile data. The docs don't cover it yet, so don't count on it.

## If a refresh is missed

- **Never delete Clip Deck to "fix" it.** Deleting it deletes your videos, subtitles and cards. An expired app keeps all of them.
- **Clip Deck expired but SideStore still works:** connect LocalDevVPN and refresh in SideStore. Clip Deck opens again with everything intact.
- **SideStore expired too:** SideStore can't refresh itself any more, so you need the computer.
  1. In iloader, choose **Install SideStore (Stable)** again with the same Apple ID ([Install](https://docs.sidestore.io/docs/installation/install)). If SideStore then shows a pairing error, replace the pairing file ([Pairing file](https://docs.sidestore.io/docs/advanced/pairing-file)).
  2. On the phone, connect LocalDevVPN and open SideStore. Sign in if it asks.
  3. Refresh **SideStore first** (its 7 DAYS counter). The [FAQ](https://docs.sidestore.io/docs/faq) says to do this before anything else.
  4. Refresh Clip Deck.
  5. If Clip Deck isn't in My Apps any more, install `ClipDeck.ipa` again through SideStore with the **same Apple ID**. It gets the same ID, so it installs over the top and keeps your data. Still don't delete Clip Deck.

## Updating Clip Deck

1. Easiest: update from the source ([Installing and updating from the source](#installing-and-updating-from-the-source)). Otherwise get the new `ClipDeck.ipa` ([Getting the IPA](#getting-the-ipa)).
2. For the file: connect LocalDevVPN, then in SideStore › My Apps tap **+** and pick the file.
3. As long as you use the same Apple ID, SideStore signs it with the same ID as before, installs it over the old copy and keeps your data. Don't delete the old app first. See the [FAQ](https://docs.sidestore.io/docs/faq).

## Moving from Sideloadly to SideStore

SideStore only refreshes apps it installed, so you install Clip Deck again through SideStore and add your episodes again. Clip Deck can't export or import its library.

1. **Before setup step 1:**
   - **If the Sideloadly copy has already expired** (it won't open), reinstall it with Sideloadly first so you can sync the cards. Installing over the top keeps its data.
   - **Check that you still have the episode's video and subtitle files** in the Files app. You will add them again in step 3.
   - Open the Sideloadly Clip Deck at home with Anki open. Tap the sync button (circling arrows, top right) and sync until the sheet says **"Everything is in Anki."** Cards already in Anki are safe.
2. **Expect the old copy to stop opening.**
   - A free Apple ID has one active signing certificate (SideStore's code: "a free account is limited to 1 active certificate").
   - Setting up SideStore with the same Apple ID will likely revoke the certificate Sideloadly used. iloader may say "Maximum certificates reached… will revoke your existing certificates" (setup step 4), or SideStore may ask to revoke (setup step 8).
   - After that, iOS won't open the Sideloadly copy. Its files stay on the phone.
3. **After setup:** install `ClipDeck.ipa` through SideStore (setup step 10). Tap **Upload episode** and add your episode(s) and subtitles again.
4. **Deleting the old copy:** only if you see **two** Clip Deck icons and the new one plays your episode. If you see only **one** Clip Deck, don't delete anything. While the old copy is installed it uses one of your 3 app slots (SideStore uses another), so delete it once the new one works.

[SideStore's FAQ](https://docs.sidestore.io/docs/faq) says a Sideloadly app's data carries over, but SideStore's code installs Clip Deck under a new ID (`dev.brent.clipdeck.<team ID>`). Plan as if it doesn't carry over.

## Alternatives and later

- **Sideloadly (instead of SideStore):** the README's original method. It can only re-sign from the computer, so the app stops opening 7 days after your last install. Use one or the other with an Apple ID: setting up one will likely revoke the other's certificate, and that copy stops opening.
- **Later: paid account.** A paid Apple Developer account ($99/yr) removes the 3-app limit and signs for 365 days ([FAQ](https://docs.sidestore.io/docs/faq)). It also allows TestFlight (T-007, see [ARCHITECTURE.md](ARCHITECTURE.md), "Deployment").

## Brent, please confirm

Nobody has tried these on a real phone. They are taken from SideStore's code or Apple's guide, so check each one on yours:

- **The Shortcuts steps on your iOS version.** On iOS 17 to 26: is there a "Create Personal Automation" step, and do you get "Run Immediately" on the trigger screen or "Ask Before Running" afterwards? On iOS 27: is it Edit › ⓘ › Privacy › Allow Running When Locked?
- **That the automation refreshes overnight with the phone locked.** Check the counters the next mornings. Also check whether the 5-second Wait is needed, and whether a long refresh stops at "continue in the foreground".
- **Does the Sideloadly copy still open after setup?** Did iloader show "Maximum certificates reached", or SideStore ask to revoke?
- **One Clip Deck or two** after setup step 10? If you have one, does it still have your episode? SideStore's FAQ says the data stays, but its code points to a new, separate app.
- **The source:** does adding the source address work, does Clip Deck install from it, and after a newer stable release does SideStore offer the update? (The code says the app is linked to the source at install time, so check an install from the source, not from a file. The `-rc` pre-releases are deliberately not in the source.)
- **Installing from Files:** does sharing `ClipDeck.ipa` from the Files app offer SideStore? (The + button in My Apps is confirmed in the code.)
- **Pairing file:** does iloader place it during the first install? The docs only describe replacing it.
- **The LocalDevVPN action:** does it show as "Enable LocalDevVPN" on your iOS version?
