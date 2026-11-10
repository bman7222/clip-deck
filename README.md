# Clip Deck

{{FILL: one or two sentences: what the app does and who it is for.}}

## Technologies

| Part | Technology |
|---|---|
| iPhone app | SwiftUI, iOS 17.0+, XcodeGen |
| Backend | None: data stays on the device (SwiftData) |
| Tests | Swift Testing (unit), XCUITest (UI) |

## Project structure

```text
ios/
  project.yml            XcodeGen spec (source of truth for the Xcode project)
  Config/                xcconfig build settings (Debug = local, Release = hosted)
  ClipDeck/
    App/                 entry point, configuration, root view
    Features/            one folder per feature (views + models)
    DesignSystem/        colours, type, spacing, reusable components
    Services/            API / SDK clients, repositories
    Models/              data types
    Resources/           asset catalog
  ClipDeckTests/          unit tests
  ClipDeckUITests/        UI tests
docs/                   product spec, architecture, design, development guide
scripts/                bootstrap, run in simulator, run tests
```

## Prerequisites

- macOS with Xcode (and an iOS simulator runtime: Xcode > Settings > Components)
- XcodeGen: `brew install xcodegen`

## Setup

```bash
./scripts/bootstrap.sh
```

{{FILL: list any values the developer must add to .env or ios/Config/Secrets.xcconfig and where to get them, or say "No credentials needed for local development."}}

## Run the backend

This app has no backend. Data is stored on the device.

## Run the app in the iOS Simulator

```bash
./scripts/run-ios.sh
```

Builds the app, boots an iPhone simulator, installs and launches the app, and saves a screenshot to `build/screenshots/`. Pick a device with `SIM_NAME="<simulator name>"` (list them with `xcrun simctl list devices available`). To work in Xcode, run `cd ios && xcodegen generate` and open `ios/ClipDeck.xcodeproj`.

## Run the tests

```bash
./scripts/test-ios.sh
```

## Documentation

- [Product spec](docs/PRODUCT_SPEC.md): purpose, users, features, scope
- [Architecture](docs/ARCHITECTURE.md): components, decisions, how parts communicate
- [Design](docs/DESIGN.md): visual identity, tokens, screens
- [Development](docs/DEVELOPMENT.md): environment, commands, simulator, troubleshooting

