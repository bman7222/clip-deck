import Foundation
import SwiftData
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import ClipDeck

/// `VideoImportModel` (T-006 AC-3 to AC-6, the part the upload sheet and "Choose the video again" share): the
/// extension check after picking, the space message and a disabled Add, the idle timer while running, and how a run
/// ends (added, cancelled, failed) with nothing added on cancel or failure. Written by loop-tester against the
/// model's public interface; the views only bind to it.
@MainActor
@Suite(.serialized)
struct VideoImportModelTests {
    let root: URL
    let store: FileStore
    let temporaryFolder: URL
    let container: ModelContainer

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "VideoImportModelTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        store = FileStore(documentsURL: root.appending(path: "Documents", directoryHint: .isDirectory),
                          libraryURL: root.appending(path: "Library", directoryHint: .isDirectory))
        temporaryFolder = root.appending(path: "tmp", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryFolder, withIntermediateDirectories: true)
        store.ensureFolders()
        container = try ModelContainer(for: Show.self, Episode.self, PendingCard.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    var context: ModelContext { container.mainContext }

    func makeImporter(available: Int64? = 1 << 40) -> EpisodeImporter {
        EpisodeImporter(store: store, temporaryFolder: temporaryFolder, supportsAV1: false,
                        availableCapacity: { _ in available })
    }

    func makePickedVideo() async throws -> URL {
        let video = root.appending(path: "Picked", directoryHint: .isDirectory).appending(path: "My Clip.mp4")
        try await TestMediaFactory.makeVideo(at: video, seconds: 2)
        return video
    }

    func episodeCount() throws -> Int { try context.fetch(FetchDescriptor<Episode>()).count }

    var stagingEntries: [String] {
        let path = EpisodeImporter.stagingRoot(in: temporaryFolder).path(percentEncoded: false)
        return (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
    }

    /// Waits (polling on the main actor) until `condition` holds or `seconds` pass.
    func waitUntil(seconds: Double = 30, _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func importWork(_ details: NewEpisodeDetails, into context: ModelContext, probe: RunProbe)
        -> @MainActor (EpisodeImporter, PreparedVideo, EpisodeImportOptions, @escaping @MainActor (Double) -> Void) async throws -> EpisodeImportResult {
        { importer, prepared, options, progress in
            probe.idleTimerDisabledDuringRun = UIApplication.shared.isIdleTimerDisabled
            return try await importer.importEpisode(prepared, as: details, options: options, into: context, progress: progress)
        }
    }

    // MARK: AC-3: extension check after picking

    @Test func anUnsupportedExtensionIsRefusedAtOnceWithTheSpecMessage() {
        let model = VideoImportModel(importer: makeImporter())
        model.pick(URL(fileURLWithPath: "/nowhere/Episode 1.avi"))

        var failed = false
        if case .failed = model.status { failed = true }
        #expect(failed)
        #expect(model.videoError == "“.avi” videos aren't supported. Use MP4, MOV, M4V or MKV.")
        #expect(model.fileName == "Episode 1.avi")
        #expect(!model.canImport)
        #expect(model.prepared == nil)
    }

    @Test func pickersAcceptMoviesAndAnyFile() {
        #expect(FileTypes.videos == [.movie, .item])
    }

    // MARK: AC-4: too little space shows the message and keeps Add disabled

    @Test func tooLittleSpaceShowsBothSizesAndKeepsAddDisabled() async throws {
        let video = try await makePickedVideo()
        let model = VideoImportModel(importer: makeImporter(available: 150_000_000))
        model.pick(video)
        try await waitUntil { !model.isPreparing }

        let size = Int64(try #require(try video.resourceValues(forKeys: [.fileSizeKey]).fileSize))
        let expected = EpisodeImportError.notEnoughSpace(
            neededBytes: StorageSpaceRule.requiredBytes(forSourceBytes: size), availableBytes: 150_000_000).localizedDescription
        #expect(model.videoError == expected)
        #expect(model.videoError?.hasPrefix("This needs about 0.3 GB free; you have 0.1 GB.") == true, "\(model.videoError ?? "nil")")
        #expect(!model.canImport)
        #expect(model.prepared == nil, "a refused file isn't held open")
    }

    // MARK: AC-5: idle timer, success, cancel, failure

    @Test func aSuccessfulRunKeepsTheScreenAwakeThenRestoresItAndAddsTheEpisode() async throws {
        let video = try await makePickedVideo()
        let model = VideoImportModel(importer: makeImporter())
        model.pick(video)
        try await waitUntil { model.canImport }
        try #require(model.canImport, "the MP4 should be ready: \(model.videoError ?? "no error")")
        #expect(model.audioTracks.isEmpty, "no audio picker for an MP4")

        UIApplication.shared.isIdleTimerDisabled = false
        let probe = RunProbe()
        model.run(importWork(NewEpisodeDetails(showName: "Show A", title: "Episode 1"), into: context, probe: probe),
                  completion: { probe.outcome = Self.describe($0) })
        #expect(model.isRunning)
        #expect(!model.canImport, "Add can't be tapped twice while running")
        #expect(UIApplication.shared.isIdleTimerDisabled, "the screen stays awake while importing")

        try await waitUntil { probe.outcome != nil }
        #expect(probe.outcome == "added")
        #expect(probe.idleTimerDisabledDuringRun == true)
        #expect(!UIApplication.shared.isIdleTimerDisabled, "the idle timer is restored afterwards")
        #expect(!model.isRunning)
        #expect(model.prepared == nil, "the imported file is let go, so Add can't add it twice")
        #expect(!model.canImport)
        #expect(try episodeCount() == 1)
        #expect(stagingEntries.isEmpty)
    }

    @Test func cancellingAConversionAddsNothingRestoresTheIdleTimerAndKeepsTheFileForARetry() async throws {
        let source = try MediaConverterTests.fixtureURL(MediaConverterTests.fixture4)
        let gate = ConverterGate()
        var importer = makeImporter()
        importer.onConversionProgress = { _ in gate.holdOnFirstCall() }
        let model = VideoImportModel(importer: importer)
        model.pick(source)
        try await waitUntil { model.canImport }
        try #require(model.canImport, "fixture 4 should be ready: \(model.videoError ?? "no error")")
        #expect(model.prepared?.needsConversion == true)
        #expect(model.selectedAudio == model.prepared?.defaultAudioStreamIndex, "the default track is preselected")

        UIApplication.shared.isIdleTimerDisabled = false
        let probe = RunProbe()
        model.run(importWork(NewEpisodeDetails(showName: "MKV Show", title: "Episode 1"), into: context, probe: probe),
                  completion: { probe.outcome = Self.describe($0) })
        try await waitUntil(seconds: 10) { gate.started }
        try #require(gate.started, "the conversion never reported progress")
        #expect(model.isConverting, "an MKV shows Converting… n%")
        #expect(model.progressText.hasPrefix("Converting… "))
        #expect(UIApplication.shared.isIdleTimerDisabled)

        model.cancelRun()
        gate.release()
        try await waitUntil { probe.outcome != nil }
        #expect(probe.outcome == "cancelled", "Cancel is silent: \(probe.outcome ?? "nil")")
        #expect(!UIApplication.shared.isIdleTimerDisabled)
        #expect(!model.isRunning)
        #expect(try episodeCount() == 0)
        #expect(stagingEntries.isEmpty)
        #expect(model.canImport, "the file stays prepared, so Add episode works again without re-picking")
        model.leave()
        #expect(model.prepared == nil)
    }

    @Test func aFailedSaveEndsWithTheMessageAndAddsNothing() async throws {
        let video = try await makePickedVideo()
        var importer = makeImporter()
        importer.save = { _ in throw SaveFailure() }
        let model = VideoImportModel(importer: importer)
        model.pick(video)
        try await waitUntil { model.canImport }
        try #require(model.canImport)

        let probe = RunProbe()
        model.run(importWork(NewEpisodeDetails(showName: "Show A", title: "Episode 1"), into: context, probe: probe),
                  completion: { probe.outcome = Self.describe($0) })
        try await waitUntil { probe.outcome != nil }
        #expect(probe.outcome == "failed: " + EpisodeImportError.saveFailed("forced by the test").localizedDescription)
        #expect(try episodeCount() == 0)
        #expect(model.canImport, "after a failure the file is still prepared for another try")
        model.leave()
    }

    // MARK: AC-6: relink through the same model and importer

    @Test func relinkingThroughTheModelConvertsAnMKVWithTheDefaultTrack() async throws {
        let show = Show(name: "Old Show", colorIndex: 0)
        context.insert(show)
        let episode = Episode(title: "Episode 2", number: 2, videoPath: "Videos/Old Show/Episode 2.mov", show: show)
        context.insert(episode)
        try context.save()

        let model = VideoImportModel(importer: makeImporter())
        let probe = RunProbe()
        let context = self.context
        // As MissingFileView does: start the relink as soon as the file is ready.
        model.pick(try MediaConverterTests.fixtureURL(MediaConverterTests.fixture4)) {
            model.run({ importer, prepared, options, progress in
                try await importer.relink(episode, to: prepared, options: options, in: context, progress: progress)
            }, completion: { probe.outcome = Self.describe($0) })
        }
        try await waitUntil { probe.outcome != nil }
        #expect(probe.outcome == "added")
        #expect(episode.videoPath == "Videos/Old Show/Episode 2.mp4")
        #expect(store.exists(episode.videoPath))
        #expect(stagingEntries.isEmpty)
    }

    static func describe(_ outcome: VideoImportModel.Outcome) -> String {
        switch outcome {
        case .added: "added"
        case .cancelled: "cancelled"
        case .failed(let message): "failed: \(message)"
        }
    }
}

@MainActor
final class RunProbe {
    var outcome: String?
    var idleTimerDisabledDuringRun: Bool?
}
