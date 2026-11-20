@preconcurrency import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import ClipDeck

/// `EpisodeImporter` (T-006 AC-1, AC-2 and the importer side of AC-6): the MP4 copy path, the MKV path with fixture 4,
/// cancel mid-convert, the launch sweep, rollback after a failed save, relink, and the free-space rule.
///
/// Every test gets its own Documents, Library and temporary folder under a fresh folder, so the sweep and the
/// "nothing left behind" checks can't touch other suites' files.
@MainActor
@Suite(.serialized)
struct EpisodeImporterTests {
    let root: URL
    let store: FileStore
    let temporaryFolder: URL
    let container: ModelContainer

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "EpisodeImporterTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        store = FileStore(documentsURL: root.appending(path: "Documents", directoryHint: .isDirectory),
                          libraryURL: root.appending(path: "Library", directoryHint: .isDirectory))
        temporaryFolder = root.appending(path: "tmp", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryFolder, withIntermediateDirectories: true)
        store.ensureFolders()
        container = try ModelContainer(for: Show.self, Episode.self, PendingCard.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    var context: ModelContext { container.mainContext }

    /// Plenty of free space unless a test says otherwise.
    func makeImporter(available: Int64? = 1 << 40) -> EpisodeImporter {
        EpisodeImporter(store: store, temporaryFolder: temporaryFolder, supportsAV1: false,
                        availableCapacity: { _ in available })
    }

    /// An importer whose conversion stops at its first progress report until the test releases `gate`.
    func makeGatedImporter(_ gate: ConverterGate) -> EpisodeImporter {
        var importer = makeImporter()
        importer.onConversionProgress = { _ in gate.holdOnFirstCall() }
        return importer
    }

    /// A 2-second MP4 and the sample SRT, outside Documents (as if picked in Files).
    func makePickedFiles() async throws -> (video: URL, subtitle: URL) {
        let folder = root.appending(path: "Picked", directoryHint: .isDirectory)
        let video = folder.appending(path: "My Clip.mp4")
        try await TestMediaFactory.makeVideo(at: video, seconds: 2)
        let subtitle = folder.appending(path: "sample.srt")
        try TestMediaFactory.sampleSRT.write(to: subtitle, atomically: true, encoding: .utf8)
        return (video, subtitle)
    }

    /// Regular files below `folder`, as relative paths.
    func files(in folder: URL) -> [String] {
        let fileManager = FileManager.default
        let subpaths = (try? fileManager.subpathsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        return subpaths.filter { subpath in
            var isFolder: ObjCBool = false
            let exists = fileManager.fileExists(atPath: folder.appending(path: subpath).path(percentEncoded: false),
                                                isDirectory: &isFolder)
            return exists && !isFolder.boolValue
        }.sorted()
    }

    var libraryFiles: [String] { files(in: store.videosFolder) + files(in: store.subtitlesFolder) }

    /// Entries left in `tmp/Converting/` (none when the folder is gone).
    var stagingEntries: [String] {
        let path = EpisodeImporter.stagingRoot(in: temporaryFolder).path(percentEncoded: false)
        return (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
    }

    func episodeCount() throws -> Int { try context.fetch(FetchDescriptor<Episode>()).count }
    func showCount() throws -> Int { try context.fetch(FetchDescriptor<Show>()).count }

    func thrownError(_ body: () async throws -> Void) async -> (any Error)? {
        do {
            try await body()
            return nil
        } catch {
            return error
        }
    }

    func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    // MARK: MP4 copy path

    @Test func copiesAnMP4AndItsSubtitleIntoTheShowFolders() async throws {
        let picked = try await makePickedFiles()
        let importer = makeImporter()
        let log = ProgressLog()

        let prepared = try await importer.prepare(picked.video)
        #expect(!prepared.needsConversion)
        #expect(prepared.fileExtension == "mp4")
        #expect(prepared.audioTracks.isEmpty)
        #expect(prepared.sourceBytes > 0)
        #expect(prepared.access.isOpen)

        let result = try await importer.importEpisode(
            prepared,
            as: NewEpisodeDetails(showName: "  Show A ", title: " Episode 1 ", number: 1, subtitleFile: picked.subtitle),
            into: context,
            progress: { log.values.append($0) })

        #expect(result.episode.title == "Episode 1")
        #expect(result.episode.number == 1)
        #expect(result.episode.show?.name == "Show A")
        #expect(result.episode.videoPath == "Videos/Show A/Episode 1.mp4")
        #expect(result.episode.subtitlePath == "Subtitles/Show A/Episode 1/sample.srt")
        #expect(result.warnings.isEmpty)
        #expect(store.exists("Videos/Show A/Episode 1.mp4"))
        #expect(store.exists("Subtitles/Show A/Episode 1/sample.srt"))
        let copied = try Data(contentsOf: store.absoluteURL("Videos/Show A/Episode 1.mp4"))
        let original = try Data(contentsOf: picked.video)
        #expect(copied == original)
        #expect(exists(picked.video), "the picked file is copied, not moved")
        #expect(try episodeCount() == 1)
        #expect(try showCount() == 1)
        #expect(stagingEntries.isEmpty)
        #expect(log.values.first == 0)
        #expect(log.values.last == 1)
        #expect(!prepared.access.isOpen, "a successful import closes the file")
    }

    @Test func aSecondEpisodeJoinsTheExistingShowIgnoringCaseAndGetsAUniqueName() async throws {
        let picked = try await makePickedFiles()
        let importer = makeImporter()
        let first = try await importer.prepare(picked.video)
        _ = try await importer.importEpisode(first, as: NewEpisodeDetails(showName: "Show A", title: "Episode 1"), into: context)
        let second = try await importer.prepare(picked.video)
        let result = try await importer.importEpisode(second, as: NewEpisodeDetails(showName: "show a", title: "Episode 1"), into: context)

        #expect(result.episode.show?.name == "Show A")
        #expect(result.episode.videoPath == "Videos/Show A/Episode 1 (2).mp4")
        #expect(try showCount() == 1)
        #expect(try episodeCount() == 2)
    }

    // MARK: MKV path

    @Test func convertsFixture4IntoAPlayableMP4Episode() async throws {
        let source = try MediaConverterTests.fixtureURL(MediaConverterTests.fixture4)
        let importer = makeImporter()
        let log = ProgressLog()
        let stages = StageLog()

        let prepared = try await importer.prepare(source, onStage: { stages.values.append($0) })
        #expect(stages.values == [.probing], "a local file isn't downloaded from iCloud")
        #expect(prepared.needsConversion)
        #expect(prepared.fileExtension == "mkv")
        #expect(prepared.audioTracks.count == 1)
        #expect(prepared.defaultAudioStreamIndex == prepared.audioTracks.first?.streamIndex)
        #expect(prepared.warnings.isEmpty)
        #expect(prepared.probe?.subtitleTracks.isEmpty == true)

        let result = try await importer.importEpisode(
            prepared,
            as: NewEpisodeDetails(showName: "MKV Show", title: "Episode 1", number: 1),
            into: context,
            progress: { log.values.append($0) })

        #expect(result.episode.videoPath == "Videos/MKV Show/Episode 1.mp4")
        #expect(result.episode.subtitlePath == nil)
        #expect(result.warnings.isEmpty, "fixture 4 has no subtitles and clean audio: \(result.warnings)")
        #expect(libraryFiles == ["MKV Show/Episode 1.mp4"])
        let asset = AVURLAsset(url: store.absoluteURL(result.episode.videoPath))
        #expect(try await asset.load(.isPlayable))
        #expect(exists(source), "the MKV is read in place and never changed")
        #expect(stagingEntries.isEmpty)
        #expect(try episodeCount() == 1)
        #expect(log.values.first == 0)
        #expect(log.values.last == 1)
        let rising = zip(log.values, log.values.dropFirst()).allSatisfy { pair in pair.0 < pair.1 }
        #expect(rising, "progress only rises: \(log.values)")
    }

    @Test func rejectsHi10PWhenPreparing() async throws {
        let source = try MediaConverterTests.fixtureURL(MediaConverterTests.fixture5)
        let importer = makeImporter()
        let error = await thrownError { _ = try await importer.prepare(source) }
        #expect(error as? EpisodeImportError == .unsupported(.h264TenBit))
        #expect(stagingEntries.isEmpty)
        #expect(libraryFiles.isEmpty)
    }

    @Test func rejectsOtherVideoTypesByExtension() async throws {
        let importer = makeImporter()
        let error = await thrownError { _ = try await importer.prepare(root.appending(path: "Episode.AVI")) }
        #expect(error as? EpisodeImportError == .unsupportedVideoType("avi"))
        #expect(error?.localizedDescription == "“.avi” videos aren't supported. Use MP4, MOV, M4V or MKV.")
        #expect(EpisodeImporter.isSupportedVideo(URL(fileURLWithPath: "/x/Episode.MKV")))
        #expect(EpisodeImporter.needsConversion(URL(fileURLWithPath: "/x/Episode.mkv")))
        #expect(!EpisodeImporter.needsConversion(URL(fileURLWithPath: "/x/Episode.m4v")))
        #expect(!EpisodeImporter.isSupportedVideo(URL(fileURLWithPath: "/x/Episode.webm")))
    }

    // MARK: Cancel, crash leftovers, failed save

    @Test func cancellingMidConvertLeavesNothingInTheLibraryOrStaging() async throws {
        let source = try MediaConverterTests.fixtureURL(MediaConverterTests.fixture4)
        let gate = ConverterGate()
        let prepared = try await makeGatedImporter(gate).prepare(source)
        let details = NewEpisodeDetails(showName: "MKV Show", title: "Episode 1")

        let task = Task { @MainActor in
            _ = try await self.makeGatedImporter(gate).importEpisode(prepared, as: details, into: self.container.mainContext)
        }
        let deadline = ContinuousClock.now + .seconds(10)
        while !gate.started, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(gate.started, "the conversion never reported progress")

        // Mid-convert: the output is open in staging, and nothing has reached Documents.
        #expect(stagingEntries.count == 1)
        #expect(libraryFiles.isEmpty)
        #expect(try episodeCount() == 0)

        task.cancel()
        gate.release()
        let result = await task.result
        switch result {
        case .success: Issue.record("expected CancellationError, the import finished")
        case .failure(let error): #expect(error is CancellationError, "got \(error)")
        }
        #expect(libraryFiles.isEmpty)
        #expect(stagingEntries.isEmpty, "staging left: \(stagingEntries)")
        #expect(try episodeCount() == 0)
        #expect(try showCount() == 0)
        #expect(prepared.access.isOpen, "the file stays open so the user can try again")
        prepared.close()
        #expect(!prepared.access.isOpen)
    }

    @Test func sweepRemovesWhatAKilledImportLeftInStaging() throws {
        // As after a kill mid-convert: a staging folder with a half-written MP4 and a subtitle file.
        let leftover = try MediaConverter.makeStagingFolder(in: temporaryFolder)
        try Data(repeating: 7, count: 4096).write(to: leftover.appending(path: "Episode.mp4"))
        try FileManager.default.createDirectory(at: leftover.appending(path: "Subtitles"), withIntermediateDirectories: true)
        try Data("1\n".utf8).write(to: leftover.appending(path: "Subtitles/sample.srt"))
        let unrelated = temporaryFolder.appending(path: "keep.txt")
        try Data("keep".utf8).write(to: unrelated)

        EpisodeImporter.sweepStaging(in: temporaryFolder)

        #expect(!exists(EpisodeImporter.stagingRoot(in: temporaryFolder)))
        #expect(exists(unrelated), "only tmp/Converting is swept")
        // Sweeping twice (or with nothing to sweep) is harmless, and staging works again afterwards.
        EpisodeImporter.sweepStaging(in: temporaryFolder)
        let fresh = try MediaConverter.makeStagingFolder(in: temporaryFolder)
        #expect(exists(fresh))
    }

    @Test func aFailedSaveRemovesTheMovedFilesAndAddsNothing() async throws {
        let picked = try await makePickedFiles()
        var importer = makeImporter()
        importer.save = { _ in throw SaveFailure() }

        let prepared = try await importer.prepare(picked.video)
        let error = await thrownError {
            _ = try await importer.importEpisode(
                prepared,
                as: NewEpisodeDetails(showName: "Show A", title: "Episode 1", subtitleFile: picked.subtitle),
                into: context)
        }
        #expect(error as? EpisodeImportError == .saveFailed("forced by the test"))
        #expect(libraryFiles.isEmpty, "left behind: \(libraryFiles)")
        #expect(!exists(store.absoluteURL("Videos/Show A")), "the show folder this import created is removed")
        #expect(!exists(store.absoluteURL("Subtitles/Show A")))
        #expect(stagingEntries.isEmpty)
        #expect(try episodeCount() == 0)
        #expect(try showCount() == 0)
        #expect(exists(picked.video))

        // No orphan is left: the next import takes the plain name.
        let working = makeImporter()
        let retry = try await working.prepare(picked.video)
        let result = try await working.importEpisode(
            retry, as: NewEpisodeDetails(showName: "Show A", title: "Episode 1", subtitleFile: picked.subtitle), into: context)
        #expect(result.episode.videoPath == "Videos/Show A/Episode 1.mp4")
        #expect(result.episode.subtitlePath == "Subtitles/Show A/Episode 1/sample.srt")
    }

    @Test func aFailedSaveKeepsAnExistingShowAndItsFiles() async throws {
        let picked = try await makePickedFiles()
        let working = makeImporter()
        let first = try await working.prepare(picked.video)
        _ = try await working.importEpisode(first, as: NewEpisodeDetails(showName: "Show A", title: "Episode 1"), into: context)

        var failing = makeImporter()
        failing.save = { _ in throw SaveFailure() }
        let second = try await failing.prepare(picked.video)
        let error = await thrownError {
            _ = try await failing.importEpisode(second, as: NewEpisodeDetails(showName: "Show A", title: "Episode 2"), into: context)
        }
        #expect(error is EpisodeImportError)
        #expect(libraryFiles == ["Show A/Episode 1.mp4"])
        #expect(try showCount() == 1)
        #expect(try episodeCount() == 1)
    }

    @Test func missingNamesAreRefusedBeforeAnythingIsWritten() async throws {
        let picked = try await makePickedFiles()
        let importer = makeImporter()
        let prepared = try await importer.prepare(picked.video)

        let noShow = await thrownError {
            _ = try await importer.importEpisode(prepared, as: NewEpisodeDetails(showName: "  ", title: "Episode 1"), into: context)
        }
        #expect(noShow as? EpisodeImportError == .missingShowName)
        let noTitle = await thrownError {
            _ = try await importer.importEpisode(prepared, as: NewEpisodeDetails(showName: "Show A", title: ""), into: context)
        }
        #expect(noTitle as? EpisodeImportError == .missingTitle)
        let badSubtitle = await thrownError {
            _ = try await importer.importEpisode(
                prepared, as: NewEpisodeDetails(showName: "Show A", title: "Episode 1", subtitleFile: root.appending(path: "notes.txt")),
                into: context)
        }
        #expect(badSubtitle as? EpisodeImportError == .unsupportedSubtitleType("txt"))
        #expect(libraryFiles.isEmpty)
        #expect(stagingEntries.isEmpty)

        prepared.close()
        let closed = await thrownError {
            _ = try await importer.importEpisode(prepared, as: NewEpisodeDetails(showName: "Show A", title: "Episode 1"), into: context)
        }
        #expect(closed as? EpisodeImportError == .sourceClosed)
        #expect(libraryFiles.isEmpty)
        #expect(stagingEntries.isEmpty)
    }

    // MARK: Relink (AC-6, importer side)

    func makeEpisodeWithMissingVideo() throws -> Episode {
        let show = Show(name: "Old Show", colorIndex: 0)
        context.insert(show)
        let episode = Episode(title: "Episode 2", number: 2, videoPath: "Videos/Old Show/Episode 2.mov", show: show)
        context.insert(episode)
        try context.save()
        return episode
    }

    @Test func relinkingWithAnMKVPointsTheEpisodeAtTheNewMP4() async throws {
        let episode = try makeEpisodeWithMissingVideo()
        let source = try MediaConverterTests.fixtureURL(MediaConverterTests.fixture4)
        let importer = makeImporter()
        let log = ProgressLog()

        let prepared = try await importer.prepare(source)
        _ = try await importer.relink(episode, to: prepared, in: context, progress: { log.values.append($0) })

        #expect(episode.videoPath == "Videos/Old Show/Episode 2.mp4")
        #expect(store.exists(episode.videoPath))
        #expect(libraryFiles == ["Old Show/Episode 2.mp4"])
        #expect(stagingEntries.isEmpty)
        #expect(log.values.last == 1)
        #expect(try episodeCount() == 1)
    }

    @Test func aFailedRelinkSaveRestoresThePathAndRemovesTheFile() async throws {
        let episode = try makeEpisodeWithMissingVideo()
        let picked = try await makePickedFiles()
        var importer = makeImporter()
        importer.save = { _ in throw SaveFailure() }

        let prepared = try await importer.prepare(picked.video)
        let error = await thrownError { _ = try await importer.relink(episode, to: prepared, in: context) }
        #expect(error as? EpisodeImportError == .saveFailed("forced by the test"))
        #expect(episode.videoPath == "Videos/Old Show/Episode 2.mov")
        #expect(libraryFiles.isEmpty)
        #expect(stagingEntries.isEmpty)
    }

    // MARK: Free space

    @Test func requiredSpaceIsTheSourcePlusTheLargerOfTenPercentAnd200MB() {
        #expect(StorageSpaceRule.requiredBytes(forSourceBytes: 0) == 200_000_000)
        #expect(StorageSpaceRule.requiredBytes(forSourceBytes: -5) == 200_000_000)
        #expect(StorageSpaceRule.requiredBytes(forSourceBytes: 1_000_000_000) == 1_200_000_000)
        #expect(StorageSpaceRule.requiredBytes(forSourceBytes: 1_999_999_999) == 2_199_999_999)
        #expect(StorageSpaceRule.requiredBytes(forSourceBytes: 2_000_000_000) == 2_200_000_000)
        #expect(StorageSpaceRule.requiredBytes(forSourceBytes: 5_000_000_000) == 5_500_000_000)
        #expect(StorageSpaceRule.requiredBytes(forSourceBytes: .max) == .max)
    }

    @Test func spaceCheckPassesAtTheLimitAndFailsOneByteBelow() throws {
        try StorageSpaceRule.check(sourceBytes: 1_000_000_000, availableBytes: 1_200_000_000)
        try StorageSpaceRule.check(sourceBytes: 1_000_000_000, availableBytes: nil)
        #expect(throws: EpisodeImportError.notEnoughSpace(neededBytes: 1_200_000_000, availableBytes: 1_199_999_999)) {
            try StorageSpaceRule.check(sourceBytes: 1_000_000_000, availableBytes: 1_199_999_999)
        }
    }

    @Test func notEnoughSpaceMessageGivesBothSizes() {
        let spec = EpisodeImportError.notEnoughSpace(neededBytes: 1_600_000_000, availableBytes: 900_000_000)
        #expect(spec.localizedDescription == "This needs about 1.6 GB free; you have 0.9 GB.")
        // Needed rounds up and free rounds down, so the two never look equal when the import is refused.
        let close = EpisodeImportError.notEnoughSpace(neededBytes: 1_550_000_001, availableBytes: 1_549_999_999)
        #expect(close.localizedDescription == "This needs about 1.6 GB free; you have 1.5 GB.")
        #expect(StorageSpaceRule.gigabytes(roundingUp: 200_000_000) == "0.2 GB")
        #expect(StorageSpaceRule.gigabytes(roundingDown: 12_345_678_901) == "12.3 GB")
    }

    @Test func prepareRefusesAFileThatDoesNotFit() async throws {
        let picked = try await makePickedFiles()
        let importer = makeImporter(available: 150_000_000)
        let error = await thrownError { _ = try await importer.prepare(picked.video) }
        let size = try #require(try picked.video.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(error as? EpisodeImportError == .notEnoughSpace(
            neededBytes: StorageSpaceRule.requiredBytes(forSourceBytes: Int64(size)), availableBytes: 150_000_000))
        #expect(libraryFiles.isEmpty)
        #expect(stagingEntries.isEmpty)
    }

    // MARK: Audio choice

    func probe(audio: [MediaProbe.Audio]) -> MediaProbe {
        MediaProbe(
            container: "matroska,webm", durationSeconds: 8, startSeconds: 0,
            video: MediaProbe.Video(streamIndex: 0, codec: "h264", profile: 100, pixelFormat: "yuv420p", bitDepth: 8,
                                    chroma: .yuv420, width: 320, height: 180),
            audioTracks: audio, subtitleTracks: [])
    }

    func prepared(_ probe: MediaProbe) throws -> PreparedVideo {
        PreparedVideo(source: root.appending(path: "x.mkv"), fileExtension: "mkv", sourceBytes: 0, probe: probe,
                      defaultPlan: try EpisodeImporter.defaultPlan(for: probe, supportsAV1: false), supportsAV1: false,
                      access: SourceAccess(url: root.appending(path: "x.mkv")))
    }

    @Test func audioLabelsAndChoices() throws {
        let tracks = [
            MediaProbe.Audio(streamIndex: 1, codec: "aac", language: "jpn", title: "Original", channels: 2, sampleRate: 48_000),
            MediaProbe.Audio(streamIndex: 2, codec: "flac", language: "eng", channels: 2, sampleRate: 48_000, isDefault: true),
            MediaProbe.Audio(streamIndex: 3, codec: "ac3", language: "und", channels: 6, sampleRate: 48_000),
        ]
        let video = try prepared(probe(audio: tracks))
        #expect(video.label(for: tracks[0]) == "jpn · Original · AAC")
        #expect(video.label(for: tracks[1]) == "eng · FLAC")
        #expect(video.label(for: tracks[2]) == "Track 3 · AC-3")
        #expect(video.defaultAudioStreamIndex == 2, "the default-flagged track")

        let chosen = try video.plan(for: EpisodeImportOptions(audioStreamIndex: 1))
        #expect(chosen?.audio?.streamIndex == 1)
        #expect(chosen?.audio?.mode == .copy)
        #expect(try video.plan(for: EpisodeImportOptions())?.audio?.streamIndex == 2)
        #expect(throws: EpisodeImportError.unsupported(.audioChoice(9))) {
            _ = try video.plan(for: EpisodeImportOptions(audioStreamIndex: 9))
        }
    }

    @Test func anUndecodableDefaultTrackFallsBackToOneThatWorks() throws {
        let tracks = [
            MediaProbe.Audio(streamIndex: 1, codec: "mlp", channels: 6, sampleRate: 48_000, isDefault: true, canDecode: false),
            MediaProbe.Audio(streamIndex: 2, codec: "aac", language: "jpn", channels: 2, sampleRate: 48_000),
        ]
        let video = try prepared(probe(audio: tracks))
        #expect(video.defaultAudioStreamIndex == 2)
        #expect(throws: EpisodeImportError.unsupported(.audioCodec("MLP"))) {
            _ = try video.plan(for: EpisodeImportOptions(audioStreamIndex: 1))
        }
        #expect(throws: EpisodeImportError.unsupported(.audioCodec("MLP"))) {
            _ = try EpisodeImporter.defaultPlan(for: probe(audio: [tracks[0]]), supportsAV1: false)
        }
    }

    @Test func aFileWithNoAudioTrackWarns() throws {
        let video = try prepared(probe(audio: []))
        #expect(video.defaultAudioStreamIndex == nil)
        #expect(video.warnings == ["This video has no sound track, so its cards will have no audio."])
    }
}

struct SaveFailure: Error, LocalizedError {
    var errorDescription: String? { "forced by the test" }
}

@MainActor
final class ProgressLog {
    var values: [Double] = []
}

@MainActor
final class StageLog {
    var values: [PrepareStage] = []
}
