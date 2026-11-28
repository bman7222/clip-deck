import SwiftUI
import UIKit


struct MoveTextGlyph: View {
    var body: some View {
        ZStack {
            Text("A")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            arrow("arrow.up").offset(y: -11)
            arrow("arrow.down").offset(y: 11)
            arrow("arrow.left").offset(x: -11)
            arrow("arrow.right").offset(x: 11)
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }

    private func arrow(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 7, weight: .heavy))
    }
}

/// The four arrows. `canStepUp` is false (and Up reads "Highest") when one more step can't visibly move the line;
/// `highestUp` is then where a Down tap from above it lands.
private struct MoveArrows: View {
    @Binding var stored: String
    var canStepUp = true
    var highestUp = SubtitleStyle.upRange.upperBound
    var limitedByCard = false

    var body: some View {
        let current = SubtitleStyle.decoded(from: stored)
        HStack(spacing: Spacing.m) {
            StyleIconButton(
                symbol: "arrow.left", id: "left", label: "Move subtitles left", value: current.horizontalSpoken,
                enabled: current.canMoveLeft, prefix: "moveText",
                action: { stored = SubtitleStyle.edited(stored) { _ = $0.stepRight(-1) } })
            StyleIconButton(
                symbol: "arrow.up", id: "up", label: "Move subtitles up",
                value: canStepUp ? current.verticalSpoken : "Highest",
                enabled: current.canMoveUp && canStepUp, prefix: "moveText",
                action: { stored = SubtitleStyle.edited(stored) { _ = $0.stepUp(1) } })
            StyleIconButton(
                symbol: "arrow.down", id: "down", label: "Move subtitles down", value: current.verticalSpoken,
                enabled: current.canMoveDown, prefix: "moveText",
                action: {
                    stored = SubtitleStyle.edited(stored) { next in
                        if limitedByCard {
                            next.up = SubtitlePlacement.upAfterDownWithCardOpen(
                                stored: next.up, highestReachable: highestUp)
                        } else {
                            _ = next.stepUp(-1)
                        }
                    }
                })
            StyleIconButton(
                symbol: "arrow.right", id: "right", label: "Move subtitles right", value: current.horizontalSpoken,
                enabled: current.canMoveRight, prefix: "moveText",
                action: { stored = SubtitleStyle.edited(stored) { _ = $0.stepRight(1) } })
        }
    }
}

struct MoveTextCard: View {
    let insets: EdgeInsets
    var canStepUp = true
    var highestUp = SubtitleStyle.upRange.upperBound
    let onDone: () -> Void

    @AppStorage(SubtitleStyle.storageKey) private var stored = ""

    var body: some View {
        let current = SubtitleStyle.decoded(from: stored)
        ViewThatFits(in: .horizontal) {
            row(current, showsValue: true)
            row(current, showsValue: false)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .padding(.top, insets.top)
        .padding(.leading, insets.leading)
        .padding(.trailing, insets.trailing)
        .background(Color.black.opacity(0.55))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("moveText.card")
    }

    private func row(_ current: SubtitleStyle, showsValue: Bool) -> some View {
        HStack(spacing: Spacing.m) {
            MoveArrows(stored: $stored, canStepUp: canStepUp, highestUp: highestUp, limitedByCard: true)
            if showsValue {
                Text(current.positionText)
                    .font(.deckCallout)
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityIdentifier("moveText.value")
            }
            StyleIconButton(
                symbol: "arrow.counterclockwise", id: "reset", label: "Reset position",
                value: current.isPositionDefault ? "Already the default place" : "Changed",
                enabled: !current.isPositionDefault, prefix: "moveText",
                action: { stored = SubtitleStyle.edited(stored) { $0.resetPosition() } })
            StyleIconButton(
                symbol: "checkmark", id: "done", label: "Done", value: "", active: true, prefix: "moveText",
                action: onDone)
            // A checkmark symbol is reported as Selected; Done is never a selection.
            .accessibilityRemoveTraits(.isSelected)
        }
    }
}

struct MoveTextSheet: View {
    let clearance: SheetClearance?

    @AppStorage(SubtitleStyle.storageKey) private var stored = ""
    @Environment(\.dismiss) private var dismiss

    init(clearance: SheetClearance?) {
        self.clearance = clearance
    }

    var body: some View {
        let current = SubtitleStyle.decoded(from: stored)
        VStack(spacing: 0) {
            HStack(spacing: Spacing.s) {
                Text("Move subtitles")
                    .font(.deckTitle)
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("moveText.title")
                Spacer(minLength: Spacing.s)
                Button { dismiss() } label: { Image(systemName: "checkmark") }
                    .buttonStyle(DeckIconButtonStyle(isActive: true))
                    .accessibilityLabel("Done")
                    .accessibilityRemoveTraits(.isSelected)
                    .accessibilityIdentifier("moveText.done")
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.s)
            ScrollView {
                VStack(spacing: Spacing.m) {
                    MoveArrows(stored: $stored)
                    Text(current.positionText)
                        .font(.deckCallout)
                        .foregroundStyle(Theme.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityIdentifier("moveText.value")
                    Button {
                        stored = SubtitleStyle.edited(stored) { $0.resetPosition() }
                    } label: {
                        Label("Reset position", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DeckPrimaryButtonStyle())
                    .disabled(current.isPositionDefault)
                    .accessibilityIdentifier("moveText.reset")
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("moveText.sheet")
        .fittedFirstDetent(clearance: clearance)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
    }
}

/// Drawn inside its own frame, so the element's frame is exactly 6 pt larger on every side.
struct MoveTextOutline: View {
    static let gap: CGFloat = 6
    static let lineWidth: CGFloat = 2
    private static let arrowSize: CGFloat = 16
    private static let arrowGap: CGFloat = 8

    /// True while a long press has lifted it for dragging (the drag itself is on the caller's gesture).
    var lifted = false

    @AppStorage(SubtitleStyle.storageKey) private var stored = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
            .strokeBorder(Theme.accent, lineWidth: lifted && reduceMotion ? 3 : Self.lineWidth)
            .contentShape(Rectangle())
            .padding(-Self.gap)
            .overlay {
                if lifted {
                    Color.clear
                        .overlay(alignment: .top) { arrow("arrow.up").offset(y: -Self.arrowSize - Self.arrowGap) }
                        .overlay(alignment: .bottom) { arrow("arrow.down").offset(y: Self.arrowSize + Self.arrowGap) }
                        .overlay(alignment: .leading) { arrow("arrow.left").offset(x: -Self.arrowSize - Self.arrowGap) }
                        .overlay(alignment: .trailing) { arrow("arrow.right").offset(x: Self.arrowSize + Self.arrowGap) }
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(lifted && !reduceMotion ? 1.06 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.3), value: lifted)
            .sensoryFeedback(trigger: lifted) { _, isLifted in isLifted ? SensoryFeedback.impact(weight: .light) : nil }
            .accessibilityElement()
            .accessibilityLabel("Subtitle position")
            .accessibilityValue(SubtitleStyle.decoded(from: stored).positionText)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: nudge(up: 1)
                case .decrement: nudge(up: -1)
                @unknown default: break
                }
            }
            .accessibilityAction(named: "Move left") { nudge(right: -1) }
            .accessibilityAction(named: "Move right") { nudge(right: 1) }
            .accessibilityIdentifier("moveText.outline")
    }

    private func arrow(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(Theme.accent)
            .frame(width: Self.arrowSize, height: Self.arrowSize)
    }

    private func nudge(up: Int = 0, right: Int = 0) {
        stored = SubtitleStyle.edited(stored) { next in
            _ = next.stepUp(up)
            _ = next.stepRight(right)
        }
    }
}
