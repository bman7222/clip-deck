import SwiftUI
import UIKit

/// The landscape subtitle style menu: a card docked to the bottom of the video column, in place of the bottom bar
/// while it is open. It holds the font, bold and size controls of the portrait sheet, icon only (the values are
/// spoken), and writes the same saved style, so every tap shows on the line above it at once. The position has its
/// own menu (`MoveTextCard`).
///
/// It has the bars' look (`Color.black.opacity(0.55)`; the player puts it in the `.dark` colour scheme) and only
/// Theme colours: idle Shell and Ink, on or selected Accent with white. The layout comes from `ViewThatFits`: one
/// row of 13, otherwise rows of 7 and 6, otherwise rows of 5, 4 and 4.
struct SubtitleStyleCard: View {
    /// The bars' insets (safe area, and the handle clearance while the panel is open), so the card stays inside the
    /// video column and the safe area exactly like the bottom bar.
    let insets: EdgeInsets
    let onMoreFonts: () -> Void
    let onDone: () -> Void

    /// The same saved value the player reads, so every change shows on the line at once.
    @AppStorage(SubtitleStyle.storageKey) private var stored = ""

    private enum Control: Hashable {
        case sans, rounded, serif, more, bold
        case sizeDown, sizeUp
        case reset, done
    }

    private static let oneRow: [[Control]] = [
        [.sans, .rounded, .serif, .more, .bold, .sizeDown, .sizeUp, .reset, .done],
    ]
    private static let twoRows: [[Control]] = [
        [.sans, .rounded, .serif, .more, .bold],
        [.sizeDown, .sizeUp, .reset, .done],
    ]

    private var style: SubtitleStyle { SubtitleStyle.decoded(from: stored) }

    var body: some View {
        let current = style
        ViewThatFits(in: .horizontal) {
            rows(Self.oneRow, current)
            rows(Self.twoRows, current)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .padding(.bottom, insets.bottom)
        .padding(.leading, insets.leading)
        .padding(.trailing, insets.trailing)
        .background(Color.black.opacity(0.55))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("subtitleStyle.card")
    }

    private func rows(_ layout: [[Control]], _ current: SubtitleStyle) -> some View {
        VStack(spacing: Spacing.s) {
            ForEach(layout.indices, id: \.self) { index in
                HStack(spacing: Spacing.s) {
                    ForEach(layout[index], id: \.self) { item in
                        control(item, current)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func control(_ item: Control, _ current: SubtitleStyle) -> some View {
        switch item {
        case .sans: presetChip(.sans, current)
        case .rounded: presetChip(.rounded, current)
        case .serif: presetChip(.serif, current)
        case .more:
            let pickedName = current.pickedFamilyName
            StyleIconButton(
                symbol: "ellipsis.circle", id: "font.more", label: "More fonts", value: pickedName ?? "None",
                active: pickedName != nil, action: onMoreFonts
            )
            .accessibilityAddTraits(pickedName != nil ? .isSelected : [])
        case .bold:
            StyleIconButton(
                symbol: "bold", id: "bold", label: "Bold", value: current.boldSpoken, active: current.bold,
                action: { update { $0.bold.toggle() } }
            )
        case .sizeDown:
            StyleIconButton(
                symbol: "textformat.size.smaller", id: "sizeDown", label: "Smaller text", value: current.sizeSpoken,
                enabled: current.canSizeDown, action: { update { _ = $0.stepSize(-1) } }
            )
        case .sizeUp:
            StyleIconButton(
                symbol: "textformat.size.larger", id: "sizeUp", label: "Larger text", value: current.sizeSpoken,
                enabled: current.canSizeUp, action: { update { _ = $0.stepSize(1) } }
            )
        case .reset:
            StyleIconButton(
                symbol: "arrow.counterclockwise", id: "reset", label: "Reset to default",
                value: current.isFontDefault ? "Already the default" : "Changed",
                enabled: !current.isFontDefault, action: { update { $0.resetFont() } }
            )
        case .done:
            StyleIconButton(
                symbol: "checkmark", id: "done", label: "Done", value: "", active: true, action: onDone
            )
            // The checkmark symbol was reported as Selected in the portrait sheet; Done is never a selection.
            .accessibilityRemoveTraits(.isSelected)
        }
    }

    /// One preset chip: "Aあ" drawn in that font and the current weight, so both scripts can be judged.
    private func presetChip(_ font: SubtitleFont, _ current: SubtitleStyle) -> some View {
        let selected = current.pickedFontName == nil && current.font == font
        let sample = SubtitleStyle(font: font, bold: current.bold).uiFont(pointSize: 18)
        return Button {
            update {
                $0.font = font
                $0.pickedFontName = nil
            }
        } label: {
            Text("Aあ")
                .font(Font(sample as CTFont))
                .lineLimit(1)
        }
        .buttonStyle(DeckIconButtonStyle(isActive: selected))
        .accessibilityLabel("\(font.title) font")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("subtitleStyle.font.\(font.rawValue)")
    }

    /// Applies a change to the saved style. The mutators clamp, so a change never leaves the allowed ranges.
    private func update(_ change: (inout SubtitleStyle) -> Void) {
        stored = SubtitleStyle.edited(stored, change)
    }
}
