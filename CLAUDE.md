# Clip Deck: notes for Claude Code

Created with the `iphone-app-setup-skill` skill. Stack: SwiftUI, iOS 17.0+, XcodeGen; backend: none.
Read `docs/ARCHITECTURE.md` before structural changes and `docs/DESIGN.md` before UI changes.

## Commands

```bash
./scripts/run-ios.sh
./scripts/test-ios.sh
cd ios && xcodegen generate   # after adding files or editing project.yml
```

## Conventions

- Bundle id `dev.brent.clipdeck`; scheme / target `ClipDeck`.
- `ios/project.yml` is the source of truth; the `.xcodeproj` is generated (`cd ios && xcodegen generate`). Never edit the `.xcodeproj`.
- Feature code in `ios/ClipDeck/Features/<Feature>/` (View + `@Observable` model); shared UI in `DesignSystem/`; network/SDK code only in `Services/`.
- App target uses Swift 6 with MainActor default isolation.
- Every interactive element gets an `accessibilityIdentifier` named `feature.element`.
- Server secrets live only in `.env` (git-ignored) on the backend. Never put them in app code or xcconfig.
- Sample/mock data only in tests or behind an explicit, documented switch.

## Verifying changes

- Use the `ios-simulator-skill` skill to build, launch, drive and screenshot the app; check light and
  dark mode and a large Dynamic Type size for UI changes.
- Run the full test suite before committing; report only results you actually ran.
- After structural changes run `python3 ~/.claude/skills/iphone-app-setup-skill/scripts/verify_project.py .`
- To resume setup or re-verify on a new machine: `/iphone-app-setup-skill verify`.

## Current status

{{FILL: what works and is verified, what is implemented but unverified, what is next.}}
