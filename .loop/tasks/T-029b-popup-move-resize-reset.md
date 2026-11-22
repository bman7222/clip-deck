---
id: T-029b
title: "Dictionary popup: move, resize and reset"
lane: frontend
depends_on: [T-021, T-029a]
status: todo
round: 0
base_sha:
issue: 35
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Move and resize the dictionary popup, and put it back with one tap

### What are we building?
The popup from T-029a has a fixed place and size. After this task you can move it by its drag handle and resize it from any edge. It never leaves its area (the video in landscape, the screen in portrait), it remembers its place and size for each orientation, and a ↺📄 button in the bar puts it back to the default.

### Why?
You can keep the popup out of the way of the subtitle and the picture.

### Done when
- AC-1 A drag-handle button `lookup.popup.move` sits at the popup's top left, and dragging it moves the popup live.
- AC-2 Pressing and dragging the left, right, top or bottom border (a 16 pt hit zone) resizes the popup from that side. The minimum is the default size (300×200 pt in landscape; the full width minus 32 by 260 pt in portrait). The maximum is the whole allowed area.
- AC-3 Bounds: in landscape the popup stays inside the video column, and it's re-clamped when the panel opens or is resized. In portrait it stays inside the screen's safe area. It never goes off-screen, and a maximum-size popup dragged into a corner stays clamped in the corner. A pure `PopupGeometry` (move, resize by edge, clamp) is unit-tested.
- AC-4 The place and size are remembered per orientation: UserDefaults JSON (for example `lookup.popupFrame.portrait` and `lookup.popupFrame.landscape`), kept across launches and re-clamped when read. `-uiTesting` launches clear them unless `-uiTestingKeepLookupPopup` is passed.
- AC-5 The ↺📄 button `player.lookupReset` (a reset arrow with a document, in `DeckIconButtonStyle`) sits in the bar spot after ✥A, in the portrait row and in every landscape variant. It shows only while a popup is open, and restores the default size and place for the current orientation: T-029a's out-of-the-way default (Q1, Brent 2026-11-22). In portrait that's full width with 16 pt margins over the subtitle list, just above the bottom safe area; in landscape, the top-trailing corner of the video, 16 pt in.
- AC-6 Tests:
  - unit: moves clamped at each edge and corner, a resize from each edge, the minimum and maximum, a maximum-size popup staying put, and a re-clamp into a smaller area;
  - UI, in both orientations, opened with `-uiTestingLookup 元気`: dragging the handle moves the popup by the drag (±3 pt); dragging far off-screen leaves it inside the bounds; resizing from the right edge widens it, and it can't shrink below the minimum; the place survives a relaunch with the keep flag; ↺📄 shows only while the popup is open and restores the default frame; each orientation keeps its own frame across a rotation.
  DESIGN.md is updated.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check the `PopupGeometry` unit tests and the popup UI tests, with their frame attachments.
- Unverified for Brent: how dragging and resizing feel on his iPhone.

### Agent notes
- Depends on: T-021 (the bar marker for ↺📄) and T-029a (the popup). Source: spec T-029, "Popup chrome", "Bounds" and the ↺📄 bullet; section G "Popup: …".
- Gesture pattern: the panel handle at PlayerView.swift:364-390 (a GestureState plus a latch, in `.global` coordinates).
- The bars draw above the popup, so the edge hit zones mustn't take taps meant for bar buttons.
- Learned: in landscape, use element screenshots and `app.debugDescription`. Known flakes are in CONTEXT.

### Out of scope
- The popup's content (T-029a), and lookups (T-030a).
