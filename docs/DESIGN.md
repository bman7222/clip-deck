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

In landscape the video fills the whole screen with no navigation bar. Tapping the video shows translucent controls over it (top bar: back and title; bottom bar: scrubber, transport, Make a Card). While playing they fade after 3 s; they stay up while paused, scrubbing, in a sheet, with the subtitles dialog open, or with VoiceOver. The subtitle line moves above the bottom bar while the controls show. A button in the top-right of the top bar (`sidebar.right`) opens the subtitle list as a side panel: the video shrinks to the left (about 70 % on a notched iPhone) and the panel takes the right: content width is 25 % of the usable width (never under 180 pt) plus the trailing safe-area inset as padding. It holds the problem banner, a compact Make a Card (icon only if too narrow) and the cue list with compact rows (time above the text). The panel stays open when the controls fade, and its open state survives a rotation to portrait and back. The subtitles button in landscape opens a dialog ("Load different subtitles") instead of a menu, so its open state can be tracked and the auto-hide never closes it. Make a Card keeps the controls up while it records. Boldness also goes into the library's glossy rounded-square show tiles, one bright hue each. Everything else is quiet:
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

Subtitles use the system font (Hiragino Sans for Japanese), bold, with a black outline on video. They scale with Dynamic Type through `UIFontMetrics`.

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
- `DeckIconButtonStyle`: a 44×44 rounded-square control on a panel. Active = aqua fill.
- `PendingBadge`: a sunflower count capsule on the Sync button.
- `ErrorBanner`: a red-tinted inline message with an optional fix action.
- `Toast`: a dark capsule confirmation at the bottom ("Card saved. 3 cards waiting to sync.").
- `SelectableText`: outlined or plain selectable text for subtitles (Look Up).
- Empty states use `ContentUnavailableView` with a single action.

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
| Upload sheet | Show, name, video, optional subtitles | Spinner replaces Add episode | — | Inline banner (unsupported type, copy failed) |
| Player | Watch, offset, switch subtitles, list, Make a Card | Spinner until the player is ready | "No subtitle lines" in the list | Banner: no subtitles, missing subtitle file (with expected location), parse error |
| Missing video | Explains which file and where; Choose the video again | — | — | — |
| Card editor | Replay, range, re-record, fields, save | "Recording…" | — | Banner (export failed) |
| Sync sheet | Waiting count, Sync, per-card status | "Syncing 2 of 5…" | "Everything is in Anki." | Setup problem banner; summary in red; per-card error |
| Anki settings | Address, test, deck/note type, field map, padding, setup steps | Spinner on Test connection | Free-text fields until connected | Error text under Test connection |

## Interaction and motion

Motion is used only where something changes:
- **Make a Card:** a red "recording" chip shows the clip range over the video while the segment plays.
- **Subtitle list:** auto-scrolls to keep the current line centred.
- **Offset value:** animates with `.numericText()`.
- **Buttons:** press-scale.
- **Toasts:** slide up.
- **Landscape side panel:** slides in from the trailing edge with the standard spring; content 25 % of the usable width (minimum 180 pt), plus the trailing inset.

Saving a card plays a success haptic. There are no ambient or entrance animations. SwiftUI's springs respect Reduce Motion.

## Accessibility

- Text contrast in both modes:
  - Ink on Shell/Panel is above 12:1;
  - InkSoft is about 5.8:1 on Panel (light).
- Aqua buttons carry white text; the light value #1A8BC4 was chosen to reach AA for bold large text.
- Icon-only buttons have spoken labels; the Sync button reads "Sync to Anki, 3 waiting".
- Hit targets are at least 44 pt.
- Type is Dynamic Type throughout, including subtitles.

Still to check on the simulator or device: AX3 text size on the player's bottom screen, and dark-mode screenshots (see the handoff notes in CLAUDE.md).
