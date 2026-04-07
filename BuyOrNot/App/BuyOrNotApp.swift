import SwiftUI
import UserNotifications

@main
struct BuyOrNotApp: App {

    @StateObject private var premiumManager = PremiumManager.shared
    @StateObject private var navigationCoordinator: NavigationCoordinator
    private let notificationDelegate: NotificationDelegate

    init() {
        let coordinator = NavigationCoordinator()
        let delegate = NotificationDelegate(coordinator: coordinator)
        _navigationCoordinator = StateObject(wrappedValue: coordinator)
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
        AdManager.shared.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(premiumManager)
                .environmentObject(navigationCoordinator)
        }
        .modelContainer(for: JudgementHistory.self)
    }
}

// MARK: - NotificationDelegate

/// UNUserNotificationCenterDelegate の実装。リマインド通知タップ時に商品名を NavigationCoordinator に渡す
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    private let coordinator: NavigationCoordinator

    init(coordinator: NavigationCoordinator) {
        self.coordinator = coordinator
    }

    /// 通知をタップしてアプリを開いた場合（バックグラウンド・終了状態からの起動両方）
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let productName = userInfo["productName"] as? String {
            Task { @MainActor in
                self.coordinator.reminderProductName = productName
            }
        }
        completionHandler()
    }

    /// フォアグラウンド中に通知が届いた場合もバナーを表示する
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
