@preconcurrency import AVFoundation
import SwiftData
import SwiftUI

@main
struct ClipDeckApp: App {
    @State private var settings: SettingsStore
    private let container: ModelContainer

    init() {
        let isUITesting = LaunchFlags.isUITesting
        #if DEBUG
        // UI tests only: prints any animation that never finishes, to find the cause of the idle stall (T-034).
        if isUITesting { UITestAnimationWatch.start() }
        #endif
        // UI tests get a fresh in-memory library and default settings on every launch.
        // -uiTestingKeepExpiryDismissal keeps only the expiry-banner dismissal day, so a test can relaunch the same day.
        if isUITesting {
            let kept = ProcessInfo.processInfo.arguments.contains("-uiTestingKeepExpiryDismissal")
                ? UserDefaults(suiteName: "uiTesting")?.string(forKey: ExpiryReminderStore.key) : nil
            UserDefaults.standard.removePersistentDomain(forName: "uiTesting")
            if let kept { UserDefaults(suiteName: "uiTesting")?.set(kept, forKey: ExpiryReminderStore.key) }
        }
        // The landscape panel width lives in the standard defaults, which outlive a UI-test launch. Start every
        // UI-test launch at the default width unless the test asks to keep it (-uiTestingKeepPanelWidth).
        if isUITesting, !ProcessInfo.processInfo.arguments.contains("-uiTestingKeepPanelWidth") {
            UserDefaults.standard.removeObject(forKey: "player.panelFraction")
        }
        // The subtitle style (global, in the standard defaults) is cleared on every UI-test launch too, unless
        // -uiTestingKeepSubtitleStyle is passed. -uiTestingSubtitleStyle <json> then seeds a style.
        if isUITesting {
            let arguments = ProcessInfo.processInfo.arguments
            if !arguments.contains("-uiTestingKeepSubtitleStyle") {
                UserDefaults.standard.removeObject(forKey: SubtitleStyle.storageKey)
            }
            if !arguments.contains("-uiTestingKeepTimelineSnap") {
                UserDefaults.standard.removeObject(forKey: ClipTimelineView.snapKey)
            }
            if let seed = SubtitleStyle.seedJSON(in: arguments) {
                UserDefaults.standard.set(SubtitleStyle.seeded(from: seed).json, forKey: SubtitleStyle.storageKey)
            }
        }
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
        // An import killed mid-way (crash, force quit, iOS ending a background conversion) leaves its staging
        // folder behind; nothing reached Documents, so it is safe to delete before any new import starts.
        EpisodeImporter.sweepStaging()
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
    static var shouldSeedSample: Bool {
        isUITesting && !ProcessInfo.processInfo.arguments.contains("-uiTestingNoSeed") && !shouldSeedMKV
    }
    /// `-uiTesting -uiTestingSampleSeconds <n>` (Debug): the seeded "Sample Show" video is n seconds long (1 to 600)
    /// instead of 6, so tests that play it can't run into its end on a slow runner. The subtitles stay the same.
    static var sampleSeconds: Int {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-uiTestingSampleSeconds"), flag + 1 < arguments.count,
              let seconds = Int(arguments[flag + 1])
        else { return 6 }
        return min(max(seconds, 1), 600)
    }
    /// `-uiTesting -uiTestingMKV` (Debug): instead of "Sample Show", import MKV fixture 4 through `EpisodeImporter`
    /// as "MKV Show / Episode 1" with the sample SRT. The fixture folder comes from the CLIPDECK_FIXTURES
    /// environment variable (UI tests forward it through `launchEnvironment`).
    static var shouldSeedMKV: Bool { isUITesting && ProcessInfo.processInfo.arguments.contains("-uiTestingMKV") }
}
