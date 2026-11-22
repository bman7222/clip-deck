---
id: T-017
title: Pick any installed font for subtitles, with Japanese that always renders cleanly
lane: frontend
depends_on: [T-015]
status: done
round: 1
base_sha: cb8203f9772d403d318591346ed9e49c13a700bc
issue: 18
spec: .loop/specs/subtitle-style.md
model:
---

## Pick any installed font for subtitles, with Japanese that always renders cleanly

### What are we building?
The portrait style sheet gets a "More fonts…" row below the three presets. It opens the iPhone's own font picker, so any installed font can be used for the subtitle line. Most fonts have no Japanese letters, so Japanese text always falls back to the matching Hiragino face (Sans, Rounded or Mincho) instead of boxes or a random font. The row shows the picked font's name and a mixed sample "Aa あア漢字", so both scripts can be judged. A picked font that later disappears quietly becomes Sans.

### Why?
Clip Deck is a Japanese and English app. Brent wants more font choice without ever breaking how Japanese lines look.

### Done when
- AC-1 `SubtitleStyle` gains `pickedFontName: String?` (a PostScript name), as the spec's "Picked font" section describes:
  - it takes the place of the preset, and picking a preset clears it;
  - `isDefault` needs it to be nil;
  - old JSON without the field still decodes;
  - `-uiTestingSubtitleStyle` accepts it.
- AC-2 Missing font: if `UIFont(name:size:)` returns nil for the stored name, the read drops it and the style uses Sans. Everything else is kept, and nothing crashes.
- AC-3 Closest preset and cascade, per the spec:
  - the closest preset is a pure function: names first ("Mincho"/"Serif" → Serif, "Rounded"/"Maru" → Rounded), then the serif family classes, otherwise Sans;
  - the cascade goes to that preset's Hiragino face (W3, or W6 with Bold; Maru W4);
  - Bold uses the family's bold face if it has one, otherwise the regular face unchanged.
- AC-4 Sheet: `subtitleStyle.font.more` ("More fonts…", `ellipsis.circle`) opens `UIFontPickerViewController`, wrapped for SwiftUI, with `includeFaces = false`, as a sheet from the style sheet.
  - Choosing a family saves it and updates the line live. Cancel changes nothing.
  - The row shows the picked font's name and "Aa あア漢字" drawn exactly as the line draws it (the cascade included). It is aqua while selected.
  - "This font has no bold weight." shows under it when that is true.
  - VoiceOver hears "More fonts", with the value set to the picked name or "None".
- AC-5 Unit tests (`SubtitleStyleTests` or a new `SubtitleFontTests`):
  - the closest-preset function, with synthetic names and traits;
  - real fonts: Georgia → Serif, `ArialRoundedMTBold` → Rounded, Helvetica → Sans;
  - CoreText runs of "Aa あア漢字" with Georgia: the Latin run uses Georgia, and the Japanese runs use `HiraMinProN-W3`, or `-W6` with Bold. No run uses `.LastResort`;
  - Georgia with Bold → `Georgia-Bold`;
  - a family without bold (for example Zapfino) keeps its face;
  - a missing name decodes to Sans;
  - JSON without the field decodes.
- AC-6 UI tests (portrait):
  - a seeded `{"pickedFontName":"Georgia"}` launch shows "Georgia" in the More fonts row, the opener is aqua, and the line shows;
  - a seeded `"NoSuchFont-Regular"` launch opens the player without a crash, with Sans selected and the opener not aqua;
  - More fonts opens the picker (wait for its search field or list), and cancelling returns to the sheet;
  - attach `style-03-picked-font`.
  - Don't drive a selection inside the system picker; it's flaky.
- AC-7 DESIGN.md and PRODUCT_SPEC.md describe More fonts and the Japanese fallback. Every existing test still passes.

### How to check
CI only:
1. `git push origin loop/subtitle-style`, then `gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=all`.
2. `gh run watch <id> --exit-status`. On failure, `gh run view <id> --log-failed`.
3. `./scripts/test-ios.sh` and `./scripts/build-ipa.sh` pass.
4. Read `style-03-picked-font`: Georgia for the Latin text, Mincho for the Japanese, no boxes.

Unverified for Brent: picking a font by hand on his iPhone, and a user-installed font that is later removed.

### Agent notes
- Depends on: T-015 (the sheet, the controls view, the presets with samples). T-016 reuses this wrapper and control in the landscape card. Source: the spec's "Picked font" section, D-1 (Brent: "both").
- The cascade uses `UIFontDescriptor.AttributeName.cascadeList`. Build the picked font through the same single font builder as the presets, so the line, the sample and the tests agree.
- Store the descriptor's PostScript name. `UIFont(name:)` with it must work at the next launch.
- Presenting a sheet from the style sheet is fine in portrait. Landscape is T-016.

### Out of scope
- The landscape card (T-016). Faces and italics. Bundled or downloaded fonts.

## Implementation notes (round 1) · sonnet
_by loop-frontend · 2026-11-21_
- Changed: `SubtitleStyle.pickedFontName: String?` (init param last, CodingKeys, `clamped()` keeps it, `isDefault` needs nil). Decoding drops a name that `UIFont(name:)` can't build and sets font to Sans, keeping the other fields. `uiFont` builds a picked font through the same single builder: the family's real bold face when Bold is on and one exists (else the regular face, no faux bold), plus a cascade to the Hiragino face of the closest preset. Pure `closestPreset(familyName:fontName:traits:)` (names, then serif classes, else Sans). `japaneseFallbackName` returns the picked font's Hiragino face. `SubtitleStyle.seeded(from:)` keeps a missing seeded name so the read path is exercised (ClipDeckApp uses it).
- Sheet: `subtitleStyle.font.more` row (`ellipsis.circle`, name + sample "Aa あア漢字" via the line's own font, aqua when picked, label "More fonts", value name or "None"), the note `subtitleStyle.font.noBold`, preset rows clear the picked font. `SystemFontPicker` (UIViewControllerRepresentable, Coordinator delegate, includeFaces false) in a `.sheet` from the style sheet; it stores the PostScript name of the resolved font.
- SheetFit: while the picker is shown, `fitFirstDetent` waits (without using attempts) and never measures, so a covered or moved sheet can't cache a wrong rise. The picker is a modal over the sheet, so the video behind stays as in T-015 (playback is not touched).
- Files: ios/ClipDeck/Features/Player/SubtitleStyle.swift, SubtitleStyleSheet.swift, ios/ClipDeck/App/ClipDeckApp.swift, ios/ClipDeckTests/SubtitleFontTests.swift (new), ios/ClipDeckUITests/SubtitleFontUITests.swift (new), docs/DESIGN.md, docs/PRODUCT_SPEC.md
- Checked: nothing compiled (Windows); scanned for line breaks inside strings.
- Tester, look at: Georgia's real family class gives Serif (rule 3); Zapfino has no bold and `withSymbolicTraits(.traitBold)` handling; the picker's "Cancel" button and search field in XCUITest on iOS 26; SheetFit after the picker closes (done button still below the video); CoreText run names in SubtitleFontTests.
- Gotchas: the picked font's `font` field is set to Sans when picked; the no-bold note shows whenever a picked font lacks bold (Bold on or off).

## Test report (round 1)
_by loop-tester · 2026-11-21 18:12_

CI 44957727655 (59383f1, scope=all, iPhone 17 Pro / iOS 26.5). The ipa job is green. The simulator job ran 345/347 with 0 build issues. The 2 failures are a known landscape flake and a wrong button label in the builder's Cancel test. Unit tests: 16/16 SubtitleFontTests pass.

| Criterion | Result | Evidence |
|-----------|--------|----------|
| AC-1 `pickedFontName`: replaces the preset, a preset clears it, `isDefault` needs nil, old JSON decodes, the seed accepts it | Pass, except "a preset clears it", which is pending the verify run | Unit: pickedFontIsSavedAndDecodedBack, aPickedFontIsNeverTheDefaultStyle, oldSavedStylesWithoutTheFieldStillDecode, aPresetStyleSavesNoPickedFont pass. The seed works: the UI tests seed Georgia, Zapfino and NoSuchFont. "A preset clears it" has been checked only by reading (SubtitleStyleSheet.swift:413-416); the deciding test is the new SubtitleFontTesterUITests/testPickingAPresetClearsThePickedFont |
| AC-2 Missing font → Sans, the rest kept, no crash | Pass | Unit: aMissingFontDecodesToSansAndKeepsTheRest, aMissingFontIsDrawnAsSansEvenWhenSetDirectly, theSeedKeepsAMissingNameSoTheReadCanDropIt. UI: testAMissingFontQuietlyBecomesSans: the player opened, the line showed, the opener reads "Default", Sans is selected, and More fonts is "None" and not selected |
| AC-3 Closest preset (pure; names, then serif classes, then Sans), the cascade to the preset's Hiragino face, real bold only | Pass | Unit: namesDecideTheClosestPresetBeforeTheFamilyClass, serifFamilyClassesGiveSerifAndEverythingElseSans, realFontsMapToTheirPreset, aRoundedPickedFont…MaruGothic, aSansPickedFont…HiraginoSansExplicitly, aFamilyWithoutBoldKeepsItsFace all pass |
| AC-4 More fonts opens the picker (families only) as a sheet; Cancel changes nothing; the row shows the name and the sample as the line draws it, aqua; the no-bold note; VoiceOver "More fonts", value name or "None" | Partly. Opening: Pass. Row, note, VO: Pass. Cancel: pending the verify run. Choosing a family: Unverified (Brent) | The picker opens: the failure tree EF31EBA0 shows `subtitleStyle.fontPicker` with the NavigationBar "Choose Font", a SearchField and family rows only ("Academy Engraved LET", "Al Nile", …, no face expanders). Row: style-03-picked-font shows an aqua row, "Georgia", and "Aa" in Georgia Bold with あア漢字 in Hiragino Mincho W6. testAFontWithoutBoldSaysSo passes (Zapfino, exact note text). Label and value are asserted in testSeededGeorgia… |
| AC-5 Unit tests (closest preset, real fonts, CoreText runs with no LastResort, Georgia-Bold, Zapfino, missing → Sans, old JSON) | Pass | 16/16 SubtitleFontTests pass in 44957727655. georgiaDrawsLatinInGeorgiaAndJapaneseInHiraginoMincho: Latin is Georgia, Japanese is HiraMinProN-W3. georgiaBold…: Georgia-Bold and HiraMinProN-W6. No run uses LastResort |
| AC-6 UI: seeded Georgia + style-03 shot; seeded missing → Sans; More fonts opens the picker and Cancel returns | Partly. 3/4 pass. The Cancel test failed on a test flaw (fixed by the tester, pending) | testSeededGeorgia… and testAMissingFont… pass. testMoreFontsOpensThePickerAndCancelReturnsToTheSheet failed at "The picker has a Cancel button": on iOS 26 the picker's dismiss button is an X labelled `close` (tree EF31EBA0 line 69) |
| AC-7 DESIGN.md and PRODUCT_SPEC.md describe More fonts and the fallback; every existing test still passes | Docs: Pass (read). Earlier suites: pending the flake re-check | Docs diff read: both describe the row, the picker, the Hiragino fallback and missing → Sans. 345/347: the only earlier-suite failure is PlayerLandscapeBehaviourUITests/testOpenSubtitlesMenuKeepsControlsUpWhilePlaying ("Controls are up when the dialog opens"), a known flake in CONTEXT Learned that the diff doesn't touch |

Screenshot reading (style-03-picked-font, 1206×2622):
- The line "元気ですか" on the video is Hiragino Mincho: brush-like serifs and thin horizontals, white with the black outline. It is clear, legible and not tofu.
- The More fonts row shows "Aa" in Georgia Bold and あア漢字 in Mincho. It looks clearly different from the Gothic Sans sample above it and matches the Serif preset's Japanese.
- The sheet's top is at about 350 pt and the video ends at 342, so the video is uncovered.
- In the same run, T-015's tester-sheet-open-frames shows the sheet at {{8.0, 349.4}} and the new row `subtitleStyle.font.more` at y 605.1, value None. tester-wrong-rise: settled at 349.41, not covered early.

SheetFit while the picker is up, by reading only: `fitFirstDetent` (SubtitleStyleSheet.swift:322-346) skips a loop turn without using an attempt while `showingFontPicker` is true, and it resets `previousTop`. So nothing is measured or cached while the picker covers the sheet. A fit that has already finished never runs again unless `SheetFitKey` changes. No run yet records the sheet's top after Cancel. The deciding tests are testCancellingThePickerLeavesTheSheetTopAndTheCachedRiseAlone, which compares before, after Cancel and on a reopen to 1 pt and requires a gap of −0.5…16 pt, and testOpeningThePickerBeforeTheSheetHasSettledCachesNoWrongRise. The second is the one that reaches the guard; the first runs after the fit has finished.

### Findings
Fixed in test code by the tester (uncommitted): the builder's Cancel lookup
Where: ios/ClipDeckUITests/SubtitleFontUITests.swift:76
Problem: `app.buttons["Cancel"]` doesn't exist on iOS 26. UIFontPickerViewController ("Choose Font", a remote view) has an X button labelled `close`.
Proof: Ran it. CI 44957727655 failed with "XCTAssertTrue failed - The picker has a Cancel button". In the hierarchy EF31EBA0, line 69 reads `Button … label: 'close'`.
Fix: done. The button is matched by label IN ["Cancel", "close", "Close"].

Could fix C1: a bold-only family ignores Bold off and says nothing
Where: ios/ClipDeck/Features/Player/SubtitleStyle.swift:245 and :255
Problem: `boldFace` returns the base font when it is already bold. So a family whose only face is bold (for example `ArialRoundedMTBold`) draws bold with Bold off, and `pickedFontHasBold` is true, so no note shows.
Proof: Read it.
Trigger: pick "Arial Rounded MT Bold" and turn Bold off.
Fix: optional. Show a note such as "This font has only a bold weight." when the base face is bold. The spec doesn't cover this case.

```text
VERDICT: Blocked
SPEC: AC-2, AC-3, AC-5 met. AC-1 met except "a preset clears it" (test pending). AC-4 met except Cancel (pending) and choosing a family (Unverified, Brent). AC-6 3/4 (the 4th is a fixed test flaw, pending). AC-7 docs met; earlier suites pending one known-flake re-check
NEEDED: verify-only pass: gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=tests -f only_testing=ClipDeckUITests (after committing the test files). Deciding: SubtitleFontUITests/testMoreFontsOpensThePickerAndCancelReturnsToTheSheet, SubtitleFontTesterUITests/testCancellingThePickerLeavesTheSheetTopAndTheCachedRiseAlone, …/testOpeningThePickerBeforeTheSheetHasSettledCachesNoWrongRise, …/testPickingAPresetClearsThePickedFont, …/testGeorgiaCloseUps (attachments for legibility), plus the re-check of PlayerLandscapeBehaviourUITests/testOpenSubtitlesMenuKeepsControlsUpWhilePlaying
CHECKS_RUN: CI 44957727655: ipa job green (build-ipa.sh); simulator job test-ios.sh 345/347, 0 build issues; failures: the known flake above and the builder's Cancel label (test flaw)
UNVERIFIED: choosing a family in the picker and the line updating live; a user-installed font later removed (Brent, on the iPhone). Mutation check of the SheetFit guard not done (ci_only, conservative budget)
REVIEWED_AT: 59383f1b4fd4d5d58d87b8f37378815268fb93b3
```

### Round 1 addendum
_by loop-tester · 2026-11-21 19:43_

Verify-only run 44960788495 (803d088, test files only; scope=tests, only_testing=ClipDeckUITests): 49/50 passed. The ipa job was skipped for scope=tests; it was green on 59383f1, and this commit changes only test files.

| Deciding test | Result | Evidence |
|---|---|---|
| SubtitleFontUITests/testMoreFontsOpensThePickerAndCancelReturnsToTheSheet | Pass | With the `close` lookup, Cancel returns to the sheet, More fonts stays "None", Sans stays selected, and the opener reads "Default" |
| SubtitleFontTesterUITests/testCancellingThePickerLeavesTheSheetTopAndTheCachedRiseAlone | Pass | Sheet top: before 349.41, after Cancel 349.41, reopened 350.37, against video maxY 342 (a 7.4–8.4 pt gap; T-015's 349–350 band). tester-after-cancel-frames, tester-reopened-frames |
| SubtitleFontTesterUITests/testOpeningThePickerBeforeTheSheetHasSettledCachesNoWrongRise | Pass | The picker was opened right away; after Cancel 350.05, reopened 350.05. tester-early-picker-frames |
| SubtitleFontTesterUITests/testPickingAPresetClearsThePickedFont | Pass | From seeded Georgia, tapping Serif gives More fonts "None", not selected, and Serif selected, with the opener "Changed". Then Sans gives "Default" |
| SubtitleFontTesterUITests/testGeorgiaCloseUps | Pass | The close-ups are read below |
| Re-check: PlayerLandscapeBehaviourUITests/testOpenSubtitlesMenuKeepsControlsUpWhilePlaying | Pass | It was the known flake in 44957727655 |
| Other SubtitleFont UI tests (seeded Georgia, missing → Sans, Zapfino note) | Pass | Pass again |

Close-ups, for legibility:
- **The line "元気ですか", Bold on:** Hiragino Mincho W6, heavy strokes with the black outline. Very legible.
- **The line, Bold off:** Mincho W3, thinner but clean and legible.
- **Neither shows tofu,** and both are clearly Mincho, not Gothic.
- **The More fonts row:** "Aa" in Georgia (old-style lowercase a), bold and regular, with あア漢字 in Mincho that matches the Serif preset's Japanese.

One failure, pre-existing and not caused by this change: ExpiryBannerUITests/testOpenSideStoreWithoutSideStoreKeepsBannerAndExplains.
- **The failure:** "XCTAssertTrue failed", then "Failed to tap library.expiryBanner.openSideStore: No matches found".
- **What the app showed:** in every UI tree for this test (83F76F9B, 47083072, F123FC15) the app shows only the "Preparing sample episode…" activity indicator for the whole 94 s. This is the sample-episode-not-ready timing flake in CONTEXT Learned (the "Seeded show should appear" family), reached through a different assertion.
- **Why it isn't this change:** T-017 touches no Library, expiry or sample code. The same app code (59383f1, identical in 803d088) passed this test in 44957727655.

With that, every Done-when item is decided by run evidence. The open items:
- One unrelated flake to re-check.
- C1 (bold-only families) is Could fix and moves to T-016's notes or a later task, so it doesn't block.
- Choosing a family by hand and a user-installed font that is later removed are left for Brent on the iPhone.

```text
VERDICT: Blocked
SPEC: AC-1..AC-7 met (AC-4 "choose a family": Unverified, Brent's hand check by design)
NEEDED: re-run CI: ExpiryBannerUITests/testOpenSideStoreWithoutSideStoreKeepsBannerAndExplains (known sample-episode timing flake; passed on the same app code in 44957727655). E.g. gh workflow run ios-simulator.yml --ref loop/subtitle-style -f scope=tests -f only_testing=ClipDeckUITests/ExpiryBannerUITests. If it passes, the verdict is Pass
CHECKS_RUN: CI 44957727655 (ipa green; 345/347); CI 44960788495 (ClipDeckUITests 49/50; all deciding T-017 tests and the landscape flake re-check pass; 1 unrelated sample-episode flake)
UNVERIFIED: choosing a family in the picker with the line updating live; a user-installed font later removed (Brent, iPhone)
REVIEWED_AT: 803d0881efe966e0c2aad238d41bda62f5984786
```
