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
xcodebuild test \
  -project "$ROOT/ios/$SCHEME.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -resultBundlePath "$RESULT" \
  ${ONLY[@]+"${ONLY[@]}"} \
  -quiet
echo "Tests passed. Results: $RESULT"
