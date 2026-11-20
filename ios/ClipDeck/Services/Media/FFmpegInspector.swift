import Foundation
internal import AetherLibavformat
internal import AetherLibavcodec
internal import AetherLibavutil

/// What libavformat reports about one stream.
nonisolated struct FFmpegStreamInfo: Sendable, Equatable {
    enum Kind: String, Sendable { case video, audio, subtitle, other }

    let index: Int
    let kind: Kind
    /// FFmpeg's codec name, e.g. "h264", "hevc", "aac", "ac3", "flac", "subrip", "ass".
    let codec: String
    /// Audio channel count; 0 for other kinds.
    let channels: Int
    /// Video pixel format name, e.g. "yuv420p10le"; nil for other kinds or when unknown.
    let pixelFormat: String?
    /// Stream start time in seconds, nil when the file does not say.
    let startSeconds: Double?
}

/// What libavformat reports about a whole file.
nonisolated struct FFmpegContainerInfo: Sendable, Equatable {
    /// FFmpeg's demuxer name, e.g. "matroska,webm".
    let formatName: String
    /// Container start time in seconds, nil when unknown.
    let startSeconds: Double?
    let durationSeconds: Double?
    let streams: [FFmpegStreamInfo]

    func streams(of kind: FFmpegStreamInfo.Kind) -> [FFmpegStreamInfo] {
        streams.filter { $0.kind == kind }
    }
}

nonisolated struct FFmpegError: Error, CustomStringConvertible, Sendable {
    let step: String
    let code: Int32
    let message: String
    var description: String { "FFmpeg \(step) failed (\(code)): \(message)" }
}

/// A small libavformat wrapper: opens a file and lists its streams. It proves the FFmpeg frameworks link
/// and run (T-012); the converter (T-004) builds its own probe on the same calls.
/// Synchronous and blocking: call it off the main actor for big files.
nonisolated enum FFmpegInspector {
    static func inspect(path: String) throws -> FFmpegContainerInfo {
        var opened: UnsafeMutablePointer<AVFormatContext>? = nil
        var code = avformat_open_input(&opened, path, nil, nil)
        guard code >= 0, let context = opened else {
            throw FFmpegError(step: "avformat_open_input", code: code, message: describe(code))
        }
        // avformat_close_input frees the context and nils the pointer it is given.
        defer {
            var toClose: UnsafeMutablePointer<AVFormatContext>? = context
            avformat_close_input(&toClose)
        }

        code = avformat_find_stream_info(context, nil)
        guard code >= 0 else {
            throw FFmpegError(step: "avformat_find_stream_info", code: code, message: describe(code))
        }

        var streams: [FFmpegStreamInfo] = []
        let count = Int(context.pointee.nb_streams)
        for index in 0..<count {
            guard let stream = context.pointee.streams[index], let parameters = stream.pointee.codecpar else { continue }
            let kind: FFmpegStreamInfo.Kind
            switch parameters.pointee.codec_type {
            case AVMEDIA_TYPE_VIDEO: kind = .video
            case AVMEDIA_TYPE_AUDIO: kind = .audio
            case AVMEDIA_TYPE_SUBTITLE: kind = .subtitle
            default: kind = .other
            }
            let codec = avcodec_get_name(parameters.pointee.codec_id).map { String(cString: $0) } ?? "unknown"
            var pixelFormat: String?
            if kind == .video, parameters.pointee.format >= 0 {
                pixelFormat = av_get_pix_fmt_name(AVPixelFormat(rawValue: parameters.pointee.format)).map { String(cString: $0) }
            }
            let timeBase = stream.pointee.time_base
            var start: Double?
            if stream.pointee.start_time != noPTS, timeBase.den != 0 {
                start = Double(stream.pointee.start_time) * Double(timeBase.num) / Double(timeBase.den)
            }
            streams.append(FFmpegStreamInfo(
                index: index,
                kind: kind,
                codec: codec,
                channels: kind == .audio ? Int(parameters.pointee.ch_layout.nb_channels) : 0,
                pixelFormat: pixelFormat,
                startSeconds: start))
        }

        let formatName = context.pointee.iformat.map { String(cString: $0.pointee.name) } ?? "unknown"
        return FFmpegContainerInfo(
            formatName: formatName,
            startSeconds: seconds(fromMicroseconds: context.pointee.start_time),
            durationSeconds: seconds(fromMicroseconds: context.pointee.duration),
            streams: streams)
    }

    /// AV_NOPTS_VALUE is a macro Swift does not import.
    private static let noPTS = Int64.min

    private static func seconds(fromMicroseconds value: Int64) -> Double? {
        value == noPTS ? nil : Double(value) / 1_000_000
    }

    private static func describe(_ code: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        av_strerror(code, &buffer, buffer.count)
        // The bytes up to the first NUL, decoded as UTF-8 (invalid bytes become U+FFFD, as String(cString:) does).
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
