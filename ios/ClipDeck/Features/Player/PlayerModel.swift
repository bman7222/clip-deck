@preconcurrency import AVFoundation
import Observation

/// Playback state for one episode: time, current subtitle, offset, and timed segment playback
/// (used by Make a Card to play exactly the clip being recorded).
@Observable
final class PlayerModel {
    let player: AVPlayer
    private(set) var track: CueTrack
    /// Added to subtitle times. Positive = subtitles appear later.
    var offsetMs: Int {
        didSet { updateCurrentCue() }
    }
    private(set) var currentMs = 0
    private(set) var durationMs = 0
    private(set) var isPlaying = false
    private(set) var currentCueIndex: Int?
    /// While true, time updates don't move the scrubber (the user is dragging it).
    var isScrubbing = false

    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var segmentEndMs: Int?
    @ObservationIgnored private var segmentContinuation: CheckedContinuation<Void, Never>?

    init(videoURL: URL, track: CueTrack, offsetMs: Int, startAtMs: Int = 0) {
        self.player = AVPlayer(url: videoURL)
        self.track = track
        self.offsetMs = offsetMs
        player.actionAtItemEnd = .pause
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 20),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time) }
        }
        Task { await loadDuration(resumeAt: startAtMs) }
    }

    /// Call when the player screen goes away; stops playback and the time observer.
    func tearDown() {
        finishSegment()
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
    }

    // MARK: Subtitles

    var currentCue: SubtitleCue? { currentCueIndex.map { track.cues[$0] } }

    /// Subtitle-clock time for the current video position.
    var subtitleMs: Int { currentMs - offsetMs }

    func replaceTrack(_ newTrack: CueTrack) {
        track = newTrack
        updateCurrentCue()
    }

    /// The cue to mine: the one on screen, else the most recent one before now.
    var cueForCard: SubtitleCue? {
        if let currentCue { return currentCue }
        return track.lastIndex(startingAtOrBefore: subtitleMs).map { track.cues[$0] }
    }

    func seek(to cue: SubtitleCue) {
        Task { await seek(toMs: cue.startMs + offsetMs) }
    }

    // MARK: Transport

    func togglePlay() { isPlaying ? pause() : play() }

    func play() {
        if durationMs > 0, currentMs >= durationMs - 100 {
            Task { await seek(toMs: 0); player.play() }
        } else {
            player.play()
        }
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
        finishSegment()
    }

    func skip(byMs delta: Int) {
        Task { await seek(toMs: currentMs + delta) }
    }

    func seek(toMs ms: Int) async {
        let clamped = max(0, durationMs > 0 ? min(ms, durationMs) : ms)
        currentMs = clamped
        updateCurrentCue()
        _ = await player.seek(
            to: CMTime(value: CMTimeValue(clamped), timescale: 1000),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    /// Jumps to `range.startMs`, plays, and pauses at `range.endMs`. Returns when playback stops.
    func playSegment(_ range: ClipRange) async {
        finishSegment()
        await seek(toMs: range.startMs)
        segmentEndMs = range.endMs
        player.play()
        isPlaying = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            segmentContinuation = continuation
        }
    }

    // MARK: Private

    private func tick(_ time: CMTime) {
        guard time.isNumeric else { return }
        let ms = Int((time.seconds * 1000).rounded())
        if !isScrubbing { currentMs = ms }
        isPlaying = player.timeControlStatus != .paused
        updateCurrentCue()
        if let end = segmentEndMs, ms >= end || (durationMs > 0 && ms >= durationMs - 50) {
            player.pause()
            isPlaying = false
            finishSegment()
        }
    }

    private func finishSegment() {
        segmentEndMs = nil
        segmentContinuation?.resume()
        segmentContinuation = nil
    }

    private func updateCurrentCue() {
        let index = track.indexOfCue(at: subtitleMs)
        if index != currentCueIndex { currentCueIndex = index }
    }

    private func loadDuration(resumeAt startMs: Int) async {
        guard let asset = player.currentItem?.asset,
              let duration = try? await asset.load(.duration),
              duration.isNumeric
        else { return }
        durationMs = Int((duration.seconds * 1000).rounded())
        if startMs > 0, startMs < durationMs - 1000 {
            await seek(toMs: startMs)
        }
    }
}
