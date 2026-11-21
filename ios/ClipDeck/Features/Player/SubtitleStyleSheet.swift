import SwiftUI
import UIKit

/// Texts the style menu shows and speaks. Percentages are exact Ints (steps are 10% and 5%).
nonisolated extension SubtitleStyle {
    /// 60 ... 200.
    var sizePercent: Int { (10 + Self.clamp(sizeStep, to: Self.sizeRange)) * 10 }
    /// 0 ... 90, how far up from the default bottom place.
    var upPercent: Int { Self.clamp(upSteps, to: Self.upRange) * 5 }
    /// -40 ... 40; negative is left.
    var rightPercent: Int { Self.clamp(rightSteps, to: Self.rightRange) * 5 }

    /// "130%".
    var sizeText: String { "\(sizePercent)%" }

    /// "130 percent".
    var sizeSpoken: String { "\(sizePercent) percent" }

    /// "Up 20% · Left 10%", or "Default place" when the line is at the default bottom centre.
    var positionText: String {
        var parts: [String] = []
        if upPercent > 0 { parts.append("Up \(upPercent)%") }
        if rightPercent < 0 {
            parts.append("Left \(-rightPercent)%")
        } else if rightPercent > 0 {
            parts.append("Right \(rightPercent)%")
        }
        return parts.isEmpty ? "Default place" : parts.joined(separator: " · ")
    }

    /// "20 percent up", or "At the default height".
    var verticalSpoken: String { upPercent > 0 ? "\(upPercent) percent up" : "At the default height" }

    /// "10 percent left", "10 percent right" or "Centred".
    var horizontalSpoken: String {
        if rightPercent < 0 { return "\(-rightPercent) percent left" }
        if rightPercent > 0 { return "\(rightPercent) percent right" }
        return "Centred"
    }
}

/// The portrait subtitle style menu: a bottom sheet that changes the saved style (and so the line on the video)
/// with every tap. The video stays visible above it. Landscape gets a card in T-016.
/// Colours come only from the Theme tokens: idle Shell and Ink, on or selected Accent with white, values InkSoft.
struct SubtitleStyleSheet: View {
    /// Height of the first detent. Sized so the sheet starts below the 16:9 video on an iPhone 17 Pro.
    static let detentHeight: CGFloat = 520

    /// The same saved value the player reads, so every change shows on the line at once.
    @AppStorage(SubtitleStyle.storageKey) private var stored = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var sampleSize: CGFloat = 20
    @State private var detent: PresentationDetent = .height(SubtitleStyleSheet.detentHeight)

    private var style: SubtitleStyle { SubtitleStyle.decoded(from: stored) }

    var body: some View {
        let current = style
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    fontSection(current)
                    sizeSection(current)
                    positionSection(current)
                    resetButton(current)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.xl)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: stored)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        // The system sheet animation is used, and it follows Reduce Motion. The video is not dimmed or covered
        // at the first detent, so the line can be judged while it changes.
        .presentationDetents([.height(Self.detentHeight), .large], selection: $detent)
        .presentationBackgroundInteraction(.enabled(upThrough: .height(Self.detentHeight)))
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: Spacing.s) {
            Text("Subtitle style")
                .font(.deckTitle)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("subtitleStyle.title")
            Spacer(minLength: Spacing.s)
            Button { dismiss() } label: { Image(systemName: "checkmark") }
                .buttonStyle(DeckIconButtonStyle(isActive: true))
                .accessibilityLabel("Done")
                .accessibilityIdentifier("subtitleStyle.done")
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.l)
        .padding(.bottom, Spacing.s)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.deckCaption)
            .foregroundStyle(Theme.inkSoft)
            .accessibilityAddTraits(.isHeader)
    }

    private func fontSection(_ current: SubtitleStyle) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            sectionTitle("Font")
            ForEach(SubtitleFont.allCases, id: \.self) { font in
                fontRow(font, selected: current.font == font, bold: current.bold)
            }
            // T-017 adds the "More fonts…" row here, right under the presets.
            boldRow(current)
        }
    }

    /// One preset: its name and the sample "Aa あア漢字" drawn in that font, so both scripts can be judged.
    private func fontRow(_ font: SubtitleFont, selected: Bool, bold: Bool) -> some View {
        let sample = SubtitleStyle(font: font, bold: bold).uiFont(pointSize: sampleSize)
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(spacing: Spacing.m))
        return Button {
            update { $0.font = font }
        } label: {
            layout {
                Text(font.title)
                    .font(.deckHeadline)
                if !stacked { Spacer(minLength: Spacing.s) }
                Text("Aa あア漢字")
                    .font(Font(sample as CTFont))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(selected ? Color.white : Theme.ink)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(
                selected ? Theme.accent : Theme.shell,
                in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(font.title) font")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("subtitleStyle.font.\(font.rawValue)")
    }

    private func boldRow(_ current: SubtitleStyle) -> some View {
        HStack(spacing: Spacing.m) {
            Text("Bold")
                .font(.deckHeadline)
                .foregroundStyle(Theme.ink)
                .accessibilityHidden(true)
            Spacer(minLength: Spacing.s)
            iconButton(
                "bold", id: "bold", label: "Bold", value: current.bold ? "On" : "Off", active: current.bold
            ) { $0.bold.toggle() }
        }
        .padding(.leading, Spacing.m)
    }

    private func sizeSection(_ current: SubtitleStyle) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            sectionTitle("Size")
            HStack(spacing: Spacing.m) {
                iconButton(
                    "textformat.size.smaller", id: "sizeDown", label: "Smaller text",
                    value: current.sizeSpoken, enabled: current.canSizeDown
                ) { _ = $0.stepSize(-1) }
                Spacer(minLength: Spacing.s)
                Text(current.sizeText)
                    .font(.deckHeadline.monospacedDigit())
                    .foregroundStyle(Theme.inkSoft)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("subtitleStyle.sizeValue")
                Spacer(minLength: Spacing.s)
                iconButton(
                    "textformat.size.larger", id: "sizeUp", label: "Larger text",
                    value: current.sizeSpoken, enabled: current.canSizeUp
                ) { _ = $0.stepSize(1) }
            }
        }
    }

    private func positionSection(_ current: SubtitleStyle) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            sectionTitle("Position")
            HStack(spacing: Spacing.m) {
                iconButton(
                    "arrow.left", id: "left", label: "Move subtitles left",
                    value: current.horizontalSpoken, enabled: current.canMoveLeft
                ) { _ = $0.stepRight(-1) }
                Spacer(minLength: 0)
                iconButton(
                    "arrow.up", id: "up", label: "Move subtitles up",
                    value: current.verticalSpoken, enabled: current.canMoveUp
                ) { _ = $0.stepUp(1) }
                Spacer(minLength: 0)
                iconButton(
                    "arrow.down", id: "down", label: "Move subtitles down",
                    value: current.verticalSpoken, enabled: current.canMoveDown
                ) { _ = $0.stepUp(-1) }
                Spacer(minLength: 0)
                iconButton(
                    "arrow.right", id: "right", label: "Move subtitles right",
                    value: current.horizontalSpoken, enabled: current.canMoveRight
                ) { _ = $0.stepRight(1) }
            }
            Text(current.positionText)
                .font(.deckCallout)
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("subtitleStyle.positionValue")
        }
    }

    private func resetButton(_ current: SubtitleStyle) -> some View {
        Button {
            stored = SubtitleStyle.default.json
        } label: {
            Label("Reset to default", systemImage: "arrow.counterclockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(DeckPrimaryButtonStyle())
        .disabled(current.isDefault)
        .accessibilityIdentifier("subtitleStyle.reset")
    }

    /// A 44 pt icon control that applies one change to the saved style. Its label and value are spoken.
    private func iconButton(
        _ symbol: String, id: String, label: String, value: String, active: Bool = false, enabled: Bool = true,
        change: @escaping (inout SubtitleStyle) -> Void
    ) -> some View {
        Button {
            update(change)
        } label: {
            Image(systemName: symbol)
        }
        .buttonStyle(DeckIconButtonStyle(isActive: active))
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityIdentifier("subtitleStyle.\(id)")
    }

    /// Applies a change to the saved style. The mutators clamp, so a change never leaves the allowed ranges.
    private func update(_ change: (inout SubtitleStyle) -> Void) {
        var next = style
        change(&next)
        stored = next.clamped().json
    }
}
