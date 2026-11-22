import SwiftData
import SwiftUI
import UIKit

/// Episode player. Portrait is laid out like a 3DS: video is the "top screen", and the controls
/// plus the subtitle list form the "bottom screen". In landscape the list is a side panel (a quarter of the screen).
struct PlayerView: View {
    @Bindable var episode: Episode
    @Environment(\.modelContext) private var context
    @Environment(SettingsStore.self) private var settings

    @State private var model: PlayerModel?
    @State private var subtitleProblem: String?
    @State private var showSidePanel = false
    @State private var showOffset = false
    @State private var showSubtitlePicker = false
    /// The portrait subtitle style sheet. Landscape has its own card (`styleMenuOpen`).
    @State private var showStyleSheet = false
    /// The landscape subtitle style card, shown in place of the bottom bar. Plain state, not a Menu: gestures on a
    /// Menu don't fire on iOS 26. It is part of `keepsControlsUp`.
    @State private var styleMenuOpen = false
    /// The system font picker opened from the card. A presented state SwiftUI clears itself, so it can hold the
    /// controls up, and the card stays open under it.
    @State private var showCardFontPicker = false
    /// The card's measured height, so the line can be pushed above it like it is above the bottom bar.
    @State private var styleCardHeight: CGFloat = 100
    /// The bottom of the portrait video in global coordinates, so the style sheet's first detent can stay under it.
    @State private var videoMaxY: CGFloat = 0
    @State private var miningRange: ClipRange?
    @State private var miningError: String?
    @State private var draft: CardDraft?
    @State private var toast: String?
    @State private var isLandscape = false
    @State private var controlsVisible = false
    @State private var hideTask: Task<Void, Never>?
    @State private var topBarHeight: CGFloat = 60
    @State private var bottomBarHeight: CGFloat = 100
    /// Landscape subtitles dialog. A presented state SwiftUI clears itself, so it can hold the controls up.
    @State private var subtitleDialogOpen = false
    /// The panel width the user chose, as a fraction of the usable width (screen width minus both insets).
    @AppStorage("player.panelFraction") private var storedPanelFraction: Double = Double(PlayerView.panelFraction)
    /// The handle drag in progress (where it started and its horizontal translation). A GestureState resets
    /// itself when the gesture ends or is cancelled, so a cancelled drag can't leave the panel or the auto-hide stuck.
    @GestureState private var panelDrag: PanelDrag? = nil
    /// The one direction latch for a handle drag: where the drag started, and whether its first event was
    /// mostly horizontal (a resize). Decided once, in `onChanged`. The live resize (`liveResizeX`) and the
    /// save in `onEnded` both read it, so a drag that resizes live is always saved and one that doesn't never moves the panel.
    @State private var panelDragOrigin: CGPoint?
    @State private var panelDragResizes = false
    /// The saved subtitle style (JSON). A string AppStorage, so a later menu that writes it updates the line live.
    @AppStorage(SubtitleStyle.storageKey) private var storedSubtitleStyle = ""
    @Environment(\.dismiss) private var dismiss
    /// Read so a text size change redraws the line (its font is built from the current Dynamic Type size).
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let store = FileStore.live

    /// Default share of the usable width the landscape subtitle panel takes.
    private static let panelFraction: CGFloat = 0.25
    /// The panel can be dragged up to this share of the usable width.
    private static let panelMaxFraction: CGFloat = 0.5
    /// The handle's 44 pt touch area reaches this far over the video, so the bars keep this much trailing
    /// padding while the panel is open and the toggle and Make a Card stay clear of it.
    private static let panelHandleClearance: CGFloat = 32
    /// The panel is never narrower than this many points.
    private static let panelMinWidth: CGFloat = 180

    var body: some View {
        Group {
            if let model {
                GeometryReader { geometry in
                    if geometry.size.width > geometry.size.height {
                        landscape(model, size: geometry.size, insets: geometry.safeAreaInsets)
                    } else {
                        portrait(model)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(isLandscape ? Color.black : Theme.shell)
        .background {
            GeometryReader { proxy in
                Color.clear.onChange(of: proxy.size, initial: true) { _, size in
                    let landscape = size.width > size.height
                    guard landscape != isLandscape else { return }
                    isLandscape = landscape
                    // Entering or leaving landscape always starts with the controls hidden.
                    controlsVisible = false
                    subtitleDialogOpen = false
                    // Rotating closes the style menu (the portrait sheet, and the landscape card with its font picker).
                    showStyleSheet = false
                    styleMenuOpen = false
                    showCardFontPicker = false
                    hideTask?.cancel()
                }
            }
        }
        .navigationTitle(episode.title)
        .navigationBarTitleDisplayMode(.inline)
        // The sheet leaves the video and the bar usable, so the back button is hidden while it is open
        // (otherwise the player could be popped with the sheet still presented).
        .navigationBarBackButtonHidden(showStyleSheet)
        .toolbarBackground(Theme.shell, for: .navigationBar)
        .toolbar(isLandscape ? .hidden : .automatic, for: .navigationBar)
        .statusBarHidden(isLandscape && !controlsShown)
        .persistentSystemOverlays(isLandscape ? .hidden : .automatic)
        .onChange(of: model?.isPlaying) { wasPlaying, playing in
            // Pausing (or a finished clip) brings the controls back; playing starts the countdown.
            // Only a real pause counts (true -> false). The model appearing paused (nil -> false) does not, so
            // landscape always starts with the controls hidden, also when the player opens already in landscape.
            if isLandscape, wasPlaying == true, playing == false { controlsVisible = true }
            restartHideTimer()
        }
        .onChange(of: keepsControlsUp) { restartHideTimer() }
        .onAppear(perform: setUp)
        .onDisappear {
            if let model {
                episode.lastPositionMs = model.currentMs
                model.tearDown()
            }
        }
        .sheet(isPresented: $showOffset) {
            if let model { OffsetSheet(model: model, onChange: { episode.offsetMs = $0 }) }
        }
        .sheet(isPresented: $showStyleSheet) {
            SubtitleStyleSheet(clearance: styleSheetClearance)
        }
        .sheet(isPresented: $showCardFontPicker) {
            SystemFontPicker(
                onPick: { name in
                    var next = SubtitleStyle.decoded(from: storedSubtitleStyle)
                    if next.pickFont(name) { storedSubtitleStyle = next.clamped().json }
                    showCardFontPicker = false
                },
                onCancel: { showCardFontPicker = false }
            )
            .accessibilityIdentifier("subtitleStyle.fontPicker")
        }
        .sheet(isPresented: $showSubtitlePicker, onDismiss: reloadSubtitles) {
            SubtitlePickerSheet(episode: episode)
        }
        .sheet(item: $draft) { draft in
            if let model {
                CardEditorView(
                    draft: draft,
                    videoURL: store.absoluteURL(episode.videoPath),
                    track: model.track,
                    offsetMs: model.offsetMs,
                    videoDurationMs: model.durationMs,
                    onSaved: { waiting in
                        toast = waiting == 1 ? "Card saved. 1 card waiting to sync." : "Card saved. \(waiting) cards waiting to sync."
                    }
                )
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Toast(message: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { self.toast = nil }
                    }
            }
        }
        .animation(.spring(duration: 0.3), value: toast)
    }

    // MARK: Layouts

    private func portrait(_ model: PlayerModel) -> some View {
        VStack(spacing: 0) {
            videoScreen(model, onTap: { model.togglePlay() })
                .aspectRatio(16 / 9, contentMode: .fit)
                .background {
                    GeometryReader { proxy in
                        Color.clear.onChange(of: proxy.frame(in: .global).maxY, initial: true) { _, value in
                            videoMaxY = value
                        }
                    }
                }
            VStack(spacing: 0) {
                controls(model)
                    .padding(Spacing.m)
                Divider()
                if let subtitleProblem {
                    ErrorBanner(message: subtitleProblem, actionTitle: "Choose subtitles") { showSubtitlePicker = true }
                        .padding(Spacing.m)
                }
                CuePanel(model: model)
            }
            .background(Theme.panel, in: UnevenRoundedRectangle(topLeadingRadius: Radius.panel, topTrailingRadius: Radius.panel, style: .continuous))
            .padding(.top, Spacing.s)
        }
    }

    /// Where the portrait video ends, so the style sheet's first detent can stay under it (the sheet measures itself
    /// and corrects the detent). Nil before the video is measured, which makes the sheet `.large` only (landscape
    /// uses the card, not the sheet).
    private var styleSheetClearance: SheetClearance? {
        guard !isLandscape, videoMaxY > 0 else { return nil }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        guard let windowHeight = scene?.keyWindow?.bounds.height ?? scene?.screen.bounds.height,
              windowHeight > videoMaxY
        else { return nil }
        return SheetClearance(windowHeight: windowHeight, videoMaxY: videoMaxY)
    }

    private func landscape(_ model: PlayerModel, size: CGSize, insets: EdgeInsets) -> some View {
        let shown = controlsShown
        // Work in full-screen widths: the whole layout ignores the safe area and the bars and the panel
        // pad their own content by the insets, so 75 % / 25 % is of the real screen width.
        // Panel content = max(25 % of the usable width, 180 pt); the trailing inset is added on top as padding.
        let totalWidth = size.width + insets.leading + insets.trailing
        let usableWidth = size.width
        let baseFraction = clampedPanelFraction(CGFloat(storedPanelFraction), usable: usableWidth)
        let fraction = liveResizeX.map { draggedPanelFraction(base: baseFraction, translation: $0, usable: usableWidth) }
            ?? baseFraction
        let panelWidth = showSidePanel ? max(usableWidth * fraction, Self.panelMinWidth) + insets.trailing : 0
        let videoWidth = totalWidth - panelWidth
        let barInsets = EdgeInsets(
            top: insets.top, leading: insets.leading,
            bottom: insets.bottom, trailing: showSidePanel ? Self.panelHandleClearance : insets.trailing
        )
        return HStack(spacing: 0) {
            videoScreen(
                model,
                subtitleMargins: SubtitleMargins(
                    top: Spacing.s + insets.top, leading: Spacing.l + barInsets.leading,
                    bottom: Spacing.m + insets.bottom, trailing: Spacing.l + barInsets.trailing),
                subtitleTopObstruction: shown ? topBarHeight + Spacing.s : 0,
                subtitleBottomObstruction: shown ? (styleMenuOpen ? styleCardHeight : bottomBarHeight) + Spacing.s : 0,
                subtitleStepsFromCard: shown && styleMenuOpen,
                badgeTopPadding: shown ? topBarHeight + Spacing.s : insets.top,
                edgeInsets: EdgeInsets(top: 0, leading: barInsets.leading, bottom: 0, trailing: barInsets.trailing),
                onTap: toggleControls
            )
            .frame(width: videoWidth)
            // The bars lie over the fixed-width video and take its width as a hard limit, so they can never
            // widen or re-centre the video column. If a bar still can't fit, it keeps its leading edge (the back
            // button stays inside the safe area) and is clipped on the trailing side.
            .overlay(alignment: .leading) {
                // Rendered only while shown, so the accessibility tree matches the screen.
                if shown {
                    VStack(alignment: .leading, spacing: 0) {
                        topBar(insets: barInsets)
                            .measuredHeight($topBarHeight)
                        Spacer(minLength: 0)
                        // The style card replaces the bottom bar while it is open; the top bar stays.
                        if styleMenuOpen {
                            SubtitleStyleCard(
                                insets: barInsets,
                                onMoreFonts: { showCardFontPicker = true },
                                onDone: closeStyleMenu
                            )
                            .measuredHeight($styleCardHeight)
                            .transition(styleCardTransition)
                        } else {
                            bottomBar(model, insets: barInsets)
                                .measuredHeight($bottomBarHeight)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: styleMenuOpen)
                    .frame(width: videoWidth, alignment: .leading)
                    .clipped()
                    .environment(\.colorScheme, .dark)
                    .transition(.opacity)
                }
            }
            .clipped()
            .animation(.easeInOut(duration: 0.2), value: shown)
            if showSidePanel {
                sidePanel(model, width: panelWidth, insets: insets)
                    .overlay(alignment: .leading) { panelHandle(usable: usableWidth, fraction: fraction) }
                    .transition(.move(edge: .trailing))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .clipped()
        .ignoresSafeArea()
        .animation(.spring(duration: 0.3), value: showSidePanel)
        // Landscape uses a dialog, not a Menu: gestures on a Menu don't fire on iOS 26, so an open Menu
        // can't be tracked and the auto-hide would tear it down. The dialog's binding clears on any dismissal.
        .confirmationDialog("Subtitles", isPresented: $subtitleDialogOpen, titleVisibility: .hidden) {
            Button("Load different subtitles") { showSubtitlePicker = true }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// A handle drag in progress: where it started and how far it has moved sideways.
    private struct PanelDrag: Equatable {
        var start: CGPoint
        var x: CGFloat
    }

    /// The live translation of the handle drag, only while the latch judged that drag a resize.
    private var liveResizeX: CGFloat? {
        guard let drag = panelDrag, panelDragResizes, panelDragOrigin == drag.start else { return nil }
        return drag.x
    }

    /// Keeps a panel fraction between 180 pt and 50 % of the usable width.
    private func clampedPanelFraction(_ value: CGFloat, usable: CGFloat) -> CGFloat {
        guard usable > 0 else { return Self.panelFraction }
        let lower = min(Self.panelMinWidth / usable, Self.panelMaxFraction)
        return min(max(value, lower), Self.panelMaxFraction)
    }

    /// Dragging left widens the panel: content width = start width - translation.
    private func draggedPanelFraction(base: CGFloat, translation: CGFloat, usable: CGFloat) -> CGFloat {
        guard usable > 0 else { return Self.panelFraction }
        return clampedPanelFraction((base * usable - translation) / usable, usable: usable)
    }

    private func resetPanelWidth() {
        withAnimation(.spring(duration: 0.3)) { storedPanelFraction = Double(Self.panelFraction) }
        restartHideTimer()
    }

    /// Drag handle on the divider: a grip with a 44 pt wide touch area that sits mostly over the video
    /// (only 12 pt overlap the panel, which is the cue rows' own padding).
    /// It has its own DragGesture (gestures on bars don't fire on iOS 26), so the video's tap and the cue
    /// list's scrolling are untouched. Double-tap resets; VoiceOver gets an adjustable control.
    private func panelHandle(usable: CGFloat, fraction: CGFloat) -> some View {
        Color.clear
            .frame(width: 44)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .overlay(alignment: .leading) {
                // The grip is centred on the panel's leading edge: the area reaches 32 pt over the video.
                // Light with a thin dark outline, so it reads over both the dark video and the light panel.
                Capsule()
                    .fill(Color.white)
                    .overlay(Capsule().stroke(Color.black.opacity(0.5), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.35), radius: 1.5)
                    .frame(width: 5, height: 40)
                    .padding(.leading, Self.panelHandleClearance - 2.5)
            }
            .offset(x: -Self.panelHandleClearance)
            .gesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .global)
                    .updating($panelDrag) { value, state, _ in
                        // Only tracks the drag; whether it resizes is the latch's call (see `liveResizeX`).
                        state = PanelDrag(start: value.startLocation, x: value.translation.width)
                    }
                    .onChanged { value in
                        // The latch: decided by the first event of each drag (a new start location), never revised.
                        // Only a mostly horizontal start resizes; a vertical start is left alone.
                        if panelDragOrigin != value.startLocation {
                            panelDragOrigin = value.startLocation
                            panelDragResizes = abs(value.translation.width) > abs(value.translation.height)
                        }
                    }
                    .onEnded { value in
                        // Same latch as the live resize, so what moved live is what gets saved.
                        let resizes = panelDragOrigin == value.startLocation && panelDragResizes
                        panelDragOrigin = nil
                        panelDragResizes = false
                        if resizes {
                            let base = clampedPanelFraction(CGFloat(storedPanelFraction), usable: usable)
                            storedPanelFraction = Double(
                                draggedPanelFraction(base: base, translation: value.translation.width, usable: usable))
                        }
                        restartHideTimer()
                    }
            )
            .onTapGesture(count: 2) { resetPanelWidth() }
            // The handle covers the video's rightmost 32 pt, so a single tap there still shows or hides the controls.
            .onTapGesture { toggleControls() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Subtitle panel width")
            .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = direction == .increment ? 0.05 : -0.05
                storedPanelFraction = Double(clampedPanelFraction(fraction + step, usable: usable))
                restartHideTimer()
            }
            .accessibilityAction(named: "Reset subtitle panel width") { resetPanelWidth() }
            .accessibilityIdentifier("player.panelHandle")
    }

    /// The landscape subtitle panel: problem banner, a compact Make a Card, then the cue list.
    /// It stays open when the overlay controls auto-hide. Its background runs to the screen edge.
    private func sidePanel(_ model: PlayerModel, width: CGFloat, insets: EdgeInsets) -> some View {
        VStack(spacing: 0) {
            if let subtitleProblem {
                ErrorBanner(message: subtitleProblem, actionTitle: "Choose subtitles") { showSubtitlePicker = true }
                    .padding(Spacing.s)
            }
            // Full label when it fits, icon only on a very narrow panel.
            ViewThatFits(in: .horizontal) {
                makeCardButton(model, fullWidth: true, identifier: "player.panel.makeCard")
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(1)
                makeCardButton(model, fullWidth: true, iconOnly: true, identifier: "player.panel.makeCard")
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            CuePanel(model: model, compact: true)
        }
        .padding(.top, insets.top)
        .padding(.bottom, insets.bottom)
        .padding(.trailing, insets.trailing)
        .frame(width: width)
        .background(Theme.panel)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("player.sidePanel")
    }

    /// Landscape top bar: back, episode title, and the button that opens or closes the subtitle panel.
    private func topBar(insets: EdgeInsets) -> some View {
        HStack(spacing: Spacing.s) {
            Button { dismiss() } label: { Image(systemName: "chevron.left") }
                .buttonStyle(DeckIconButtonStyle())
                .accessibilityLabel("Back")
                .accessibilityIdentifier("player.back")
            Text(episode.title)
                .font(.deckHeadline)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                showSidePanel.toggle()
                restartHideTimer()
            } label: { Image(systemName: "sidebar.right") }
                .buttonStyle(DeckIconButtonStyle(isActive: showSidePanel))
                .accessibilityLabel(showSidePanel ? "Hide subtitle list" : "Show subtitle list")
                .accessibilityIdentifier("player.panelToggle")
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .padding(.top, insets.top)
        .padding(.leading, insets.leading)
        .padding(.trailing, insets.trailing)
        .background(Color.black.opacity(0.55))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("player.topBar")
    }

    /// Landscape bottom bar: scrubber, then transport and Make a Card on one row.
    private func bottomBar(_ model: PlayerModel, insets: EdgeInsets) -> some View {
        VStack(spacing: Spacing.xs) {
            Scrubber(model: model)
            // With the side list open there is less room: fall back to an icon-only Make a Card, and with the
            // panel near its 50 % maximum also drop the ±5 s skips (the scrubber still seeks). The last row needs
            // about 245 pt; at 50 % on an 874 pt wide iPhone the row gets about 320 pt (column 438 minus insets and padding).
            ViewThatFits(in: .horizontal) {
                bottomRow(model, iconOnly: false)
                bottomRow(model, iconOnly: true)
                bottomRow(model, iconOnly: true, skips: false)
            }
            if let miningError {
                ErrorBanner(message: miningError)
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .padding(.bottom, insets.bottom)
        .padding(.leading, insets.leading)
        .padding(.trailing, insets.trailing)
        .background(Color.black.opacity(0.55))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("player.bottomBar")
    }

    private func bottomRow(_ model: PlayerModel, iconOnly: Bool, skips: Bool = true) -> some View {
        HStack(spacing: Spacing.s) {
            transportButtons(model, landscape: true, skips: skips)
            Spacer(minLength: Spacing.s)
            makeCardButton(model, fullWidth: false, iconOnly: iconOnly)
        }
    }

    /// The video with its subtitle line. `onTap` differs by orientation: play/pause or show/hide controls.
    private func videoScreen(
        _ model: PlayerModel,
        subtitleMargins: SubtitleMargins = SubtitleMargins(
            top: Spacing.s, leading: Spacing.l, bottom: Spacing.m, trailing: Spacing.l),
        subtitleTopObstruction: CGFloat = 0,
        subtitleBottomObstruction: CGFloat = 0,
        subtitleStepsFromCard: Bool = false,
        badgeTopPadding: CGFloat = 0,
        edgeInsets: EdgeInsets = EdgeInsets(),
        onTap: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .bottom) {
            PlayerLayerView(player: model.player)
                .accessibilityIdentifier("player.video")
                .onTapGesture(perform: onTap)
        }
        // The line is an overlay, so it takes the video's size and never changes the video's layout.
        .overlay {
            if let cue = model.currentCue {
                subtitleLine(
                    cue.text, margins: subtitleMargins,
                    topObstruction: subtitleTopObstruction, bottomObstruction: subtitleBottomObstruction,
                    stepsFromCard: subtitleStepsFromCard)
            }
        }
        // The recording badge is drawn after (above) the line, so a line moved up and left can't cover it.
        .overlay {
            if let miningRange {
                RecordingBadge(range: miningRange)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, badgeTopPadding)
                    .padding(.leading, edgeInsets.leading)
                    .padding(Spacing.s)
            }
        }
        .background { Color.black }
        .clipped()
    }

    /// The line on the video, drawn in the saved style and placed by `SubtitlePlacement` (it stays inside the
    /// video, below the top bar and above the bottom bar while they show).
    private func subtitleLine(
        _ text: String, margins: SubtitleMargins, topObstruction: CGFloat, bottomObstruction: CGFloat,
        stepsFromCard: Bool
    ) -> some View {
        _ = dynamicTypeSize
        let style = SubtitleStyle.decoded(from: storedSubtitleStyle)
        return GeometryReader { geometry in
            let regionHeight = max(0, geometry.size.height - margins.top - margins.bottom)
            SubtitleLineLayout(
                style: style, margins: margins, topObstruction: topObstruction, bottomObstruction: bottomObstruction,
                stepsFromObstruction: stepsFromCard
            ) {
                SelectableText(
                    text: text, textStyle: .title3, weight: .bold, color: .white, outlined: true,
                    font: style.uiFont(regionHeight: regionHeight), hugsWidth: true, identifier: "player.subtitle")
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .animation(.easeInOut(duration: 0.2), value: bottomObstruction)
        .animation(.easeInOut(duration: 0.2), value: topObstruction)
    }

    // MARK: Overlay timing

    private var controlsShown: Bool { controlsVisible || voiceOverOn }

    /// While any of these hold, the controls never auto-hide.
    private var keepsControlsUp: Bool {
        let dialogs = showOffset || showSubtitlePicker || showStyleSheet || subtitleDialogOpen || draft != nil
        let styleMenu = styleMenuOpen || showCardFontPicker
        let busy = miningRange != nil || panelDrag != nil || !(model?.isPlaying ?? false) || (model?.isScrubbing ?? false)
        return voiceOverOn || dialogs || styleMenu || busy
    }

    /// The card rises from the bottom while fading in, or only fades under Reduce Motion; it leaves the same way.
    private var styleCardTransition: AnyTransition {
        reduceMotion ? AnyTransition.opacity : AnyTransition.move(edge: .bottom).combined(with: AnyTransition.opacity)
    }

    private func toggleControls() {
        // A tap on the video while the card is open only closes the card; the controls stay.
        if styleMenuOpen {
            closeStyleMenu()
            return
        }
        controlsVisible.toggle()
        restartHideTimer()
    }

    /// Closes the landscape style card (Done, or a tap on the video) and restarts the hide countdown.
    private func closeStyleMenu() {
        styleMenuOpen = false
        restartHideTimer()
    }

    private func restartHideTimer() {
        hideTask?.cancel()
        hideTask = nil
        guard isLandscape, controlsVisible, !keepsControlsUp else { return }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            controlsVisible = false
        }
    }

    private func controls(_ model: PlayerModel) -> some View {
        VStack(spacing: Spacing.s) {
            Scrubber(model: model)
            HStack(spacing: Spacing.s) {
                transportButtons(model, landscape: false)
                Spacer(minLength: 0)
            }
            makeCardButton(model, fullWidth: true)
            if let miningError {
                ErrorBanner(message: miningError)
            }
        }
    }

    /// Skip buttons restart the landscape auto-hide countdown (no-op in portrait). The other controls
    /// already do it through state changes: play/pause, scrubbing, the offset sheet, the subtitles dialog.
    /// `skips: false` leaves out the ±5 s buttons (the tightest landscape bar).
    @ViewBuilder
    private func transportButtons(_ model: PlayerModel, landscape: Bool, skips: Bool = true) -> some View {
        if skips {
            Button { model.skip(byMs: -5_000); restartHideTimer() } label: { Image(systemName: "gobackward.5") }
                .buttonStyle(DeckIconButtonStyle())
                .accessibilityLabel("Back 5 seconds")
        }
        Button { model.togglePlay() } label: { Image(systemName: model.isPlaying ? "pause.fill" : "play.fill") }
            .buttonStyle(DeckIconButtonStyle(isActive: true))
            .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
            .accessibilityIdentifier("player.playPause")
        if skips {
            Button { model.skip(byMs: 5_000); restartHideTimer() } label: { Image(systemName: "goforward.5") }
                .buttonStyle(DeckIconButtonStyle())
                .accessibilityLabel("Forward 5 seconds")
        }
        Button { showOffset = true } label: {
            Text(TimeFormat.offset(model.offsetMs))
                .font(.deckCaption)
                .lineLimit(1)
                .frame(width: 60)
        }
        .buttonStyle(DeckIconButtonStyle(isActive: model.offsetMs != 0))
        .frame(width: 60)
        .accessibilityLabel("Subtitle offset \(TimeFormat.offset(model.offsetMs))")
        .accessibilityIdentifier("player.offset")
        if landscape {
            // Same identifier as the portrait Menu; opens the landscape dialog (see `landscape(_:insets:)`).
            Button { subtitleDialogOpen = true } label: { Image(systemName: "captions.bubble.fill") }
                .buttonStyle(DeckIconButtonStyle())
                .accessibilityLabel("Subtitles")
                .accessibilityIdentifier("player.subtitlesMenu")
        } else {
            Menu {
                Button("Load different subtitles", systemImage: "captions.bubble") { showSubtitlePicker = true }
            } label: {
                Image(systemName: "captions.bubble.fill")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .background(Theme.shell, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            }
            .accessibilityLabel("Subtitles")
            .accessibilityIdentifier("player.subtitlesMenu")
        }
        // Directly after the subtitles button, in portrait and in all landscape rows. A Button with a presented
        // state, not a Menu: gestures on a Menu don't fire on iOS 26. Aqua when the style isn't the default.
        let styleIsDefault = SubtitleStyle.decoded(from: storedSubtitleStyle).isDefault
        Button {
            // Landscape opens the card in place of the bottom bar; portrait presents the sheet.
            if landscape { styleMenuOpen = true } else { showStyleSheet = true }
            restartHideTimer()
        } label: { Image(systemName: "textformat") }
            .buttonStyle(DeckIconButtonStyle(isActive: !styleIsDefault))
            .accessibilityLabel("Subtitle style")
            .accessibilityValue(styleIsDefault ? "Default" : "Changed")
            .accessibilityIdentifier("player.subtitleStyle")
    }

    private func makeCardButton(
        _ model: PlayerModel, fullWidth: Bool, iconOnly: Bool = false, identifier: String = "player.makeCard"
    ) -> some View {
        Button {
            Task { await makeCard(model) }
        } label: {
            Label(miningRange == nil ? "Make a Card" : "Recording…", systemImage: "rectangle.stack.badge.plus")
                .labelStyle(MakeCardLabelStyle(iconOnly: iconOnly))
                .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .accessibilityLabel(miningRange == nil ? "Make a Card" : "Recording")
        .buttonStyle(DeckPrimaryButtonStyle())
        .disabled(miningRange != nil || model.track.isEmpty)
        .accessibilityIdentifier(identifier)
    }

    // MARK: Actions

    private func setUp() {
        guard model == nil else { return }
        let newModel = PlayerModel(
            videoURL: store.absoluteURL(episode.videoPath),
            track: loadTrack(),
            offsetMs: episode.offsetMs,
            startAtMs: episode.lastPositionMs
        )
        model = newModel
    }

    private func reloadSubtitles() {
        model?.replaceTrack(loadTrack())
    }

    /// Loads the episode's subtitle file, recording a clear problem message if it can't.
    private func loadTrack() -> CueTrack {
        subtitleProblem = nil
        guard let path = episode.subtitlePath else {
            subtitleProblem = "No subtitles are assigned to this episode yet."
            return .empty
        }
        guard store.exists(path) else {
            let name = (path as NSString).lastPathComponent
            subtitleProblem = "Subtitle file “\(name)” is missing. It should be in \(store.locationDescription(ofRelativePath: path))."
            return .empty
        }
        do {
            return CueTrack(cues: try SubtitleParser.parse(contentsOf: store.absoluteURL(path)))
        } catch {
            subtitleProblem = error.localizedDescription
            return .empty
        }
    }

    /// Make a Card: jump to the line's start, play it to the end while cutting the audio and
    /// screenshot from the file, then open the card editor.
    private func makeCard(_ model: PlayerModel) async {
        miningError = nil
        guard let cue = model.cueForCard else {
            miningError = "There's no subtitle line at this point. Play to a line, or tap one in the list."
            return
        }
        let range = ClipMath.range(of: cue, offsetMs: model.offsetMs)
        let id = UUID()
        let videoURL = store.absoluteURL(episode.videoPath)
        let extractor = ClipExtractor(
            startPaddingMs: settings.anki.audioPaddingStartMs,
            endPaddingMs: settings.anki.audioPaddingEndMs
        )
        miningRange = range

        let extraction = Task {
            try await CardDraft.recordMedia(id: id, videoURL: videoURL, range: range, extractor: extractor, store: store)
        }
        await model.playSegment(range)
        let media = await extraction.result
        miningRange = nil

        switch media {
        case .success(let hasImage):
            draft = CardDraft(
                id: id,
                showName: episode.show?.name ?? "",
                episodeTitle: episode.title,
                range: range,
                sentence: ClipMath.sentence(for: range, track: model.track, offsetMs: model.offsetMs),
                hasImage: hasImage
            )
        case .failure(let error):
            miningError = error.localizedDescription
        }
    }
}

// MARK: - Pieces

/// Red "recording" chip shown over the video while a clip is being captured.
private struct RecordingBadge: View {
    let range: ClipRange

    var body: some View {
        Label("\(TimeFormat.clock(range.startMs)) – \(TimeFormat.clock(range.endMs))", systemImage: "record.circle.fill")
            .font(.deckCaption)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(Theme.danger, in: Capsule())
            .accessibilityLabel("Recording clip")
    }
}

private struct MakeCardLabelStyle: LabelStyle {
    let iconOnly: Bool

    func makeBody(configuration: Configuration) -> some View {
        if iconOnly {
            configuration.icon
        } else {
            Label(configuration)
        }
    }
}

private extension View {
    /// Writes this view's height into `height` whenever it changes.
    func measuredHeight(_ height: Binding<CGFloat>) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.onChange(of: proxy.size.height, initial: true) { _, value in height.wrappedValue = value }
            }
        }
    }
}

private struct Scrubber: View {
    @Bindable var model: PlayerModel
    @State private var dragValue: Double = 0

    var body: some View {
        HStack(spacing: Spacing.s) {
            Text(TimeFormat.clock(model.isScrubbing ? Int(dragValue) : model.currentMs))
                .font(.deckTime)
                .foregroundStyle(Theme.inkSoft)
            Slider(
                value: Binding(
                    get: { model.isScrubbing ? dragValue : Double(model.currentMs) },
                    set: { dragValue = $0 }
                ),
                in: 0...Double(max(model.durationMs, 1)),
                onEditingChanged: { editing in
                    if editing {
                        dragValue = Double(model.currentMs)
                        model.isScrubbing = true
                    } else {
                        model.isScrubbing = false
                        Task { await model.seek(toMs: Int(dragValue)) }
                    }
                }
            )
            .accessibilityLabel("Playback position")
            Text(TimeFormat.clock(model.durationMs))
                .font(.deckTime)
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

/// Every subtitle line in order; the current one is highlighted. Tap a line to jump to it.
struct CuePanel: View {
    let model: PlayerModel
    /// Compact rows (time above the text, tighter padding) for the narrow landscape panel.
    var compact = false

    var body: some View {
        if model.track.isEmpty {
            ContentUnavailableView(
                "No subtitle lines",
                systemImage: "captions.bubble",
                description: Text("Choose a subtitle file from the subtitles menu.")
            )
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(model.track.cues) { cue in
                            CueRow(cue: cue, offsetMs: model.offsetMs, isCurrent: cue.id == model.currentCueIndex, compact: compact)
                                .id(cue.id)
                                .onTapGesture { model.seek(to: cue) }
                                // One element per line (time + text), so VoiceOver and UI tests see a single button.
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier("cue.row.\(cue.id)")
                        }
                    }
                    .padding(.vertical, Spacing.s)
                }
                .onChange(of: model.currentCueIndex) { _, index in
                    guard let index else { return }
                    withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(index, anchor: .center) }
                }
            }
        }
    }
}

private struct CueRow: View {
    let cue: SubtitleCue
    let offsetMs: Int
    let isCurrent: Bool
    var compact = false

    private var timeText: some View {
        Text(TimeFormat.clock(cue.startMs + offsetMs))
            .font(.deckTime)
            .foregroundStyle(isCurrent ? .white.opacity(0.85) : Theme.inkSoft)
    }

    private var lineText: some View {
        Text(cue.text)
            .font(.deckBody)
            .foregroundStyle(isCurrent ? .white : Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 2) {
                    timeText
                    lineText
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                    timeText.frame(width: 56, alignment: .leading)
                    lineText
                }
            }
        }
        .padding(.horizontal, compact ? Spacing.s : Spacing.m)
        .padding(.vertical, compact ? Spacing.xs : Spacing.s)
        .background(
            isCurrent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.clear),
            in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
        )
        .padding(.horizontal, compact ? Spacing.xs : Spacing.s)
        .contentShape(Rectangle())
    }
}

/// Offset control: nudge subtitles earlier or later until they match the speech.
private struct OffsetSheet: View {
    let model: PlayerModel
    let onChange: (Int) -> Void

    var body: some View {
        VStack(spacing: Spacing.l) {
            Text("Subtitle offset")
                .font(.deckTitle)
                .foregroundStyle(Theme.ink)
            Text(TimeFormat.offset(model.offsetMs))
                .font(.system(.largeTitle, design: .rounded, weight: .heavy).monospacedDigit())
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText())
                .accessibilityIdentifier("offset.value")
            Text("Later shows subtitles after the speech; earlier shows them before.")
                .font(.deckCallout)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            HStack(spacing: Spacing.s) {
                nudge("−1 s", -1_000)
                nudge("−0.1 s", -100)
                nudge("+0.1 s", 100)
                nudge("+1 s", 1_000)
            }
            Button("Reset to 0") { set(0) }
                .font(.deckHeadline)
                .disabled(model.offsetMs == 0)
        }
        .padding(Spacing.xl)
        .presentationDetents([.height(320)])
        .presentationBackground(Theme.panel)
    }

    private func nudge(_ title: String, _ delta: Int) -> some View {
        Button(title) { set(model.offsetMs + delta) }
            .font(.deckHeadline)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.shell, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .accessibilityIdentifier("offset.\(delta)")
    }

    private func set(_ value: Int) {
        withAnimation { model.offsetMs = value }
        onChange(value)
    }
}
