#!/usr/bin/env bash
# Build ClipDeck for an iPhone simulator, install it, launch it, and save a launch screenshot.
# Usage: ./scripts/run-ios.sh                 (uses a booted iPhone or the newest one)
#        SIM_NAME="iPhone 17 Pro" ./scripts/run-ios.sh
# Needs: macOS, Xcode with an iOS simulator runtime, xcodegen (brew install xcodegen).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="ClipDeck"
BUNDLE_ID="dev.brent.clipdeck"
DERIVED="$ROOT/build/DerivedData"
SHOTS="$ROOT/build/screenshots"

command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "xcodebuild not found: install Xcode" >&2; exit 1; }

(cd "$ROOT/ios" && xcodegen generate --quiet)

UDID="$(python3 "$ROOT/scripts/pick-simulator.py" "${SIM_NAME:-}")"
echo "Simulator: $UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true      # already booted is fine
xcrun simctl bootstatus "$UDID" -b >/dev/null
open -a Simulator 2>/dev/null || true               # Xcode 27+ has no Simulator.app; the app still runs headless

echo "Building $SCHEME..."
xcodebuild build \
  -project "$ROOT/ios/$SCHEME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -quiet

APP="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID"

sleep 3
mkdir -p "$SHOTS"
SHOT="$SHOTS/launch-$(date +%Y%m%d-%H%M%S).png"
xcrun simctl io "$UDID" screenshot "$SHOT" >/dev/null
echo "Launched $BUNDLE_ID. Screenshot: $SHOT"
