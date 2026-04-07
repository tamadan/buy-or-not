import UserNotifications

/// ローカル通知によるリマインダー管理
@MainActor
final class ReminderManager {

    static let shared = ReminderManager()

    private init() {}

    // MARK: - Permission

    /// 通知許可を要求する。既に許可済みの場合は即 true を返す
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                print("⚠️ [ReminderManager] 権限リクエスト失敗: \(error)")
                return false
            }
        default:
            return false
        }
    }

    // MARK: - Schedule

    /// N日後の朝10時にリマインド通知をスケジュールする
    /// - Returns: スケジュール成功なら true
    @discardableResult
    func scheduleReminder(for productName: String, afterDays days: Int) async -> Bool {
        guard days > 0 else { return false }

        let granted = await requestPermission()
        guard granted else { return false }

        let content = UNMutableNotificationContent()
        content.title = "🐬 まだ気になってる？"
        content.body = "「\(productName)」のこと、まだ気になってる？"
        content.sound = .default
        content.userInfo = ["productName": productName]

        // N日後の朝10時を計算
        guard let triggerDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) else {
            return false
        }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
        components.hour = 10
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        // 同一商品への重複リマインドを防ぐため商品名から決定論的なIDを生成する
        let slug = productName
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let identifier = "irukasore-reminder-\(slug)"
        // 既存の同一IDペンディング通知を削除してから再登録する
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            print("⚠️ [ReminderManager] スケジュール失敗: \(error)")
            return false
        }
    }
}
