#if DEBUG
@preconcurrency import AVFoundation
import CoreVideo

/// DEBUG-only: writes a small MP4 (coloured frames + a 440 Hz tone) so unit tests and the
/// UI-test seed have a real video without shipping fixture files. Never used in Release builds.
enum TestMediaFactory {
    enum FactoryError: Error {
        case writerFailed(String)
        case bufferFailed
        case timedOut
    }

    static let width = 320
    static let height = 180
    static let framesPerSecond: Int32 = 10
    static let sampleRate = 44_100

    static func makeVideo(at url: URL, seconds: Int = 6) async throws {
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        videoInput.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
        ])
        audioInput.expectsMediaDataInRealTime = false
        writer.add(videoInput)
        writer.add(audioInput)

        guard writer.startWriting() else {
            throw FactoryError.writerFailed(writer.error?.localizedDescription ?? "startWriting")
        }
        writer.startSession(atSourceTime: .zero)

        let format = try pcmFormat()
        let samplesPerFrame = sampleRate / Int(framesPerSecond)
        let totalFrames = seconds * Int(framesPerSecond)

        // Interleave one video frame with its matching slice of audio so neither input stalls.
        for frame in 0..<totalFrames {
            try await waitUntilReady(videoInput, writer: writer)
            guard let pool = adaptor.pixelBufferPool else { throw FactoryError.bufferFailed }
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            guard let pixelBuffer else { throw FactoryError.bufferFailed }
            fill(pixelBuffer, second: frame / Int(framesPerSecond))
            _ = adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: framesPerSecond))

            try await waitUntilReady(audioInput, writer: writer)
            let sample = try toneBuffer(format: format, startFrame: frame * samplesPerFrame, frameCount: samplesPerFrame)
            _ = audioInput.append(sample)
        }

        videoInput.markAsFinished()
        audioInput.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw FactoryError.writerFailed(writer.error?.localizedDescription ?? "finishWriting")
        }
    }

    /// How long one input may stay "not ready" before the factory gives up. It is a time limit, not an attempt
    /// count: the old 1,000 x 5 ms loop gave up after about 5 s on a slow CI VM and seeded nothing (T-034).
    static let readyTimeout: Duration = .seconds(60)

    private static func waitUntilReady(_ input: AVAssetWriterInput, writer: AVAssetWriter) async throws {
        let deadline = ContinuousClock.now + readyTimeout
        while !input.isReadyForMoreMediaData {
            // A failed writer never becomes ready again; report why instead of waiting out the deadline.
            if writer.status == .failed || writer.status == .cancelled {
                throw FactoryError.writerFailed(writer.error?.localizedDescription ?? "writer status \(writer.status.rawValue)")
            }
            if ContinuousClock.now >= deadline { throw FactoryError.timedOut }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private static func fill(_ buffer: CVPixelBuffer, second: Int) {
        let palette: [(UInt8, UInt8, UInt8)] = [(214, 162, 31), (92, 184, 73), (215, 99, 94), (210, 99, 138), (46, 166, 245), (139, 99, 210)]
        let (b, g, r) = palette[second % palette.count]
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer)?.assumingMemoryBound(to: UInt8.self) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<height {
            let row = base + y * bytesPerRow
            for x in 0..<width {
                row[x * 4] = b
                row[x * 4 + 1] = g
                row[x * 4 + 2] = r
                row[x * 4 + 3] = 255
            }
        }
    }

    private static func pcmFormat() throws -> CMAudioFormatDescription {
        var description = AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        var format: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault, asbd: &description, layoutSize: 0, layout: nil,
            magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format
        )
        guard status == noErr, let format else { throw FactoryError.bufferFailed }
        return format
    }

    private static func toneBuffer(format: CMAudioFormatDescription, startFrame: Int, frameCount: Int) throws -> CMSampleBuffer {
        var samples = [Int16](repeating: 0, count: frameCount)
        for index in 0..<frameCount {
            let time = Double(startFrame + index) / Double(sampleRate)
            samples[index] = Int16(sin(2 * Double.pi * 440 * time) * 8_000)
        }
        let byteCount = frameCount * MemoryLayout<Int16>.size

        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: byteCount,
            blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0,
            dataLength: byteCount, flags: 0, blockBufferOut: &blockBuffer
        )
        guard status == noErr, let blockBuffer else { throw FactoryError.bufferFailed }
        status = samples.withUnsafeBytes { bytes in
            CMBlockBufferReplaceDataBytes(with: bytes.baseAddress!, blockBuffer: blockBuffer, offsetIntoDestination: 0, dataLength: byteCount)
        }
        guard status == noErr else { throw FactoryError.bufferFailed }

        var sampleBuffer: CMSampleBuffer?
        status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: kCFAllocatorDefault, dataBuffer: blockBuffer, formatDescription: format,
            sampleCount: frameCount,
            presentationTimeStamp: CMTime(value: CMTimeValue(startFrame), timescale: CMTimeScale(sampleRate)),
            packetDescriptions: nil, sampleBufferOut: &sampleBuffer
        )
        guard status == noErr, let sampleBuffer else { throw FactoryError.bufferFailed }
        return sampleBuffer
    }

    /// A short SRT matching the 6-second test video.
    static let sampleSRT = """
    1
    00:00:00,500 --> 00:00:02,000
    こんにちは

    2
    00:00:02,000 --> 00:00:04,000
    元気ですか

    3
    00:00:04,000 --> 00:00:05,500
    またね

    """
}
#endif
