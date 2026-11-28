#!/usr/bin/env bash
# Fail unless the built IPA carries the licence texts the FFmpeg LGPL-2.1 build requires.
# Usage: ./scripts/check-ipa-notices.sh [path/to/ClipDeck.ipa]      default: build/ipa/ClipDeck.ipa
# Checks inside Payload/ClipDeck.app/Licenses/:
#   FFmpeg-LGPL-2.1.txt    contains "GNU LESSER GENERAL PUBLIC LICENSE"
#   FFmpeg-NOTICE.txt      contains the FFmpegBuild tag URL
#   ClipDeck-LICENSE.txt   contains "All rights reserved"
#   ZIPFoundation-LICENSE.txt contains "MIT License"
#   Deconjugation-LICENSE.txt contains "Apache License"
# Also fails if the bundled copy of LICENSE differs from the repository's LICENSE, and if an FFmpeg
# framework is missing from the app bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IPA="${1:-$ROOT/build/ipa/ClipDeck.ipa}"
APP="Payload/ClipDeck.app"
TAG_URL="https://github.com/superuser404notfound/FFmpegBuild/tree/3.16.0"

[[ -f "$IPA" ]] || { echo "IPA not found: $IPA (run scripts/build-ipa.sh first)" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/clipdeck-ipa-check.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
unzip -q "$IPA" -d "$WORK"

fail=0
check() { # file, text, description
  local file="$WORK/$APP/Licenses/$1"
  if [[ ! -f "$file" ]]; then
    echo "FAIL: $APP/Licenses/$1 is missing ($3)" >&2; fail=1
  elif ! grep -q -- "$2" "$file"; then
    echo "FAIL: $APP/Licenses/$1 does not contain \"$2\" ($3)" >&2; fail=1
  else
    echo "ok:   $APP/Licenses/$1 contains \"$2\""
  fi
}

check FFmpeg-LGPL-2.1.txt "GNU LESSER GENERAL PUBLIC LICENSE" "bundled LGPL-2.1 text"
check FFmpeg-NOTICE.txt "$TAG_URL" "FFmpeg notice with the FFmpegBuild tag URL"
check ClipDeck-LICENSE.txt "All rights reserved" "Clip Deck licence"
check ZIPFoundation-LICENSE.txt "MIT License" "ZIPFoundation licence"
check Deconjugation-LICENSE.txt "Apache License" "JL and Nazeka deconjugation rules licence"

if [[ -f "$WORK/$APP/Licenses/ClipDeck-LICENSE.txt" ]] && ! cmp -s "$ROOT/LICENSE" "$WORK/$APP/Licenses/ClipDeck-LICENSE.txt"; then
  echo "FAIL: bundled ClipDeck-LICENSE.txt differs from the root LICENSE (copy LICENSE to ios/ClipDeck/Resources/Licenses/ClipDeck-LICENSE.txt)" >&2
  fail=1
fi

for lib in AetherLibavformat AetherLibavcodec AetherLibavutil AetherLibswresample AetherLibdav1d AetherLibzvbi; do
  if [[ ! -d "$WORK/$APP/Frameworks/$lib.framework" ]]; then
    echo "FAIL: $APP/Frameworks/$lib.framework is missing" >&2; fail=1
  fi
done

if [[ $fail -ne 0 ]]; then
  echo "IPA notice check FAILED: $IPA" >&2
  exit 1
fi
echo "IPA notice check passed: $IPA"
