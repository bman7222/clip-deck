import SwiftUI

/// The clip timeline in Make a Card: an overview strip of the whole episode and a zoomed track with two draggable
/// handles. It writes the editor's `range`; every rule (window, snapping, clamps, handle choice) is `ClipTimeline`.
struct ClipTimelineView: View {
    static let snapKey = "cardEditor.timelineSnap"

    @Binding var range: ClipRange
    let track: CueTrack
    let offsetMs: Int
    let videoDurationMs: Int

    @AppStorage(ClipTimelineView.snapKey) private var snapOn = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var window: ClipRange
    @State private var drag: Drag?

    private struct Drag {
        let handle: ClipTimeline.Handle
        let startX: CGFloat
        var notch: Int?
    }

    private static let handleSize: CGFloat = 28
    private static let hitSize: CGFloat = 44
    private static let inset = handleSize / 2
    private static let railHeight: CGFloat = 28
    private static let bubbleWidth: CGFloat = 64

    init(range: Binding<ClipRange>, track: CueTrack, offsetMs: Int, videoDurationMs: Int) {
        _range = range
        self.track = track
        self.offsetMs = offsetMs
        self.videoDurationMs = videoDurationMs
        _window = State(initialValue: ClipTimeline(
            track: track, offsetMs: offsetMs, videoDurationMs: videoDurationMs, range: range.wrappedValue, widthPt: 0
        ).window)
    }

    private func timeline(width: CGFloat, window: ClipRange?) -> ClipTimeline {
        ClipTimeline(track: track, offsetMs: offsetMs, videoDurationMs: videoDurationMs, range: range, widthPt: width, window: window)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            overview
            zoomedTrack
            HStack {
                Text(TimeFormat.clock(window.startMs)).accessibilityIdentifier("card.timeline.windowStart")
                Spacer()
                snapChip
                Spacer()
                Text(TimeFormat.clock(window.endMs)).accessibilityIdentifier("card.timeline.windowEnd")
            }
            .font(.deckTime)
            .foregroundStyle(Theme.inkSoft)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card.timeline")
        .onChange(of: range) { recentre(after: nil) }
    }

    // MARK: Parts

    private var overview: some View {
        GeometryReader { geo in
            let duration = timeline(width: 0, window: nil).durationMs
            let whole = timeline(width: geo.size.width, window: ClipRange(startMs: 0, endMs: duration))
            let start = whole.x(forMs: range.startMs)
            let end = whole.x(forMs: range.endMs)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.shell)
                Capsule().fill(Theme.accent)
                    .frame(width: max(3, end - start))
                    .offset(x: start)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    private var zoomedTrack: some View {
        GeometryReader { geo in
            let trackWidth = max(0, geo.size.width - Self.handleSize)
            let tl = timeline(width: trackWidth, window: window)
            let startX = Self.inset + tl.x(forMs: range.startMs)
            let endX = Self.inset + tl.x(forMs: range.endMs)
            let railTop = (Self.hitSize - Self.railHeight) / 2
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .fill(Theme.shell)
                    .frame(width: trackWidth, height: Self.railHeight)
                    .offset(x: Self.inset, y: railTop)
                Rectangle()
                    .fill(Theme.accent.opacity(0.25))
                    .frame(width: max(0, endX - startX), height: Self.railHeight)
                    .offset(x: startX, y: railTop)
                ForEach(tl.drawnNotches, id: \.self) { ms in
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: 2, height: 10)
                        .offset(x: Self.inset + tl.x(forMs: ms) - 1, y: (Self.hitSize - 10) / 2)
                }
                handleView(.start, x: startX, timeline: tl)
                handleView(.end, x: endX, timeline: tl)
                if let drag { bubble(for: drag.handle, timeline: tl, width: geo.size.width) }
            }
            .frame(width: geo.size.width, height: Self.hitSize, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { dragChanged($0, trackWidth: trackWidth) }
                    .onEnded { _ in
                        let handle = drag?.handle
                        drag = nil
                        recentre(after: handle)
                    }
            )
        }
        .frame(height: Self.hitSize)
    }

    private func handleView(_ handle: ClipTimeline.Handle, x: CGFloat, timeline tl: ClipTimeline) -> some View {
        let isStart = handle == .start
        let ms = isStart ? tl.range.startMs : tl.range.endMs
        return Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(Theme.accent, lineWidth: 3))
            .frame(width: Self.handleSize, height: Self.handleSize)
            .frame(width: Self.hitSize, height: Self.hitSize)
            .offset(x: x - Self.hitSize / 2)
            .accessibilityElement()
            .accessibilityIdentifier(isStart ? "card.timeline.start" : "card.timeline.end")
            .accessibilityLabel(isStart ? "Clip start" : "Clip end")
            .accessibilityValue(TimeFormat.clock(ms))
            .accessibilityAdjustableAction { direction in
                let step = direction == .increment ? 100 : -100
                range = tl.dragged(handle, toMs: ms + step)
            }
    }

    private func bubble(for handle: ClipTimeline.Handle, timeline tl: ClipTimeline, width: CGFloat) -> some View {
        let ms = handle == .start ? tl.range.startMs : tl.range.endMs
        let centre = Self.inset + tl.x(forMs: ms)
        let half = Self.bubbleWidth / 2
        return Text(TimeFormat.clock(ms))
            .font(.deckCaption.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(Theme.panel)
            .frame(width: Self.bubbleWidth, height: 24)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            .position(x: min(max(centre, half), max(half, width - half)), y: -4)
            .accessibilityHidden(true)
    }

    private var snapChip: some View {
        let hasNotches = !track.cues.isEmpty
        return Button { snapOn.toggle() } label: {
            Text("Snap")
                .font(.deckCaption)
                .foregroundStyle(snapOn ? Color.white : Theme.ink)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.xs)
                .background(snapOn ? Theme.accent : Theme.shell, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                .frame(minHeight: Self.hitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!hasNotches)
        .opacity(hasNotches ? 1 : 0.45)
        .accessibilityLabel("Snap to line edges")
        .accessibilityValue(snapOn ? "On" : "Off")
        .accessibilityIdentifier("card.timeline.snap")
    }

    // MARK: Dragging

    private func dragChanged(_ value: DragGesture.Value, trackWidth: CGFloat) {
        let tl = timeline(width: trackWidth, window: window)
        var current: Drag
        if let drag {
            current = drag
        } else {
            let handle = tl.handle(forTouchX: value.startLocation.x - Self.inset, dragDeltaX: value.translation.width)
            current = Drag(handle: handle, startX: tl.x(forMs: handle == .start ? tl.range.startMs : tl.range.endMs), notch: nil)
        }
        let snapped = tl.snap(pointerX: current.startX + value.translation.width, current: current.notch, enabled: snapOn)
        current.notch = snapped.notch
        drag = current
        range = tl.dragged(current.handle, toMs: snapped.ms)
    }

    private func recentre(after handle: ClipTimeline.Handle?) {
        guard timeline(width: 0, window: window).needsRecentring(draggedHandle: handle) else { return }
        let centred = timeline(width: 0, window: nil).window
        if reduceMotion {
            window = centred
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { window = centred }
        }
    }
}
