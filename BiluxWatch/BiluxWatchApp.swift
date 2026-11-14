import SwiftUI

@main
struct BiluxWatchApp: App {
    @StateObject private var bridge = WatchBridge()
    @StateObject private var health = WatchHealthReader()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(bridge)
                .environmentObject(health)
                .preferredColorScheme(.dark)
        }
    }
}
