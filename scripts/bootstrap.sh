#!/usr/bin/env bash
# One-time setup on a fresh clone: checks tools, creates local config files, installs dependencies,
# and generates the Xcode project. Safe to re-run; never overwrites existing local config.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
missing=0
need() { command -v "$1" >/dev/null || { echo "Missing: $1  ->  $2"; missing=1; }; }

need xcodebuild "Install Xcode from the App Store, then: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
need xcodegen "brew install xcodegen"
need python3 "Install Xcode command line tools: xcode-select --install"

[[ $missing -eq 0 ]] || { echo "Install the missing tools above, then re-run."; exit 1; }

[[ -f "$ROOT/.env" ]] || { cp "$ROOT/.env.example" "$ROOT/.env"; echo "Created .env from .env.example"; }
[[ -f "$ROOT/ios/Config/Secrets.xcconfig" ]] || {
  cp "$ROOT/ios/Config/Secrets.example.xcconfig" "$ROOT/ios/Config/Secrets.xcconfig"
  echo "Created ios/Config/Secrets.xcconfig from the example"
}

(cd "$ROOT/ios" && xcodegen generate)
echo "Done. Next: see README.md > Run the app."
