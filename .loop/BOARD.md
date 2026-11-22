# Board: clip-deck
Goal: player controls, Move-Text, offline dictionary, clip timeline · Branch: loop/player-lookup-timeline · Updated: 2026-11-22

| ID | Title | Lane | Depends on | Status | Round | Result |
|----|-------|------|------------|--------|-------|--------|
| T-019 | New app icon #21 | frontend | — | done | 1 | aa89224 |
| T-020 | Split the simulator job #22 | backend | — | todo | | |
| T-021 | Centred playback overlay, plain bottom pause button, new bar layout #23 | frontend | — | todo | | |
| T-022 | Subtitles avoid the overlay #24 | frontend | T-021 | todo | | |
| T-023 | Continuous position plus separate resets #25 | backend | T-022 | todo | | |
| T-024a | Move-Text button and menu with the blue outline #26 | frontend | T-021, T-023 | todo | | |
| T-024b | Font menu without arrows, with its own Reset #27 | frontend | T-024a | todo | | |
| T-025 | Drag the outline #28 | frontend | T-024a | todo | | |
| T-032 | Timeline maths #29 | backend | — | todo | | |
| T-033 | Timeline view in Make a Card #30 | frontend | T-032 | todo | | |
| T-026 | Dictionary store and Yomitan importer #31 | backend | — | todo | | |
| T-027 | Deinflection and lookup engine #32 | backend | T-026 | todo | | |
| T-028 | Dictionary manager #33 | frontend | T-026 | todo | | |
| T-029a | Dictionary popup: formatted entries #34 | frontend | T-027, T-028 | todo | | |
| T-029b | Dictionary popup: move, resize and reset #35 | frontend | T-021, T-029a | todo | | |
| T-030a | Lookup Mode in the player: tap or hold a word #36 | frontend | T-021, T-029b | todo | | |
| T-030b | Lookup Mode in the player: Use for a card #37 | frontend | T-030a | todo | | |
| T-031 | Lookup in Make a Card #38 | frontend | T-030b | todo | | |

## History (earlier goals)

Goal: subtitle style controls (font, bold, offset, size, reset) · Branch: loop/subtitle-style · Updated: 2026-11-22

| ID | Title | Lane | Depends on | Status | Round | Result |
|----|-------|------|------------|--------|-------|--------|
| T-014 | Draw the on-video subtitle line in a saved style that always stays inside the video #15 | frontend | — | done | 1 | 93d3c08 |
| T-015 | Adjust the subtitle style from a menu in the portrait player #16 | frontend | T-014 | done | 3 | fab9468 |
| T-017 | Pick any installed font for subtitles, with Japanese that always renders cleanly #18 | frontend | T-015 | done | 1 | 31bc513 |
| T-016 | Adjust the subtitle style in landscape from a card in the bottom bar #17 | frontend | T-015, T-017 | done | 2 | c713b66 |
| T-018 | Stop Up when the line can't go higher, and trust a font's weight over its name #19 | frontend | T-016 | done | 2 | df44e8b |

Goal: MKV import, full-screen landscape player with resizable subtitle panel, SideStore refresh without a computer · Branch: loop/mkv-landscape-sideload · Updated: 2026-11-20

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
