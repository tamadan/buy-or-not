import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var navigationCoordinator = NavigationCoordinator()

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("ホーム", systemImage: "house.fill")
            }
            .tag(0)

            HistoryView()
                .tabItem {
                    Label("履歴", systemImage: "clock.fill")
                }
                .tag(1)
        }
        .environmentObject(navigationCoordinator)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: JudgementHistory.self, inMemory: true)
}
