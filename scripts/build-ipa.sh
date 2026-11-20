#!/usr/bin/env bash
# Build an UNSIGNED ClipDeck.ipa for installing on your own iPhone with Sideloadly (or AltStore),
# which re-signs it with your Apple ID. Output: build/ipa/ClipDeck.ipa
# Optional env vars (used by .github/workflows/release.yml; unset = the values in ios/project.yml):
#   MARKETING_VERSION        CFBundleShortVersionString, e.g. 0.2.0
#   CURRENT_PROJECT_VERSION  CFBundleVersion, e.g. the CI run number
# Needs: macOS with Xcode and xcodegen (runs in GitHub Actions; see .github/workflows/ios-simulator.yml).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="ClipDeck"
ARCHIVE="$ROOT/build/$SCHEME.xcarchive"
OUT="$ROOT/build/ipa"

command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen" >&2; exit 1; }
(cd "$ROOT/ios" && xcodegen generate --quiet)

VERSION_ARGS=()
if [[ -n "${MARKETING_VERSION:-}" ]]; then
  [[ "$MARKETING_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$ ]] \
    || { echo "MARKETING_VERSION '$MARKETING_VERSION' is not like 1.2.3 or 1.2.3-rc1" >&2; exit 1; }
  VERSION_ARGS+=("MARKETING_VERSION=$MARKETING_VERSION")
fi
if [[ -n "${CURRENT_PROJECT_VERSION:-}" ]]; then
  [[ "$CURRENT_PROJECT_VERSION" =~ ^[0-9]+$ ]] \
    || { echo "CURRENT_PROJECT_VERSION '$CURRENT_PROJECT_VERSION' must be a whole number" >&2; exit 1; }
  VERSION_ARGS+=("CURRENT_PROJECT_VERSION=$CURRENT_PROJECT_VERSION")
fi

rm -rf "$ARCHIVE" "$OUT"
xcodebuild archive \
  -project "$ROOT/ios/$SCHEME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  ${VERSION_ARGS[@]+"${VERSION_ARGS[@]}"} \
  -quiet

mkdir -p "$OUT/Payload"
cp -R "$ARCHIVE/Products/Applications/$SCHEME.app" "$OUT/Payload/"
(cd "$OUT" && zip -qry "$SCHEME.ipa" Payload && rm -rf Payload)
echo "Unsigned IPA: $OUT/$SCHEME.ipa"
