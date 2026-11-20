# Board: clip-deck
Goal: MKV import, full-screen landscape player with resizable subtitle panel, SideStore refresh without a computer · Branch: loop/mkv-landscape-sideload · Updated: 2026-11-19

| ID | Title | Lane | Depends on | Status | Round | Result |
|----|-------|------|------------|--------|-------|--------|
| T-001 | Watch in landscape full screen, with controls that appear on tap #1 | frontend | — | testing | 1 | |
| T-002 | Pop the subtitle list out on the right in landscape #2 | frontend | T-001 | todo | | |
| T-011 | Drag the divider to resize the landscape subtitle panel #11 | frontend | T-002 | todo | | |
| T-004 | Convert an MKV file into a playable MP4 inside the app #4 | backend | — | todo | | |
| T-006 | Add an MKV episode from the upload sheet #6 | fullstack | T-004 | todo | | |
| T-005 | Optional: use the subtitles built into an MKV #5 | fullstack | T-006 | todo | | |
| T-003 | Write the SideStore guide so Clip Deck refreshes itself without a computer #3 | backend | — | todo | | |
| T-009 | Publish each Clip Deck build as a GitHub Release #9 | backend | — | todo | | |
| T-010 | Let SideStore find and install Clip Deck updates on its own #10 | backend | T-009 | todo | | |
| T-008 | Remind me once a day to refresh in SideStore before the app expires #8 | fullstack | — | todo | | |
| T-007 | Upload a build to TestFlight from GitHub Actions #7 | backend | T-003 | blocked | | Needs a paid Apple Developer account; Brent is staying on the free account for now |
