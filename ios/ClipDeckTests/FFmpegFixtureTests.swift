import Foundation
import Testing
@testable import ClipDeck

/// Opens each generated MKV fixture (scripts/make-test-media.sh) with libavformat. This proves the FFmpeg
/// frameworks link and run in the simulator, and that the fixtures contain what the later tests assume.
/// The folder comes from CLIPDECK_FIXTURES (scripts/test-ios.sh sets TEST_RUNNER_CLIPDECK_FIXTURES); without it
/// the tests look in <repo>/build/fixtures.
struct FFmpegFixtureTests {
    static func fixturesFolder() throws -> URL {
        if let path = ProcessInfo.processInfo.environment["CLIPDECK_FIXTURES"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        // This file is <repo>/ios/ClipDeckTests/FFmpegFixtureTests.swift.
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return repo.appending(path: "build/fixtures", directoryHint: .isDirectory)
    }

    static func inspect(_ name: String) throws -> FFmpegContainerInfo {
        let url = try fixturesFolder().appending(path: name)
        try #require(FileManager.default.fileExists(atPath: url.path),
                     "Missing fixture \(name) in \(url.deletingLastPathComponent().path). Run scripts/make-test-media.sh (needs ffmpeg).")
        return try FFmpegInspector.inspect(path: url.path)
    }

    @Test func fixture1H264WithAACAndTwoSubtitleTracks() throws {
        let info = try Self.inspect("01-h264-bframes-aac-srt-ass.mkv")
        #expect(info.formatName.contains("matroska"))
        #expect(info.streams.count == 4)
        let video = try #require(info.streams(of: .video).first)
        #expect(info.streams(of: .video).count == 1)
        #expect(video.codec == "h264")
        #expect(video.pixelFormat == "yuv420p")
        let audio = info.streams(of: .audio)
        #expect(audio.map(\.codec) == ["aac"])
        #expect(audio.first?.channels == 2)
        #expect(info.streams(of: .subtitle).map(\.codec) == ["subrip", "ass"])
        let duration = try #require(info.durationSeconds)
        #expect(abs(duration - 8) < 0.5)
        let start = try #require(info.startSeconds)
        #expect(abs(start) < 0.1)
    }

    @Test func fixture2HEVCMain10WithFLAC() throws {
        let info = try Self.inspect("02-hevc-main10-flac.mkv")
        #expect(info.streams.count == 2)
        let video = try #require(info.streams(of: .video).first)
        #expect(video.codec == "hevc")
        #expect(video.pixelFormat == "yuv420p10le")
        #expect(info.streams(of: .audio).map(\.codec) == ["flac"])
        #expect(info.streams(of: .subtitle).isEmpty)
    }

    @Test func fixture3StartsAtOneSecondWithDelayedAC3() throws {
        let info = try Self.inspect("03-offset-ac3-51-srt.mkv")
        let video = try #require(info.streams(of: .video).first)
        #expect(video.codec == "h264")
        let audio = try #require(info.streams(of: .audio).first)
        #expect(info.streams(of: .audio).count == 1)
        #expect(audio.codec == "ac3")
        #expect(audio.channels == 6)
        #expect(info.streams(of: .subtitle).map(\.codec) == ["subrip"])

        // The file starts at 1.0 s, and the audio starts about 0.5 s after the video.
        let start = try #require(info.startSeconds)
        #expect(abs(start - 1.0) < 0.05, "container start \(start)")
        let videoStart = try #require(video.startSeconds)
        let audioStart = try #require(audio.startSeconds)
        #expect(abs(videoStart - 1.0) < 0.05, "video start \(videoStart)")
        // Spec: "audio delayed 0.5 s". Bound it on both sides (an AC-3 encoder priming of 256 samples is 5 ms).
        #expect(abs(audioStart - videoStart - 0.5) < 0.05, "audio start \(audioStart), video start \(videoStart)")
        #expect(abs(audioStart - 1.5) < 0.05, "audio start \(audioStart)")
    }

    @Test func fixture4HasNoSubtitlesAndAAC51() throws {
        let info = try Self.inspect("04-nosubs-aac51.mkv")
        #expect(info.streams.count == 2)
        #expect(info.streams(of: .video).map(\.codec) == ["h264"])
        let audio = try #require(info.streams(of: .audio).first)
        #expect(audio.codec == "aac")
        #expect(audio.channels == 6)
        #expect(info.streams(of: .subtitle).isEmpty)
    }

    @Test func fixture5IsH264TenBit() throws {
        let info = try Self.inspect("05-h264-hi10p.mkv")
        let video = try #require(info.streams(of: .video).first)
        #expect(video.codec == "h264")
        #expect(video.pixelFormat == "yuv420p10le")
    }

    @Test func missingFileThrowsAClearError() {
        #expect(throws: FFmpegError.self) {
            try FFmpegInspector.inspect(path: "/nonexistent/clipdeck-missing.mkv")
        }
    }

    /// Added by loop-tester (T-012 round 2): the av_strerror text is decoded up to its NUL (FFmpegInspector.describe).
    @Test func missingFileErrorCarriesFFmpegMessage() {
        do {
            _ = try FFmpegInspector.inspect(path: "/nonexistent/clipdeck-missing.mkv")
            Issue.record("expected FFmpegError")
        } catch let error as FFmpegError {
            #expect(error.step == "avformat_open_input")
            #expect(error.code < 0)
            #expect(error.message == "No such file or directory", "message: \(error.message.debugDescription)")
            #expect(!error.message.contains("\u{0}"))
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }
}
