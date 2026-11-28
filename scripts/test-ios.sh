#!/usr/bin/env bash
# Run ClipDeck unit tests (Swift Testing) and UI tests (XCUITest) on an iPhone simulator.
# Usage: ./scripts/test-ios.sh                     all tests
#        ./scripts/test-ios.sh ClipDeckTests       one test target (passed to -only-testing)
#        ./scripts/test-ios.sh ClipDeckUITests/AboutUITests ClipDeckTests   several -only-testing values
#        ONLY_TESTING="ClipDeckTests ClipDeckUITests/AboutUITests" SKIP_TESTING="ClipDeckUITests/LaunchUITests" ./scripts/test-ios.sh
#                                                  space-separated lists (CI shards use these); every value is an
#                                                  xcodebuild -only-testing / -skip-testing identifier without spaces
#        SIM_NAME="iPhone 17 Pro" ./scripts/test-ios.sh
# Needs ffmpeg (brew install ffmpeg) to generate the MKV fixtures in build/fixtures.
# Results bundle: build/TestResults-<timestamp>.xcresult (open in Xcode for details).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="ClipDeck"
DERIVED="$ROOT/build/DerivedData"
RESULT="$ROOT/build/TestResults-$(date +%Y%m%d-%H%M%S).xcresult"

command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen" >&2; exit 1; }
command -v ffmpeg >/dev/null || { echo "ffmpeg not found: brew install ffmpeg (the tests generate their MKV fixtures with it)" >&2; exit 1; }

UDID="$(python3 "$ROOT/scripts/pick-simulator.py" "${SIM_NAME:-}")"
# A fresh simulator does first-boot work for about 10 minutes (on CI: an Apple Intelligence banner, timed-out terminate
# and screenshot calls), so it boots before the build and the tests start once it has been up SETTLE_SECONDS (T-036).
SETTLE_SECONDS="${SETTLE_SECONDS:-$([[ -n "${CI:-}" ]] && echo 660 || echo 0)}"
BOOTED_AT=""
if xcrun simctl boot "$UDID" 2>/dev/null; then BOOTED_AT=$(date +%s); fi

(cd "$ROOT/ios" && xcodegen generate --quiet)

# Generate the MKV test fixtures; xcodebuild passes TEST_RUNNER_* to the test process without the prefix.
FIXTURES="$ROOT/build/fixtures"
bash "$ROOT/scripts/make-test-media.sh" "$FIXTURES"
export TEST_RUNNER_CLIPDECK_FIXTURES="$FIXTURES"

FILTER=()
for v in "$@"; do FILTER+=(-only-testing "$v"); done
read -ra only_env <<< "${ONLY_TESTING:-}"
for v in ${only_env[@]+"${only_env[@]}"}; do FILTER+=(-only-testing "$v"); done
read -ra skip_env <<< "${SKIP_TESTING:-}"
for v in ${skip_env[@]+"${skip_env[@]}"}; do FILTER+=(-skip-testing "$v"); done

mkdir -p "$ROOT/build"
status=0
xcodebuild build-for-testing \
  -project "$ROOT/ios/$SCHEME.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -quiet || status=$?
if [[ $status -eq 0 && -n "$BOOTED_AT" ]]; then
  wait_for=$(( BOOTED_AT + SETTLE_SECONDS - $(date +%s) ))
  if (( wait_for > 0 )); then
    echo "Letting the simulator settle for ${wait_for}s more (boot to tests: ${SETTLE_SECONDS}s)"
    sleep "$wait_for"
  fi
fi
if [[ $status -eq 0 ]]; then
  xcodebuild test-without-building \
    -project "$ROOT/ios/$SCHEME.xcodeproj" \
    -scheme "$SCHEME" \
    -destination "id=$UDID" \
    -derivedDataPath "$DERIVED" \
    -resultBundlePath "$RESULT" \
    ${FILTER[@]+"${FILTER[@]}"} \
    -quiet || status=$?
fi

# Save the UI tests' screenshots (XCTAttachments) as PNGs, pass or fail, for review.
if [[ -d "$RESULT" ]]; then
  SHOTS="$ROOT/build/screenshots/ui-tests"
  mkdir -p "$SHOTS"
  xcrun xcresulttool export attachments --path "$RESULT" --output-path "$SHOTS" >/dev/null 2>&1 \
    && echo "UI test screenshots: $SHOTS" \
    || echo "(Could not export screenshots; open $RESULT in Xcode.)"
  # Every idle-stall guard event (UITestSupport.rotateToLandscape, T-034) and system-banner guard event
  # (UITestSupport.dismissSystemBanner, T-035) becomes a GitHub warning, so a run the guard recovered still shows it
  # on the run page. This never changes the exit status.
  if [[ -f "$SHOTS/manifest.json" ]]; then
    python3 - "$SHOTS" <<'PY' || true
import json, os, sys
shots = sys.argv[1]
with open(os.path.join(shots, "manifest.json"), encoding="utf-8") as manifest:
    tests = json.load(manifest)
for test in tests:
    for item in test.get("attachments", []):
        name = item.get("suggestedHumanReadableName", "")
        kind = next((k for k in ("idle-stall-guard", "system-banner-guard") if name.startswith(k)), None)
        if kind is None:
            continue
        summary = f"{kind} attachment"
        path = os.path.join(shots, item.get("exportedFileName", ""))
        if os.path.isfile(path):
            with open(path, encoding="utf-8", errors="replace") as handle:
                summary = handle.readline().strip() or summary
        title = "UI test idle stall" if kind == "idle-stall-guard" else "System banner over the app"
        print(f"::warning title={title}::{test.get('testIdentifier', '?')}: {summary}")
PY
  fi
fi

if [[ $status -ne 0 ]]; then
  echo "Tests FAILED (exit $status). Results: $RESULT" >&2
  exit $status
fi
echo "Tests passed. Results: $RESULT"
