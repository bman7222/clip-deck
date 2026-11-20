import Foundation
import os
internal import AetherLibavformat
internal import AetherLibavcodec
internal import AetherLibavutil
internal import AetherLibswresample

/// Converts an MKV (or any file libavformat reads) into an MP4 that AVFoundation plays, following a
/// `ConversionPlan`. Video is stream-copied; audio is copied or transcoded to AAC-LC stereo; subtitle streams
/// are never written into the MP4; the text ones the plan names are written as `.srt`/`.ass` files beside it.
///
/// Concurrency (spec › Concurrency): the app target defaults to MainActor and uses approachable concurrency, so
/// a plain `nonisolated async` function would run on the caller's actor and freeze the UI. `convert` therefore
/// runs a synchronous core (`ConversionCore.run`) in `Task.detached`. Every libav pointer lives inside that core;
/// only Sendable values (URLs, the plan, progress doubles, the report) cross.
///
/// Timeline (spec › Timeline rule): MP4 time t = source time t. Nothing is rebased; stream start offsets and audio
/// delays become MP4 edit lists (`use_editlist=1`). Packets follow FFmpeg's remux.c (`av_packet_rescale_ts`,
/// strictly increasing DTS, `av_interleaved_write_frame`). No `+faststart`.
nonisolated enum MediaConverter {
    nonisolated struct Report: Sendable, Equatable {
        var outputURL: URL
        /// True would mean the libav work ran on the main thread (a test checks it never does).
        var ranOnMainThread: Bool
        var videoPackets: Int
        var audioPackets: Int
        /// Problems the conversion survived (empty for a clean file).
        var warnings: [Warning] = []
        /// The subtitle files written (one per planned text track that had cues), in the plan's order.
        var subtitleFiles: [SubtitleFile] = []
    }

    /// A subtitle track written to disk by the converter (spec › Conversion rules › Subtitles).
    nonisolated struct SubtitleFile: Sendable, Equatable {
        var streamIndex: Int
        var url: URL
        var cueCount: Int
    }

    nonisolated enum Warning: Sendable, Equatable {
        /// This many damaged audio packets or frames were skipped, as ffmpeg does; the sound has short gaps there.
        case skippedDamagedAudio(Int)
        /// A planned subtitle track had no cue, so no file was written (the name is the file name it would have had).
        case emptySubtitleTrack(String)
        /// A subtitle track held an absurd amount of text and was dropped.
        case oversizedSubtitleTrack(String)
        /// A subtitle file couldn't be written (disk full, say). The video import carries on without it.
        case subtitleNotSaved(String)

        var message: String {
            switch self {
            case .skippedDamagedAudio(let count):
                "\(count) damaged audio \(count == 1 ? "frame was" : "frames were") skipped, so the sound may drop out briefly."
            case .emptySubtitleTrack(let name):
                "The subtitle track “\(name)” has no lines, so no file was saved for it."
            case .oversizedSubtitleTrack(let name):
                "The subtitle track “\(name)” is too large to read, so no file was saved for it."
            case .subtitleNotSaved(let name):
                "The subtitle track \u{201C}\(name)\u{201D} couldn't be saved, so it is missing from this episode's subtitle files."
            }
        }
    }

    /// Converts `source` into a new MP4 at `output`.
    /// - `output` must not exist yet and its folder must exist (use `makeStagingFolder()`). The converter writes
    ///   only that file (plus the subtitle files below), and deletes them again if the conversion fails or is cancelled.
    /// - `plan.subtitles` are written during the same read pass as `.srt`/`.ass` files named `fileName` in
    ///   `subtitlesFolder` (default: the output's folder; it must exist, and the files must not). Their times are the
    ///   MP4's times (no rebase). A track without cues writes nothing and adds a warning.
    /// - `progress` gets 0 once the output is open, then rising values at most about 10 times a second, then 1 on
    ///   success. It is called on the conversion thread: hop to the main actor yourself to update UI.
    /// - Cancelling the calling task stops the work within about a second and throws `CancellationError`.
    static func convert(source: URL, plan: ConversionPlan, to output: URL, subtitlesFolder: URL? = nil,
                        progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> Report {
        let cancel = ConversionCancelFlag()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                try ConversionCore.run(source: source, plan: plan, output: output, subtitlesFolder: subtitlesFolder,
                                       cancel: cancel, progress: progress)
            }.value
        } onCancel: {
            cancel.cancel()
        }
    }

    /// Creates `tmp/Converting/<uuid>/` (spec › Staging). The importer (T-006) moves results out of it on success
    /// and sweeps `tmp/Converting/` at launch.
    static func makeStagingFolder(in temporaryFolder: URL = FileManager.default.temporaryDirectory) throws -> URL {
        let folder = temporaryFolder
            .appending(path: "Converting", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}

nonisolated enum MediaConversionError: Error, LocalizedError, Sendable {
    case outputExists(String)
    case outputFolderMissing(String)
    /// The file no longer matches the plan (it changed between probing and converting).
    case sourceChanged(String)
    case noAACEncoder
    /// The file is damaged in a way the converter won't work around (absurd timestamps, unreadable audio).
    case damagedFile(String)
    /// A subtitle file couldn't be written (disk full, or the name is taken).
    case subtitleWriteFailed(String)
    case failed(FFmpegError)

    var errorDescription: String? {
        switch self {
        case .outputExists(let name): "The converted file \(name) already exists."
        case .outputFolderMissing(let path): "The folder for the converted file is missing: \(path)"
        case .sourceChanged(let detail): "The video file changed while it was being added (\(detail)). Choose it again."
        case .noAACEncoder: "This build of Clip Deck has no AAC encoder."
        case .damagedFile(let detail): "This video file looks damaged (\(detail)). Try another copy of the file."
        case .subtitleWriteFailed(let detail): "A subtitle file couldn't be saved: \(detail)"
        case .failed(let error): "The video couldn't be converted. \(error.description)"
        }
    }
}

/// The cancel flag shared by the task's cancellation handler, libavformat's interrupt callback and the packet
/// loop. `OSAllocatedUnfairLock` because `Synchronization.Mutex`/`Atomic` need iOS 18 (the app targets 17).
nonisolated final class ConversionCancelFlag: Sendable {
    private let state = OSAllocatedUnfairLock(initialState: false)

    var isCancelled: Bool { state.withLock { value in value } }

    func cancel() { state.withLock { value in value = true } }

    /// An AVIOInterruptCB that makes libavformat's blocking reads and writes fail with AVERROR_EXIT once this flag
    /// is set. It holds the flag unretained: keep the flag alive while any context uses the callback.
    func interruptCallback() -> AVIOInterruptCB {
        AVIOInterruptCB(
            callback: { opaque in
                guard let opaque else { return 0 }
                return Unmanaged<ConversionCancelFlag>.fromOpaque(opaque).takeUnretainedValue().isCancelled ? 1 : 0
            },
            opaque: Unmanaged.passUnretained(self).toOpaque())
    }
}

/// Limits progress reports to one per `interval` seconds, each larger than the last.
nonisolated struct ProgressThrottle: Sendable {
    let interval: Double
    private(set) var lastValue: Double = -1
    private(set) var lastTime: Double = -Double.infinity

    init(interval: Double = 0.1) {
        self.interval = interval
    }

    /// Returns the value to report (clamped to 0...1), or nil to skip. `force` ignores the interval (start, end).
    mutating func next(_ value: Double, now: Double, force: Bool = false) -> Double? {
        guard value.isFinite else { return nil }
        let clamped = min(max(value, 0), 1)
        guard clamped > lastValue else { return nil }
        guard force || now - lastTime >= interval else { return nil }
        lastValue = clamped
        lastTime = now
        return clamped
    }
}

/// A timestamp so far from zero that only a damaged or hostile file can have it (2^60 ticks is over 36,000
/// years even at 1 GHz). Rejecting these keeps every later addition far from Int64 overflow, which traps in Swift.
nonisolated struct TimestampOutOfRange: Error, Equatable, Sendable, CustomStringConvertible {
    let value: Int64
    var description: String { "a timestamp is out of range: \(value)" }
}

/// Keeps one output stream's timestamps valid for the MP4 muxer, which rejects unset timestamps, a DTS that
/// doesn't strictly increase, and PTS < DTS. Same repairs as the ffmpeg command line (fftools/ffmpeg_mux.c);
/// normal files pass through unchanged. Values are in the output stream's time base.
nonisolated struct TimestampFixer: Sendable, Equatable {
    /// Largest accepted magnitude.
    static let limit: Int64 = 1 << 60

    private(set) var lastDTS: Int64?
    /// How many packets needed a change (0 for a well-formed file).
    private(set) var repairs = 0

    init() {}

    static func isInRange(_ value: Int64) -> Bool {
        value <= limit && value >= -limit
    }

    /// Returns the timestamps to write, or nil when the packet carries none and nothing came before it.
    /// Throws for a timestamp beyond ±2^60 (a damaged file). The median is found by comparison and the only
    /// addition is `lastDTS &+ 1`, so nothing here can trap.
    mutating func fix(pts: Int64?, dts: Int64?) throws(TimestampOutOfRange) -> (pts: Int64, dts: Int64)? {
        if let pts, !Self.isInRange(pts) { throw TimestampOutOfRange(value: pts) }
        if let dts, !Self.isInRange(dts) { throw TimestampOutOfRange(value: dts) }
        // Inputs are within ±2^60 and lastDTS only grows by 1 per bumped packet, so this is nowhere near Int64.max;
        // `&+` makes "never traps" explicit anyway.
        let next = lastDTS.map { $0 &+ 1 }

        // An unset DTS takes the PTS (or the next tick); an unset PTS takes the DTS.
        guard var d = dts ?? pts ?? next else { return nil }
        var p = pts ?? d
        let original = (p, d)
        let filled = pts == nil || dts == nil

        if d > p {
            if let next {
                // Invalid DTS: the median of PTS, DTS and the next allowed DTS (ffmpeg_mux.c), found by
                // comparison so no sum can overflow.
                let median = max(min(p, d), min(max(p, d), next))
                p = median
                d = median
            } else {
                d = p
            }
        }
        if let next, d < next {
            if p >= d { p = max(p, next) }
            d = next
        }
        if p < d { p = d }

        if filled || original != (p, d) { repairs += 1 }
        lastDTS = d
        return (p, d)
    }
}

/// When skipping audio decode errors stops being "a damaged frame here and there" and becomes "this track is
/// broken". ffmpeg skips decode errors; so do we, unless there are many and they are a large share of the packets.
nonisolated struct DecodeErrorBudget: Sendable, Equatable {
    /// Up to this many errors are always skipped.
    static let alwaysSkip = 50
    /// Past `alwaysSkip`, give up once more than 1 packet in `failureRatio` has failed.
    static let failureRatio = 10

    private(set) var packets = 0
    private(set) var errors = 0

    init() {}

    mutating func countPacket() { packets += 1 }

    /// Records one error. Returns false when the conversion should give up.
    mutating func recordError() -> Bool {
        errors += 1
        if errors <= Self.alwaysSkip { return true }
        return errors * Self.failureRatio <= packets
    }
}

/// The synchronous core. Runs on a detached task's thread; never on the main thread.
nonisolated enum ConversionCore {
    static func run(source: URL, plan: ConversionPlan, output: URL, subtitlesFolder: URL? = nil, cancel: ConversionCancelFlag,
                    progress: @escaping @Sendable (Double) -> Void) throws -> MediaConverter.Report {
        let ranOnMainThread = Thread.isMainThread
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: output.path(percentEncoded: false)) {
            throw MediaConversionError.outputExists(output.lastPathComponent)
        }
        let folder = output.deletingLastPathComponent().path(percentEncoded: false)
        var isFolder: ObjCBool = false
        guard fileManager.fileExists(atPath: folder, isDirectory: &isFolder), isFolder.boolValue else {
            throw MediaConversionError.outputFolderMissing(folder)
        }
        let subtitleFolder = subtitlesFolder ?? output.deletingLastPathComponent()
        if !plan.subtitles.isEmpty {
            let path = subtitleFolder.path(percentEncoded: false)
            var isSubtitleFolder: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isSubtitleFolder), isSubtitleFolder.boolValue else {
                throw MediaConversionError.outputFolderMissing(path)
            }
            for extraction in plan.subtitles {
                let target = subtitleFolder.appending(path: extraction.fileName).path(percentEncoded: false)
                if fileManager.fileExists(atPath: target) { throw MediaConversionError.outputExists(extraction.fileName) }
            }
        }

        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let session = ConversionSession(plan: plan, cancel: cancel, progress: progress)
        var writtenSubtitles: [URL] = []
        do {
            // The interrupt callback holds `cancel` unretained; keep it alive for the whole run.
            try withExtendedLifetime(cancel) {
                try session.run(sourcePath: FFmpegSupport.path(source), outputPath: FFmpegSupport.path(output))
            }
            session.close()
            var warnings = session.warnings
            var subtitleFiles: [MediaConverter.SubtitleFile] = []
            for collector in session.subtitleCollectors {
                if cancel.isCancelled { throw CancellationError() }
                let name = collector.extraction.fileName
                guard let file = collector.file() else {
                    warnings.append(collector.isTooLarge ? .oversizedSubtitleTrack(name) : .emptySubtitleTrack(name))
                    continue
                }
                let url = subtitleFolder.appending(path: name)
                do {
                    // .withoutOverwriting: never replaces a file that appeared since the check above.
                    try Data(file.text.utf8).write(to: url, options: .withoutOverwriting)
                } catch {
                    // Only the track chosen as the episode's subtitle fails the import; any other track is a warning.
                    if collector.extraction.isRequired {
                        throw MediaConversionError.subtitleWriteFailed(error.localizedDescription)
                    }
                    warnings.append(.subtitleNotSaved(name))
                    continue
                }
                writtenSubtitles.append(url)
                subtitleFiles.append(MediaConverter.SubtitleFile(
                    streamIndex: collector.extraction.streamIndex, url: url, cueCount: file.cueCount))
            }
            return MediaConverter.Report(
                outputURL: output,
                ranOnMainThread: ranOnMainThread,
                videoPackets: session.videoPackets,
                audioPackets: session.audioPackets,
                warnings: warnings,
                subtitleFiles: subtitleFiles)
        } catch {
            session.close()   // closes the output file before it is deleted
            try? fileManager.removeItem(at: output)
            for url in writtenSubtitles { try? fileManager.removeItem(at: url) }
            if cancel.isCancelled || error is CancellationError { throw CancellationError() }
            throw error
        }
    }
}

/// Owns every libav object of one conversion. Created, used and closed inside `ConversionCore.run` only, on one
/// thread; never shared. `close()` (also called from deinit) frees everything and is safe to call twice.
nonisolated final class ConversionSession {
    private let plan: ConversionPlan
    private let cancel: ConversionCancelFlag
    private let progress: @Sendable (Double) -> Void
    private var throttle = ProgressThrottle()

    private var input: UnsafeMutablePointer<AVFormatContext>?
    private var output: UnsafeMutablePointer<AVFormatContext>?
    private var packet: UnsafeMutablePointer<AVPacket>?

    // Audio transcoding only.
    private var decoder: UnsafeMutablePointer<AVCodecContext>?
    private var encoder: UnsafeMutablePointer<AVCodecContext>?
    private var resampler: OpaquePointer?          // SwrContext
    private var fifo: OpaquePointer?               // AVAudioFifo
    private var decodedFrame: UnsafeMutablePointer<AVFrame>?
    private var resampledFrame: UnsafeMutablePointer<AVFrame>?
    private var encoderFrame: UnsafeMutablePointer<AVFrame>?
    private var encodedPacket: UnsafeMutablePointer<AVPacket>?
    private var nextAudioPTS: Int64?               // in 1/outputSampleRate
    private var outputSampleRate: Int32 = 0
    private var outputChannels: Int32 = 0

    private var videoInput = -1
    private var audioInput = -1
    private var videoOutput = -1
    private var audioOutput = -1
    private var fixers: [TimestampFixer] = []
    private var decodeErrors = DecodeErrorBudget()
    /// Subtitle tracks being extracted, by input stream index.
    private var collectors: [Int: SubtitleCollector] = [:]

    private(set) var videoPackets = 0
    private(set) var audioPackets = 0
    var warnings: [MediaConverter.Warning] {
        decodeErrors.errors > 0 ? [.skippedDamagedAudio(decodeErrors.errors)] : []
    }
    /// What was collected from the planned subtitle tracks, in the plan's order.
    var subtitleCollectors: [SubtitleCollector] {
        plan.subtitles.compactMap { collectors[$0.streamIndex] }
    }

    init(plan: ConversionPlan, cancel: ConversionCancelFlag, progress: @escaping @Sendable (Double) -> Void) {
        self.plan = plan
        self.cancel = cancel
        self.progress = progress
    }

    deinit { close() }

    func run(sourcePath: String, outputPath: String) throws {
        let input = try openInput(sourcePath)
        let (videoStream, audioStream) = try selectStreams(input)
        let output = try openOutput(outputPath, video: videoStream, audio: audioStream)
        try writeHeader(output)
        report(0, force: true)
        try copyPackets(input: input, output: output)
        try finish(output)
        report(1, force: true)
    }

    func close() {
        av_packet_free(&packet)
        av_packet_free(&encodedPacket)
        av_frame_free(&decodedFrame)
        av_frame_free(&resampledFrame)
        av_frame_free(&encoderFrame)
        swr_free(&resampler)
        if let fifo {
            av_audio_fifo_free(fifo)
            self.fifo = nil
        }
        avcodec_free_context(&decoder)
        avcodec_free_context(&encoder)
        if let output {
            if output.pointee.pb != nil { avio_closep(&output.pointee.pb) }
            avformat_free_context(output)
            self.output = nil
        }
        avformat_close_input(&input)
    }

    // MARK: Setup

    /// libavformat calls this during blocking reads and writes; returning 1 makes them fail with AVERROR_EXIT.
    private func interruptCallback() -> AVIOInterruptCB {
        cancel.interruptCallback()
    }

    private func openInput(_ path: String) throws -> UnsafeMutablePointer<AVFormatContext> {
        guard let context = avformat_alloc_context() else { throw failure("avformat_alloc_context", FFmpegSupport.errorNoMemory) }
        context.pointee.interrupt_callback = interruptCallback()
        var opened: UnsafeMutablePointer<AVFormatContext>? = context
        // On failure avformat_open_input frees the context and sets `opened` to nil.
        let code = avformat_open_input(&opened, path, nil, nil)
        guard code >= 0, let opened else { throw failure("avformat_open_input", code) }
        input = opened
        try check(avformat_find_stream_info(opened, nil), "avformat_find_stream_info")
        return opened
    }

    /// The plan's streams, checked against the file. Every other stream is discarded at the demuxer, so subtitle,
    /// attachment and unused audio packets are never even read.
    private func selectStreams(_ input: UnsafeMutablePointer<AVFormatContext>) throws
        -> (video: UnsafeMutablePointer<AVStream>, audio: UnsafeMutablePointer<AVStream>?) {
        let video = try stream(input, plan.video.streamIndex, type: AVMEDIA_TYPE_VIDEO, codec: plan.video.codec)
        videoInput = plan.video.streamIndex
        var audio: UnsafeMutablePointer<AVStream>?
        if let audioPlan = plan.audio {
            audio = try stream(input, audioPlan.streamIndex, type: AVMEDIA_TYPE_AUDIO, codec: audioPlan.codec)
            audioInput = audioPlan.streamIndex
        }
        for extraction in plan.subtitles {
            let subtitle = try stream(input, extraction.streamIndex, type: AVMEDIA_TYPE_SUBTITLE, codec: extraction.codec)
            collectors[extraction.streamIndex] = SubtitleCollector(extraction: extraction, header: codecPrivateText(subtitle))
        }
        for index in 0..<Int(input.pointee.nb_streams) where index != videoInput && index != audioInput && collectors[index] == nil {
            input.pointee.streams[index]?.pointee.discard = AVDISCARD_ALL
        }
        return (video, audio)
    }

    /// The track's CodecPrivate (the ASS header) as text; empty when there is none.
    private func codecPrivateText(_ stream: UnsafeMutablePointer<AVStream>) -> String {
        guard let parameters = stream.pointee.codecpar,
              let data = parameters.pointee.extradata, parameters.pointee.extradata_size > 0 else { return "" }
        let bytes = UnsafeBufferPointer(start: UnsafePointer(data), count: Int(parameters.pointee.extradata_size))
        return String(decoding: bytes, as: UTF8.self)
    }

    private func stream(_ context: UnsafeMutablePointer<AVFormatContext>, _ index: Int, type: AVMediaType,
                        codec: String) throws -> UnsafeMutablePointer<AVStream> {
        guard index >= 0, index < Int(context.pointee.nb_streams),
              let stream = context.pointee.streams[index],
              let parameters = stream.pointee.codecpar,
              parameters.pointee.codec_type == type else {
            throw MediaConversionError.sourceChanged("stream \(index) is missing")
        }
        let found = FFmpegSupport.codecName(parameters.pointee.codec_id)
        guard found == codec else {
            throw MediaConversionError.sourceChanged("stream \(index) is \(found), expected \(codec)")
        }
        return stream
    }

    private func openOutput(_ path: String, video videoIn: UnsafeMutablePointer<AVStream>,
                            audio audioIn: UnsafeMutablePointer<AVStream>?) throws -> UnsafeMutablePointer<AVFormatContext> {
        var created: UnsafeMutablePointer<AVFormatContext>? = nil
        try check(avformat_alloc_output_context2(&created, nil, "mp4", nil), "avformat_alloc_output_context2")
        guard let output = created else { throw failure("avformat_alloc_output_context2", FFmpegSupport.errorNoMemory) }
        self.output = output
        output.pointee.interrupt_callback = interruptCallback()

        // Video: stream copy, as remux.c does.
        guard let videoOut = avformat_new_stream(output, nil) else { throw failure("avformat_new_stream", FFmpegSupport.errorNoMemory) }
        try check(avcodec_parameters_copy(videoOut.pointee.codecpar, videoIn.pointee.codecpar), "avcodec_parameters_copy (video)")
        let videoParameters: UnsafeMutablePointer<AVCodecParameters> = videoOut.pointee.codecpar
        videoParameters.pointee.codec_tag = plan.video.tagAsHVC1 ? FFmpegSupport.hvc1Tag : 0
        if plan.video.dropsDolbyVision {
            let sideData = videoParameters.pointee.coded_side_data
            av_packet_side_data_remove(sideData, &videoParameters.pointee.nb_coded_side_data, AV_PKT_DATA_DOVI_CONF)
        }
        videoOut.pointee.time_base = videoIn.pointee.time_base
        videoOut.pointee.avg_frame_rate = videoIn.pointee.avg_frame_rate
        copyLanguage(from: videoIn, to: videoOut)
        videoOutput = Int(videoOut.pointee.index)

        if let audioPlan = plan.audio, let audioIn {
            switch audioPlan.mode {
            case .copy:
                guard let audioOut = avformat_new_stream(output, nil) else { throw failure("avformat_new_stream", FFmpegSupport.errorNoMemory) }
                try check(avcodec_parameters_copy(audioOut.pointee.codecpar, audioIn.pointee.codecpar), "avcodec_parameters_copy (audio)")
                audioOut.pointee.codecpar.pointee.codec_tag = 0
                audioOut.pointee.time_base = audioIn.pointee.time_base
                copyLanguage(from: audioIn, to: audioOut)
                audioOutput = Int(audioOut.pointee.index)
            case .transcodeToAAC(let sampleRate, let channels, let bitRate):
                let audioOut = try setUpTranscoder(input: audioIn, output: output, sampleRate: sampleRate, channels: channels, bitRate: bitRate)
                copyLanguage(from: audioIn, to: audioOut)
                audioOutput = Int(audioOut.pointee.index)
            }
        }
        fixers = Array(repeating: TimestampFixer(), count: Int(output.pointee.nb_streams))

        var interrupt = interruptCallback()
        try check(avio_open2(&output.pointee.pb, path, FFmpegSupport.avioFlagWrite, &interrupt, nil), "avio_open2")
        return output
    }

    private func setUpTranscoder(input audioIn: UnsafeMutablePointer<AVStream>, output: UnsafeMutablePointer<AVFormatContext>,
                                 sampleRate: Int, channels: Int, bitRate: Int) throws -> UnsafeMutablePointer<AVStream> {
        let inputParameters: UnsafeMutablePointer<AVCodecParameters> = audioIn.pointee.codecpar
        guard let decoderCodec = avcodec_find_decoder(inputParameters.pointee.codec_id) else {
            throw MediaConversionError.sourceChanged("no decoder for \(FFmpegSupport.codecName(inputParameters.pointee.codec_id))")
        }
        guard let decoder = avcodec_alloc_context3(decoderCodec) else { throw failure("avcodec_alloc_context3", FFmpegSupport.errorNoMemory) }
        self.decoder = decoder
        try check(avcodec_parameters_to_context(decoder, inputParameters), "avcodec_parameters_to_context")
        // Decoded frames carry timestamps in the input stream's time base.
        decoder.pointee.pkt_timebase = audioIn.pointee.time_base
        try check(avcodec_open2(decoder, decoderCodec, nil), "avcodec_open2 (audio decoder)")

        // FFmpegBuild 3.16.0 has only FFmpeg's native AAC encoder (no aac_at); it takes planar float.
        guard let encoderCodec = avcodec_find_encoder_by_name("aac") ?? avcodec_find_encoder(AV_CODEC_ID_AAC) else {
            throw MediaConversionError.noAACEncoder
        }
        guard let encoder = avcodec_alloc_context3(encoderCodec) else { throw failure("avcodec_alloc_context3", FFmpegSupport.errorNoMemory) }
        self.encoder = encoder
        encoder.pointee.sample_fmt = AV_SAMPLE_FMT_FLTP
        encoder.pointee.sample_rate = Int32(sampleRate)
        av_channel_layout_default(&encoder.pointee.ch_layout, Int32(channels))
        encoder.pointee.bit_rate = Int64(bitRate)
        encoder.pointee.time_base = AVRational(num: 1, den: Int32(sampleRate))
        if (output.pointee.oformat.pointee.flags & FFmpegSupport.formatGlobalHeader) != 0 {
            encoder.pointee.flags |= FFmpegSupport.codecFlagGlobalHeader
        }
        try check(avcodec_open2(encoder, encoderCodec, nil), "avcodec_open2 (AAC encoder)")

        guard let audioOut = avformat_new_stream(output, nil) else { throw failure("avformat_new_stream", FFmpegSupport.errorNoMemory) }
        try check(avcodec_parameters_from_context(audioOut.pointee.codecpar, encoder), "avcodec_parameters_from_context")
        audioOut.pointee.codecpar.pointee.codec_tag = 0
        audioOut.pointee.time_base = encoder.pointee.time_base

        guard let fifo = av_audio_fifo_alloc(AV_SAMPLE_FMT_FLTP, Int32(channels), 4096) else {
            throw failure("av_audio_fifo_alloc", FFmpegSupport.errorNoMemory)
        }
        self.fifo = fifo
        decodedFrame = av_frame_alloc()
        resampledFrame = av_frame_alloc()
        encoderFrame = av_frame_alloc()
        encodedPacket = av_packet_alloc()
        guard decodedFrame != nil, resampledFrame != nil, encoderFrame != nil, encodedPacket != nil else {
            throw failure("av_frame_alloc", FFmpegSupport.errorNoMemory)
        }
        outputSampleRate = Int32(sampleRate)
        outputChannels = Int32(channels)
        return audioOut
    }

    private func copyLanguage(from source: UnsafeMutablePointer<AVStream>, to destination: UnsafeMutablePointer<AVStream>) {
        guard let language = FFmpegSupport.metadata(source.pointee.metadata, "language") else { return }
        av_dict_set(&destination.pointee.metadata, "language", language, 0)
    }

    private func writeHeader(_ output: UnsafeMutablePointer<AVFormatContext>) throws {
        var options: OpaquePointer? = nil
        // Edit lists carry start offsets and audio delays (the timeline rule). No movflags: no +faststart.
        av_dict_set(&options, "use_editlist", "1", 0)
        defer { av_dict_free(&options) }
        try check(avformat_write_header(output, &options), "avformat_write_header")
    }

    // MARK: Packets

    private func copyPackets(input: UnsafeMutablePointer<AVFormatContext>, output: UnsafeMutablePointer<AVFormatContext>) throws {
        guard let packet = av_packet_alloc() else { throw failure("av_packet_alloc", FFmpegSupport.errorNoMemory) }
        self.packet = packet
        let sourceSize: Int64 = input.pointee.pb != nil ? avio_size(input.pointee.pb) : -1

        while true {
            if cancel.isCancelled { throw CancellationError() }
            let code = av_read_frame(input, packet)
            if code == FFmpegSupport.errorEOF { break }
            guard code >= 0 else { throw failure("av_read_frame", code) }

            let index = Int(packet.pointee.stream_index)
            if index == videoInput, let inStream = input.pointee.streams[index] {
                try writeCopy(packet, from: inStream, to: videoOutput, in: output)
                videoPackets += 1
            } else if index == audioInput, let inStream = input.pointee.streams[index] {
                if decoder != nil {
                    try decode(packet, output: output)
                } else {
                    try writeCopy(packet, from: inStream, to: audioOutput, in: output)
                    audioPackets += 1
                }
            } else if collectors[index] != nil, let inStream = input.pointee.streams[index] {
                collectSubtitle(packet, from: inStream, index: index)
            }
            av_packet_unref(packet)
            reportProgress(input: input, sourceSize: sourceSize)
        }
    }

    /// Keeps a subtitle packet's text and its time on the source clock (= the MP4's clock). A packet without a
    /// usable timestamp or text is skipped.
    private func collectSubtitle(_ packet: UnsafeMutablePointer<AVPacket>, from stream: UnsafeMutablePointer<AVStream>, index: Int) {
        let timeBase = stream.pointee.time_base
        let timestamp = packet.pointee.pts != FFmpegSupport.noPTS ? packet.pointee.pts : packet.pointee.dts
        guard collectors[index]?.isTooLarge == false else { return }   // already dropped: don't decode more text
        guard let data = packet.pointee.data, packet.pointee.size > 0,
              timeBase.num > 0, timeBase.den > 0,
              timestamp != FFmpegSupport.noPTS, TimestampFixer.isInRange(timestamp),
              packet.pointee.duration >= 0, TimestampFixer.isInRange(packet.pointee.duration) else { return }
        let milliseconds = AVRational(num: 1, den: 1000)
        let start = av_rescale_q(timestamp, timeBase, milliseconds)
        let duration = av_rescale_q(packet.pointee.duration, timeBase, milliseconds)
        let text = String(decoding: UnsafeBufferPointer(start: UnsafePointer(data), count: Int(packet.pointee.size)), as: UTF8.self)
        collectors[index]?.add(startMs: Int(start), durationMs: Int(duration), text: text)
    }

    private func writeCopy(_ packet: UnsafeMutablePointer<AVPacket>, from inStream: UnsafeMutablePointer<AVStream>,
                           to outIndex: Int, in output: UnsafeMutablePointer<AVFormatContext>) throws {
        guard let outStream = output.pointee.streams[outIndex] else { return }
        av_packet_rescale_ts(packet, inStream.pointee.time_base, outStream.pointee.time_base)
        packet.pointee.stream_index = Int32(outIndex)
        packet.pointee.pos = -1
        try write(packet, to: outIndex, in: output)
    }

    /// Repairs timestamps if needed, then hands the packet to the interleaving muxer (which takes its data).
    private func write(_ packet: UnsafeMutablePointer<AVPacket>, to outIndex: Int, in output: UnsafeMutablePointer<AVFormatContext>) throws {
        let pts = packet.pointee.pts == FFmpegSupport.noPTS ? nil : packet.pointee.pts
        let dts = packet.pointee.dts == FFmpegSupport.noPTS ? nil : packet.pointee.dts
        let fixedOrNil: (pts: Int64, dts: Int64)?
        do {
            fixedOrNil = try fixers[outIndex].fix(pts: pts, dts: dts)
        } catch {
            av_packet_unref(packet)
            throw MediaConversionError.damagedFile("\(error)")
        }
        guard let fixed = fixedOrNil else {
            av_packet_unref(packet)   // no timestamps at all before any good packet: drop it
            return
        }
        packet.pointee.pts = fixed.pts
        packet.pointee.dts = fixed.dts
        try check(av_interleaved_write_frame(output, packet), "av_interleaved_write_frame")
    }

    private func reportProgress(input: UnsafeMutablePointer<AVFormatContext>, sourceSize: Int64) {
        guard sourceSize > 0, let pb = input.pointee.pb else { return }
        let position = avio_seek(pb, 0, SEEK_CUR)
        guard position >= 0 else { return }
        // 1.0 is reported only after the trailer is written.
        report(min(Double(position) / Double(sourceSize), 0.99))
    }

    private func report(_ value: Double, force: Bool = false) {
        if let reported = throttle.next(value, now: ProcessInfo.processInfo.systemUptime, force: force) {
            progress(reported)
        }
    }

    // MARK: Audio transcoding

    private func decode(_ packet: UnsafeMutablePointer<AVPacket>, output: UnsafeMutablePointer<AVFormatContext>) throws {
        guard let decoder else { return }
        decodeErrors.countPacket()
        var code = avcodec_send_packet(decoder, packet)
        if code == FFmpegSupport.errorAgain {
            // The decoder is full: take its frames, then the packet fits.
            try drainDecoder(output: output)
            code = avcodec_send_packet(decoder, packet)
        }
        if code < 0 {
            // A damaged audio packet: skip it, as ffmpeg does (fatal errors still stop the conversion).
            try skipDecodeError(code, "avcodec_send_packet")
            return
        }
        try drainDecoder(output: output)
    }

    /// Out of memory, an interrupt and cancellation are fatal. Anything else is one damaged packet or frame,
    /// skipped until `DecodeErrorBudget` says the whole track is broken.
    private func skipDecodeError(_ code: Int32, _ step: String) throws {
        if code == FFmpegSupport.errorNoMemory || code == FFmpegSupport.errorExit || cancel.isCancelled {
            throw failure(step, code)
        }
        guard decodeErrors.recordError() else {
            throw MediaConversionError.damagedFile(
                "\(decodeErrors.errors) of \(decodeErrors.packets) audio packets can't be decoded; last error: \(FFmpegSupport.describe(code))")
        }
    }

    private func drainDecoder(output: UnsafeMutablePointer<AVFormatContext>) throws {
        guard let decoder, let frame = decodedFrame else { return }
        while true {
            let code = avcodec_receive_frame(decoder, frame)
            if code == FFmpegSupport.errorAgain || code == FFmpegSupport.errorEOF { return }
            if code < 0 {
                // Like ffmpeg: skip the bad frame and go on with the next packet.
                try skipDecodeError(code, "avcodec_receive_frame")
                return
            }
            defer { av_frame_unref(frame) }
            try resample(frame)
            try encodeQueued(flush: false, output: output)
        }
    }

    /// Converts one decoded frame (or the resampler's tail, for nil) to stereo float at the output rate and queues
    /// the samples. The first frame's timestamp anchors the output clock, so the audio keeps its source start.
    private func resample(_ frame: UnsafeMutablePointer<AVFrame>?) throws {
        if let frame {
            if nextAudioPTS == nil {
                let best = frame.pointee.best_effort_timestamp
                let timestamp = best != FFmpegSupport.noPTS ? best : frame.pointee.pts
                if timestamp != FFmpegSupport.noPTS, let decoder {
                    let anchor = av_rescale_q(timestamp, decoder.pointee.pkt_timebase, AVRational(num: 1, den: outputSampleRate))
                    // Bounded like every packet timestamp, so the sample counts added below can't overflow.
                    guard TimestampFixer.isInRange(anchor) else {
                        throw MediaConversionError.damagedFile("an audio timestamp is out of range: \(anchor)")
                    }
                    nextAudioPTS = anchor
                } else {
                    nextAudioPTS = 0
                }
            }
            // swresample needs a real layout to downmix; some decoders leave it unspecified.
            if frame.pointee.ch_layout.order == AV_CHANNEL_ORDER_UNSPEC {
                let count = frame.pointee.ch_layout.nb_channels
                av_channel_layout_uninit(&frame.pointee.ch_layout)
                av_channel_layout_default(&frame.pointee.ch_layout, count)
            }
            if resampler == nil {
                resampler = swr_alloc()
                guard resampler != nil else { throw failure("swr_alloc", FFmpegSupport.errorNoMemory) }
                try configureResampler(for: frame)
            }
        } else if resampler == nil {
            return   // no audio was ever decoded
        }
        guard let resampler, let resampled = resampledFrame else { return }

        try prepareResampledFrame()
        var code = swr_convert_frame(resampler, resampled, frame.map { UnsafePointer($0) })
        if code < 0, let frame {
            // The input format changed mid-stream (for example 5.1 to stereo): reconfigure once and retry.
            try configureResampler(for: frame)
            try prepareResampledFrame()
            code = swr_convert_frame(resampler, resampled, UnsafePointer(frame))
        }
        try check(code, "swr_convert_frame")
        let count = resampled.pointee.nb_samples
        if count > 0 { try queue(resampled, count: count) }
        av_frame_unref(resampled)
    }

    private func configureResampler(for frame: UnsafeMutablePointer<AVFrame>) throws {
        guard let resampler, let resampled = resampledFrame else { return }
        try prepareResampledFrame()
        try check(swr_config_frame(resampler, resampled, frame), "swr_config_frame")
        try check(swr_init(resampler), "swr_init")
    }

    /// An empty output frame with the target format; swr_convert_frame allocates its buffer.
    private func prepareResampledFrame() throws {
        guard let resampled = resampledFrame, let encoder else { return }
        av_frame_unref(resampled)
        resampled.pointee.format = AV_SAMPLE_FMT_FLTP.rawValue
        resampled.pointee.sample_rate = outputSampleRate
        try check(av_channel_layout_copy(&resampled.pointee.ch_layout, &encoder.pointee.ch_layout), "av_channel_layout_copy")
    }

    private func queue(_ frame: UnsafeMutablePointer<AVFrame>, count: Int32) throws {
        guard let fifo, let planes = frame.pointee.extended_data else { return }
        let written = planes.withMemoryRebound(to: UnsafeMutableRawPointer?.self, capacity: Int(outputChannels)) {
            av_audio_fifo_write(fifo, $0, count)
        }
        guard written == count else { throw failure("av_audio_fifo_write", written < 0 ? written : FFmpegSupport.errorNoMemory) }
    }

    /// Feeds the encoder whole 1024-sample frames from the FIFO (and the short last one when flushing).
    private func encodeQueued(flush: Bool, output: UnsafeMutablePointer<AVFormatContext>) throws {
        guard let fifo, let encoder, let frame = encoderFrame else { return }
        let frameSize = encoder.pointee.frame_size > 0 ? encoder.pointee.frame_size : 1024
        while true {
            let available = av_audio_fifo_size(fifo)
            guard available >= frameSize || (flush && available > 0) else { break }
            let count = min(available, frameSize)
            av_frame_unref(frame)
            frame.pointee.nb_samples = count
            frame.pointee.format = AV_SAMPLE_FMT_FLTP.rawValue
            frame.pointee.sample_rate = outputSampleRate
            try check(av_channel_layout_copy(&frame.pointee.ch_layout, &encoder.pointee.ch_layout), "av_channel_layout_copy")
            try check(av_frame_get_buffer(frame, 0), "av_frame_get_buffer")
            guard let planes = frame.pointee.extended_data else { throw failure("av_frame_get_buffer", FFmpegSupport.errorNoMemory) }
            let read = planes.withMemoryRebound(to: UnsafeMutableRawPointer?.self, capacity: Int(outputChannels)) {
                av_audio_fifo_read(fifo, $0, count)
            }
            guard read == count else { throw failure("av_audio_fifo_read", read < 0 ? read : FFmpegSupport.errorInvalidData) }
            let pts = nextAudioPTS ?? 0
            frame.pointee.pts = pts
            nextAudioPTS = pts &+ Int64(count)   // pts is within ±2^60 (+ samples so far): no wrap
            try encode(frame, output: output)
            av_frame_unref(frame)
        }
        if flush { try encode(nil, output: output) }
    }

    private func encode(_ frame: UnsafeMutablePointer<AVFrame>?, output: UnsafeMutablePointer<AVFormatContext>) throws {
        guard let encoder, let packet = encodedPacket, let outStream = output.pointee.streams[audioOutput] else { return }
        let sent = avcodec_send_frame(encoder, frame.map { UnsafePointer($0) })
        if !(frame == nil && sent == FFmpegSupport.errorEOF) {
            try check(sent, "avcodec_send_frame")
        }
        while true {
            let code = avcodec_receive_packet(encoder, packet)
            if code == FFmpegSupport.errorAgain || code == FFmpegSupport.errorEOF { return }
            try check(code, "avcodec_receive_packet")
            av_packet_rescale_ts(packet, encoder.pointee.time_base, outStream.pointee.time_base)
            packet.pointee.stream_index = Int32(audioOutput)
            try write(packet, to: audioOutput, in: output)
            audioPackets += 1
        }
    }

    // MARK: Finish

    private func finish(_ output: UnsafeMutablePointer<AVFormatContext>) throws {
        if let decoder {
            let code = avcodec_send_packet(decoder, nil)
            if code < 0, code != FFmpegSupport.errorEOF { try skipDecodeError(code, "avcodec_send_packet (flush)") }
            try drainDecoder(output: output)
            try resample(nil)
            try encodeQueued(flush: true, output: output)
        }
        if cancel.isCancelled { throw CancellationError() }
        try check(av_write_trailer(output), "av_write_trailer")
        // Closing flushes the last bytes; a full disk shows up here.
        try check(avio_closep(&output.pointee.pb), "avio_closep")
    }

    // MARK: Errors

    private func check(_ code: Int32, _ step: String) throws {
        guard code < 0 else { return }
        throw failure(step, code)
    }

    private func failure(_ step: String, _ code: Int32) -> Error {
        if cancel.isCancelled || code == FFmpegSupport.errorExit { return CancellationError() }
        return MediaConversionError.failed(FFmpegSupport.error(step, code))
    }
}
