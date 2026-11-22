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

    /// The Bold control's spoken value: "On" or "Off", or why Bold can't change the picked font.
    var boldSpoken: String {
        if pickedFontIsAlwaysBold { return "This font is always bold" }
        if pickedFontName != nil, !pickedFontHasBold { return "This font has no bold weight" }
        return bold ? "On" : "Off"
    }

    /// Saves a font chosen in the picker (by PostScript name) in place of the preset. False, and nothing changes,
    /// for a name that can't be built.
    @discardableResult
    mutating func pickFont(_ postScriptName: String) -> Bool {
        guard Self.isInstalled(postScriptName) else { return false }
        pickedFontName = postScriptName
        font = .sans
        return true
    }

    /// "10 percent left", "10 percent right" or "Centred".
    var horizontalSpoken: String {
        if rightPercent < 0 { return "\(-rightPercent) percent left" }
        if rightPercent > 0 { return "\(rightPercent) percent right" }
        return "Centred"
    }
}

/// Where the portrait video ends on screen, so the style sheet's first detent can keep the sheet under it.
/// Both values are in window points (the window is the screen on iPhone).
nonisolated struct SheetClearance: Equatable, Sendable {
    var windowHeight: CGFloat
    var videoMaxY: CGFloat
}

/// One measurement turned into a fix: the rise the system really used, and the first detent height to use from now
/// on (the current height when the sheet already sits where it should).
nonisolated struct SheetFitCorrection: Equatable, Sendable {
    var rise: CGFloat
    var detentHeight: CGFloat
}

/// The arithmetic that keeps the style sheet's first detent just under the video.
///
/// The system draws a `.height(h)` sheet with its top at `windowHeight - h - rise`. The rise belongs to the OS,
/// not to the app: on iOS 26 (iPhone 17 Pro) the lower detent is a floating card, inset 8 pt and drawn at about
/// 0.96 scale, which comes to about 20 pt; systems that draw an edge-to-edge sheet and add the bottom safe area to
/// the detent rise by that inset instead. So the rise is measured once the sheet has settled, and 20 pt is only the
/// first guess.
nonisolated enum SheetFit {
    /// The gap kept between the bottom of the video and the top of the sheet.
    static let gapBelowVideo: CGFloat = 8
    /// The rise assumed until one has been measured (iOS 26 on iPhone 17 Pro).
    static let firstGuessRise: CGFloat = 20
    /// The first detent is never shorter than this (title, Done and a little content; the rest scrolls).
    static let minimumDetentHeight: CGFloat = 120
    /// A measured rise outside this range is not a settled sheet at the first detent (it is mid-animation, being
    /// dragged, or at `.large`), so it is ignored.
    static let plausibleRise: ClosedRange<CGFloat> = -24 ... 96
    /// Smaller differences than this are left alone, so the sheet never shuffles by a fraction of a point.
    static let minimumChange: CGFloat = 1

    /// Height of the first detent: the room under the video, less the gap and the rise, so the sheet never covers
    /// the video. Never below `minimumDetentHeight`; when the room is small the content scrolls and `.large` is the
    /// second detent.
    static func detentHeight(for clearance: SheetClearance, rise: CGFloat) -> CGFloat {
        max(minimumDetentHeight, clearance.windowHeight - clearance.videoMaxY - gapBelowVideo - rise)
    }

    /// The rise implied by a sheet of `detentHeight` whose top was measured at `sheetTop`, or nil when the
    /// measurement makes no sense (not finite, off the window, or an implausible rise).
    static func rise(windowHeight: CGFloat, detentHeight: CGFloat, sheetTop: CGFloat) -> CGFloat? {
        guard windowHeight.isFinite, detentHeight.isFinite, sheetTop.isFinite,
              windowHeight > 0, detentHeight > 0, sheetTop > 0, sheetTop < windowHeight
        else { return nil }
        let measured = (windowHeight - detentHeight) - sheetTop
        return plausibleRise.contains(measured) ? measured : nil
    }

    /// The fix for a sheet at the first detent of `detentHeight` whose top was measured at `sheetTop`, or nil when
    /// the measurement makes no sense (the current detent is then kept).
    static func correction(for clearance: SheetClearance, detentHeight: CGFloat, sheetTop: CGFloat) -> SheetFitCorrection? {
        guard let measured = rise(windowHeight: clearance.windowHeight, detentHeight: detentHeight, sheetTop: sheetTop)
        else { return nil }
        let corrected = self.detentHeight(for: clearance, rise: measured)
        let height = abs(corrected - detentHeight) < minimumChange ? detentHeight : corrected
        return SheetFitCorrection(rise: measured, detentHeight: height)
    }
}

/// Holds the UIKit view behind the sheet's content, so the sheet's real top on screen can be read.
/// UIKit's `convert(_:to:)` includes the transforms the system applies to a sheet (on iOS 26 the content of the
/// lower detent is drawn scaled; CI 44888942981 shows 44 pt buttons as 42.2 pt), and it reads the model frame,
/// which doesn't depend on SwiftUI laying the sheet out again after the system moved it.
final class SheetTopProbe {
    weak var view: UIView?

    /// The top of the sheet in window points, or nil while the probe isn't in a window.
    var top: CGFloat? {
        guard let view, let window = view.window else { return nil }
        return view.convert(view.bounds, to: window).minY
    }
}

/// An empty, untouchable UIKit view laid behind the whole sheet (safe areas included) for `SheetTopProbe`.
private struct SheetTopProbeView: UIViewRepresentable {
    let probe: SheetTopProbe

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        probe.view = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        probe.view = view
    }
}

/// The system font picker (families only) for SwiftUI, shared by the portrait sheet and the landscape card. It reports the chosen family's PostScript name, or a cancel.
struct SystemFontPicker: UIViewControllerRepresentable {
    let onPick: (String) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIFontPickerViewController {
        let configuration = UIFontPickerViewController.Configuration()
        configuration.includeFaces = false
        let picker = UIFontPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIFontPickerViewController, context: Context) {
        context.coordinator.onPick = onPick
        context.coordinator.onCancel = onCancel
    }

    final class Coordinator: NSObject, UIFontPickerViewControllerDelegate {
        var onPick: (String) -> Void
        var onCancel: () -> Void

        init(onPick: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
            guard let descriptor = viewController.selectedFontDescriptor else {
                onCancel()
                return
            }
            // A family descriptor may carry no face name, so ask the font it resolves to.
            onPick(UIFont(descriptor: descriptor, size: SubtitleStyle.minimumPointSize).fontName)
        }

        func fontPickerViewControllerDidCancel(_ viewController: UIFontPickerViewController) {
            onCancel()
        }
    }
}

/// What the first detent was fitted for. A new value (a different video bottom or window, or a new text size)
/// refits the detent and measures again; nothing else does.
private nonisolated struct SheetFitKey: Equatable {
    var clearance: SheetClearance?
    var textSize: DynamicTypeSize
}

/// One 44 pt icon control of the style menu: its label and value are spoken, and its identifier is
/// `subtitleStyle.<id>`. The portrait sheet and the landscape card both build their controls from it.
struct StyleIconButton: View {
    let symbol: String
    let id: String
    let label: String
    let value: String
    var active = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(DeckIconButtonStyle(isActive: active))
            .disabled(!enabled)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityIdentifier("subtitleStyle.\(id)")
    }
}

/// The portrait subtitle style menu: a bottom sheet that changes the saved style (and so the line on the video)
/// with every tap. The video stays visible above it. Landscape has its own card (`SubtitleStyleCard`).
/// Colours come only from the Theme tokens: idle Shell and Ink, on or selected Accent with white, values InkSoft.
struct SubtitleStyleSheet: View {
    /// Where the last measured rise is kept, so later opens (also after a relaunch) are right from the start.
    static let riseKey = "player.styleSheetRise"

    /// The last measured rise, or the first guess when none was measured (or the saved one is implausible).
    static var cachedRise: CGFloat {
        get {
            guard let saved = UserDefaults.standard.object(forKey: riseKey) as? Double else {
                return SheetFit.firstGuessRise
            }
            let rise = CGFloat(saved)
            return SheetFit.plausibleRise.contains(rise) ? rise : SheetFit.firstGuessRise
        }
        set {
            UserDefaults.standard.set(Double(newValue), forKey: riseKey)
        }
    }

    /// The video to keep clear, or nil when there is none (landscape, or not measured yet): the sheet is then
    /// `.large` only.
    let clearance: SheetClearance?

    /// The same saved value the player reads, so every change shows on the line at once.
    @AppStorage(SubtitleStyle.storageKey) private var stored = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var sampleSize: CGFloat = 20
    /// The selected detent. It always names a detent in `detents`: it changes together with `firstHeight`.
    @State private var detent: PresentationDetent
    /// The first detent's height in use, or nil for `.large` only.
    @State private var firstHeight: CGFloat?
    @State private var probe = SheetTopProbe()
    /// The system font picker is presented over this sheet. While it is, the sheet underneath is moved and scaled by
    /// the system, so its top must not be measured (a wrong rise would be cached).
    @State private var showingFontPicker = false

    init(clearance: SheetClearance?) {
        self.clearance = clearance
        let height = clearance.map { SheetFit.detentHeight(for: $0, rise: Self.cachedRise) }
        _firstHeight = State(initialValue: height)
        _detent = State(initialValue: height.map { PresentationDetent.height($0) } ?? PresentationDetent.large)
    }

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
        // A container, so UI tests can read where the sheet starts (`subtitleStyle.sheet`); its controls stay
        // separate elements.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("subtitleStyle.sheet")
        .background {
            SheetTopProbeView(probe: probe)
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
        .task(id: SheetFitKey(clearance: clearance, textSize: dynamicTypeSize)) {
            await fitFirstDetent()
        }
        .sheet(isPresented: $showingFontPicker) {
            SystemFontPicker(
                onPick: { name in
                    pickFont(name)
                    showingFontPicker = false
                },
                onCancel: { showingFontPicker = false }
            )
            .accessibilityIdentifier("subtitleStyle.fontPicker")
        }
        // The system sheet animation is used, and it follows Reduce Motion. The video is not dimmed or covered
        // at the first detent, so the line can be judged while it changes.
        .presentationDetents(detents, selection: $detent)
        .presentationBackgroundInteraction(backgroundInteraction)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.panel)
    }

    private var detents: Set<PresentationDetent> {
        guard clearance != nil, let firstHeight else { return [.large] }
        return [.height(firstHeight), .large]
    }

    /// Same detent as the first one, so the video is neither dimmed nor covered while the line is judged.
    private var backgroundInteraction: PresentationBackgroundInteraction {
        guard clearance != nil, let firstHeight else { return .automatic }
        return .enabled(upThrough: .height(firstHeight))
    }

    // MARK: Fitting the first detent

    /// Keeps the first detent just under the video. It runs when the sheet appears and again only when the geometry
    /// really changes (`SheetFitKey`). It first refits from the cached rise if needed, then waits for the sheet to
    /// settle, measures where the system really drew it, and corrects the detent at most once. The correction moves
    /// the sheet, but nothing measures again until the key changes, so it can't feed back into a loop.
    private func fitFirstDetent() async {
        guard let clearance else {
            // No video to keep clear: `.large` only, and the selection must stay in the set.
            if firstHeight != nil {
                firstHeight = nil
                detent = .large
            }
            return
        }
        // Usually already fitted: `init` used the same values. A changed geometry refits from the cached rise.
        let expected = SheetFit.detentHeight(for: clearance, rise: Self.cachedRise)
        let needsRefit = firstHeight.map { abs($0 - expected) >= SheetFit.minimumChange } ?? true
        if needsRefit { useFirstDetent(expected) }

        // The sheet's presentation animation takes about a third of a second.
        try? await Task.sleep(for: .milliseconds(450))
        var previousTop: CGFloat?
        var attempts = 0
        while attempts < 12 {
            if Task.isCancelled { return }
            if showingFontPicker {
                // The picker covers this sheet and the system moves it: wait without using up an attempt.
                previousTop = nil
                try? await Task.sleep(for: .milliseconds(100))
                continue
            }
            attempts += 1
            if let height = firstHeight, detent == .height(height), let top = probe.top {
                // Two equal readings 0.1 s apart: the sheet has settled (it isn't animating or being dragged).
                if let previousTop, abs(top - previousTop) < 0.5 {
                    if let fit = SheetFit.correction(for: clearance, detentHeight: height, sheetTop: top) {
                        Self.cachedRise = fit.rise
                        if fit.detentHeight != height { useFirstDetent(fit.detentHeight) }
                    }
                    return
                }
                previousTop = top
            } else {
                // At `.large`, or not in a window yet: nothing to measure now.
                previousTop = nil
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Changes the first detent's height and, unless the sheet is at `.large`, the selection with it, in the same
    /// update, so the selection always names a detent in the set.
    private func useFirstDetent(_ height: CGFloat) {
        let atLarge = detent == .large
        firstHeight = height
        detent = atLarge ? .large : .height(height)
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
                // The label is a checkmark symbol, which the accessibility tree reported as Selected (CI 44888942981),
                // while Bold, the same style with another symbol, was not. Done is never a selection.
                .accessibilityRemoveTraits(.isSelected)
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
                fontRow(font, selected: current.pickedFontName == nil && current.font == font, bold: current.bold)
            }
            moreFontsRow(current)
            if current.pickedFontName != nil, !current.pickedFontHasBold {
                Text("This font has no bold weight.")
                    .font(.deckCaption)
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.horizontal, Spacing.m)
                    .accessibilityIdentifier("subtitleStyle.font.noBold")
            }
            if current.pickedFontIsAlwaysBold {
                Text("This font is always bold.")
                    .font(.deckCaption)
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.horizontal, Spacing.m)
                    .accessibilityIdentifier("subtitleStyle.font.alwaysBold")
            }
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
            update {
                $0.font = font
                $0.pickedFontName = nil
            }
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

    /// "More fonts…": opens the system font picker. Once a font is picked the row shows its name and the sample
    /// "Aa あア漢字" drawn exactly as the line draws it (Japanese cascade included), and is aqua like a selected preset.
    private func moreFontsRow(_ current: SubtitleStyle) -> some View {
        let pickedName = current.pickedFamilyName
        let selected = pickedName != nil
        let sample = current.uiFont(pointSize: sampleSize)
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(spacing: Spacing.m))
        return Button {
            showingFontPicker = true
        } label: {
            layout {
                Label {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("More fonts…")
                            .font(.deckHeadline)
                        if let pickedName {
                            Text(pickedName)
                                .font(.deckCaption)
                        }
                    }
                } icon: {
                    Image(systemName: "ellipsis.circle")
                }
                if !stacked { Spacer(minLength: Spacing.s) }
                if selected {
                    Text("Aa あア漢字")
                        .font(Font(sample as CTFont))
                        .accessibilityHidden(true)
                }
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
        .accessibilityLabel("More fonts")
        .accessibilityValue(pickedName ?? "None")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("subtitleStyle.font.more")
    }

    /// Saves a font chosen in the picker (by PostScript name) in place of the preset. Nothing happens for a name
    /// that can't be built.
    private func pickFont(_ postScriptName: String) {
        update { _ = $0.pickFont(postScriptName) }
    }

    private func boldRow(_ current: SubtitleStyle) -> some View {
        HStack(spacing: Spacing.m) {
            Text("Bold")
                .font(.deckHeadline)
                .foregroundStyle(Theme.ink)
                .accessibilityHidden(true)
            Spacer(minLength: Spacing.s)
            iconButton(
                "bold", id: "bold", label: "Bold", value: current.boldSpoken, active: current.bold
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
        StyleIconButton(
            symbol: symbol, id: id, label: label, value: value, active: active, enabled: enabled,
            action: { update(change) })
    }

    /// Applies a change to the saved style. The mutators clamp, so a change never leaves the allowed ranges.
    private func update(_ change: (inout SubtitleStyle) -> Void) {
        var next = style
        change(&next)
        stored = next.clamped().json
    }
}
