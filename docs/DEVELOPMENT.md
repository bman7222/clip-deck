# Clip Deck: development guide

## Environment

Building needs macOS with Xcode 26+ (Swift 6, iOS simulator runtime) and XcodeGen (`brew install xcodegen`).

**Without a Mac** (the original setup), development works like this:
- **Building:** GitHub Actions builds and tests on a macOS runner (`.github/workflows/ios-simulator.yml`).
- **Installing:** the `ipa` job produces an unsigned `ClipDeck.ipa`. Install it with Sideloadly; see the README.
- **Editing:** Swift code can be edited on Windows, but it is only compiled by the runner.

Check your machine: `python3 ~/.claude/skills/iphone-app-setup-skill/scripts/env_check.py` (if the skill is installed).

## First-time setup

```bash
./scripts/bootstrap.sh
```

## Environment variables

There are none.
- The app has no server-side configuration and no build-time secrets.
- `.env.example` and `ios/Config/Secrets.example.xcconfig` exist only as scaffold placeholders.
- The AnkiConnect address and optional API key are entered in the app and stored on the device.

| Variable | Used by | Purpose | Where to get it |
|---|---|---|---|
| None | | | |

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
./scripts/build-ipa.sh                    # unsigned build/ipa/ClipDeck.ipa for Sideloadly
cd ios && xcodegen generate               # after adding files or editing project.yml
```

## Simulator

`./scripts/run-ios.sh` picks a booted iPhone simulator, otherwise the newest iPhone. Set `SIM_NAME` to choose one.

To try the app without importing anything, launch a Debug build with the `-uiTesting` argument. It creates "Sample Show": a generated 6-second video with a 3-line Japanese SRT, in an in-memory library.
- In Xcode: Scheme › Run › Arguments.
- From the command line: `xcrun simctl launch booted dev.brent.clipdeck -uiTesting`.

To test syncing from the simulator, use `http://localhost:8765` in Anki settings while Anki runs on the same Mac.

With Claude Code, the `ios-simulator-skill` skill can drive the running app. It taps and types by accessibility identifier, takes screenshots, and switches dark mode and text size. Identifiers follow `feature.element`:
- `library.sync`, `library.upload`, `library.show.<name>`;
- `episode.row.<title>`;
- `cue.row.<n>`, `player.makeCard`, `player.offset`;
- `card.save`, `card.addNext`, `card.rerecord`, `card.field.<field>`;
- `sync.start`.

## Tests

```bash
./scripts/test-ios.sh
```

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
- **MediaAndFileTests:**
  - file names and locations, and importing;
  - real clip extraction from a generated MP4 (2-second clip within ±150 ms, padding clamped, screenshot written).

**UI tests (`ClipDeckUITests`):**
- **LaunchUITests:** the empty library offers Upload, and the upload sheet stays disabled without a video.
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
| Video won't import | Only MP4, MOV and M4V play with Apple's player. Convert MKV first, e.g. `ffmpeg -i in.mkv -c copy out.mp4` when the codecs are H.264/HEVC + AAC |
| "Video file is missing" | The file was moved or deleted in the Files app. Tap **Choose the video again** |
| Sideloaded app won't open | Developer Mode on? Apple ID trusted under VPN & Device Management? Free-account installs expire after 7 days; re-install |
