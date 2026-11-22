# Board: clip-deck
Goal: subtitle style controls (font, bold, offset, size, reset) · Branch: loop/subtitle-style · Updated: 2026-11-20

| ID | Title | Lane | Depends on | Status | Round | Result |
|----|-------|------|------------|--------|-------|--------|
| T-001 | Watch in landscape full screen, with controls that appear on tap #1 | frontend | — | done | 4 | ab238b4 |
| T-002 | Pop the subtitle list out on the right in landscape #2 | frontend | T-001 | done | 2 | dbe6201 |
| T-011 | Drag the divider to resize the landscape subtitle panel #11 | frontend | T-002 | done | 4 | 3f38205 |
| T-012 | Add the FFmpeg libraries, the test MKVs and the licence notices #12 | fullstack | — | done | 2 | 1489506 |
| T-004 | Convert an MKV file into a playable MP4 inside the app #4 | backend | T-012 | done | 2 | a2483ee |
| T-006 | Add an MKV episode from the upload sheet #6 | fullstack | T-004 | done | 1 | 428e97c |
| T-005 | Optional: use the subtitles built into an MKV #5 | fullstack | T-006 | done | 2 | ee09056 |
| T-013 | Tidy up the loose ends from the loop's reviews #13 | backend | T-005 | done | 2 | ad12371 |
| T-003 | Write the SideStore guide so Clip Deck refreshes itself without a computer #3 | backend | — | done | 3 | 9a66a4a |
| T-009 | Publish each Clip Deck build as a GitHub Release #9 | backend | — | done | 1 | e6138e1 |
| T-010 | Let SideStore find and install Clip Deck updates on its own #10 | backend | T-009, T-012 | done | 1 | 46fa8aa |
| T-008 | Remind me once a day to refresh in SideStore before the app expires #8 | fullstack | — | done | 2 | 0adca02 |
| T-007 | Upload a build to TestFlight from GitHub Actions #7 | backend | T-003 | blocked | | Needs a paid Apple Developer account; Brent is staying on the free account for now |
| T-014 | Draw the on-video subtitle line in a saved style that always stays inside the video #15 | frontend | — | done | 1 | 93d3c08 |
| T-015 | Adjust the subtitle style from a menu in the portrait player #16 | frontend | T-014 | done | 3 | fab9468 |
| T-017 | Pick any installed font for subtitles, with Japanese that always renders cleanly #18 | frontend | T-015 | done | 1 | 31bc513 |
| T-016 | Adjust the subtitle style in landscape from a card in the bottom bar #17 | frontend | T-015, T-017 | done | 2 | c713b66 |
| T-018 | Stop Up when the line can't go higher, and trust a font's weight over its name #19 | frontend | T-016 | todo | | |
