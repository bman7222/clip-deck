---
id: T-033
title: Timeline view in Make a Card
lane: frontend
depends_on: [T-032]
status: todo
round: 0
base_sha:
issue: 30
spec: .loop/specs/player-lookup-timeline.md
model:
---

## Drag the clip's start and end on a timeline in Make a Card

### What are we building?
Make a Card only has ±0.1/±0.5 s nudge buttons for the clip range. After this task a timeline sits above them. A thin strip shows the whole episode with the clip marked. Below it, a zoomed track has blue notches at line edges and two round handles you drag to set the start and end, snapping to line edges when Snap is on. Handles and nudges stay in sync, and a changed range still needs a re-record, as today.

### Why?
Picking a clip by eye is faster and more accurate than counting nudges.

### Done when
- AC-1 `card.timeline` sits above the nudge rows and has two parts:
  - an overview strip covering the whole episode, 8 pt tall, with an aqua block for the clip;
  - a zoomed track: a rounded track in the normal theme with solid `Theme.accent` 2×10 pt notches, a 25 % accent fill between the handles, and two 28 pt white handles with a 3 pt accent border and 44 pt hit areas (`card.timeline.start`, `card.timeline.end`).
  Labels show the window's start and end (m:ss.t).
- AC-2 Dragging a handle moves it live, using T-032's clamps and handle choice. While dragging, a bubble shows the time (m:ss.t), and it flips inward at the track's edges. The window re-centres with a 0.2 s animation (plain under Reduce Motion) when a drag ends at an edge, or when the range leaves the window, for example after nudges.
- AC-3 The Snap chip `card.timeline.snap` is an on/off switch that starts on and is remembered across launches (cleared on `-uiTesting` launches unless a keep flag is passed). When on, handles snap to notches (T-032). With no cues there are no notches, and the chip is disabled.
- AC-4 One source of truth: the handles and the nudge rows both write the editor's `range`. After a drag, `needsRerecord` behaves exactly as after a nudge: Save is disabled and the red Re-record button appears. Re-record updates the media and the sentence as today, and the `card.range` text always matches the handles.
- AC-5 VoiceOver: each handle is adjustable by ±0.1 s, labelled "Clip start" or "Clip end", with an m:ss.t value. The timeline works in light and dark mode and at a large Dynamic Type size, and the track is full width on small phones.
- AC-6 UI tests (MiningFlow style: Make a Card on the sample's line 2, 2.0–4.0 s):
  - the timeline and both handles exist;
  - with Snap on, dragging the end handle right lands exactly on 5.5 s (`card.range` reads "0:02.0 – 0:05.5"); Save is disabled and Re-record shows; Re-record, then Save, works;
  - with Snap off, a drag lands between notches;
  - a +0.1 nudge moves the end handle right;
  - the chip's state survives a relaunch with the keep flag.
  Every existing test passes, and DESIGN.md describes the timeline.

### How to check
CI only: the orchestrator pushes, then runs `gh workflow run ios-simulator.yml --ref loop/player-lookup-timeline -f scope=all`, watches it and downloads `-p 'simulator-results*'`. Check the new timeline UI tests, MiningFlowUITests, and screenshots of the editor in light and dark mode.
- Unverified for Brent: handle feel on a real 24-minute episode.

### Agent notes
- Depends on: T-032 (`ClipTimeline`). Source: spec T-033; section G default 6 (blue notches, 25 % fill, white handles with a 3 pt accent border) and "Snap with an on/off switch".
- Code in CardEditorView.swift: `range`/`recordedRange` are at lines 20-21, `needsRerecord` at 84, `clipPanel` at 100-154 and `nudgeRow` at 156-178. The editor is a sheet inside the player; UI tests reach it through `player.makeCard` (see MiningFlowUITests).
- Put one DragGesture on the track and let T-032's handle choice pick the handle, rather than one gesture per handle, so overlapping hit areas follow the rule.
- The sample video is 6 s with offset 0, so the window is the whole 6 s.
- The spec's optional playhead line during Play clip isn't required.
- Learned: a `.contain` container reports the union of its children's frames.

- Could-fix from T-032's tester: `drawnNotches` compares x values with `<` at exactly 2 pt (fragile at the boundary); the 0.5 pt tie tolerance is tested only at a 0 pt gap; `dragged` with duration 0 is untested. Fix any that the view's use touches.
- `ClipTimeline` is MainActor by default like `CueTrack` and `ClipMath` (AC-1 of T-032 said nonisolated); the view is MainActor, so it doesn't matter here.

### Out of scope
- A playhead, lookups in the editor (T-031), changing ClipMath's rules.
