# Context: clip-deck

Offline iPhone video player for language learners (like asbplayer): watch your own episodes with SRT/ASS
subtitles, turn a subtitle line into an Anki card (audio clip, screenshot, sentence), sync cards to desktop Anki via AnkiConnect.

## Stack
- SwiftUI, iOS 17.0+, Swift 6 (MainActor default isolation), SwiftData, AVFoundation, XcodeGen. No backend.
- Tests: Swift Testing (unit, `ios/ClipDeckTests`), XCUITest (`ios/ClipDeckUITests`).

## Where things live
- `ios/project.yml` — source of truth; `.xcodeproj` is generated (`cd ios && xcodegen generate`). Never edit the .xcodeproj.
- `ios/ClipDeck/Features/<Feature>/` — View + `@Observable` model (Library, Player, CardEditor, Sync, Settings)
- `ios/ClipDeck/Services/` — Subtitles, Media, Anki, `FileStore.swift`; `Models/` — SwiftData (Show, Episode, PendingCard)
- `ios/ClipDeck/DesignSystem/` — colours, type, tiles, buttons
- `scripts/` — bootstrap, run-ios, test-ios, build-ipa; `.github/workflows/ios-simulator.yml` — CI

## Commands (run only on macOS / CI)
- Test: `./scripts/test-ios.sh` · Run + screenshot: `./scripts/run-ios.sh` · Unsigned IPA: `./scripts/build-ipa.sh`

## Conventions that matter
- Every interactive element gets `accessibilityIdentifier` named `feature.element`.
- SwiftData file paths are relative to Documents (`FileStore`); never store absolute paths.
- Card media names fixed per card (`CardMediaNames`) so Sync retries are idempotent.
- `-uiTesting` launch arg: in-memory library + generated "Sample Show"; `-uiTestingNoSeed` skips the sample.
- No secrets in app code or xcconfig. Mock data only in tests or behind a documented switch.
- After adding files: they must be picked up by XcodeGen (check `project.yml` sources).

## How to verify
- Brent is on Windows with no Mac. Nothing Swift can be compiled locally.
- CI: push the loop branch, then `gh workflow run ios-simulator.yml --ref <branch>` (push alone doesn't trigger it on non-main branches).
  Watch with `gh run watch`, read `--log-failed`, download `simulator-results` (screenshots, xcresult) and `ClipDeck-ipa`.
- Only Brent can check: real iPhone install via Sideloadly, real video import from Files, sync with desktop Anki.

## Full docs
- `CLAUDE.md`, `README.md`, `docs/ARCHITECTURE.md`, `docs/DESIGN.md`, `docs/PRODUCT_SPEC.md`, `docs/DEVELOPMENT.md`

## Learned
<!-- Agents append one-line facts here that the next agent needs. -->
- iOS 26: tap gestures attached to a SwiftUI Menu (and simultaneousGesture on bars) don't fire; use Button + confirmationDialog when you need to know a menu is open.
- XCUITest `app.screenshot()` in landscape comes out rotated and cropped to about 400 pt; check layout from the xcresult UI hierarchy and the screen recording.
- `ClipExtractorTests.cutsExactAudioAndScreenshot` can time out on CI (pre-existing flake); `gh run rerun <id> --failed` once before treating it as a failure.
- Landscape UI evidence: `XCUIElement.screenshot()` of a single element comes out unrotated and correct, and attaching `app.debugDescription` as text records every element's frame. Use these instead of `app.screenshot()`.
- Landscape panel width rule (Brent): panel content = max(25% of the usable width, 180 pt) + trailing inset, where usable width = full width − both insets. Panel rows are compact (time above the text).
- CI's "Upload screenshots and test results" step can fail with a GitHub `CreateArtifact ... Request timeout`. That is infrastructure, not code: re-dispatch the workflow (the tests themselves passed if test-ios printed "Tests passed").
- XCUITest on iOS 26: a List row's label and value are one StaticText ("Clip Deck, 0.1.0"). `XCUIElement.screenshot()` of a very tall Text fails with "Rendering screen failed"; use `app.screenshot()` there.
- FFmpeg: use `FFmpegInspector` (Services/Media) as the only libav* entry point. Test fixtures come from `scripts/make-test-media.sh` into build/fixtures (env CLIPDECK_FIXTURES / TEST_RUNNER_CLIPDECK_FIXTURES).
