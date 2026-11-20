import Foundation
internal import AetherLibavformat
internal import AetherLibavcodec
internal import AetherLibavutil

/// What a source file contains, as far as the import needs to know (spec › Contracts › MediaProbe).
/// Plain Sendable values: no libav pointer ever leaves `MediaProber`.
/// Times are in seconds on the source's own clock (no rebasing).
nonisolated struct MediaProbe: Sendable, Equatable {
    nonisolated enum Chroma: String, Sendable, Equatable {
        case yuv420 = "4:2:0"
        case yuv422 = "4:2:2"
        case yuv444 = "4:4:4"
        case rgb = "RGB"
        case monochrome = "monochrome"
        case other = "other"
    }

    /// The Dolby Vision configuration record (dvcC/dvvC, or Matroska's BlockAdditionMapping).
    nonisolated struct DolbyVision: Sendable, Equatable {
        var profile: Int
        var level: Int = 0
        /// 0 means the base layer is not backwards compatible (profile 5).
        var baseLayerCompatibilityID: Int
    }

    nonisolated struct Video: Sendable, Equatable {
        var streamIndex: Int
        /// FFmpeg codec name: "h264", "hevc", "av1", "vp9", "mpeg4", ...
        var codec: String
        /// FFmpeg profile number (AV_PROFILE_*), nil when unknown. H.264 High 10 = 110, HEVC Main = 1, Main 10 = 2.
        var profile: Int? = nil
        var profileName: String? = nil
        /// FFmpeg pixel format name, e.g. "yuv420p", "yuv420p10le"; nil when FFmpeg couldn't tell.
        var pixelFormat: String? = nil
        var bitDepth: Int? = nil
        var chroma: Chroma? = nil
        var width: Int = 0
        var height: Int = 0
        var dolbyVision: DolbyVision? = nil
        var startSeconds: Double? = nil
        /// Start relative to the container start (0 for most files).
        var startOffsetSeconds: Double? = nil
    }

    nonisolated struct Audio: Sendable, Equatable {
        var streamIndex: Int
        /// FFmpeg codec name: "aac", "mp3", "ac3", "eac3", "flac", "opus", "vorbis", "dts", "truehd", "pcm_s16le", ...
        var codec: String
        var language: String? = nil
        var title: String? = nil
        var channels: Int
        var sampleRate: Int
        var startSeconds: Double? = nil
        /// Start relative to the container start: an audio delay shows up here.
        var startOffsetSeconds: Double? = nil
        var isDefault: Bool = false
        /// This FFmpeg build has a decoder for it (needed when it must be transcoded).
        var canDecode: Bool = true
    }

    nonisolated struct Subtitle: Sendable, Equatable {
        var streamIndex: Int
        /// FFmpeg codec name: "subrip", "ass", "webvtt", "hdmv_pgs_subtitle", "dvd_subtitle", ...
        var codec: String
        var language: String? = nil
        var title: String? = nil
        var isDefault: Bool = false
        /// Text subtitles (SRT, ASS, WebVTT) as opposed to pictures (PGS, VobSub, DVB).
        var isText: Bool
    }

    /// FFmpeg demuxer name, e.g. "matroska,webm".
    var container: String
    /// Container duration as libavformat reports it.
    var durationSeconds: Double?
    /// Container start time (the earliest stream start).
    var startSeconds: Double?
    /// The first real video stream (cover-art attachments are skipped); nil when there is none.
    var video: Video?
    var audioTracks: [Audio]
    var subtitleTracks: [Subtitle]
}

/// Reads a `MediaProbe` with libavformat. All libav pointers stay inside `read(url:)`.
nonisolated enum MediaProber {
    /// Synchronous and blocking: reads the header and a few seconds of the file. Use `load(url:)` from UI code.
    /// Setting `cancel` makes libavformat's reads fail (interrupt callback) and this throws `CancellationError`.
    static func read(url: URL, cancel: ConversionCancelFlag = ConversionCancelFlag()) throws -> MediaProbe {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        return try withExtendedLifetime(cancel) {
            guard let allocated = avformat_alloc_context() else {
                throw FFmpegSupport.error("avformat_alloc_context", FFmpegSupport.errorNoMemory)
            }
            allocated.pointee.interrupt_callback = cancel.interruptCallback()
            var opened: UnsafeMutablePointer<AVFormatContext>? = allocated
            var code = avformat_open_input(&opened, FFmpegSupport.path(url), nil, nil)
            // On failure avformat_open_input frees the context and leaves `opened` nil.
            guard code >= 0, let context = opened else {
                if cancel.isCancelled { throw CancellationError() }
                throw FFmpegSupport.error("avformat_open_input", code)
            }
            defer {
                var toClose: UnsafeMutablePointer<AVFormatContext>? = context
                avformat_close_input(&toClose)
            }
            code = avformat_find_stream_info(context, nil)
            if cancel.isCancelled { throw CancellationError() }
            guard code >= 0 else { throw FFmpegSupport.error("avformat_find_stream_info", code) }
            return probe(context)
        }
    }

    /// Runs `read(url:)` off the caller's actor (the app target defaults to MainActor). Cancelling the calling task
    /// stops the probe within about a second and throws `CancellationError`.
    static func load(url: URL) async throws -> MediaProbe {
        let cancel = ConversionCancelFlag()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) { try MediaProber.read(url: url, cancel: cancel) }.value
        } onCancel: {
            cancel.cancel()
        }
    }

    private static func probe(_ context: UnsafeMutablePointer<AVFormatContext>) -> MediaProbe {
        let containerStart = FFmpegSupport.seconds(microseconds: context.pointee.start_time)
        var video: MediaProbe.Video?
        var audio: [MediaProbe.Audio] = []
        var subtitles: [MediaProbe.Subtitle] = []

        for index in 0..<Int(context.pointee.nb_streams) {
            guard let stream = context.pointee.streams[index], let parameters = stream.pointee.codecpar else { continue }
            let codecID = parameters.pointee.codec_id
            let codec = FFmpegSupport.codecName(codecID)
            let disposition = stream.pointee.disposition
            let isDefault = (disposition & FFmpegSupport.dispositionDefault) != 0
            let start = FFmpegSupport.seconds(stream.pointee.start_time, stream.pointee.time_base)
            var offset: Double?
            if let start, let containerStart { offset = start - containerStart }
            let language = FFmpegSupport.metadata(stream.pointee.metadata, "language")
            let title = FFmpegSupport.metadata(stream.pointee.metadata, "title")

            switch parameters.pointee.codec_type {
            case AVMEDIA_TYPE_VIDEO:
                // Cover art in an MKV shows up as a video stream with the attached-picture flag.
                guard video == nil, (disposition & FFmpegSupport.dispositionAttachedPicture) == 0 else { continue }
                video = videoInfo(index: index, codec: codec, parameters: parameters, start: start, offset: offset)
            case AVMEDIA_TYPE_AUDIO:
                audio.append(MediaProbe.Audio(
                    streamIndex: index,
                    codec: codec,
                    language: language,
                    title: title,
                    channels: Int(parameters.pointee.ch_layout.nb_channels),
                    sampleRate: Int(parameters.pointee.sample_rate),
                    startSeconds: start,
                    startOffsetSeconds: offset,
                    isDefault: isDefault,
                    canDecode: avcodec_find_decoder(codecID) != nil))
            case AVMEDIA_TYPE_SUBTITLE:
                var isText = false
                if let descriptor = avcodec_descriptor_get(codecID) {
                    isText = (descriptor.pointee.props & FFmpegSupport.codecPropTextSubtitle) != 0
                }
                subtitles.append(MediaProbe.Subtitle(
                    streamIndex: index, codec: codec, language: language, title: title, isDefault: isDefault, isText: isText))
            default:
                continue
            }
        }

        return MediaProbe(
            container: context.pointee.iformat.map { String(cString: $0.pointee.name) } ?? "unknown",
            durationSeconds: FFmpegSupport.seconds(microseconds: context.pointee.duration),
            startSeconds: containerStart,
            video: video,
            audioTracks: audio,
            subtitleTracks: subtitles)
    }

    private static func videoInfo(index: Int, codec: String, parameters: UnsafeMutablePointer<AVCodecParameters>,
                                  start: Double?, offset: Double?) -> MediaProbe.Video {
        let codecID = parameters.pointee.codec_id
        let rawProfile = parameters.pointee.profile
        var profile: Int?
        var profileName: String?
        if rawProfile != FFmpegSupport.profileUnknown {
            profile = Int(rawProfile)
            if let decoder = avcodec_find_decoder(codecID) {
                profileName = av_get_profile_name(decoder, rawProfile).map { String(cString: $0) }
            }
        }

        var pixelFormatName: String?
        var bitDepth: Int?
        var chroma: MediaProbe.Chroma?
        if parameters.pointee.format >= 0 {
            let pixelFormat = AVPixelFormat(rawValue: parameters.pointee.format)
            pixelFormatName = av_get_pix_fmt_name(pixelFormat).map { String(cString: $0) }
            if let descriptor = av_pix_fmt_desc_get(pixelFormat) {
                bitDepth = Int(descriptor.pointee.comp.0.depth)
                chroma = chromaOf(descriptor.pointee)
            }
        }

        var dolbyVision: MediaProbe.DolbyVision?
        // FFmpeg 7+ keeps stream-level side data (the Dolby Vision record) on the codec parameters.
        if let sideData = av_packet_side_data_get(parameters.pointee.coded_side_data,
                                                  parameters.pointee.nb_coded_side_data,
                                                  AV_PKT_DATA_DOVI_CONF),
           let bytes = sideData.pointee.data,
           sideData.pointee.size >= MemoryLayout<AVDOVIDecoderConfigurationRecord>.size {
            let record = UnsafeRawPointer(bytes).loadUnaligned(as: AVDOVIDecoderConfigurationRecord.self)
            dolbyVision = MediaProbe.DolbyVision(
                profile: Int(record.dv_profile),
                level: Int(record.dv_level),
                baseLayerCompatibilityID: Int(record.dv_bl_signal_compatibility_id))
        }

        return MediaProbe.Video(
            streamIndex: index,
            codec: codec,
            profile: profile,
            profileName: profileName,
            pixelFormat: pixelFormatName,
            bitDepth: bitDepth,
            chroma: chroma,
            width: Int(parameters.pointee.width),
            height: Int(parameters.pointee.height),
            dolbyVision: dolbyVision,
            startSeconds: start,
            startOffsetSeconds: offset)
    }

    private static func chromaOf(_ descriptor: AVPixFmtDescriptor) -> MediaProbe.Chroma {
        if (descriptor.flags & FFmpegSupport.pixelFormatFlagRGB) != 0 { return .rgb }
        if descriptor.nb_components < 3 { return .monochrome }
        switch (descriptor.log2_chroma_w, descriptor.log2_chroma_h) {
        case (1, 1): return .yuv420
        case (1, 0): return .yuv422
        case (0, 0): return .yuv444
        default: return .other
        }
    }
}
