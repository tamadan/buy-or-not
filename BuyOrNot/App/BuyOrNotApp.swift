import SwiftUI
import SwiftData

@main
struct BuyOrNotApp: App {

    @StateObject private var premiumManager = PremiumManager.shared

    init() {
        AdManager.shared.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(premiumManager)
        }
        .modelContainer(for: JudgementHistory.self)
    }
}
