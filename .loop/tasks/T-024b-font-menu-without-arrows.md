---
id: T-024b
title: Font menu without arrows, with its own Reset
lane: frontend
depends_on: [T-024a]
status: todo
round: 0
base_sha:
issue: 27
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Keep only font, bold and size in the Font menu, with a Reset that leaves the position alone

### What are we building?
After T-024a the position has its own menu, but the Font menu still shows arrows, and its Reset undoes everything. After this task the Font sheet and card have no arrows and no Position section, the card fits in one tidy row (or two), and the Font Reset only resets font, bold and size.

### Why?
Each menu does one job, and resetting a font never throws away a carefully chosen position.

### Done when
- AC-1 The portrait Font sheet has no Position section and no gap where it was: Size and Reset move up. Reset (`subtitleStyle.reset`) calls `resetFont()`. It's disabled when the font group is at its default, and its value reads "Default" or "Changed" for the font group only.
- AC-2 The landscape Font card shows one row: Sans, Rounded, Serif, More, Bold, size−, size+, Reset, Done. Its fallback is two rows: [Sans, Rounded, Serif, More, Bold] / [size−, size+, Reset, Done], with Reset just left of Done as listed. The three-row layout and the arrows are gone; nothing else in the card changes.
- AC-3 The Aa button (`player.subtitleStyle`) is aqua and reads "Changed" only when the font group isn't at its default. A moved line alone doesn't light it; ✥A shows that.
- AC-4 The Font card's Up-dim and Down-jump wiring goes away with its arrows. Where the line sits while the Font card is open doesn't change: it's still lifted above the card as today.
- AC-5 Tests, in both orientations:
  - with a seeded `{"font":"serif","sizeStep":3,"up":0.30,"right":-0.20}`, Font Reset restores Sans at 100 % and leaves `player.subtitle` at its moved place (±1 pt), and Move-Text Reset leaves the serif font and the size alone;
  - the card shows 9 controls in one row with the panel closed and 5 + 4 at a 50 % panel, all inside the column and the safe area;
  - no `subtitleStyle.up|down|left|right` element exists in the sheet or the card.
- AC-6 The old tests that drive the Font menu's arrows (in SubtitleStyleCardTesterUITests, SubtitleUpLimitTesterUITests, SubtitleStyleSheetTesterUITests, SubtitleStyleCardUITests, SubtitleStyleUITests and SubtitleStyleTesterUITests) are moved to the Move-Text controls (`moveText.*`) where they still prove something T-024a's tests don't. Where they duplicate T-024a's tests, they're deleted. List which in your notes. Every remaining test passes, and DESIGN.md "Subtitle style menu" is updated.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check the edited SubtitleStyle* suites, SubtitleStyleSheetTesterUITests (the sheet still clears the video after the Position section is removed), and the new reset tests.

### Agent notes
- Depends on: T-024a (positions must already be movable from Move-Text). Source: spec T-024, the "Font menu" part.
- Code: the controls and layouts are at SubtitleStyleCard.swift:26-44, and the arrow and Reset cases around 114-140. PlayerView.swift:239-247 and 272-278 pass `canStepUp`/`highestUp` to the card (renamed from `highestUpStep` in T-023). In SubtitleStyleSheet.swift, the sections are at 283-286 and Position/Reset at 580-622.
- The sheet's first detent is fitted to its content by SheetFit (Learned). After removing the section, check that it still sits under the video.
- The card has a background, so XCUITest reports its real frame (Learned).
- C5 from T-023's tester: `SubtitleStyleSheetTesterUITests/testUsingTheSheetDoesNotPausePlayback` reads the button 4–5 s after Play on the 6 s clip and flaked in 45168178904. Since this task reworks that class, launch it with `-uiTestingSampleSeconds 20`.
- **AC-7 (Brent, 2026-11-23, from T-022's tester):** in portrait, tapping the video while the Aa sheet is open closes the sheet, as if Done were pressed. Landscape already does this with the Aa card. Today the tap silently flips `portraitOverlayVisible`, so after Done the overlay may unexpectedly stay hidden or appear (SubtitleStyleSheet.swift:320, 331-334; PlayerView.swift:188, 540, 635-638). Add a UI test: open the sheet, tap the video, and the sheet must close with the overlay state unchanged.
- Since T-022 the centred overlay hides while either Aa menu is open, in both orientations, so the line shows at its saved place there (DESIGN.md "Style menus"). C2 from T-022's tester: DESIGN.md:95 says "see Style card", but that bullet is now "Style menus"; fix the wording here.

### Out of scope
- Font, size and bold rules; the Move-Text menu itself.
