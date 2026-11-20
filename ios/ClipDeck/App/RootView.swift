import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var isSeeding = LaunchFlags.shouldSeedSample || LaunchFlags.shouldSeedMKV

    var body: some View {
        if isSeeding {
            ProgressView("Preparing sample episode…")
                .task {
                    #if DEBUG
                    if LaunchFlags.shouldSeedMKV {
                        await UITestSeeder.seedMKV(context: context)
                    } else {
                        await UITestSeeder.seed(context: context)
                    }
                    #endif
                    isSeeding = false
                }
        } else {
            LibraryView()
        }
    }
}

#if DEBUG
/// UI-test only (`-uiTesting` launch argument, Debug builds): creates "Sample Show" with a
/// generated 6-second video and a 3-line SRT, so tests exercise the real player and Make a Card.
enum UITestSeeder {
    static func seed(context: ModelContext) async {
        let store = FileStore.live
        let videoPath = "Videos/Sample Show/Episode 1.mp4"
        let subtitlePath = "Subtitles/Sample Show/Episode 1/sample.srt"
        do {
            try await TestMediaFactory.makeVideo(at: store.absoluteURL(videoPath))
            let subtitleURL = store.absoluteURL(subtitlePath)
            try FileManager.default.createDirectory(at: subtitleURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try TestMediaFactory.sampleSRT.write(to: subtitleURL, atomically: true, encoding: .utf8)
        } catch {
            print("UITestSeeder failed: \(error)")
            return
        }
        let show = Show(name: "Sample Show", colorIndex: 3)
        context.insert(show)
        context.insert(Episode(title: "Episode 1", number: 1, videoPath: videoPath, subtitlePath: subtitlePath, show: show))
        try? context.save()
    }

    static let mkvFixtureName = "04-nosubs-aac51.mkv"

    /// `-uiTestingMKV`: imports MKV fixture 4 (no subtitle tracks, AAC 5.1) from CLIPDECK_FIXTURES through the
    /// real `EpisodeImporter` (prepare, convert, move, save) as "MKV Show / Episode 1", with the sample SRT as
    /// its subtitle file. On failure it prints why and seeds nothing, so the UI test fails at its first wait.
    static func seedMKV(context: ModelContext) async {
        guard let folder = ProcessInfo.processInfo.environment["CLIPDECK_FIXTURES"], !folder.isEmpty else {
            print("UITestSeeder: -uiTestingMKV needs CLIPDECK_FIXTURES (the folder from scripts/make-test-media.sh)")
            return
        }
        let source = URL(fileURLWithPath: folder, isDirectory: true).appending(path: mkvFixtureName)
        let store = FileStore.live
        // Documents outlive the in-memory library between UI-test launches; start from clean folders so the
        // episode always lands at "Videos/MKV Show/Episode 1.mp4".
        try? FileManager.default.removeItem(at: store.absoluteURL(store.videoFolderPath(show: "MKV Show")))
        try? FileManager.default.removeItem(at: store.absoluteURL("Subtitles/\(FileStore.safeName("MKV Show"))"))
        let subtitle = FileManager.default.temporaryDirectory
            .appending(path: "uiTestingMKV", directoryHint: .isDirectory)
            .appending(path: "sample.srt")
        do {
            try FileManager.default.createDirectory(at: subtitle.deletingLastPathComponent(), withIntermediateDirectories: true)
            try TestMediaFactory.sampleSRT.write(to: subtitle, atomically: true, encoding: .utf8)
            let importer = EpisodeImporter()
            let prepared = try await importer.prepare(source)
            _ = try await importer.importEpisode(
                prepared,
                as: NewEpisodeDetails(showName: "MKV Show", title: "Episode 1", number: 1, subtitleFile: subtitle),
                into: context)
        } catch {
            print("UITestSeeder: importing \(source.path(percentEncoded: false)) failed: \(error)")
        }
    }
}
#endif
