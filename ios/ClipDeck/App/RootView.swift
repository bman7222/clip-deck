import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var isSeeding = LaunchFlags.shouldSeedSample

    var body: some View {
        if isSeeding {
            ProgressView("Preparing sample episode…")
                .task {
                    #if DEBUG
                    await UITestSeeder.seed(context: context)
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
}
#endif
