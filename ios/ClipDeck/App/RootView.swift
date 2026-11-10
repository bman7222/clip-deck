import SwiftUI

/// Skeleton root screen. It exists only to prove the project builds and launches.
/// Replace it with the app's real navigation root (and update the UI test) in the first feature pass.
struct RootView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Clip Deck",
                systemImage: "hammer",
                description: Text("The project skeleton is running.")
            )
        }
    }
}

#Preview {
    RootView()
}
