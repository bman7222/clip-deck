import Foundation
internal import AetherLibavformat
internal import AetherLibavcodec
internal import AetherLibavutil

/// Small helpers shared by `MediaProber` and the converter. FFmpeg's function-like macros (AVERROR, MKTAG,
/// AV_NOPTS_VALUE) don't import into Swift, so their values are rebuilt here (checked against the FFmpegBuild
/// 3.16.0 / FFmpeg n8.1.3 headers: error.h, avformat.h, avcodec.h, avio.h, codec_desc.h, pixdesc.h, defs.h).
nonisolated enum FFmpegSupport {
    /// AV_NOPTS_VALUE.
    static let noPTS = Int64.min

    /// MKTAG(a, b, c, d).
    static func tag(_ a: Unicode.Scalar, _ b: Unicode.Scalar, _ c: Unicode.Scalar, _ d: Unicode.Scalar) -> UInt32 {
        UInt32(UInt8(ascii: a)) | (UInt32(UInt8(ascii: b)) << 8) | (UInt32(UInt8(ascii: c)) << 16) | (UInt32(UInt8(ascii: d)) << 24)
    }

    /// FFERRTAG(a, b, c, d) = -MKTAG(a, b, c, d).
    static func errorTag(_ a: Unicode.Scalar, _ b: Unicode.Scalar, _ c: Unicode.Scalar, _ d: Unicode.Scalar) -> Int32 {
        -Int32(bitPattern: tag(a, b, c, d))
    }

    static let errorEOF = errorTag("E", "O", "F", " ")           // AVERROR_EOF
    static let errorExit = errorTag("E", "X", "I", "T")          // AVERROR_EXIT (the interrupt callback fired)
    static let errorInvalidData = errorTag("I", "N", "D", "A")   // AVERROR_INVALIDDATA
    static let errorAgain: Int32 = -POSIXErrorCode.EAGAIN.rawValue   // AVERROR(EAGAIN)
    static let errorNoMemory: Int32 = -POSIXErrorCode.ENOMEM.rawValue

    /// The MP4 sample entry AVFoundation needs for HEVC.
    static let hvc1Tag = tag("h", "v", "c", "1")

    static let formatGlobalHeader: Int32 = 0x0040            // AVFMT_GLOBALHEADER
    static let codecFlagGlobalHeader: Int32 = 1 << 22        // AV_CODEC_FLAG_GLOBAL_HEADER
    static let avioFlagWrite: Int32 = 2                      // AVIO_FLAG_WRITE
    static let dispositionDefault: Int32 = 1 << 0            // AV_DISPOSITION_DEFAULT
    static let dispositionAttachedPicture: Int32 = 1 << 10   // AV_DISPOSITION_ATTACHED_PIC
    static let codecPropTextSubtitle: Int32 = 1 << 17        // AV_CODEC_PROP_TEXT_SUB
    static let pixelFormatFlagRGB: UInt64 = 1 << 5           // AV_PIX_FMT_FLAG_RGB
    static let profileUnknown: Int32 = -99                   // AV_PROFILE_UNKNOWN

    /// libav* path for a file URL. The "file:" prefix stops libavformat from reading a colon in a file name
    /// (e.g. "Re:Zero 01.mkv") as a protocol.
    static func path(_ url: URL) -> String {
        "file:" + url.path(percentEncoded: false)
    }

    static func describe(_ code: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        av_strerror(code, &buffer, buffer.count)
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    static func error(_ step: String, _ code: Int32) -> FFmpegError {
        FFmpegError(step: step, code: code, message: describe(code))
    }

    static func codecName(_ id: AVCodecID) -> String {
        avcodec_get_name(id).map { String(cString: $0) } ?? "unknown"
    }

    static func metadata(_ dictionary: OpaquePointer?, _ key: String) -> String? {
        guard let dictionary, let entry = av_dict_get(dictionary, key, nil, 0), let value = entry.pointee.value else { return nil }
        let text = String(cString: value)
        return text.isEmpty ? nil : text
    }

    static func seconds(_ timestamp: Int64, _ timeBase: AVRational) -> Double? {
        guard timestamp != noPTS, timeBase.den != 0 else { return nil }
        return Double(timestamp) * Double(timeBase.num) / Double(timeBase.den)
    }

    /// AVFormatContext start_time / duration are in AV_TIME_BASE (microseconds).
    static func seconds(microseconds value: Int64) -> Double? {
        value == noPTS ? nil : Double(value) / 1_000_000
    }
}
