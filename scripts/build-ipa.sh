#!/usr/bin/env bash
# Build an UNSIGNED ClipDeck.ipa for installing on your own iPhone with Sideloadly (or AltStore),
# which re-signs it with your Apple ID. Output: build/ipa/ClipDeck.ipa
# Needs: macOS with Xcode and xcodegen (runs in GitHub Actions; see .github/workflows/ios-simulator.yml).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="ClipDeck"
ARCHIVE="$ROOT/build/$SCHEME.xcarchive"
OUT="$ROOT/build/ipa"

command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen" >&2; exit 1; }
(cd "$ROOT/ios" && xcodegen generate --quiet)

rm -rf "$ARCHIVE" "$OUT"
xcodebuild archive \
  -project "$ROOT/ios/$SCHEME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  -quiet

mkdir -p "$OUT/Payload"
cp -R "$ARCHIVE/Products/Applications/$SCHEME.app" "$OUT/Payload/"
(cd "$OUT" && zip -qry "$SCHEME.ipa" Payload && rm -rf Payload)
echo "Unsigned IPA: $OUT/$SCHEME.ipa"
