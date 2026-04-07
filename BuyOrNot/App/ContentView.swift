import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
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
        .onChange(of: navigationCoordinator.reminderProductName) { _, name in
            // 通知タップ時に必ずホームタブに切り替える
            if name != nil { selectedTab = 0 }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NavigationCoordinator())
        .modelContainer(for: JudgementHistory.self, inMemory: true)
}
