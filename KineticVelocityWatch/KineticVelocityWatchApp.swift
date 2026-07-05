import SwiftUI

@main
struct KineticVelocityWatchApp: App {
    @StateObject private var store = TrainingSessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
        .persistentSystemOverlays(.hidden)
    }
}
