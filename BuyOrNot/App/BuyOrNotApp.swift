import SwiftUI
import SwiftData

@main
struct BuyOrNotApp: App {

    init() {
        AdManager.shared.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: JudgementHistory.self)
    }
}
