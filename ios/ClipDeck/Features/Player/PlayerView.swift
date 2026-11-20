import SwiftData
import SwiftUI

/// Episode player. Portrait is laid out like a 3DS: video is the "top screen", and the controls
/// plus the subtitle list form the "bottom screen". In landscape the list is a side pop-out.
struct PlayerView: View {
    @Bindable var episode: Episode
    @Environment(\.modelContext) private var context
    @Environment(SettingsStore.self) private var settings

    @State private var model: PlayerModel?
    @State private var subtitleProblem: String?
    @State private var showSidePanel = false
    @State private var showOffset = false
    @State private var showSubtitlePicker = false
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn

    private let store = FileStore.live

    var body: some View {
        Group {
            if let model {
                GeometryReader { geometry in
                    if geometry.size.width > geometry.size.height {
                        landscape(model, insets: geometry.safeAreaInsets)
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
                    hideTask?.cancel()
                }
            }
        }
        .navigationTitle(episode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.shell, for: .navigationBar)
        .toolbar(isLandscape ? .hidden : .automatic, for: .navigationBar)
        .statusBarHidden(isLandscape && !controlsShown)
        .persistentSystemOverlays(isLandscape ? .hidden : .automatic)
        .onChange(of: model?.isPlaying) { _, playing in
            // Pausing (or a finished clip) brings the controls back; playing starts the countdown.
            if isLandscape, playing == false { controlsVisible = true }
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

    private func landscape(_ model: PlayerModel, insets: EdgeInsets) -> some View {
        let shown = controlsShown
        return HStack(spacing: 0) {
            ZStack {
                videoScreen(
                    model,
                    subtitleBottomPadding: shown ? bottomBarHeight + insets.bottom + Spacing.s : Spacing.m + insets.bottom,
                    badgeTopPadding: shown ? topBarHeight + insets.top + Spacing.s : insets.top,
                    edgeInsets: EdgeInsets(
                        top: 0, leading: insets.leading,
                        bottom: 0, trailing: showSidePanel ? 0 : insets.trailing
                    ),
                    onTap: toggleControls
                )
                .ignoresSafeArea(edges: showSidePanel ? [.vertical, .leading] : .all)

                // Rendered only while shown, so the accessibility tree matches the screen.
                if shown {
                    VStack(spacing: 0) {
                        topBar
                            .measuredHeight($topBarHeight)
                        Spacer(minLength: 0)
                        bottomBar(model)
                            .measuredHeight($bottomBarHeight)
                    }
                    .environment(\.colorScheme, .dark)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: shown)
            if showSidePanel {
                VStack(spacing: 0) {
                    if let subtitleProblem {
                        ErrorBanner(message: subtitleProblem, actionTitle: "Choose subtitles") { showSubtitlePicker = true }
                            .padding(Spacing.s)
                    }
                    CuePanel(model: model)
                }
                .frame(width: 320)
                .background(Theme.panel)
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(duration: 0.3), value: showSidePanel)
        // Landscape uses a dialog, not a Menu: gestures on a Menu don't fire on iOS 26, so an open Menu
        // can't be tracked and the auto-hide would tear it down. The dialog's binding clears on any dismissal.
        .confirmationDialog("Subtitles", isPresented: $subtitleDialogOpen, titleVisibility: .hidden) {
            Button("Load different subtitles") { showSubtitlePicker = true }
            Button(showSidePanel ? "Hide subtitle list" : "Show subtitle list") { showSidePanel.toggle() }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// Landscape top bar: back, episode title, and an empty trailing slot (filled by the panel button later).
    private var topBar: some View {
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
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(Color.black.opacity(0.55).ignoresSafeArea(edges: [.top, .horizontal]))
    }

    /// Landscape bottom bar: scrubber, then transport and Make a Card on one row.
    private func bottomBar(_ model: PlayerModel) -> some View {
        VStack(spacing: Spacing.xs) {
            Scrubber(model: model)
            // With the side list open there is less room: fall back to an icon-only Make a Card.
            ViewThatFits(in: .horizontal) {
                bottomRow(model, iconOnly: false)
                bottomRow(model, iconOnly: true)
            }
            if let miningError {
                ErrorBanner(message: miningError)
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(Color.black.opacity(0.55).ignoresSafeArea(edges: [.bottom, .horizontal]))
    }

    private func bottomRow(_ model: PlayerModel, iconOnly: Bool) -> some View {
        HStack(spacing: Spacing.s) {
            transportButtons(model, landscape: true)
            Spacer(minLength: Spacing.s)
            makeCardButton(model, fullWidth: false, iconOnly: iconOnly)
        }
    }

    /// The video with its subtitle line. `onTap` differs by orientation: play/pause or show/hide controls.
    private func videoScreen(
        _ model: PlayerModel,
        subtitleBottomPadding: CGFloat = Spacing.m,
        badgeTopPadding: CGFloat = 0,
        edgeInsets: EdgeInsets = EdgeInsets(),
        onTap: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .bottom) {
            PlayerLayerView(player: model.player)
                .accessibilityIdentifier("player.video")
                .onTapGesture(perform: onTap)
            if let cue = model.currentCue {
                SelectableText(text: cue.text, textStyle: .title3, weight: .bold, color: .white, outlined: true, identifier: "player.subtitle")
                    .padding(.horizontal, Spacing.l)
                    .padding(.leading, edgeInsets.leading)
                    .padding(.trailing, edgeInsets.trailing)
                    .padding(.bottom, subtitleBottomPadding)
                    .animation(.easeInOut(duration: 0.2), value: subtitleBottomPadding)
            }
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

    // MARK: Overlay timing

    private var controlsShown: Bool { controlsVisible || voiceOverOn }

    /// While any of these hold, the controls never auto-hide.
    private var keepsControlsUp: Bool {
        voiceOverOn || showOffset || showSubtitlePicker || subtitleDialogOpen || draft != nil
            || !(model?.isPlaying ?? false) || (model?.isScrubbing ?? false)
    }

    private func toggleControls() {
        controlsVisible.toggle()
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
    @ViewBuilder
    private func transportButtons(_ model: PlayerModel, landscape: Bool) -> some View {
        Button { model.skip(byMs: -5_000); restartHideTimer() } label: { Image(systemName: "gobackward.5") }
            .buttonStyle(DeckIconButtonStyle())
            .accessibilityLabel("Back 5 seconds")
        Button { model.togglePlay() } label: { Image(systemName: model.isPlaying ? "pause.fill" : "play.fill") }
            .buttonStyle(DeckIconButtonStyle(isActive: true))
            .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
            .accessibilityIdentifier("player.playPause")
        Button { model.skip(byMs: 5_000); restartHideTimer() } label: { Image(systemName: "goforward.5") }
            .buttonStyle(DeckIconButtonStyle())
            .accessibilityLabel("Forward 5 seconds")
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
                Button(showSidePanel ? "Hide subtitle list" : "Show subtitle list", systemImage: "sidebar.right") { showSidePanel.toggle() }
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
    }

    private func makeCardButton(_ model: PlayerModel, fullWidth: Bool, iconOnly: Bool = false) -> some View {
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
        .accessibilityIdentifier("player.makeCard")
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
                            CueRow(cue: cue, offsetMs: model.offsetMs, isCurrent: cue.id == model.currentCueIndex)
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

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
            Text(TimeFormat.clock(cue.startMs + offsetMs))
                .font(.deckTime)
                .foregroundStyle(isCurrent ? .white.opacity(0.85) : Theme.inkSoft)
                .frame(width: 56, alignment: .leading)
            Text(cue.text)
                .font(.deckBody)
                .foregroundStyle(isCurrent ? .white : Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(
            isCurrent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.clear),
            in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
        )
        .padding(.horizontal, Spacing.s)
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
