import SwiftUI

@main
struct BiluxApp: App {
    @StateObject private var journal = BiluxStore()
    @StateObject private var health = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            MainTabs()
                .environmentObject(journal)
                .environmentObject(health)
                .preferredColorScheme(.dark)
        }
    }
}
