# Clip Deck: development guide

## Environment

- macOS with Xcode (and an iOS simulator runtime: Xcode > Settings > Components)
- XcodeGen: `brew install xcodegen`

Check your machine: `python3 ~/.claude/skills/iphone-app-setup-skill/scripts/env_check.py` (if the skill is installed).

## First-time setup

```bash
./scripts/bootstrap.sh
```

## Environment variables

Server-side values go in `.env` (copied from `.env.example`, git-ignored).
Public, per-build app values go in `ios/Config/*.xcconfig`; per-developer ones in `ios/Config/Secrets.xcconfig` (copied from `Secrets.example.xcconfig`, git-ignored). In xcconfig files write `//` in URLs as `/$()/`.

| Variable | Used by | Purpose | Where to get it |
|---|---|---|---|
{{FILL: one row per variable in .env.example and ios/Config/Secrets.example.xcconfig, or "None".}}

## Daily commands

```bash
./scripts/run-ios.sh
./scripts/test-ios.sh
cd ios && xcodegen generate   # after adding files or editing project.yml
```

## Simulator

`./scripts/run-ios.sh` picks a booted iPhone simulator, else the newest iPhone (set `SIM_NAME` to choose). The simulator shares this Mac's network, so `localhost` reaches local services. A physical iPhone needs the Mac's LAN IP in `ios/Config/Debug.xcconfig` and a signing team (`DEVELOPMENT_TEAM` in `ios/project.yml`).

With Claude Code, the `ios-simulator-skill` skill can drive the running app (tap/type by
accessibility label or identifier, screenshots, dark mode, text size, permissions, location, logs).

## Tests

```bash
./scripts/test-ios.sh
```

{{FILL: what each test suite covers and anything it needs running first (e.g. the local backend).}}

## Troubleshooting

| Problem | Fix |
|---|---|
| `xcodegen: command not found` | `brew install xcodegen` |
| No simulators / SDK not found | Xcode > Settings > Components: install an iOS runtime; `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| Scheme not found / new files missing in Xcode | `cd ios && xcodegen generate` |
| App can't reach the backend | Is it running? Check the URL in `ios/Config/Debug.xcconfig` (`http:/$()/...`) |
| Crash when asking for a permission | Add the usage description in `ios/project.yml` > `info.properties` |
{{FILL: add problems actually hit during setup and how they were fixed.}}
