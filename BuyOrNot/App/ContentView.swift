import SwiftUI

struct ContentView: View {
    @StateObject private var navigationCoordinator = NavigationCoordinator()

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .environmentObject(navigationCoordinator)
    }
}

#Preview {
    ContentView()
}
