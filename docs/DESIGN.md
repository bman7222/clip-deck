# Clip Deck: design

Produced with the `frontend-design` skill, translated to native iOS.

## Subject, audience, primary job

- **Subject:** a pocket study player for anime and drama episodes.
- **Audience:** language learners who already mine with asbplayer and Yomitan on a computer.
- **Primary job:** get from "I want that line" to a saved card in two taps, while the video stays the star.

## Visual direction

The user asked for a feel like the Nintendo 3DS home menu: clear, friendly icons that pop, and rounded squares.

**The memorable element is the player's dual-screen layout.** In portrait the video is the "top screen". Below it, a raised "bottom screen" panel with rounded top corners holds:
- the scrubber and transport;
- the big **Make a Card** button;
- the tap-to-seek subtitle list.

In landscape the video fills the whole screen with no navigation bar. The controls always start hidden, whether you rotate into landscape or open the player with the phone already in landscape. Tapping the video shows translucent controls over it (top bar: back and title; bottom bar: scrubber, transport, Make a Card). The bars lie over the video column and never widen it: with the panel wide, Make a Card goes icon only, and near the 50 % maximum the bottom row also drops the ±5 s skips. While playing they fade after 3 s; they stay up while paused, scrubbing, in a sheet, with the subtitles dialog open, or with VoiceOver. The subtitle line moves above the bottom bar while the controls show. A button in the top-right of the top bar (`sidebar.right`) opens the subtitle list as a side panel: the video shrinks to the left (about 70 % on a notched iPhone) and the panel takes the right: content width starts at 25 % of the usable width (never under 180 pt) plus the trailing safe-area inset as padding. A grip on the divider (`player.panelHandle`, 44 pt touch area) drags the panel between 180 pt and 50 % of the usable width, double-tap resets it to 25 %, a single tap shows or hides the controls like a tap on the video, and the width is remembered across launches. It holds the problem banner, a compact Make a Card (icon only if too narrow) and the cue list with compact rows (time above the text). The panel stays open when the controls fade, and its open state survives a rotation to portrait and back. The subtitles button in landscape opens a dialog ("Load different subtitles") instead of a menu, so its open state can be tracked and the auto-hide never closes it. Make a Card keeps the controls up while it records. Boldness also goes into the library's glossy rounded-square show tiles, one bright hue each. Everything else is quiet:
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

The player's controls row has a `textformat` ("Aa") button, `player.subtitleStyle`, right after the subtitles button. It is a Button (not a Menu) that presents a sheet, idle until the style changes from the default, then aqua like the timing offset button. Landscape shows the same button in the bottom bar; its card comes in a later task, so for now it opens the same sheet.

The portrait sheet (`SubtitleStyleSheet`, `presentationBackground(Theme.panel)`) has a fixed-height detent (520 pt, so it starts below the video on an iPhone 17 Pro) plus `.large`, no background dimming at the first detent so the line can be judged while it changes, and scrolling content under a pinned header (title and Done). Top to bottom:
- Font: one row per preset (Sans, Rounded, Serif), the name and the sample "Aa あア漢字" drawn in that font and in the current weight, so both scripts can be judged. The selected row is aqua with white text, the others Shell with Ink. The "More fonts…" row goes under the presets later.
- Bold: a toggle icon control.
- Size: smaller, the value ("130%", InkSoft) and larger.
- Position: left, up, down, right, and a value line ("Up 20% · Left 10%" or "Default place").
- A full-width "Reset to default", disabled while the style is the default.

Every icon is different: `textformat` (opener), `bold`, `textformat.size.smaller`, `textformat.size.larger`, `arrow.left`, `arrow.up`, `arrow.down`, `arrow.right`, `arrow.counterclockwise` (Reset) and `checkmark` (Done). Arrows rather than chevrons, because `chevron.left` is Back. Colours come only from the Theme tokens: idle Shell and Ink, on or selected Accent with white, values and captions InkSoft. A control at its limit is disabled.

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
└──────────────────────────┘    ││ ⟲5 ▶ 5⟳  +0.3s  💬     ││    │ ← previous   next →      │
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
- **Toasts:** slide up.
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
