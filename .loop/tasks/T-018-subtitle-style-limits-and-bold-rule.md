---
id: T-018
title: Stop Up when the line can't go higher, and trust a font's weight over its name
lane: frontend
depends_on: [T-016]
status: todo
round: 0
base_sha:
issue: 19
spec: .loop/specs/subtitle-style.md
model:
---

## Stop Up when the line can't go higher, and trust a font's weight over its name

### What are we building?
Two small fixes from T-016's review. With the landscape style card open, the line stops below the top bar after about 12, 9 or 6 Up taps (for a 1-, 2- or 3-row card), but Up stays enabled, so later taps change the saved value without showing anything. And a font whose name contains "Black", "Heavy" or "Bold" counts as bold even when the font reports a light weight.

### Why?
Brent chose to fix both in a follow-up: every enabled tap should show its effect, and a light font named "…Black" shouldn't disable Bold or say "This font is always bold."

### Done when
- AC-1 While the landscape card is open, Up is disabled (dimmed, with VoiceOver value "Highest") as soon as one more step would no longer move the line. That is, the placement for step n+1 is clamped to the same place as step n (SubtitlePlacement.swift:55-61). Closing the card and the portrait sheet keep their existing rule: Up disables only at the stored limit (90%). The value text keeps showing the stored percent.
- AC-2 A unit test for the new "can the line still move up with the card open" function covers 1-, 2- and 3-row card heights and the top-bar clamp. A UI test taps Up with the card open until it disables and asserts that every tap before that moved the line by more than 1 pt.
- AC-3 `SubtitleStyle.isBoldFace` (SubtitleStyle.swift:244-252) uses the name ("bold", "heavy", "black") only when the font has no weight trait. When a weight trait exists, the rule is weight >= 0.3 or the bold symbolic trait. ArialRoundedMTBold must still count as bold, by its weight trait: prove it with a test that fails if the name rule were the only path. Add a unit test for a light face whose name contains "Black".
- AC-4 Every existing test still passes. Update docs/DESIGN.md (the landscape card note) to match.

### How to check
- CI: `gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=all`.
- The new unit tests in SubtitleStyleTests / SubtitleFontTests, and the new card UI test.

### Agent notes
- Depends on: T-016
- Source: T-016 Test report round 2, Could fix C3 and C4; Brent's decision, 2026-11-22 ("small follow-up task after").
- Keep T-014's placement for the closed card and portrait unchanged. Only the "can step up" decision, used while the card is open, is new.
- Read .loop/CONTEXT.md "Learned": a `.contain` container frame is a union; don't put a mutating call inside `#expect`; `.traitBold` misses ArialRoundedMTBold.

### Out of scope
- Changing step sizes or limits; ASS file styles.
