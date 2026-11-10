@preconcurrency import AVFoundation
import SwiftData
import SwiftUI

@main
struct ClipDeckApp: App {
    @State private var settings: SettingsStore
    private let container: ModelContainer

    init() {
        let isUITesting = LaunchFlags.isUITesting
        // UI tests get a fresh in-memory library and default settings on every launch.
        if isUITesting { UserDefaults.standard.removePersistentDomain(forName: "uiTesting") }
        _settings = State(initialValue: isUITesting
            ? SettingsStore(defaults: UserDefaults(suiteName: "uiTesting") ?? .standard, key: "ankiSettings.uiTesting")
            : SettingsStore())
        do {
            container = try ModelContainer(
                for: Show.self, Episode.self, PendingCard.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: isUITesting)
            )
        } catch {
            fatalError("Clip Deck couldn't open its library database: \(error)")
        }
        FileStore.live.ensureFolders()
        // Play sound even with the silent switch on, like a video app.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
        .environment(settings)
    }
}

enum LaunchFlags {
    /// Passed by the UI tests (see ClipDeckUITests). Debug builds only seed sample media when set.
    static var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }
    /// UI tests that need an empty library pass this too.
    static var shouldSeedSample: Bool { isUITesting && !ProcessInfo.processInfo.arguments.contains("-uiTestingNoSeed") }
}
