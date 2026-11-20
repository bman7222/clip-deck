import SwiftUI
import UIKit

/// The video half of the upload sheet and of "Choose the video again" (spec › Import, files and lifecycle; J-1, J-5
/// to J-7). It prepares a picked file through `EpisodeImporter`, holds the audio-track choice, and runs the import
/// with progress and Cancel, keeping the screen awake and asking iOS for background time while it runs.
///
/// Every import goes through `EpisodeImporter`; this model never copies files itself.
@Observable
final class VideoImportModel {
    /// Where the picked video is in its check.
    enum Status: Equatable {
        /// Nothing picked yet.
        case empty
        /// `prepare` is running; the stage is nil until the importer reports one (MP4 usually finishes first).
        case preparing(PrepareStage?)
        /// Prepared and usable (the audio choice may still fail: see `videoError`).
        case ready
        /// The file can't be used; `videoError` says why.
        case failed
    }

    /// How a run ended, for the view to react to.
    enum Outcome {
        case added(EpisodeImportResult)
        /// The user tapped Cancel. Nothing was added and nothing is shown.
        case cancelled
        /// A message for the `ErrorBanner`. Nothing was added.
        case failed(String)
    }

    /// Spec J-5: shown when iOS ends the background time while a conversion runs.
    static let backgroundExpiredMessage = "Conversion stopped. Keep Clip Deck open until it finishes."

    @ObservationIgnored let importer: EpisodeImporter

    /// The picked file's name, shown in the Video row (also for a refused file, next to its message).
    private(set) var fileName: String?
    private(set) var status: Status = .empty
    /// The prepared file, held open until it is imported, another file is picked, or the screen goes away.
    private(set) var prepared: PreparedVideo?
    /// The chosen audio track (a `MediaProbe.Audio.streamIndex`); starts at the prepared default.
    private(set) var selectedAudio: Int?
    /// The chosen embedded subtitle track (an `EmbeddedSubtitleTrack.streamIndex`); nil = "None". Starts at the
    /// prepared default.
    private(set) var selectedSubtitle: Int?
    /// Why this video can't be added (prepare or audio-plan failure). Add stays disabled while it is set.
    private(set) var videoError: String?

    private(set) var isRunning = false
    /// 0...1 while running.
    private(set) var progress: Double = 0
    /// True while an MKV converts ("Converting… n%"); false for a plain copy ("Adding…").
    private(set) var isConverting = false

    @ObservationIgnored private var prepareTask: Task<Void, Never>?
    @ObservationIgnored private var prepareToken: UUID?
    @ObservationIgnored private var runTask: Task<Void, Never>?
    @ObservationIgnored private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    @ObservationIgnored private var idleTimerWasDisabled = false
    @ObservationIgnored private var backgroundTimeExpired = false

    init(importer: EpisodeImporter = EpisodeImporter()) {
        self.importer = importer
    }

    // MARK: Derived state

    /// The prepared file can be imported now with the current audio choice.
    var canImport: Bool { status == .ready && prepared != nil && videoError == nil && !isRunning }

    var isPreparing: Bool {
        if case .preparing = status { return true }
        return false
    }

    /// The status line under the Video row while `prepare` runs.
    var preparingText: String {
        guard case .preparing(let stage) = status else { return "" }
        switch stage {
        case .downloadingFromICloud: return "Downloading from iCloud…"
        case .probing: return "Reading the video…"
        case nil: return "Opening the video…"
        }
    }

    /// The audio tracks to choose from; the picker shows only when there are two or more.
    var audioTracks: [MediaProbe.Audio] { prepared?.audioTracks ?? [] }

    func audioLabel(for track: MediaProbe.Audio) -> String {
        prepared?.label(for: track) ?? ConversionPlan.displayName(ofCodec: track.codec)
    }

    /// "Converting… 42%" for an MKV, "Adding…" for a copy.
    var progressText: String {
        isConverting ? "Converting… \(Int((progress * 100).rounded(.down)))%" : "Adding…"
    }

    /// The text tracks to offer in the "Embedded subtitles" picker. Empty (row hidden) for MP4/MOV/M4V, an MKV
    /// without subtitle tracks, or one with pictures only.
    var usableSubtitleTracks: [EmbeddedSubtitleTrack] { prepared?.usableSubtitleTracks ?? [] }

    /// Tracks that can't be used (pictures, unwritable formats); shown greyed out, never selectable. Only listed
    /// when there is something usable to choose from.
    var unusableSubtitleTracks: [EmbeddedSubtitleTrack] {
        guard !usableSubtitleTracks.isEmpty else { return [] }
        return (prepared?.subtitleTracks ?? []).filter { !$0.isUsable }
    }

    /// Every usable text track is saved (so each shows under "Load different subtitles"); the picker only decides
    /// which one the episode starts with.
    var options: EpisodeImportOptions {
        EpisodeImportOptions(
            audioStreamIndex: selectedAudio,
            embeddedSubtitleStreams: prepared?.usableSubtitleStreamIndices ?? [],
            chosenSubtitleStream: selectedSubtitle)
    }

    // MARK: Picking and preparing

    /// Starts checking a picked file, replacing (and closing) any earlier one. Unsupported extensions are refused
    /// at once; everything else goes through `EpisodeImporter.prepare`. `onReady` runs once the file is usable.
    func pick(_ url: URL, onReady: (() -> Void)? = nil) {
        clear()
        fileName = url.lastPathComponent
        guard EpisodeImporter.isSupportedVideo(url) else {
            status = .failed
            videoError = EpisodeImportError.unsupportedVideoType(url.pathExtension.lowercased()).localizedDescription
            return
        }
        status = .preparing(nil)
        let token = UUID()
        prepareToken = token
        let importer = self.importer
        // Strong captures: the task is short and is cancelled by a new pick or by leaving the screen.
        prepareTask = Task {
            do {
                let prepared = try await importer.prepare(url) { stage in
                    guard self.prepareToken == token else { return }
                    self.status = .preparing(stage)
                }
                // A newer pick (or leaving the screen) replaced this one while it was preparing.
                guard self.prepareToken == token, !Task.isCancelled else {
                    prepared.close()
                    return
                }
                self.prepared = prepared
                self.selectedAudio = prepared.defaultAudioStreamIndex
                self.selectedSubtitle = prepared.defaultSubtitleStreamIndex
                self.status = .ready
                self.prepareTask = nil
                self.checkPlan()
                if self.videoError == nil { onReady?() }
            } catch is CancellationError {
                // Cancelled by a newer pick or by leaving: nothing to show.
            } catch {
                guard self.prepareToken == token else { return }
                self.status = .failed
                self.videoError = error.localizedDescription
                self.prepareTask = nil
            }
        }
    }

    /// The audio picker's choice. Re-checks the plan: a track that can't be used shows its message and keeps Add
    /// disabled.
    func selectAudio(_ streamIndex: Int) {
        guard streamIndex != selectedAudio else { return }
        selectedAudio = streamIndex
        checkPlan()
    }

    /// The "Embedded subtitles" picker's choice; nil is "None".
    func selectSubtitle(_ streamIndex: Int?) {
        selectedSubtitle = streamIndex
    }

    private func checkPlan() {
        guard let prepared else { return }
        do {
            _ = try prepared.plan(for: options)
            videoError = nil
        } catch {
            videoError = error.localizedDescription
        }
    }

    /// Forgets the picked file: cancels a running prepare and closes the prepared file. Does not stop a run.
    func clear() {
        prepareTask?.cancel()
        prepareTask = nil
        prepareToken = nil
        prepared?.close()
        prepared = nil
        selectedAudio = nil
        selectedSubtitle = nil
        videoError = nil
        fileName = nil
        status = .empty
    }

    /// The screen is going away: stop everything and close the file.
    func leave() {
        runTask?.cancel()
        clear()
    }

    // MARK: Running the import

    /// Runs `work` (an `importEpisode` or `relink` call) with the prepared file and the current options. While it
    /// runs the screen stays awake and a background task covers short trips out of the app; if iOS ends that time,
    /// the run is cancelled and ends with `backgroundExpiredMessage`. `completion` gets the outcome on the main
    /// actor after the idle timer has been restored.
    func run(
        _ work: @escaping @MainActor (EpisodeImporter, PreparedVideo, EpisodeImportOptions,
                                      @escaping @MainActor (Double) -> Void) async throws -> EpisodeImportResult,
        completion: @escaping @MainActor (Outcome) -> Void
    ) {
        guard canImport, let prepared else { return }
        isRunning = true
        isConverting = prepared.needsConversion
        progress = 0
        backgroundTimeExpired = false

        let application = UIApplication.shared
        idleTimerWasDisabled = application.isIdleTimerDisabled
        application.isIdleTimerDisabled = true
        backgroundTask = application.beginBackgroundTask(withName: "Clip Deck import") { [weak self] in
            MainActor.assumeIsolated { self?.backgroundTimeRanOut() }
        }

        let importer = self.importer
        let options = self.options
        runTask = Task {
            let outcome: Outcome
            do {
                let result = try await work(importer, prepared, options) { value in
                    self.progress = min(max(value, 0), 1)
                }
                outcome = .added(result)
            } catch {
                if self.backgroundTimeExpired {
                    outcome = .failed(Self.backgroundExpiredMessage)
                } else if error is CancellationError || Task.isCancelled {
                    outcome = .cancelled
                } else {
                    outcome = .failed(error.localizedDescription)
                }
            }
            self.finishRun()
            completion(outcome)
        }
    }

    /// The Cancel button while running: the importer stops within about a second and adds nothing.
    func cancelRun() {
        runTask?.cancel()
    }

    private func backgroundTimeRanOut() {
        backgroundTimeExpired = true
        runTask?.cancel()
        // iOS ends the app if the task isn't ended here; the cancelled run finishes when the app is back.
        endBackgroundTask()
    }

    private func finishRun() {
        UIApplication.shared.isIdleTimerDisabled = idleTimerWasDisabled
        endBackgroundTask()
        runTask = nil
        isRunning = false
        // A successful import closes the file; keep the state in step so Add can't be tapped again.
        if let prepared, !prepared.access.isOpen {
            self.prepared = nil
            status = .empty
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
