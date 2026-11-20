@preconcurrency import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import os
import Testing
@testable import ClipDeck

/// Real conversions of the CI fixtures (scripts/make-test-media.sh) with `MediaConverter`, checked with
/// AVFoundation and `ClipExtractor` (T-004 AC-1, AC-3 to AC-7).
///
/// Fixture design (all 24 fps, 8 s of video): second s of the picture has colour s mod 8 (RGB bits: 1 red,
/// 2 green, 4 blue) and the audio beeps for 0.2 s at the start of every even second. Fixture 3's video starts at
/// 1.0 s and its audio 0.5 s later. "Second 0" of a fixture is its first video frame, read from the probe, so the
/// tests also hold if Homebrew's ffmpeg shifts a whole file (B-frame delay).
@MainActor
@Suite(.serialized)
struct MediaConverterTests {
    nonisolated static let fixture1 = "01-h264-bframes-aac-srt-ass.mkv"
    nonisolated static let fixture2 = "02-hevc-main10-flac.mkv"
    nonisolated static let fixture3 = "03-offset-ac3-51-srt.mkv"
    nonisolated static let fixture4 = "04-nosubs-aac51.mkv"
    nonisolated static let fixture5 = "05-h264-hi10p.mkv"
    nonisolated static let fixtureSeconds = 8.0
    nonisolated static let frame = 1.0 / 24.0

    struct Converted {
        let source: URL
        let probe: MediaProbe
        let plan: ConversionPlan
        let folder: URL
        let output: URL
        let report: MediaConverter.Report
    }

    static func fixtureURL(_ name: String) throws -> URL {
        let url = try FFmpegFixtureTests.fixturesFolder().appending(path: name)
        try #require(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)),
                     "Missing fixture \(name). Run scripts/make-test-media.sh (needs ffmpeg).")
        return url
    }

    static func convert(_ name: String, progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> Converted {
        let source = try fixtureURL(name)
        let probe = try await MediaProber.load(url: source)
        let plan = try ConversionPlan.make(probe: probe, supportsAV1: false)
        let folder = try MediaConverter.makeStagingFolder()
        let output = folder.appending(path: "Episode.mp4")
        let report = try await MediaConverter.convert(source: source, plan: plan, to: output, progress: progress)
        return Converted(source: source, probe: probe, plan: plan, folder: folder, output: output, report: report)
    }

    static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    static func folderIsEmpty(_ folder: URL) throws -> Bool {
        try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).isEmpty
    }

    // MARK: AC-1 probe

    @Test func probeFixture1() async throws {
        let probe = try await MediaProber.load(url: Self.fixtureURL(Self.fixture1))
        #expect(probe.container.contains("matroska"))
        let video = try #require(probe.video)
        #expect(video.codec == "h264")
        #expect(video.pixelFormat == "yuv420p")
        #expect(video.bitDepth == 8)
        #expect(video.chroma == .yuv420)
        #expect(video.width == 320 && video.height == 180)
        #expect(video.dolbyVision == nil)
        #expect(video.startSeconds != nil)
        let audio = try #require(probe.audioTracks.first)
        #expect(probe.audioTracks.count == 1)
        #expect(audio.codec == "aac")
        #expect(audio.channels == 2)
        #expect(audio.sampleRate == 48_000)
        #expect(audio.canDecode)
        #expect(audio.startSeconds != nil)
        #expect(probe.subtitleTracks.map(\.codec) == ["subrip", "ass"])
        #expect(probe.subtitleTracks.allSatisfy { $0.isText })
        #expect(probe.subtitleTracks.map(\.language) == ["jpn", "jpn"])
        #expect(probe.subtitleTracks.map(\.title) == ["SRT", "Full"])
        let duration = try #require(probe.durationSeconds)
        #expect(abs(duration - Self.fixtureSeconds) < 0.5)
    }

    @Test func probeFixture2() async throws {
        let probe = try await MediaProber.load(url: Self.fixtureURL(Self.fixture2))
        let video = try #require(probe.video)
        #expect(video.codec == "hevc")
        #expect(video.pixelFormat == "yuv420p10le")
        #expect(video.bitDepth == 10)
        #expect(video.chroma == .yuv420)
        #expect(video.profile == 2, "profile \(String(describing: video.profile)) \(video.profileName ?? "")")
        #expect(probe.audioTracks.map(\.codec) == ["flac"])
        #expect(probe.audioTracks.first?.sampleRate == 48_000)
        #expect(probe.subtitleTracks.isEmpty)
    }

    @Test func probeFixture3StartAndAudioOffset() async throws {
        let probe = try await MediaProber.load(url: Self.fixtureURL(Self.fixture3))
        let start = try #require(probe.startSeconds)
        #expect(abs(start - 1.0) < 0.05, "container start \(start)")
        let video = try #require(probe.video)
        #expect(abs((video.startOffsetSeconds ?? 99) - 0) < 0.05)
        let audio = try #require(probe.audioTracks.first)
        #expect(audio.codec == "ac3")
        #expect(audio.channels == 6)
        #expect(audio.sampleRate == 48_000)
        let offset = try #require(audio.startOffsetSeconds)
        #expect(abs(offset - 0.5) < 0.05, "audio offset \(offset)")
        #expect(probe.subtitleTracks.map(\.codec) == ["subrip"])
    }

    @Test func probeFixture5() async throws {
        let probe = try await MediaProber.load(url: Self.fixtureURL(Self.fixture5))
        let video = try #require(probe.video)
        #expect(video.codec == "h264")
        #expect(video.pixelFormat == "yuv420p10le")
        #expect(video.bitDepth == 10)
        #expect(video.profile == 110)
    }

    // MARK: AC-5 / AC-7 conversions

    @Test(arguments: ["01-h264-bframes-aac-srt-ass.mkv", "02-hevc-main10-flac.mkv", "03-offset-ac3-51-srt.mkv", "04-nosubs-aac51.mkv"])
    func convertsToAPlayableMP4(_ name: String) async throws {
        let converted = try await Self.convert(name)
        defer { try? FileManager.default.removeItem(at: converted.folder) }
        #expect(converted.plan.warnings.isEmpty)
        #expect(converted.report.warnings.isEmpty, "\(name): \(converted.report.warnings)")

        let asset = AVURLAsset(url: converted.output)
        #expect(try await asset.load(.isPlayable))
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        #expect(videoTracks.count == 1)
        #expect(audioTracks.count == 1)
        // Subtitle streams are never written (AC-7): only the two tracks exist.
        #expect(try await asset.load(.tracks).count == 2)
        for type in [AVMediaType.text, .subtitle, .closedCaption] {
            #expect(try await asset.loadTracks(withMediaType: type).isEmpty, "\(type.rawValue) track in \(name)")
        }

        // Lasts as long as the source: 8 s of video from its first frame, on the source clock.
        let videoStart = try #require(converted.probe.video?.startSeconds)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - (videoStart + Self.fixtureSeconds)) <= 0.15,
                "\(name): MP4 \(duration) s, source video \(videoStart) + \(Self.fixtureSeconds) s")

        // No rebasing (AC-4): the MP4's first video frame is at the source's first video frame.
        let videoTrack = try #require(videoTracks.first)
        let mp4VideoStart = try await Self.firstMediaTime(of: videoTrack)
        #expect(abs(mp4VideoStart - videoStart) < Self.frame, "\(name): MP4 video starts at \(mp4VideoStart), source at \(videoStart)")

        // ClipExtractor still works: a 2 s clip and a screenshot.
        let extractor = ClipExtractor(startPaddingMs: 0, endPaddingMs: 0)
        let clip = converted.folder.appending(path: "clip.m4a")
        let image = converted.folder.appending(path: "clip.jpg")
        try await extractor.exportAudio(videoURL: converted.output, range: ClipRange(startMs: 3_000, endMs: 5_000), to: clip)
        let clipMs = try await ClipExtractor.durationMs(of: clip)
        #expect(abs(clipMs - 2_000) <= 150, "\(name): clip was \(clipMs) ms")
        try await extractor.exportScreenshot(videoURL: converted.output, atMs: 4_000, to: image)
        let imageSize = try FileManager.default.attributesOfItem(atPath: image.path(percentEncoded: false))[.size] as? Int
        #expect((imageSize ?? 0) > 0)
    }

    @Test func fixture1CopiesH264AndAAC() async throws {
        let converted = try await Self.convert(Self.fixture1)
        defer { try? FileManager.default.removeItem(at: converted.folder) }
        #expect(converted.plan.audio?.mode == .copy)
        #expect(!converted.plan.video.tagAsHVC1)
        let asset = AVURLAsset(url: converted.output)
        let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
        #expect(try await Self.subtype(of: video) == kCMVideoCodecType_H264)
        let audio = try await Self.audioFormat(of: asset)
        #expect(audio.mFormatID == kAudioFormatMPEG4AAC)
        #expect(audio.mChannelsPerFrame == 2)
        #expect(audio.mSampleRate == 48_000)
    }

    @Test func fixture2TagsHEVCAsHVC1AndTranscodesFLAC() async throws {
        let converted = try await Self.convert(Self.fixture2)
        defer { try? FileManager.default.removeItem(at: converted.folder) }
        #expect(converted.plan.video.tagAsHVC1)
        let asset = AVURLAsset(url: converted.output)
        let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let subtype = try await Self.subtype(of: video)
        #expect(subtype == kCMVideoCodecType_HEVC, "sample entry \(Self.fourCC(subtype)), expected hvc1")
        let audio = try await Self.audioFormat(of: asset)
        #expect(audio.mFormatID == kAudioFormatMPEG4AAC)
        #expect(audio.mChannelsPerFrame == 2)
        #expect(audio.mSampleRate == 48_000)
    }

    @Test func fixture3KeepsItsOffsetsInEditLists() async throws {
        let converted = try await Self.convert(Self.fixture3)
        defer { try? FileManager.default.removeItem(at: converted.folder) }
        let asset = AVURLAsset(url: converted.output)

        let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let videoSegments = try await video.load(.segments)
        #expect(videoSegments.first?.isEmpty == true, "an empty edit holds the 1 s start offset")
        let videoStart = try await Self.firstMediaTime(of: video)
        #expect(abs(videoStart - 1.0) < Self.frame, "video starts at \(videoStart)")

        let audio = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let sourceAudioStart = try #require(converted.probe.audioTracks.first?.startSeconds)
        let audioStart = try await Self.firstMediaTime(of: audio)
        // The AAC encoder's 1024-sample priming starts 21 ms before the first source sample.
        #expect(abs(audioStart - sourceAudioStart) < 0.04, "audio starts at \(audioStart), source at \(sourceAudioStart)")

        let format = try await Self.audioFormat(of: asset)
        #expect(format.mFormatID == kAudioFormatMPEG4AAC)
        #expect(format.mChannelsPerFrame == 2)   // AC-3 5.1 becomes stereo
        #expect(format.mSampleRate == 48_000)
    }

    @Test func fixture4AAC51BecomesStereoAndHasNoWarnings() async throws {
        let converted = try await Self.convert(Self.fixture4)
        defer { try? FileManager.default.removeItem(at: converted.folder) }
        #expect(converted.probe.subtitleTracks.isEmpty)
        #expect(converted.plan.warnings.isEmpty)
        #expect(converted.plan.audio?.mode == .transcodeToAAC(sampleRate: 48_000, channels: 2, bitRate: 192_000))
        let format = try await Self.audioFormat(of: AVURLAsset(url: converted.output))
        #expect(format.mChannelsPerFrame == 2)
    }

    @Test func fixture5IsRejectedAtThePlanStageAndWritesNothing() async throws {
        let probe = try await MediaProber.load(url: Self.fixtureURL(Self.fixture5))
        let folder = try MediaConverter.makeStagingFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let error = ConversionPlanTests.rejection(probe)
        #expect(error == .h264TenBit)
        #expect(error?.message.contains("H.264 10-bit") == true)
        #expect(try Self.folderIsEmpty(folder))
    }

    // MARK: AC-6 sync

    @Test func fixture1PictureAndSoundStayInSync() async throws {
        try await checkSync(Self.fixture1, audioDelay: 0)
    }

    @Test func fixture3PictureAndSoundStayInSync() async throws {
        try await checkSync(Self.fixture3, audioDelay: 0.5)
    }

    /// `audioDelay`: how much later than the first video frame the fixture's audio pattern starts.
    private func checkSync(_ name: String, audioDelay: Double) async throws {
        let converted = try await Self.convert(name)
        defer { try? FileManager.default.removeItem(at: converted.folder) }
        let asset = AVURLAsset(url: converted.output)
        let zero = try #require(converted.probe.video?.startSeconds)

        // Picture: around every colour change, the frame shown is the source frame for that time (within a frame).
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        for second in 1...6 {
            let change = zero + Double(second)
            let before = try await Self.colourIndex(generator, at: change - Self.frame - 0.01)
            let after = try await Self.colourIndex(generator, at: change + Self.frame + 0.01)
            let middle = try await Self.colourIndex(generator, at: change + 0.5)
            #expect(before == (second - 1) % 8, "\(name): colour just before \(change) s")
            #expect(after == second % 8, "\(name): colour just after \(change) s")
            #expect(middle == second % 8, "\(name): colour at \(change + 0.5) s")
        }

        // Sound: every beep starts within 40 ms of its source time.
        let expected = stride(from: zero + audioDelay, to: zero + Self.fixtureSeconds - 0.3, by: 2.0).map { $0 }
        let onsets = try await Self.beepOnsets(in: asset)
        #expect(onsets.count == expected.count, "\(name): onsets \(onsets), expected \(expected)")
        for time in expected {
            let nearest = onsets.min { abs($0 - time) < abs($1 - time) }
            let error = nearest.map { abs($0 - time) } ?? .infinity
            #expect(error <= 0.04, "\(name): beep expected at \(time) s, nearest onset \(String(describing: nearest))")
        }
    }

    // MARK: AC-3 concurrency, progress, cancel

    @Test func coreRunsOffTheMainThreadAndReportsThrottledProgress() async throws {
        let recorder = ConverterProgressRecorder()
        let started = ContinuousClock.now
        let converted = try await Self.convert(Self.fixture4, progress: { recorder.record($0) })
        let elapsed = Self.seconds(ContinuousClock.now - started)
        defer { try? FileManager.default.removeItem(at: converted.folder) }

        #expect(!converted.report.ranOnMainThread)
        #expect(converted.report.videoPackets > 0 && converted.report.audioPackets > 0)
        let values = recorder.values
        #expect(values.first == 0)
        #expect(values.last == 1)
        #expect(values == values.sorted() && Set(values).count == values.count, "values \(values)")
        #expect(values.allSatisfy { (0...1).contains($0) })
        #expect(Double(values.count) <= elapsed * 10 + 3, "\(values.count) reports in \(elapsed) s")
    }

    @Test func mainActorKeepsTickingDuringAConversion() async throws {
        let ticks = ConverterTickCounter()
        let heartbeat = Task { @MainActor in
            while !Task.isCancelled {
                ticks.count += 1
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
        defer { heartbeat.cancel() }
        // The first 4 progress calls sleep 120 ms on the conversion thread, so the conversion lasts at least ~0.4 s.
        let slow = ConverterSlowProgress(delayedCalls: 4, delay: 0.12)
        let started = ContinuousClock.now
        let converted = try await Self.convert(Self.fixture1, progress: { slow.call($0) })
        let elapsed = ContinuousClock.now - started
        let count = ticks.count
        defer { try? FileManager.default.removeItem(at: converted.folder) }

        #expect(elapsed >= .milliseconds(300), "conversion took \(elapsed)")
        // A blocked main actor would give 0 or 1 ticks; 10 ms sleeps give about 30 or more.
        #expect(count >= 8, "\(count) heartbeat ticks in \(elapsed)")
        #expect(!converted.report.ranOnMainThread)
    }

    @Test func cancellingMidwayStopsWithinASecondAndLeavesNoFile() async throws {
        let source = try Self.fixtureURL(Self.fixture1)
        let probe = try await MediaProber.load(url: source)
        let plan = try ConversionPlan.make(probe: probe, supportsAV1: false)
        let folder = try MediaConverter.makeStagingFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let output = folder.appending(path: "Episode.mp4")

        // The first progress report (0, sent once the output file is open) waits for the test to cancel.
        let gate = ConverterGate()
        let task = Task {
            try await MediaConverter.convert(source: source, plan: plan, to: output, progress: { _ in gate.holdOnFirstCall() })
        }
        let deadline = ContinuousClock.now + .seconds(10)
        while !gate.started, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(gate.started, "the conversion never reported progress")
        #expect(FileManager.default.fileExists(atPath: output.path(percentEncoded: false)), "output is open mid-way")

        let cancelledAt = ContinuousClock.now
        task.cancel()
        gate.release()
        let result = await task.result
        let stoppedAfter = ContinuousClock.now - cancelledAt

        switch result {
        case .success: Issue.record("expected CancellationError, the conversion finished")
        case .failure(let error): #expect(error is CancellationError, "got \(error)")
        }
        #expect(stoppedAfter < .seconds(1), "stopped after \(stoppedAfter)")
        #expect(!FileManager.default.fileExists(atPath: output.path(percentEncoded: false)))
        #expect(try Self.folderIsEmpty(folder))
    }

    @Test func alreadyCancelledTaskWritesNothing() async throws {
        let source = try Self.fixtureURL(Self.fixture1)
        let probe = try await MediaProber.load(url: source)
        let plan = try ConversionPlan.make(probe: probe, supportsAV1: false)
        let folder = try MediaConverter.makeStagingFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let output = folder.appending(path: "Episode.mp4")

        // The task inherits the main actor, so it can't start before cancel() below.
        let task = Task { try await MediaConverter.convert(source: source, plan: plan, to: output) }
        task.cancel()
        let result = await task.result
        switch result {
        case .success: Issue.record("expected CancellationError")
        case .failure(let error): #expect(error is CancellationError, "got \(error)")
        }
        #expect(try Self.folderIsEmpty(folder))
    }

    @Test func cancellingAProbeThrowsCancellationError() async throws {
        let source = try Self.fixtureURL(Self.fixture1)
        // The task inherits the main actor, so it can't start before cancel() below.
        let task = Task { try await MediaProber.load(url: source) }
        task.cancel()
        let result = await task.result
        switch result {
        case .success: Issue.record("expected CancellationError, the probe finished")
        case .failure(let error): #expect(error is CancellationError, "got \(error)")
        }
    }

    @Test func aSetCancelFlagStopsTheProbe() throws {
        // Calls the synchronous core directly with the flag already set: the interrupt callback fails the first
        // read fail, and the probe reports a cancellation, not an FFmpeg error.
        let source = try Self.fixtureURL(Self.fixture1)
        let flag = ConversionCancelFlag()
        flag.cancel()
        #expect(throws: CancellationError.self) {
            _ = try MediaProber.read(url: source, cancel: flag)
        }
        // The same file probes fine with a fresh flag.
        let probe = try MediaProber.read(url: source, cancel: ConversionCancelFlag())
        #expect(probe.video?.codec == "h264")
    }

    @Test func aSetCancelFlagStopsTheConverterThroughTheInterruptCallback() throws {
        // Calls the synchronous core with the flag already set: the AVIOInterruptCB fails the first read, so
        // the run ends with CancellationError before any progress is reported and leaves nothing behind.
        let source = try Self.fixtureURL(Self.fixture1)
        let probe = try MediaProber.read(url: source, cancel: ConversionCancelFlag())
        let plan = try ConversionPlan.make(probe: probe, supportsAV1: false)
        let folder = try MediaConverter.makeStagingFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let flag = ConversionCancelFlag()
        flag.cancel()
        let reports = OSAllocatedUnfairLock(initialState: 0)
        #expect(throws: CancellationError.self) {
            _ = try ConversionCore.run(source: source, plan: plan, output: folder.appending(path: "Episode.mp4"), cancel: flag,
                                       progress: { _ in reports.withLock { count in count += 1 } })
        }
        #expect(reports.withLock { count in count } == 0, "no progress is reported")
        #expect(try Self.folderIsEmpty(folder))
    }

    @Test func refusesToOverwriteAnExistingFile() async throws {
        let source = try Self.fixtureURL(Self.fixture1)
        let probe = try await MediaProber.load(url: source)
        let plan = try ConversionPlan.make(probe: probe, supportsAV1: false)
        let folder = try MediaConverter.makeStagingFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let output = folder.appending(path: "Episode.mp4")
        try Data("keep me".utf8).write(to: output)

        await #expect(throws: MediaConversionError.self) {
            _ = try await MediaConverter.convert(source: source, plan: plan, to: output)
        }
        #expect(try Data(contentsOf: output) == Data("keep me".utf8))
    }

    @Test func aPlanThatNoLongerMatchesTheFileFailsAndWritesNothing() async throws {
        let source = try Self.fixtureURL(Self.fixture4)
        let probe = try await MediaProber.load(url: source)
        var plan = try ConversionPlan.make(probe: probe, supportsAV1: false)
        plan.video.codec = "hevc"   // fixture 4 is H.264
        let folder = try MediaConverter.makeStagingFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let output = folder.appending(path: "Episode.mp4")

        await #expect(throws: MediaConversionError.self) {
            _ = try await MediaConverter.convert(source: source, plan: plan, to: output)
        }
        #expect(try Self.folderIsEmpty(folder))
    }

    @Test func stagingFolderIsUnderTmpConverting() throws {
        let folder = try MediaConverter.makeStagingFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(folder.deletingLastPathComponent().lastPathComponent == "Converting")
        #expect(UUID(uuidString: folder.lastPathComponent) != nil)
        #expect(folder.path(percentEncoded: false).hasPrefix(FileManager.default.temporaryDirectory.path(percentEncoded: false)))
    }

    // MARK: Helpers

    /// Where the track's first non-empty edit starts on the asset timeline.
    static func firstMediaTime(of track: AVAssetTrack) async throws -> Double {
        let segments = try await track.load(.segments)
        let media = try #require(segments.first { !$0.isEmpty }, "track has no media segment")
        return media.timeMapping.target.start.seconds
    }

    static func subtype(of track: AVAssetTrack) async throws -> FourCharCode {
        let description = try #require(try await track.load(.formatDescriptions).first)
        return CMFormatDescriptionGetMediaSubType(description)
    }

    static func audioFormat(of asset: AVURLAsset) async throws -> AudioStreamBasicDescription {
        let track = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let description = try #require(try await track.load(.formatDescriptions).first)
        return try #require(CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee)
    }

    static func fourCC(_ code: FourCharCode) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((code >> $0) & 0xFF) }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// The fixture colour index (R = 1, G = 2, B = 4) of the frame shown at `seconds`.
    static func colourIndex(_ generator: AVAssetImageGenerator, at seconds: Double) async throws -> Int {
        let (image, _) = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 90_000))
        return colourIndex(of: image)
    }

    static func colourIndex(of image: CGImage) -> Int {
        var pixel: [UInt8] = [0, 0, 0, 0]
        pixel.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.interpolationQuality = .medium
            // The frame is one solid colour, so scaling it to one pixel keeps that colour.
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return (pixel[0] > 127 ? 1 : 0) | (pixel[1] > 127 ? 2 : 0) | (pixel[2] > 127 ? 4 : 0)
    }

    /// Start times of the beeps, decoded with AVAssetReader on the asset timeline (edit lists applied).
    static func beepOnsets(in asset: AVURLAsset) async throws -> [Double] {
        let track = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let reader = try AVAssetReader(asset: asset)
        let rate = 48_000.0
        let output = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: rate,
            AVNumberOfChannelsKey: 2,
        ])
        reader.add(output)
        try #require(reader.startReading(), "AVAssetReader: \(String(describing: reader.error))")

        var onsets: [Double] = []
        var lastLoud = -Double.infinity
        while let buffer = output.copyNextSampleBuffer() {
            let start = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            var samples = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
            let status = samples.withUnsafeMutableBytes { bytes in
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: bytes.baseAddress!)
            }
            guard status == kCMBlockBufferNoErr else { continue }
            // Interleaved stereo: frame i is samples[2i], samples[2i + 1].
            for frameIndex in 0..<(samples.count / 2) {
                let level = max(abs(samples[2 * frameIndex]), abs(samples[2 * frameIndex + 1]))
                guard level > 0.05 else { continue }
                let time = start + Double(frameIndex) / rate
                if time - lastLoud > 0.5 { onsets.append(time) }   // beeps are 0.2 s on, 1.8 s off
                lastLoud = time
            }
        }
        #expect(reader.status == .completed, "AVAssetReader: \(String(describing: reader.error))")
        return onsets
    }
}

/// Collects progress values from the conversion thread.
final class ConverterProgressRecorder: Sendable {
    private let state = OSAllocatedUnfairLock<[Double]>(initialState: [])
    func record(_ value: Double) { state.withLock { values in values.append(value) } }
    var values: [Double] { state.withLock { values in values } }
}

/// Sleeps on the conversion thread for the first `delayedCalls` progress reports.
final class ConverterSlowProgress: Sendable {
    private let calls = OSAllocatedUnfairLock(initialState: 0)
    let delayedCalls: Int
    let delay: TimeInterval

    init(delayedCalls: Int, delay: TimeInterval) {
        self.delayedCalls = delayedCalls
        self.delay = delay
    }

    func call(_ value: Double) {
        let number = calls.withLock { count in
            count += 1
            return count
        }
        if number <= delayedCalls { Thread.sleep(forTimeInterval: delay) }
    }
}

/// Holds the conversion thread inside its first progress report until the test releases it.
final class ConverterGate: Sendable {
    private struct State: Sendable {
        var calls = 0
        var started = false
        var released = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var started: Bool { state.withLock { value in value.started } }

    func release() { state.withLock { value in value.released = true } }

    func holdOnFirstCall() {
        let first = state.withLock { value in
            value.calls += 1
            value.started = true
            return value.calls == 1
        }
        guard first else { return }
        let deadline = Date().addingTimeInterval(5)
        while !state.withLock({ value in value.released }), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.001)
        }
    }
}

@MainActor
final class ConverterTickCounter {
    var count = 0
}
