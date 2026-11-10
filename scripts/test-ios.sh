#!/usr/bin/env bash
# Run ClipDeck unit tests (Swift Testing) and UI tests (XCUITest) on an iPhone simulator.
# Usage: ./scripts/test-ios.sh                     all tests
#        ./scripts/test-ios.sh ClipDeckTests       one test target (passed to -only-testing)
#        SIM_NAME="iPhone 17 Pro" ./scripts/test-ios.sh
# Results bundle: build/TestResults-<timestamp>.xcresult (open in Xcode for details).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="ClipDeck"
DERIVED="$ROOT/build/DerivedData"
RESULT="$ROOT/build/TestResults-$(date +%Y%m%d-%H%M%S).xcresult"

command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen" >&2; exit 1; }
(cd "$ROOT/ios" && xcodegen generate --quiet)

UDID="$(python3 "$ROOT/scripts/pick-simulator.py" "${SIM_NAME:-}")"
ONLY=()
if [[ $# -gt 0 ]]; then ONLY=(-only-testing "$1"); fi

mkdir -p "$ROOT/build"
status=0
xcodebuild test \
  -project "$ROOT/ios/$SCHEME.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -resultBundlePath "$RESULT" \
  ${ONLY[@]+"${ONLY[@]}"} \
  -quiet || status=$?

# Save the UI tests' screenshots (XCTAttachments) as PNGs, pass or fail, for review.
if [[ -d "$RESULT" ]]; then
  SHOTS="$ROOT/build/screenshots/ui-tests"
  mkdir -p "$SHOTS"
  xcrun xcresulttool export attachments --path "$RESULT" --output-path "$SHOTS" >/dev/null 2>&1 \
    && echo "UI test screenshots: $SHOTS" \
    || echo "(Could not export screenshots; open $RESULT in Xcode.)"
fi

if [[ $status -ne 0 ]]; then
  echo "Tests FAILED (exit $status). Results: $RESULT" >&2
  exit $status
fi
echo "Tests passed. Results: $RESULT"
