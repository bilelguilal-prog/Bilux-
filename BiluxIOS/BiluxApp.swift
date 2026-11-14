import SwiftUI

@main
@MainActor
struct BiluxApp: App {
    @StateObject private var journal: BiluxStore
    @StateObject private var health: HealthKitManager

    init() {
        let store = BiluxStore()
        let healthManager = HealthKitManager()
        _journal = StateObject(wrappedValue: store)
        _health = StateObject(wrappedValue: healthManager)
        // Activation anticipée pour recevoir les séances envoyées par la montre.
        WatchPhoneBridge.shared.configure(journal: store, health: healthManager)
    }

    var body: some Scene {
        WindowGroup {
            MainTabs()
                .environmentObject(journal)
                .environmentObject(health)
                .preferredColorScheme(.dark)
        }
    }
}
