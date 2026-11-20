import Foundation

/// Why a file can't be imported. Each message names the format and says what to do (spec › J-4).
nonisolated enum UnsupportedMediaError: Error, Equatable, Sendable, LocalizedError {
    case noVideoTrack
    /// A codec the iPhone can't play, e.g. "VP9", "MPEG-4 Part 2", "MPEG-2", "VC-1".
    case videoCodec(String)
    /// Chroma other than 4:2:0, e.g. codec "HEVC", chroma "4:2:2".
    case chroma(codec: String, chroma: String)
    /// H.264 High 10 ("Hi10P").
    case h264TenBit
    /// Bit depth the iPhone can't decode, e.g. 12-bit HEVC.
    case bitDepth(codec: String, bits: Int)
    /// An HEVC profile other than Main and Main 10.
    case hevcProfile(String)
    /// FFmpeg couldn't tell the pixel format, and the profile doesn't settle it.
    case unknownVideoFormat(codec: String)
    case dolbyVisionProfile(Int)
    /// AV1 on a device without AV1 hardware decoding.
    case av1NotSupported
    /// The chosen audio stream index isn't an audio track of this file.
    case audioChoice(Int)
    /// Audio that must be transcoded but has no decoder in this FFmpeg build.
    case audioCodec(String)

    static let advice = "Convert it on a computer to H.264 (8-bit) or HEVC, for example with HandBrake, then try again."

    var errorDescription: String? { message }

    var message: String {
        switch self {
        case .noVideoTrack:
            "This file has no video track Clip Deck can use."
        case .videoCodec(let name):
            "\(name) video can't be played on iPhone. \(Self.advice)"
        case .chroma(let codec, let chroma):
            "\(codec) video with \(chroma) colour can't be played on iPhone. \(Self.advice)"
        case .h264TenBit:
            "H.264 10-bit (Hi10P) video can't be played on iPhone. \(Self.advice)"
        case .bitDepth(let codec, let bits):
            "\(bits)-bit \(codec) video can't be played on iPhone. \(Self.advice)"
        case .hevcProfile(let profile):
            "HEVC \(profile) video can't be played on iPhone. \(Self.advice)"
        case .unknownVideoFormat(let codec):
            "Clip Deck couldn't read the format of this \(codec) video. \(Self.advice)"
        case .dolbyVisionProfile(let profile):
            "Dolby Vision profile \(profile) video can't be played on iPhone. \(Self.advice)"
        case .av1NotSupported:
            "This iPhone can't play AV1 video. \(Self.advice)"
        case .audioChoice:
            "The chosen audio track isn't in this file. Choose another one."
        case .audioCodec(let name):
            "\(name) audio can't be converted. Choose another audio track, or convert the file on a computer."
        }
    }
}

/// How an MKV becomes an MP4 (spec › Conversion rules). A pure function of the probe, the chosen audio
/// track and `supportsAV1`: no I/O, so every rule is unit-tested on probe values.
/// Subtitle streams never appear in a plan: the converter writes none (T-005 extracts them as files).
nonisolated struct ConversionPlan: Sendable, Equatable {
    nonisolated struct Video: Sendable, Equatable {
        var streamIndex: Int
        /// FFmpeg codec name; the converter checks the file still has it.
        var codec: String
        /// Write the MP4 sample entry as `hvc1` (HEVC). AVFoundation doesn't play `hev1`.
        var tagAsHVC1: Bool
        /// Drop the Dolby Vision configuration so the MP4 holds the plain HEVC base layer.
        var dropsDolbyVision: Bool
    }

    nonisolated enum AudioMode: Sendable, Equatable {
        /// Stream copy (AAC or MP3 with at most 2 channels).
        case copy
        /// Decode, downmix/resample with swresample, encode with FFmpeg's AAC-LC encoder.
        case transcodeToAAC(sampleRate: Int, channels: Int, bitRate: Int)
    }

    nonisolated struct Audio: Sendable, Equatable {
        var streamIndex: Int
        var codec: String
        var mode: AudioMode
    }

    nonisolated enum Warning: String, Sendable, Equatable {
        /// The file has no audio track: it plays, but cards will have no sound.
        case noAudioTrack
    }

    var video: Video
    /// nil only when the file has no audio track at all.
    var audio: Audio?
    var warnings: [Warning]
    /// From the probe; used for progress when the file size is unknown.
    var sourceStartSeconds: Double?
    var sourceDurationSeconds: Double?

    static let transcodeBitRate = 192_000
    static let transcodeChannels = 2
    static let maximumSampleRate = 48_000
    /// Sample rates FFmpeg's native AAC encoder accepts (libavcodec/aacenctab.c, ff_mpeg4audio_sample_rates).
    static let aacSampleRates = [96_000, 88_200, 64_000, 48_000, 44_100, 32_000, 24_000, 22_050, 16_000, 12_000, 11_025, 8_000, 7_350]

    /// - Parameters:
    ///   - audioStreamIndex: the user's choice (a stream index from `probe.audioTracks`); nil = the file's
    ///     default-flagged track, else the first.
    ///   - supportsAV1: `VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)` on the device.
    static func make(probe: MediaProbe, audioStreamIndex: Int? = nil, supportsAV1: Bool) throws(UnsupportedMediaError) -> ConversionPlan {
        let video = try videoPlan(probe.video, supportsAV1: supportsAV1)

        let chosen: MediaProbe.Audio?
        if let audioStreamIndex {
            guard let track = probe.audioTracks.first(where: { $0.streamIndex == audioStreamIndex }) else {
                throw .audioChoice(audioStreamIndex)
            }
            chosen = track
        } else {
            chosen = defaultAudioTrack(in: probe)
        }

        var audio: Audio?
        var warnings: [Warning] = []
        if let chosen {
            let mode = try audioMode(chosen)
            audio = Audio(streamIndex: chosen.streamIndex, codec: chosen.codec, mode: mode)
        } else {
            warnings.append(.noAudioTrack)
        }

        return ConversionPlan(
            video: video,
            audio: audio,
            warnings: warnings,
            sourceStartSeconds: probe.startSeconds,
            sourceDurationSeconds: probe.durationSeconds)
    }

    /// The file's default-flagged audio track, else the first one.
    static func defaultAudioTrack(in probe: MediaProbe) -> MediaProbe.Audio? {
        probe.audioTracks.first(where: \.isDefault) ?? probe.audioTracks.first
    }

    /// The source rate, capped at 48 kHz, snapped down to a rate the AAC encoder accepts.
    static func outputSampleRate(forSource rate: Int) -> Int {
        let target = rate > 0 ? min(rate, maximumSampleRate) : maximumSampleRate
        return aacSampleRates.filter { $0 <= target }.max() ?? aacSampleRates.last ?? maximumSampleRate
    }

    /// A readable codec name for messages.
    static func displayName(ofCodec codec: String) -> String {
        switch codec {
        case "h264": "H.264"
        case "hevc": "HEVC"
        case "av1": "AV1"
        case "vp9": "VP9"
        case "vp8": "VP8"
        case "mpeg4": "MPEG-4 Part 2 (DivX/Xvid)"
        case "mpeg2video": "MPEG-2"
        case "mpeg1video": "MPEG-1"
        case "vc1": "VC-1"
        case "wmv3": "WMV 9"
        case "theora": "Theora"
        case "aac": "AAC"
        case "mp3": "MP3"
        case "ac3": "AC-3"
        case "eac3": "E-AC-3"
        case "flac": "FLAC"
        case "opus": "Opus"
        case "vorbis": "Vorbis"
        case "dts": "DTS"
        case "truehd": "TrueHD"
        default: codec.uppercased()
        }
    }

    // MARK: Video rules

    private static func videoPlan(_ video: MediaProbe.Video?, supportsAV1: Bool) throws(UnsupportedMediaError) -> Video {
        guard let video else { throw .noVideoTrack }
        let name = displayName(ofCodec: video.codec)

        // Profile 5 (and any other Dolby Vision without a compatible base layer) only plays as Dolby Vision.
        if let dolbyVision = video.dolbyVision, dolbyVision.profile == 5 || dolbyVision.baseLayerCompatibilityID == 0 {
            throw .dolbyVisionProfile(dolbyVision.profile)
        }

        switch video.codec {
        case "h264":
            if video.chroma != nil, video.bitDepth != nil {
                try checkPixels(video, codecName: name, allowedDepths: [8])
            } else {
                try checkH264Profile(video.profile)
            }
            return Video(streamIndex: video.streamIndex, codec: video.codec, tagAsHVC1: false, dropsDolbyVision: video.dolbyVision != nil)

        case "hevc":
            if video.chroma != nil, video.bitDepth != nil {
                try checkPixels(video, codecName: name, allowedDepths: [8, 10])
            } else if video.profile == nil {
                throw .unknownVideoFormat(codec: name)
            }
            // Main (1) and Main 10 (2) only; unknown profile is fine once the pixels passed.
            if let profile = video.profile, profile != 1, profile != 2 {
                throw .hevcProfile(video.profileName ?? "profile \(profile)")
            }
            return Video(streamIndex: video.streamIndex, codec: video.codec, tagAsHVC1: true, dropsDolbyVision: video.dolbyVision != nil)

        case "av1":
            guard supportsAV1 else { throw .av1NotSupported }
            guard video.chroma != nil, video.bitDepth != nil else { throw .unknownVideoFormat(codec: name) }
            try checkPixels(video, codecName: name, allowedDepths: [8, 10])
            return Video(streamIndex: video.streamIndex, codec: video.codec, tagAsHVC1: false, dropsDolbyVision: video.dolbyVision != nil)

        default:
            throw .videoCodec(name)
        }
    }

    private static func checkPixels(_ video: MediaProbe.Video, codecName: String, allowedDepths: Set<Int>) throws(UnsupportedMediaError) {
        guard let chroma = video.chroma, let depth = video.bitDepth else { throw .unknownVideoFormat(codec: codecName) }
        guard chroma == .yuv420 else { throw .chroma(codec: codecName, chroma: chroma.rawValue) }
        guard allowedDepths.contains(depth) else {
            if video.codec == "h264", depth == 10 { throw .h264TenBit }
            throw .bitDepth(codec: codecName, bits: depth)
        }
    }

    /// Used only when FFmpeg couldn't report the pixel format (AV_PROFILE_H264_* numbers from defs.h).
    private static func checkH264Profile(_ profile: Int?) throws(UnsupportedMediaError) {
        guard let profile else { throw .unknownVideoFormat(codec: "H.264") }
        switch profile {
        case 66, 66 | (1 << 9), 77, 88, 100:   // Baseline, Constrained Baseline, Main, Extended, High
            return
        case 110, 110 | (1 << 11):             // High 10, High 10 Intra
            throw .h264TenBit
        case 122, 122 | (1 << 11):             // High 4:2:2
            throw .chroma(codec: "H.264", chroma: MediaProbe.Chroma.yuv422.rawValue)
        case 244, 244 | (1 << 11), 44:         // High 4:4:4 Predictive / Intra, CAVLC 4:4:4
            throw .chroma(codec: "H.264", chroma: MediaProbe.Chroma.yuv444.rawValue)
        default:
            throw .unknownVideoFormat(codec: "H.264")
        }
    }

    // MARK: Audio rules

    private static func audioMode(_ track: MediaProbe.Audio) throws(UnsupportedMediaError) -> AudioMode {
        if track.codec == "aac" || track.codec == "mp3", (1...2).contains(track.channels) {
            return .copy
        }
        guard track.canDecode else { throw .audioCodec(displayName(ofCodec: track.codec)) }
        return .transcodeToAAC(
            sampleRate: outputSampleRate(forSource: track.sampleRate),
            channels: transcodeChannels,
            bitRate: transcodeBitRate)
    }
}
