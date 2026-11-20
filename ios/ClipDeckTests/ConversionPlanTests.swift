import Foundation
import Testing
@testable import ClipDeck

/// The conversion rules (spec › Conversion rules, T-004 AC-2), on probe values only: no FFmpeg, no files.
struct ConversionPlanTests {
    // MARK: Probe builders

    static func video(_ codec: String = "h264", pixelFormat: String? = "yuv420p", depth: Int? = 8,
                      chroma: MediaProbe.Chroma? = .yuv420, profile: Int? = nil,
                      dolbyVision: MediaProbe.DolbyVision? = nil) -> MediaProbe.Video {
        MediaProbe.Video(streamIndex: 0, codec: codec, profile: profile, pixelFormat: pixelFormat, bitDepth: depth,
                         chroma: chroma, width: 1920, height: 1080, dolbyVision: dolbyVision)
    }

    static func audio(_ index: Int = 1, _ codec: String = "aac", channels: Int = 2, rate: Int = 48_000,
                      isDefault: Bool = false, canDecode: Bool = true) -> MediaProbe.Audio {
        MediaProbe.Audio(streamIndex: index, codec: codec, channels: channels, sampleRate: rate,
                         isDefault: isDefault, canDecode: canDecode)
    }

    static func probe(video: MediaProbe.Video? = ConversionPlanTests.video(),
                      audio: [MediaProbe.Audio] = [ConversionPlanTests.audio()],
                      subtitles: [MediaProbe.Subtitle] = []) -> MediaProbe {
        MediaProbe(container: "matroska,webm", durationSeconds: 1_440, startSeconds: 0,
                   video: video, audioTracks: audio, subtitleTracks: subtitles)
    }

    static func plan(_ probe: MediaProbe, audio: Int? = nil, supportsAV1: Bool = false) throws -> ConversionPlan {
        try ConversionPlan.make(probe: probe, audioStreamIndex: audio, supportsAV1: supportsAV1)
    }

    /// The rejection for `probe`, or nil when it is accepted.
    static func rejection(_ probe: MediaProbe, supportsAV1: Bool = false) -> UnsupportedMediaError? {
        do {
            _ = try ConversionPlan.make(probe: probe, supportsAV1: supportsAV1)
            return nil
        } catch {
            return error
        }
    }

    static func expectRejected(_ probe: MediaProbe, as expected: UnsupportedMediaError, mentioning text: String,
                               supportsAV1: Bool = false, sourceLocation: SourceLocation = #_sourceLocation) {
        let error = rejection(probe, supportsAV1: supportsAV1)
        #expect(error == expected, sourceLocation: sourceLocation)
        let message = error?.message ?? ""
        #expect(message.contains(text), "message: \(message)", sourceLocation: sourceLocation)
        #expect(message.contains("HandBrake"), "message: \(message)", sourceLocation: sourceLocation)
    }

    // MARK: Video: copied

    @Test func copiesH264yuv420p() throws {
        let plan = try Self.plan(Self.probe())
        #expect(plan.video == ConversionPlan.Video(streamIndex: 0, codec: "h264", tagAsHVC1: false, dropsDolbyVision: false))
        #expect(plan.warnings.isEmpty)
    }

    @Test func copiesHEVCMainAsHVC1() throws {
        let plan = try Self.plan(Self.probe(video: Self.video("hevc", profile: 1)))
        #expect(plan.video.tagAsHVC1)
        #expect(!plan.video.dropsDolbyVision)
    }

    @Test func copiesHEVCMain10AsHVC1() throws {
        let plan = try Self.plan(Self.probe(video: Self.video("hevc", pixelFormat: "yuv420p10le", depth: 10, profile: 2)))
        #expect(plan.video == ConversionPlan.Video(streamIndex: 0, codec: "hevc", tagAsHVC1: true, dropsDolbyVision: false))
    }

    @Test func copiesDolbyVision81AsHVC1BaseLayer() throws {
        let video = Self.video("hevc", pixelFormat: "yuv420p10le", depth: 10, profile: 2,
                               dolbyVision: MediaProbe.DolbyVision(profile: 8, level: 6, baseLayerCompatibilityID: 1))
        let plan = try Self.plan(Self.probe(video: video))
        #expect(plan.video.tagAsHVC1)
        #expect(plan.video.dropsDolbyVision)
    }

    @Test func h264WithoutPixelFormatFallsBackToTheProfile() throws {
        let high = Self.video(pixelFormat: nil, depth: nil, chroma: nil, profile: 100)
        #expect(try Self.plan(Self.probe(video: high)).video.codec == "h264")
        let high10 = Self.video(pixelFormat: nil, depth: nil, chroma: nil, profile: 110)
        #expect(Self.rejection(Self.probe(video: high10)) == .h264TenBit)
        let unknown = Self.video(pixelFormat: nil, depth: nil, chroma: nil, profile: nil)
        #expect(Self.rejection(Self.probe(video: unknown)) == .unknownVideoFormat(codec: "H.264"))
    }

    // MARK: Video: rejected

    @Test func rejectsDolbyVisionProfile5() {
        let video = Self.video("hevc", pixelFormat: "yuv420p10le", depth: 10, profile: 2,
                               dolbyVision: MediaProbe.DolbyVision(profile: 5, level: 6, baseLayerCompatibilityID: 0))
        Self.expectRejected(Self.probe(video: video), as: .dolbyVisionProfile(5), mentioning: "Dolby Vision profile 5")
    }

    @Test func rejects422() {
        let video = Self.video("hevc", pixelFormat: "yuv422p10le", depth: 10, chroma: .yuv422, profile: 4)
        Self.expectRejected(Self.probe(video: video), as: .chroma(codec: "HEVC", chroma: "4:2:2"), mentioning: "4:2:2")
    }

    @Test func rejects444() {
        let video = Self.video("h264", pixelFormat: "yuv444p", depth: 8, chroma: .yuv444, profile: 244)
        Self.expectRejected(Self.probe(video: video), as: .chroma(codec: "H.264", chroma: "4:4:4"), mentioning: "4:4:4")
    }

    @Test func rejects12Bit() {
        let video = Self.video("hevc", pixelFormat: "yuv420p12le", depth: 12, profile: 4)
        Self.expectRejected(Self.probe(video: video), as: .bitDepth(codec: "HEVC", bits: 12), mentioning: "12-bit")
    }

    @Test func rejectsH264TenBit() {
        let video = Self.video("h264", pixelFormat: "yuv420p10le", depth: 10, profile: 110)
        Self.expectRejected(Self.probe(video: video), as: .h264TenBit, mentioning: "H.264 10-bit")
    }

    @Test func rejectsVP9() {
        let video = Self.video("vp9", profile: 0)
        Self.expectRejected(Self.probe(video: video), as: .videoCodec("VP9"), mentioning: "VP9")
    }

    @Test func rejectsOtherCodecsByName() {
        Self.expectRejected(Self.probe(video: Self.video("mpeg4")), as: .videoCodec("MPEG-4 Part 2 (DivX/Xvid)"), mentioning: "MPEG-4")
        Self.expectRejected(Self.probe(video: Self.video("mpeg2video")), as: .videoCodec("MPEG-2"), mentioning: "MPEG-2")
        Self.expectRejected(Self.probe(video: Self.video("vc1")), as: .videoCodec("VC-1"), mentioning: "VC-1")
    }

    @Test func rejectsHEVCRangeExtensionsEvenIn420() {
        let video = Self.video("hevc", pixelFormat: "yuv420p", depth: 8, profile: 4)
        #expect(Self.rejection(Self.probe(video: video)) == .hevcProfile("profile 4"))
    }

    @Test func rejectsAFileWithoutVideo() {
        #expect(Self.rejection(Self.probe(video: nil)) == .noVideoTrack)
    }

    // MARK: AV1

    @Test func av1IsCopiedOnlyWhenTheDeviceDecodesIt() throws {
        let probe = Self.probe(video: Self.video("av1", pixelFormat: "yuv420p10le", depth: 10, profile: 0))
        let plan = try Self.plan(probe, supportsAV1: true)
        #expect(plan.video == ConversionPlan.Video(streamIndex: 0, codec: "av1", tagAsHVC1: false, dropsDolbyVision: false))
        Self.expectRejected(probe, as: .av1NotSupported, mentioning: "AV1", supportsAV1: false)
    }

    // MARK: Audio

    @Test func aacStereoIsCopied() throws {
        let plan = try Self.plan(Self.probe(audio: [Self.audio(1, "aac", channels: 2)]))
        #expect(plan.audio == ConversionPlan.Audio(streamIndex: 1, codec: "aac", mode: .copy))
    }

    @Test func mp3StereoIsCopied() throws {
        let plan = try Self.plan(Self.probe(audio: [Self.audio(1, "mp3", channels: 2, rate: 44_100)]))
        #expect(plan.audio?.mode == .copy)
    }

    struct TranscodeCase: Sendable, CustomTestStringConvertible {
        var codec: String
        var channels: Int
        var rate: Int
        var expectedRate: Int
        var testDescription: String { "\(codec) \(channels) ch \(rate) Hz" }
    }

    @Test(arguments: [
        TranscodeCase(codec: "aac", channels: 6, rate: 48_000, expectedRate: 48_000),     // AAC 5.1 becomes stereo (Brent)
        TranscodeCase(codec: "ac3", channels: 6, rate: 48_000, expectedRate: 48_000),
        TranscodeCase(codec: "eac3", channels: 6, rate: 48_000, expectedRate: 48_000),
        TranscodeCase(codec: "flac", channels: 2, rate: 96_000, expectedRate: 48_000),    // capped at 48 kHz
        TranscodeCase(codec: "flac", channels: 2, rate: 44_100, expectedRate: 44_100),    // 44.1 kHz stays 44.1 kHz
        TranscodeCase(codec: "opus", channels: 2, rate: 48_000, expectedRate: 48_000),
        TranscodeCase(codec: "vorbis", channels: 2, rate: 44_100, expectedRate: 44_100),
        TranscodeCase(codec: "truehd", channels: 8, rate: 48_000, expectedRate: 48_000),
        TranscodeCase(codec: "mp3", channels: 6, rate: 48_000, expectedRate: 48_000),
    ])
    func otherAudioIsTranscodedToStereoAAC(_ example: TranscodeCase) throws {
        let track = Self.audio(1, example.codec, channels: example.channels, rate: example.rate)
        let plan = try Self.plan(Self.probe(audio: [track]))
        #expect(plan.audio == ConversionPlan.Audio(
            streamIndex: 1, codec: example.codec,
            mode: .transcodeToAAC(sampleRate: example.expectedRate, channels: 2, bitRate: 192_000)))
    }

    @Test func outputSampleRates() {
        #expect(ConversionPlan.outputSampleRate(forSource: 96_000) == 48_000)
        #expect(ConversionPlan.outputSampleRate(forSource: 48_000) == 48_000)
        #expect(ConversionPlan.outputSampleRate(forSource: 44_100) == 44_100)
        #expect(ConversionPlan.outputSampleRate(forSource: 22_050) == 22_050)
        #expect(ConversionPlan.outputSampleRate(forSource: 37_800) == 32_000)   // not an AAC rate: next one down
        #expect(ConversionPlan.outputSampleRate(forSource: 0) == 48_000)        // unknown
    }

    @Test func defaultAudioIsTheDefaultFlaggedTrack() throws {
        let tracks = [Self.audio(1, "aac", isDefault: false), Self.audio(2, "ac3", channels: 6, isDefault: true)]
        let plan = try Self.plan(Self.probe(audio: tracks))
        #expect(plan.audio?.streamIndex == 2)
    }

    @Test func defaultAudioIsTheFirstTrackWhenNoneIsFlagged() throws {
        let tracks = [Self.audio(1, "flac"), Self.audio(2, "aac")]
        #expect(try Self.plan(Self.probe(audio: tracks)).audio?.streamIndex == 1)
    }

    @Test func chosenAudioTrackWins() throws {
        let tracks = [Self.audio(1, "aac", isDefault: true), Self.audio(2, "flac")]
        let plan = try Self.plan(Self.probe(audio: tracks), audio: 2)
        #expect(plan.audio?.streamIndex == 2)
        #expect(plan.audio?.mode == .transcodeToAAC(sampleRate: 48_000, channels: 2, bitRate: 192_000))
    }

    @Test func choosingAStreamThatIsNotAudioIsAnError() {
        do {
            _ = try ConversionPlan.make(probe: Self.probe(), audioStreamIndex: 0, supportsAV1: false)
            Issue.record("expected audioChoice")
        } catch {
            #expect(error == .audioChoice(0))
        }
    }

    @Test func audioWithoutADecoderIsRejectedByName() {
        let probe = Self.probe(audio: [Self.audio(1, "dts", channels: 6, canDecode: false)])
        #expect(Self.rejection(probe) == .audioCodec("DTS"))
    }

    @Test func noAudioTrackGivesAVideoOnlyPlanWithAWarning() throws {
        let plan = try Self.plan(Self.probe(audio: []))
        #expect(plan.audio == nil)
        #expect(plan.warnings == [.noAudioTrack])
    }

    // MARK: Subtitles (AC-7)

    @Test func zeroSubtitleTracksGiveNoWarning() throws {
        let plan = try Self.plan(Self.probe(subtitles: []))
        #expect(plan.warnings.isEmpty)
    }

    @Test func pictureOnlySubtitleTracksGiveNoWarning() throws {
        let pictures = [
            MediaProbe.Subtitle(streamIndex: 2, codec: "hdmv_pgs_subtitle", language: "jpn", isText: false),
            MediaProbe.Subtitle(streamIndex: 3, codec: "dvd_subtitle", language: "eng", isText: false),
        ]
        let plan = try Self.plan(Self.probe(subtitles: pictures))
        #expect(plan.warnings.isEmpty)
        #expect(plan.video.streamIndex == 0)
        #expect(plan.audio?.streamIndex == 1)   // the plan names only the video and one audio stream
    }

    @Test func planCarriesTheSourceClock() throws {
        var probe = Self.probe()
        probe.startSeconds = 1.0
        probe.durationSeconds = 9.0
        let plan = try Self.plan(probe)
        #expect(plan.sourceStartSeconds == 1.0)
        #expect(plan.sourceDurationSeconds == 9.0)
    }
}

/// The converter's pure helpers.
struct ConverterHelperTests {
    @Test func progressIsThrottledAndRising() {
        var throttle = ProgressThrottle(interval: 0.1)
        let start = throttle.next(0, now: 10.0, force: true)
        let tooSoon = throttle.next(0.05, now: 10.05)
        let later = throttle.next(0.10, now: 10.11)
        let backwards = throttle.next(0.08, now: 10.50)
        let same = throttle.next(0.10, now: 10.60)
        let tooBig = throttle.next(2.0, now: 10.70)
        let notANumber = throttle.next(.nan, now: 11.0)
        #expect(start == 0)
        #expect(tooSoon == nil)
        #expect(later == 0.10)
        #expect(backwards == nil)
        #expect(same == nil)
        #expect(tooBig == 1.0)
        #expect(notANumber == nil)
    }

    @Test func forcedReportsIgnoreTheInterval() {
        var throttle = ProgressThrottle(interval: 0.1)
        let start = throttle.next(0, now: 1.0, force: true)
        let tooSoon = throttle.next(0.5, now: 1.01)
        let end = throttle.next(1, now: 1.02, force: true)
        #expect(start == 0)
        #expect(tooSoon == nil)
        #expect(end == 1)
    }

    @Test func wellFormedBFrameTimestampsPassUnchanged() throws {
        var fixer = TimestampFixer()
        // I P B B as a B-frame encoder emits them: DTS rises, PTS is reordered and never below DTS.
        let packets: [(Int64, Int64)] = [(2, 0), (5, 1), (3, 2), (4, 3), (8, 4), (6, 5), (7, 6)]
        for (pts, dts) in packets {
            let fixed = try fixer.fix(pts: pts, dts: dts)
            #expect(fixed?.pts == pts && fixed?.dts == dts, "packet \(pts)/\(dts)")
        }
        #expect(fixer.repairs == 0)
    }

    @Test func negativeStartTimestampsAreKept() throws {
        // AAC priming and B-frame delay start below zero; the MP4 edit list trims that, so nothing is shifted.
        var fixer = TimestampFixer()
        let first = try fixer.fix(pts: -1024, dts: -1024)
        #expect(first?.pts == -1024 && first?.dts == -1024)
        #expect(fixer.repairs == 0)
    }

    @Test func repeatedOrFallingDTSIsBumped() throws {
        var fixer = TimestampFixer()
        _ = try fixer.fix(pts: 10, dts: 10)
        let same = try fixer.fix(pts: 12, dts: 10)
        let falling = try fixer.fix(pts: 11, dts: 5)
        #expect(same?.dts == 11 && same?.pts == 12)
        #expect(falling?.dts == 12 && falling?.pts == 12)
        #expect(fixer.repairs == 2)
    }

    @Test func dtsAfterPTSUsesTheMedian() throws {
        var fixer = TimestampFixer()
        _ = try fixer.fix(pts: 100, dts: 100)
        let fixed = try fixer.fix(pts: 101, dts: 150)   // median of 101, 150 and 101 (the next allowed DTS) = 101
        let late = try fixer.fix(pts: 90, dts: 120)     // median of 90, 120 and 102 = 102
        #expect(fixed?.pts == 101 && fixed?.dts == 101)
        #expect(late?.pts == 102 && late?.dts == 102)
    }

    @Test func missingTimestampsAreFilled() throws {
        var fixer = TimestampFixer()
        let nothing = try fixer.fix(pts: nil, dts: nil)   // nothing to go on yet: dropped
        let onlyPTS = try fixer.fix(pts: 40, dts: nil)
        let onlyDTS = try fixer.fix(pts: nil, dts: 41)
        let neither = try fixer.fix(pts: nil, dts: nil)
        #expect(nothing == nil)
        #expect(onlyPTS?.pts == 40 && onlyPTS?.dts == 40)
        #expect(onlyDTS?.pts == 41 && onlyDTS?.dts == 41)
        #expect(neither?.pts == 42 && neither?.dts == 42)
    }

    /// The thrown value for `fix`, or nil when it returned. A trap here would crash the test run.
    static func outOfRange(_ fixer: inout TimestampFixer, pts: Int64?, dts: Int64?) -> TimestampOutOfRange? {
        do {
            _ = try fixer.fix(pts: pts, dts: dts)
            return nil
        } catch {
            return error
        }
    }

    @Test func extremeTimestampsAreRejectedWithoutATrap() {
        // A damaged or hostile MKV can carry any Int64. Each call twice in a row: the second used to hit
        // `lastDTS + 1` and the median sum, which trap in Swift.
        for value in [Int64.max, Int64.min, Int64.max - 1, Int64.min + 1, TimestampFixer.limit + 1, -TimestampFixer.limit - 1] {
            var fixer = TimestampFixer()
            let first = Self.outOfRange(&fixer, pts: value, dts: value)
            let second = Self.outOfRange(&fixer, pts: value, dts: value)
            let dtsOnly = Self.outOfRange(&fixer, pts: nil, dts: value)
            let ptsOnly = Self.outOfRange(&fixer, pts: value, dts: nil)
            let expected = TimestampOutOfRange(value: value)
            #expect(first == expected, "\(value)")
            #expect(second == expected, "\(value) again")
            #expect(dtsOnly == expected, "\(value) as DTS only")
            #expect(ptsOnly == expected, "\(value) as PTS only")
            #expect(fixer.lastDTS == nil, "nothing was accepted")
        }
    }

    @Test func extremeValueAfterANearLimitPacketIsRejected() {
        var fixer = TimestampFixer()
        let atLimit = Self.outOfRange(&fixer, pts: TimestampFixer.limit, dts: TimestampFixer.limit)
        let nearMax = Self.outOfRange(&fixer, pts: Int64.max - 1, dts: Int64.max)
        let mixed = Self.outOfRange(&fixer, pts: Int64.min, dts: Int64.max)
        #expect(atLimit == nil)
        #expect(nearMax == TimestampOutOfRange(value: Int64.max - 1))
        #expect(mixed == TimestampOutOfRange(value: Int64.min))
        #expect(fixer.lastDTS == TimestampFixer.limit)
    }

    @Test func repairsAtTheLimitDoNotTrap() throws {
        var fixer = TimestampFixer()
        let limit = TimestampFixer.limit
        let first = try fixer.fix(pts: limit, dts: limit)
        let repeated = try fixer.fix(pts: limit, dts: limit)            // bumped to limit + 1
        let again = try fixer.fix(pts: nil, dts: nil)                   // next tick after that
        let backwards = try fixer.fix(pts: -limit, dts: limit)          // DTS > PTS: the median, by comparison
        #expect(first?.dts == limit)
        #expect(repeated?.dts == limit + 1 && repeated?.pts == limit + 1)
        #expect(again?.dts == limit + 2)
        #expect(backwards?.dts == limit + 3 && backwards?.pts == limit + 3)
    }

    @Test func decodeErrorsAreSkippedUntilTheTrackLooksBroken() {
        // A long episode with a few damaged frames keeps going.
        var scattered = DecodeErrorBudget()
        for _ in 0..<10_000 { scattered.countPacket() }
        var keptGoing = true
        for _ in 0..<200 where !scattered.recordError() { keptGoing = false }
        #expect(keptGoing)
        #expect(scattered.errors == 200)

        // A track where every packet fails gives up just past the always-skip count.
        var broken = DecodeErrorBudget()
        var gaveUpAt: Int?
        for index in 1...1_000 {
            broken.countPacket()
            if !broken.recordError() {
                gaveUpAt = index
                break
            }
        }
        #expect(gaveUpAt == DecodeErrorBudget.alwaysSkip + 1)

        // A few errors at the very start (before many packets were read) are still skipped.
        var early = DecodeErrorBudget()
        early.countPacket()
        var earlyOK = true
        for _ in 0..<DecodeErrorBudget.alwaysSkip where !early.recordError() { earlyOK = false }
        #expect(earlyOK)
    }

    @Test func damagedFileMessagesAreClear() {
        let timestamp = MediaConversionError.damagedFile("\(TimestampOutOfRange(value: Int64.max))").errorDescription ?? ""
        #expect(timestamp.contains("looks damaged"), "\(timestamp)")
        #expect(timestamp.contains("out of range: \(Int64.max)"), "\(timestamp)")
        #expect(MediaConverter.Warning.skippedDamagedAudio(1).message.contains("1 damaged audio frame was skipped"))
        #expect(MediaConverter.Warning.skippedDamagedAudio(3).message.contains("3 damaged audio frames were skipped"))
    }
}
