import SwiftUI

@main
struct BuyOrNotApp: App {

    init() {
        AdManager.shared.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
