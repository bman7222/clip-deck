# Clip Deck: development guide

## Environment

Building needs macOS with Xcode 26+ (Swift 6, iOS simulator runtime) and XcodeGen (`brew install xcodegen`).
Running the tests also needs Homebrew FFmpeg (`brew install ffmpeg`, with libx264 and libx265): `test-ios.sh` uses it
to generate the MKV test fixtures, and `bootstrap.sh` checks for it. It is a test tool only; the app ships its own
FFmpeg libraries (FFmpegBuild, see ARCHITECTURE.md).

**Without a Mac** (the original setup), development works like this:
- **Building:** GitHub Actions builds and tests on a macOS runner (`.github/workflows/ios-simulator.yml`).
- **Installing:** the `ipa` job produces an unsigned `ClipDeck.ipa`. Install it with SideStore (recommended, see [INSTALL_ON_IPHONE.md](INSTALL_ON_IPHONE.md)) or Sideloadly. Tagged builds (`git tag v0.2.0 && git push origin v0.2.0`) are published as GitHub Releases by `.github/workflows/release.yml`; see [Cutting a release](INSTALL_ON_IPHONE.md#cutting-a-release-on-the-computer). Use only one per Apple ID: setting up one will likely revoke the other's certificate.
- **Editing:** Swift code can be edited on Windows, but it is only compiled by the runner.

Check your machine: `python3 ~/.claude/skills/iphone-app-setup-skill/scripts/env_check.py` (if the skill is installed).

## First-time setup

```bash
./scripts/bootstrap.sh
```

## Environment variables

The app itself reads none:
- The app has no server-side configuration and no build-time secrets.
- `.env.example` and `ios/Config/Secrets.example.xcconfig` exist only as scaffold placeholders.
- The AnkiConnect address and optional API key are entered in the app and stored on the device.

Only the scripts and the tests use these:

| Variable | Used by | Purpose | Default |
|---|---|---|---|
| `SIM_NAME` | `run-ios.sh`, `test-ios.sh` | Simulator to use, e.g. `iPhone 17 Pro` | booted iPhone, else the newest |
| `SETTLE_SECONDS` | `test-ios.sh` | When the script boots the simulator itself, the tests start no sooner than this many seconds after the boot (the build runs meanwhile). A fresh simulator spends about 10 minutes on first-boot work (an Apple Intelligence banner, slow terminate and screenshot calls) | 660 when `CI` is set, else 0 |
| `CLIPDECK_FIXTURES` | The MKV unit tests (unit-test process); the app under `-uiTestingMKV` and `-uiTestingDictionary` (Debug) | Folder with the generated MKV fixtures and a `dictionaries/` folder (a copy of `scripts/fixtures/dictionaries`) | `<repo>/build/fixtures` in the unit tests; none in the app |
| `TEST_RUNNER_CLIPDECK_FIXTURES` | `test-ios.sh` exports it | `xcodebuild test` strips the `TEST_RUNNER_` prefix and passes `CLIPDECK_FIXTURES` to the test process | `<repo>/build/fixtures` |

To run the fixture tests from Xcode against another folder, set `CLIPDECK_FIXTURES` in the scheme's Test action
(Arguments › Environment Variables). Without it the tests look in `<repo>/build/fixtures`, which is where
`test-ios.sh` writes them.

## Anki setup

Do this once, on the computer that runs Anki:

1. In Anki: **Tools › Add-ons › Get Add-ons**, enter code `2055492159` (AnkiConnect), then restart Anki.
2. Open **Tools › Add-ons › AnkiConnect › Config** and set:
   ```json
   "webBindAddress": "0.0.0.0",
   "webBindPort": 8765
   ```
   Optionally set `"apiKey"` to a password and enter the same value in the app. Restart Anki.
3. Allow Anki through the computer's firewall for private networks. Windows asks the first time; otherwise use **Windows Security › Firewall › Allow an app**.
4. Find the computer's IP address (Windows: `ipconfig`, "IPv4 Address").
5. In Clip Deck, open the gear icon › **Anki settings**:
   - enter `http://<that IP>:8765` and tap **Test connection**;
   - pick the deck and note type;
   - map the fields. The defaults match Lapis/Yomitan mining note types.
6. iOS asks for **Local Network** permission the first time. Allow it (**Settings › Clip Deck › Local Network**).

To sync, keep Anki open on the computer. Have the phone on the same Wi-Fi (or the same Tailscale network), then tap **Sync** on the library screen.

## Daily commands

```bash
./scripts/run-ios.sh                      # build, launch in a simulator, screenshot
./scripts/test-ios.sh                     # unit + UI tests, UI screenshots to build/screenshots/ui-tests
./scripts/test-ios.sh ClipDeckTests       # unit tests only
./scripts/build-ipa.sh                    # unsigned build/ipa/ClipDeck.ipa for SideStore or Sideloadly
cd ios && xcodegen generate               # after adding files or editing project.yml
```

## Simulator

`./scripts/run-ios.sh` picks a booted iPhone simulator, otherwise the newest iPhone. Set `SIM_NAME` to choose one.

To try the app without importing anything, launch a Debug build with the `-uiTesting` argument. It creates "Sample Show": a generated 6-second video with a 3-line Japanese SRT, in an in-memory library.
- In Xcode: Scheme › Run › Arguments.
- From the command line: `xcrun simctl launch booted dev.brent.clipdeck -uiTesting`.

To try an MKV episode, add `-uiTestingMKV` (with `-uiTesting`). Instead of "Sample Show", the app imports fixture 4
(`04-nosubs-aac51.mkv`: H.264, AAC 5.1, no subtitle tracks) through the real `EpisodeImporter` as "MKV Show / Episode 1",
with the sample SRT as its subtitle file. The app finds the fixture through `CLIPDECK_FIXTURES`:
- UI tests: `app.launchEnvironment["CLIPDECK_FIXTURES"] = ProcessInfo.processInfo.environment["CLIPDECK_FIXTURES"]`.
- Command line: `SIMCTL_CHILD_CLIPDECK_FIXTURES="$PWD/build/fixtures" xcrun simctl launch booted dev.brent.clipdeck -uiTesting -uiTestingMKV`
  (run `scripts/make-test-media.sh build/fixtures` first).
If the variable or the file is missing, the app prints why to the console and the library stays empty.

To try the install-expiry reminder (shown from 48 hours before a sideloaded install expires), add
`-uiTestingExpiry <ISO-8601 date>` (Debug), e.g. `xcrun simctl launch booted dev.brent.clipdeck -uiTesting -uiTestingExpiry 2026-11-21T14:02:00Z`.
Simulator, TestFlight and App Store builds have no signing profile, so without the flag no banner appears. Dismissing
hides it for the rest of the local day; `-uiTestingKeepExpiryDismissal` keeps that dismissal across a relaunch.

To test syncing from the simulator, use `http://localhost:8765` in Anki settings while Anki runs on the same Mac.

With Claude Code, the `ios-simulator-skill` skill can drive the running app. It taps and types by accessibility identifier, takes screenshots, and switches dark mode and text size. Identifiers follow `feature.element`:
- `library.sync`, `library.upload`, `library.show.<name>`;
- `episode.row.<title>`;
- `cue.row.<n>`, `player.makeCard`, `player.offset`, `player.back` (landscape top bar), `player.video`, `player.panelToggle` (landscape top bar), `player.sidePanel`, `player.panelHandle`, `player.panel.makeCard`;
- `card.save`, `card.addNext`, `card.rerecord`, `card.field.<field>`, `card.timeline`, `card.timeline.start`, `card.timeline.end`, `card.timeline.snap`;
- `sync.start`.

## Tests

```bash
./scripts/test-ios.sh
```

**Fixtures.** `test-ios.sh` first runs `scripts/make-test-media.sh`, which uses Homebrew `ffmpeg` to write five small
MKV files (8 s each, 320x180) into `build/fixtures/`. Every video shows a solid colour that changes each second, and
every audio track beeps for 0.2 s at the start of each even second, so sync can be measured:

| File | Contents |
|---|---|
| `01-h264-bframes-aac-srt-ass.mkv` | H.264 with B-frames, AAC stereo, SRT and ASS tracks (Japanese) |
| `02-hevc-main10-flac.mkv` | HEVC Main10, open GOP, FLAC |
| `03-offset-ac3-51-srt.mkv` | video starts at 1.0 s, audio at 1.5 s; AC-3 5.1; SRT |
| `04-nosubs-aac51.mkv` | H.264, AAC 5.1, no subtitles |
| `05-h264-hi10p.mkv` | H.264 High 10 (the importer must reject it) |

The script skips the work when all five exist and are newer than the script; delete `build/fixtures/` to force a
rebuild, or run `./scripts/make-test-media.sh [folder]` by hand. No media files are kept in git (`build/` is ignored).
CI installs `ffmpeg` and generates them fresh on every run. The tests find the folder through `CLIPDECK_FIXTURES`
(see Environment variables).

**CI jobs and shards.** `ios-simulator.yml` runs the simulator tests as four parallel jobs (`fail-fast: false`), planned by
a small `plan` job:

- **simulator (shard 1):** `ClipDeckTests` plus an explicit list of UI classes (`SHARD1_UI` in the workflow), then
  `scripts/run-ios.sh` (the launch screenshot). Artifact `simulator-results-1`.
- **simulator (shard 2):** an explicit list of UI classes (`SHARD2_UI`). Artifact `simulator-results-2`.
- **simulator (shard 3):** another explicit list of UI classes (`SHARD3_UI`). Artifact `simulator-results-3`.
- **simulator (shard 4):** everything else, as `-skip-testing` of `ClipDeckTests` and the three lists, so a new UI class or a
  new test target always runs here without any edit. Artifact `simulator-results-4`.
- **ipa:** builds the unsigned IPA (artifact `ClipDeck-ipa`).

Each artifact holds the screenshots and the xcresult of its job. `workflow_dispatch` inputs: `scope` (`all`, `tests` =
the simulator jobs only, `ipa`) and `only_testing` (a non-empty value runs just that filter in a single job, shard 1;
the other shards are not created). To rebalance, move class names between the three lists (the workflow's comment has the timings); aim for about 22 to 25 minutes per job. `test-ios.sh` takes several `-only-testing`
values as arguments or as the space-separated `ONLY_TESTING` / `SKIP_TESTING` environment variables.

**UI-test helpers (`ios/ClipDeckUITests/UITestSupport.swift`).** CI runners are slow and lose taps, so UI tests wait for
state, not for time:
- `launchSeeded(app)` launches with `-uiTesting` and waits (45 s) for "Sample Show"; if the library is still empty it
  relaunches once, which seeds again. `openSampleEpisode` and `launchAndOpenSampleEpisode` go on into the player.
  Never write your own "Seeded show should appear" wait.
- `wait(timeout:until:)`, `waitForLabel`, `waitForValue` and `waitForFrame` poll a condition (first check at once,
  then every 0.2 s) instead of a fixed sleep.
- `tap(_:until:)` taps and waits for a state; only if the state did not come does it tap again, and only while the
  button still exists and is hittable. `tapStep(_:reader:from:to:)` is the same for a button that steps a stored value
  (Up): a lost tap leaves the old value and is repeated, a doubled step shows another value and fails the test.
- `readTogether(_:)` reads value and label from one snapshot. `settle`, `attachText` and `attachScreenshot` are the
  shared settle and evidence helpers.
- A test that plays the video asks for a longer clip with `-uiTestingSampleSeconds` (20 or 30) so a slow runner can't
  play the 6 s clip to its end. `TestMediaFactory` (DEBUG) waits up to 60 s per writer input, not 1,000 x 5 ms, and the
  seeder retries once.
- `rotateToLandscape(app)` is how a test's setup turns the player (open in portrait) to landscape. It guards against
  the **idle stall**: on a slow runner the app can stop answering XCTest's "animations idle" wait within about a
  second of that rotation, for the rest of the process (6 of 375 rotations, T-034), and every later action then waits
  2 x 60 s. After the rotation it sets the same orientation again, which is only XCTest's wait for idle (under a
  second, or 60 s when stalled). Over 50 s it logs the stall, terminates the app, opens the player again (by default
  `launchAndOpenSampleEpisode` with the same launch arguments) and rotates once more; it relaunches only once. A
  rotation in the middle of a test (where the state before it matters) stays a plain `XCUIDevice` rotation.
- When the guard fires you see it in three places: an activity named "Idle stall guard…" with an `idle-stall-guard`
  attachment in the xcresult, a `UITestSupport: Idle stall guard…` line on the runner's stdout, and a GitHub warning
  ("UI test idle stall", printed by `test-ios.sh` from the exported attachments) on the run page. A healthy run
  shows none of them.
- `UITestAnimationWatch` (app, DEBUG, `-uiTesting` only) hunts the cause. Every 2 s it walks the windows' layer trees
  and prints, once each, any animation that stays on a layer for 3 s or more ("UITestAnimationWatch: …" in the app's
  stdout in the xcresult). iOS 26 Liquid Glass "match" animations (infinite duration, no delegate) are skipped as permanent noise. A spinner during a slow seed shows up as one line and proves it runs. No line near a stall
  means the animation XCTest waits for is no longer on a layer in any window.

**Unit tests (`ClipDeckTests`, Swift Testing):**
- **SubtitleParserTests:**
  - SRT, including CRLF, tags and missing blank lines;
  - ASS: custom `Format:` order, override tags, `\N`, comments and drawings skipped;
  - time formats, and UTF-8 BOM / Shift-JIS decoding;
  - error messages.
- **ClipMathTests:**
  - the cue on screen, including overlaps;
  - offset handling;
  - sentence text for partial ranges;
  - Add previous/next line, and nudging with clamping.
- **AnkiTests:**
  - AnkiConnect requests (version 6, API key);
  - address parsing, response/error decoding, and "unreachable" mapping;
  - the syncer: field mapping, HTML escaping, media upload, duplicates, retry skipping, stopping when unreachable, failing cards;
  - settings persistence.
- **FFmpegFixtureTests:** opens each fixture with libavformat and checks codecs, track counts and the 1.0 s start of fixture 3. It proves the FFmpeg frameworks link and run in the simulator.
- **MediaAndFileTests:**
  - file names and locations, and importing;
  - real clip extraction from a generated MP4 (2-second clip within ±150 ms, padding clamped, screenshot written).

**UI tests (`ClipDeckUITests`):**
- **LaunchUITests:** the empty library offers Upload, and the upload sheet stays disabled without a video.
- **AboutUITests:** Settings › About and licences shows the Clip Deck licence and the LGPL text, and both source links open Safari.
- **MKVImportUITests:** with `-uiTestingMKV`, the converted fixture-4 episode lists its three subtitle lines, plays line 2 and makes a card (`mkv-01-player`, `mkv-02-card`); the upload sheet offers MKV and keeps Add episode disabled without a video.
- **CardTimelineUITests:** the Make a Card timeline on the sample's line 2 (120 s video): both handles exist, a snapped drag of the end handle lands on 5.5 s and Re-record then Save works, an unsnapped drag lands between edges, a +0.1 nudge moves the end handle, and the Snap chip survives a relaunch with `-uiTestingKeepTimelineSnap`.
- **MiningFlowUITests:** the full primary flow on the seeded sample:
  1. open the show, then the episode;
  2. tap line 2 in the list;
  3. Make a Card. Expect range `0:02.0 – 0:04.0` and sentence `元気ですか`;
  4. Add next line, then Re-record. Expect the sentence `元気ですか\nまたね`;
  5. save;
  6. the library shows "1 waiting", and the sync sheet says 1 card is waiting.

  It takes screenshots at each step.

No test talks to a real Anki. Syncing with desktop Anki is checked by hand (see the README's Install section, then Sync).

## Troubleshooting

| Problem | Fix |
|---|---|
| `xcodegen: command not found` | `brew install xcodegen` |
| No simulators / SDK not found | Xcode › Settings › Components: install an iOS runtime; `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| Scheme not found / new files missing in Xcode | `cd ios && xcodegen generate` |
| Sync says Anki can't be reached | Is Anki open? Check `webBindAddress` is `0.0.0.0` and Anki was restarted. Check the firewall, the same Wi-Fi, and the IP. Check Local Network permission is on |
| Sync says "model was not found" / field errors | Re-run Test connection in Anki settings and re-pick the note type and fields |
| `ffmpeg not found` from `test-ios.sh` or `bootstrap.sh` | `brew install ffmpeg` (tests only) |
| Fixture tests say a fixture is missing | `./scripts/make-test-media.sh` (needs `ffmpeg` with libx264 and libx265) |
| "“.xyz” videos aren't supported" | Only MP4, MOV, M4V and MKV are accepted. Convert other containers (AVI, WebM, TS) on a computer first |
| An MKV is refused with a codec message | The iPhone can't play that video (H.264 10-bit "Hi10P", VP9, 4:2:2/4:4:4, 12-bit, Dolby Vision profile 5, or AV1 without AV1 hardware). Re-encode it on a computer to H.264 8-bit or HEVC, e.g. with HandBrake. Audio is never the problem unless the chosen track has no decoder: pick another track in the Audio picker |
| "Downloading from iCloud…" never finishes | The file is still in iCloud Drive. Check the connection, or open it once in the Files app so it downloads, then choose it again |
| "This needs about 1.6 GB free; you have 0.9 GB." | An import needs the file's size plus 10 % (at least 200 MB) free. Free space in Settings › General › iPhone Storage |
| "Conversion stopped. Keep Clip Deck open until it finishes." | iOS ended the background time while an MKV converted. Add it again and stay in the app; nothing half-imported is kept |
| "Video file is missing" | The file was moved or deleted in the Files app. Tap **Choose the video again** |
| Sideloaded app won't open | Developer Mode on? Apple ID trusted under VPN & Device Management? Free-account installs expire after 7 days: refresh in SideStore (LocalDevVPN connected, My Apps › Refresh All), see [INSTALL_ON_IPHONE.md](INSTALL_ON_IPHONE.md). Never delete the app: that deletes your data |
| Sideloadly copy stopped opening after SideStore setup | Expected: with one free Apple ID, setting up SideStore will likely revoke Sideloadly's certificate. Sync cards to Anki before setup. Install Clip Deck through SideStore and add the episodes again. Delete the old copy only if there are two Clip Deck icons and the new one plays your episode. See [Moving from Sideloadly to SideStore](INSTALL_ON_IPHONE.md#moving-from-sideloadly-to-sidestore) |
