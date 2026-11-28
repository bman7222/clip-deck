# Clip Deck: design

Produced with the `frontend-design` skill, translated to native iOS.

## Subject, audience, primary job

- **Subject:** a pocket study player for anime and drama episodes.
- **Audience:** language learners who already mine with asbplayer and Yomitan on a computer.
- **Primary job:** get from "I want that line" to a saved card in two taps, while the video stays the star.

## Visual direction

The user asked for a feel like the Nintendo 3DS home menu: clear, friendly icons that pop, and rounded squares.

**The memorable element is the player's dual-screen layout.** In portrait the video is the "top screen". Below it, a raised "bottom screen" panel with rounded top corners holds:
- the scrubber and transport (play/pause, offset, subtitles, style);
- the big **Make a Card** button;
- the tap-to-seek subtitle list.

In landscape the video fills the whole screen with no navigation bar. The controls always start hidden, whether you rotate into landscape or open the player with the phone already in landscape. Tapping the video shows translucent controls over it (top bar: back and title; bottom bar: scrubber, transport, Make a Card). The bars lie over the video column and never widen it: with the panel wide, Make a Card goes icon only, and when even that doesn't fit the bottom bar becomes two rows (`⏯ ±0.0s Subs Aa` above an icon-only Make a Card on the trailing side). While playing they fade after 3 s; they stay up while paused, scrubbing, in a sheet, with the subtitles dialog or the subtitle style card (and its font picker) open, or with VoiceOver. The "Aa" button swaps the bottom bar for the style card, and the line moves above it. The subtitle line moves above the bottom bar while the controls show. A button in the top-right of the top bar (`sidebar.right`) opens the subtitle list as a side panel: the video shrinks to the left (about 70 % on a notched iPhone) and the panel takes the right: content width starts at 25 % of the usable width (never under 180 pt) plus the trailing safe-area inset as padding. A grip on the divider (`player.panelHandle`, 44 pt touch area) drags the panel between 180 pt and 50 % of the usable width, double-tap resets it to 25 %, a single tap shows or hides the controls like a tap on the video, and the width is remembered across launches. It holds the problem banner, a compact Make a Card (icon only if too narrow) and the cue list with compact rows (time above the text). The panel stays open when the controls fade, and its open state survives a rotation to portrait and back. The subtitles button in landscape opens a dialog ("Load different subtitles") instead of a menu, so its open state can be tracked and the auto-hide never closes it. Make a Card keeps the controls up while it records. Boldness also goes into the library's glossy rounded-square show tiles, one bright hue each. Everything else is quiet:
- a cool console-grey shell;
- white panels;
- no decorative gradients beyond the single top highlight on tiles.

Choices that avoid the generic defaults: no cream/serif look and no black/acid-green. Colour carries meaning:
- aqua = current/selected/primary action;
- sunflower = waiting to sync;
- red = recording or errors.

## Tokens

| Token | Light | Dark | Use |
|---|---|---|---|
| Shell | #EEF1F4 | #16191E | Screen background (console grey) |
| Panel | #FFFFFF | #23272E | Bottom screen, editor panels, rows |
| Ink | #1D2733 | #E9EDF2 | Primary text |
| InkSoft | #5B6673 | #9AA4B0 | Secondary text, timestamps |
| AccentColor (aqua) | #1A8BC4 | #3DB2E8 | Current line, primary buttons, links |
| Pending (sunflower) | #E0A400 | #F5C02E | Sync badge, "waiting" icons only |
| Danger | #C9302C | #FF6B6B | Recording chip, errors, Re-record |

The show tile hues are the same in both modes: coral, tangerine, leaf, aqua, grape and rose. They are assigned in creation order.

**Type roles:** SF Rounded throughout, scaled with Dynamic Type (`Font.system(_:design: .rounded, weight:)`):
- large title: heavy;
- titles and headlines: bold;
- body: regular;
- times: rounded with monospaced digits.

Subtitles default to the system font (Hiragino Sans for Japanese), bold, with a black outline on video. They scale with Dynamic Type through `UIFontMetrics`, times the chosen size (60% to 200%). The font, weight, size and place can be changed from the subtitle style menu (see "Subtitle style menu" below).

**Spacing scale:** 4 / 8 / 12 / 16 / 24.

**Corner radii by hierarchy:**
- tiles: 26 (scaled with tile size);
- panels: 22;
- controls: 14;
- chips and icon buttons: 10.

**Code:** `ios/ClipDeck/DesignSystem/` (`Theme.swift`, `Components.swift`) and `Resources/Assets.xcassets` colour sets.

## Components

- `DeckTile`: a rounded-square show icon with a big initial glyph, a top highlight and a hue-tinted shadow.
- `DeckPrimaryButtonStyle`: a filled aqua (or red) block button with a press-scale. Used for Make a Card, Sync, Play clip and Re-record.
- `DeckIconButtonStyle`: a 44×44 rounded-square control on a panel. Idle = Shell fill and Ink glyph; active = aqua fill and a white glyph; disabled = 0.45 opacity (the same value as `DeckPrimaryButtonStyle`). The press-scale is skipped under Reduce Motion.
- `PendingBadge`: a sunflower count capsule on the Sync button.
- `ErrorBanner`: a red-tinted inline message with an optional fix action.
- `ImportProgressView`: "Converting… n%" in bold rounded type with monospaced digits, an aqua bar and a red Cancel, plus "Keep Clip Deck open until it finishes." Shared by the upload sheet and Missing video.
- `Toast`: a dark capsule confirmation at the bottom ("Card saved. 3 cards waiting to sync.").
- `SelectableText`: outlined or plain selectable text for subtitles (Look Up).
- Empty states use `ContentUnavailableView` with a single action.

## Subtitle style menu

The player's controls row has a `textformat` ("Aa") button, `player.subtitleStyle`, right after the subtitles button. It is a Button (not a Menu) that presents a sheet, idle until the style changes from the default, then aqua like the timing offset button. Landscape shows the same button in the bottom bar, next to the subtitles button in all three `ViewThatFits` rows; it opens the card described below instead of the sheet.

The portrait sheet (`SubtitleStyleSheet`, `presentationBackground(Theme.panel)`) has a first detent sized from the room under the portrait video (window height minus the video's bottom, an 8 pt gap and the system's sheet rise, so it never covers the video; the content scrolls when the room is small, never below 120 pt) plus `.large`. The rise is the OS's, not the app's (about 20 pt for iOS 26's floating sheet; edge-to-edge sheets differ), so the sheet measures its own top once it has settled at the first detent, corrects the detent once (both the detent set and the selection), and keeps the measured rise in `player.styleSheetRise` so later opens are right from the start (landscape: `.large` only), and the navigation back button is hidden while it is open, no background dimming at the first detent so the line can be judged while it changes, and scrolling content under a pinned header (title and Done). Top to bottom:
- Font: one row per preset (Sans, Rounded, Serif), the name and the sample "Aa あア漢字" drawn in that font and in the current weight, so both scripts can be judged. The selected row is aqua with white text, the others Shell with Ink. Under them the "More fonts…" row (`ellipsis.circle`, `subtitleStyle.font.more`) opens the iPhone's own font picker (families only) as a sheet. A picked font takes the place of the preset: the row turns aqua, shows the font's name and the same sample drawn exactly as the line draws it, and "This font has no bold weight." shows under it when the family has no real bold (no faux bold is ever drawn). A face counts as bold by its weight trait (0.3 or more) when it reports a non-zero weight, or by the bold symbolic trait; when the weight is missing or exactly 0.0 (Arial Rounded MT Bold reports 0.0), its name ("Bold", "Heavy", "Black") decides. So a light face (negative weight) named "...Black" is not bold. Japanese always falls back to the Hiragino face closest to the picked font (Sans, Rounded or Mincho; W6 with Bold, Maru Gothic one weight), so there are no boxes. A saved font that is no longer installed quietly becomes Sans. VoiceOver: "More fonts", value the picked name or "None".
- Bold: a toggle icon control.
- Size: smaller, the value ("130%", InkSoft) and larger.
- A full-width Reset (`subtitleStyle.reset`, "Reset to default"): restores font, bold and size only and leaves the position alone. Disabled, with value "Default", while the font group is at its default; otherwise the value is "Changed". The position lives in the Move-Text menu.

A family whose only face is bold (for example Arial Rounded MT Bold) is drawn bold whatever the Bold control says, so "This font is always bold." shows under the More fonts row (`subtitleStyle.font.alwaysBold`) and the Bold control's spoken value says the same; a family with no bold at all keeps "This font has no bold weight."

Every icon is different: `textformat` (opener), `bold`, `textformat.size.smaller`, `textformat.size.larger`, `arrow.counterclockwise` (Reset) and `checkmark` (Done). Colours come only from the Theme tokens: idle Shell and Ink, on or selected Accent with white, values and captions InkSoft. A control at its limit is disabled.

**Landscape card** (`SubtitleStyleCard`, `subtitleStyle.card`). Tapping the "Aa" button in the bottom bar swaps the bottom bar for a card docked to the bottom of the video column; the top bar stays. It has the bars' look (`Color.black.opacity(0.55)`, `.dark` colour scheme, the same safe-area and panel-handle insets), so it never leaves the video column or the safe area. It holds the Font sheet's controls (no arrows) with the same identifiers, icon only, built from the same `StyleIconButton` as the sheet: the three preset chips, each showing "Aあ" in its own font and the current weight (`subtitleStyle.font.sans|rounded|serif`), More fonts (`ellipsis.circle`, `subtitleStyle.font.more`, aqua while a font is picked, VoiceOver value the picked font's name or "None"), Bold, size smaller and larger, Reset (`arrow.counterclockwise`; font group only, like the sheet's) and Done (`checkmark`). `ViewThatFits` lays them out as one row of 9, otherwise rows of 5 (Sans, Rounded, Serif, More, Bold) and 4 (size smaller, larger, Reset, Done), so with the panel at 50 % on an iPhone 17 Pro every control is still reachable. The line is pushed above the card through the same placement as for the bars, with the card's measured height (plus `Spacing.s`) as the bottom obstruction, so the line shows at its saved place, lifted above the card while it is open, and goes back to its real styled place when the card closes. More fonts opens the system font picker over the card; cancelling or choosing returns to the open card. The card and the picker both keep the controls up. Done, a tap on the video (which only closes the card and doesn't also hide the controls) and a rotation close it, and closing restarts the 3 s hide countdown.

## Move-Text menu and outline

A button right after Aa, in portrait and in every landscape bar row: an "A" with four small outward arrows (`MoveTextGlyph`, drawn in SwiftUI), `player.moveText`, label "Move subtitles", value the place in words (`positionText`), `DeckIconButtonStyle` (aqua when the place isn't the default). Like Aa it is a Button with a presented state, never a Menu. It moves only the place; the Font menu (Aa) has no arrows and its Reset leaves the place alone. The Aa button is aqua only while the font group is changed, so a moved line lights this button, not Aa. One menu at a time: the button does nothing while the Aa menu is open.

- **Portrait sheet** (`MoveTextSheet`, `moveText.sheet`): a short sheet whose first detent is fitted under the video with `SheetFit` and the cached rise, like the Aa sheet (no dimming, so the video and the line stay visible), plus `.large`. Title "Move subtitles", Done (`moveText.done`), the four arrows `moveText.left|up|down|right` (each 5 % of the region per tap, dimmed at the limit, spoken values as in the Aa menu), the value line `moveText.value` ("Up 20% · Left 10%" or "Default place") and Reset (`moveText.reset`, `arrow.counterclockwise`), which restores the position only and is disabled at the default place.
- **Landscape card** (`MoveTextCard`, `moveText.card`): the same controls in one compact row (arrows, value text, Reset, Done), in the bars' look, in place of the top bar, with the bottom bar hidden. The value text is the first thing to drop out when the row doesn't fit. The line is kept under the card (card height plus `Spacing.s` as the top obstruction, no bottom obstruction, `up` counted from the video's bottom). Up dims with the value "Highest" when one more step wouldn't visibly move the line; the first Down from above the highest reachable place lands one step below it.
- **Pausing and the overlay:** opening the menu pauses a playing video. Done, a swipe down of the sheet, or a tap on the video closes it, and playback resumes only if opening the menu paused it; a rotation closes it without resuming. The centred overlay is hidden while the menu is open (both orientations), so its avoidance never moves the line while you position it, and returns on close by its normal rules (it stays while paused, hides 3 s after playback resumes). The controls stay up while the card is open.
- **Outline** (`moveText.outline`): while the menu is open, a 2 pt `Theme.accent` rounded rectangle, 6 pt outside the line's own frame. With no line on screen, a one-line sample "あいう Abc" in the current font and size at 50 % opacity (`moveText.sample`) takes its place and the outline frames that. It goes when the menu closes.

## Playback overlay

Both orientations show a centred overlay on the video, like a normal video player: back 5 s (`gobackward.5`, `player.overlay.back5`), play/pause (`player.overlay.playPause`) and forward 5 s (`goforward.5`, `player.overlay.forward5`). Each glyph is white on a translucent black circle (50 % black) so it stays readable on bright scenes: 52 pt for the centre, 44 pt for the skips. The centres sit at 25 %, 50 % and 75 % of the **video container's** width, vertically centred. The container is the 16:9 video in portrait and the video column in landscape, so the overlay re-centres when the side panel opens or is resized. The play/pause value reads "Playing" or "Paused".

- **Landscape:** it shows and hides with the controls (a tap on the video, 3 s auto-hide while playing, always up while paused or with a sheet or dialog open; see "Style menus" below).
- **Portrait:** it has its own state. It starts hidden; a tap on the video shows or hides it (a tap no longer plays or pauses), and a real pause (playing to paused) shows it. It auto-hides 3 s after playing starts and stays while paused.
- **Style menus (one rule, both orientations):** the overlay hides for everyone while the subtitle style menu is open, VoiceOver included: the landscape card (Aa) or the portrait style sheet. It comes back when the menu closes (Done), so the menu never cuts through it and the line shows at its true saved place while the user steps it (the Move-Text menu follows the same rule). A tap on the video closes the portrait sheet, as Done does, and leaves the overlay as it was (landscape already did this with the card).
- **Both:** a 0.2 s fade (opacity only, so Reduce Motion needs nothing else); always shown under VoiceOver, except while a style menu is open; hidden after a rotation; a skip tap restarts the 3 s countdown; a tap on an overlay button does not also toggle the overlay. Z-order: video, subtitle line, overlay, recording badge; the landscape bars lie above it.
- **The subtitle line steps aside:** while the overlay shows, `SubtitlePlacement.frame(avoid:)` gets a band computed from the layout rule above (not from measured views): from back 5's left edge to forward 5's right edge, 52 pt tall and centred, plus 8 pt on every side. A line whose placed frame meets the band moves just above it (bottom = band top) or just below it (top = band bottom), whichever is the smaller move and still fits the active region (between the top and bottom bars); if neither fits it goes below, kept inside the region by the usual clamps; a line that doesn't meet the band stays put. It moves with the same 0.2 s ease, and goes back when the overlay hides. The band is a display-only input: `player.subtitleStyle` is never written.

**Bar play/pause colour rule:** the bar's `player.playPause` is plain (Shell fill, Ink glyph) while playing and aqua while paused (`DeckIconButtonStyle(isActive: !isPlaying)`). Its accessibility value is "Playing" or "Paused"; its label stays "Play" or "Pause". The ±5 s skips are not in any bar.

**Bar order** (later buttons are inserted at the marked places): portrait `⏯ ±0.0s Subs Aa ✥A` then Make a Card on its own row; landscape `⏯ ±0.0s Subs Aa ✥A … Make a Card` with three `ViewThatFits` variants (full label, icon-only Make a Card, two rows).

## Screens

```
Library                         Player (portrait)               Card editor
┌──────────────────────────┐    ┌──────────────────────────┐    ┌──────────────────────────┐
│ ⚙   Clip Deck    ⟳③  +   │    │ ‹  Episode 3             │    │ Discard  Make a Card Save│
│ [ Shows | Subtitles ]    │    │┌────────────────────────┐│    │ ┌──────────────────────┐ │
│                          │    ││        video           ││    │ │     screenshot       │ │
│ ▢▢▢   ▢▢▢   ▢▢▢          │    ││   待って、行かないで    ││    │ └──────────────────────┘ │
│ ▢A▢   ▢F▢   ▢K▢          │    │└────────────────────────┘│    │ ▶ Play clip   1:45.0–1:53│
│ Attack Frieren K-On      │    │╭────── bottom screen ───╮│    │ Start −.5 −.1 +.1 +.5    │
│ 3 eps  1 ep   2 eps      │    ││ 1:47 ━━━━●───── 23:40  ││    │ End   −.5 −.1 +.1 +.5    │
└──────────────────────────┘    ││ ▶  +0.3s  💬  Aa         ││    │ ← previous   next →      │
                                ││ [ Make a Card        ] ││    │ Sentence ______________  │
Show                            ││ 1:40 前の行             ││    │ Word ____  Definition __ │
┌──────────────────────────┐    ││▐1:45 待って、行かないで▌││    └──────────────────────────┘
│ ▢A▢ Attack on Titan      │    ││ 1:53 お願い              ││
│ ▢1▢ Episode 1  ep1.ass 💬│    │╰────────────────────────╯│
│ ▢3▢ Episode 3  No subs 💬│    └──────────────────────────┘
└──────────────────────────┘
```

| Screen | Purpose | Loading | Empty | Error |
|---|---|---|---|---|
| Library | Pick a show; Sync; Upload | — | "Your library is empty" + Upload episode | — |
| Subtitles tab | Browse Subtitles/Show/Episode folders, preview lines | — | "No subtitle files here" | Parse errors shown on preview |
| Show | Episodes; subtitle icon per row; swipe to delete | — | — | Row says "Video file missing" in red |
| Upload sheet | Show, name, video (MP4, MOV, M4V or MKV), optional subtitles. For an MKV with two or more audio tracks, an Audio picker (`upload.audioTrack`, "jpn · Original · AAC", the file's default preselected). For an MKV with text subtitle tracks, an Embedded subtitles picker (`upload.embeddedSubtitle`: "None" plus each text track as "language · title · format", the default-flagged or first text track preselected). Picture tracks are listed below it greyed out as "image-based, can't be used", and text formats Clip Deck can't write (for example mov_text) as "format not supported"; neither can be chosen; with no text tracks the row is hidden. A subtitle file chosen below wins, and the footer says the embedded tracks are still saved) | After picking: a status row (`upload.preparing`) with "Downloading from iCloud…" or "Reading the video…". After Add episode: a progress section at the top, "Converting… n%" with a bar for an MKV or "Adding…" for a copy (`upload.progress`), and Cancel (`upload.cancelConvert`); the fields lock, the screen stays on, and the toolbar shows a spinner | — | Inline banner under the video (`upload.videoError`: unsupported type, unsupported video or audio track, not enough space, unreadable file; Add episode stays disabled) and at the bottom (`upload.error`: import failed, background time ran out). Cancel shows nothing and keeps the sheet. Import notes (e.g. damaged audio skipped) show in an "Episode added" alert before the sheet closes |
| Player | Watch, offset, switch subtitles, subtitle style (sheet), list, Make a Card | Spinner until the player is ready | "No subtitle lines" in the list | Banner: no subtitles, missing subtitle file (with expected location), parse error |
| Missing video | Explains which file and where; Choose the video again (MP4, MOV, M4V or MKV; an MKV uses its default audio track) | The same status row (`missing.preparing`) and progress panel with Cancel (`missing.progress`, `missing.cancelConvert`) as the upload sheet, below the button; back is hidden while it runs | — | Banner (`missing.videoError`, `missing.error`), with Try again when the file is still open |
| Card editor | Replay, range, re-record, fields, save | "Recording…" | — | Banner (export failed) |
| Sync sheet | Waiting count, Sync, per-card status | "Syncing 2 of 5…" | "Everything is in Anki." | Setup problem banner; summary in red; per-card error |
| Anki settings | Address, test, deck/note type, field map, padding, setup steps | Spinner on Test connection | Free-text fields until connected | Error text under Test connection |
| About and licences | Settings › About and licences: versions, Clip Deck licence, FFmpeg notice with source links, full LGPL-2.1 text, other components. One scrolling list; monospaced footnote text that follows Dynamic Type | — | "Licence text missing: <name>" in place of a file that is not bundled | — |

## Interaction and motion

Motion is used only where something changes:
- **Make a Card:** a red "recording" chip shows the clip range over the video while the segment plays.
- **Subtitle list:** auto-scrolls to keep the current line centred.
- **Offset value:** animates with `.numericText()`.
- **Buttons:** press-scale.
- **Playback overlay:** a 0.2 s opacity fade in and out (no movement, so it is the same under Reduce Motion).
- **Toasts:** slide up.
- **Subtitle style card (landscape):** rises from the bottom of the video column while fading in, and leaves the same way (0.25 s ease); under Reduce Motion it only fades.
- **Subtitle style sheet:** rises with the system sheet animation, which follows Reduce Motion. The size value animates with `.numericText()` and the selection colour fades in 0.15 s, both skipped under Reduce Motion.
- **Landscape side panel:** slides in from the trailing edge with the standard spring; content 25 % of the usable width by default (minimum 180 pt, maximum 50 %), plus the trailing inset; resizable with the divider grip, remembered as a fraction.

Saving a card plays a success haptic. There are no ambient or entrance animations. SwiftUI's springs respect Reduce Motion.

## Accessibility

- Text contrast in both modes:
  - Ink on Shell/Panel is above 12:1;
  - InkSoft is about 5.8:1 on Panel (light).
- Aqua buttons carry white text; the light value #1A8BC4 was chosen to reach AA for bold large text.
- Icon-only buttons have spoken labels; the Sync button reads "Sync to Anki, 3 waiting".
- Hit targets are at least 44 pt.
- The subtitle style menu: every control has a spoken label and value ("Larger text, 130 percent", "Move subtitles up, 20 percent up", "Bold, On"); the selected font reads as selected; a control at its limit is dimmed and VoiceOver says so; the sheet scrolls, and at an accessibility text size the font rows stack their name over the sample, so Reset can always be reached.
- Type is Dynamic Type throughout, including subtitles.

Still to check on the simulator or device: AX3 text size on the player's bottom screen, and dark-mode screenshots (see the handoff notes in CLAUDE.md).
