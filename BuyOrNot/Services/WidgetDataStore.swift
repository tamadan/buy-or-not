import WidgetKit
import Foundation

/// アプリとウィジェット間で月次データを共有する
/// App Group UserDefaults にデータを書き込み、WidgetKit に更新を通知する
struct WidgetDataStore {

    static let appGroupID = "group.com.irukasore.app"

    enum Key {
        static let savedAmount  = "widget.savedAmount"
        static let stoppedCount = "widget.stoppedCount"
        static let isPremium    = "widget.isPremium"
        static let updatedAt    = "widget.updatedAt"
    }

    /// 履歴・プレミアム状態を App Group に保存し、ウィジェットを更新する
    static func update(history: [JudgementHistory], isPremium: Bool) {
        let calendar = Calendar.current
        let now = Date()
        let thisMonth = calendar.dateComponents([.year, .month], from: now)

        let monthly = history.filter {
            let c = calendar.dateComponents([.year, .month], from: $0.date)
            return c.year == thisMonth.year && c.month == thisMonth.month
        }

        let savedAmount  = monthly.compactMap { $0.savedAmount }.reduce(0, +)
        let stoppedCount = monthly.filter { !$0.didBuy }.count

        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(savedAmount,  forKey: Key.savedAmount)
        defaults?.set(stoppedCount, forKey: Key.stoppedCount)
        defaults?.set(isPremium,    forKey: Key.isPremium)
        defaults?.set(now,          forKey: Key.updatedAt)

        WidgetCenter.shared.reloadAllTimelines()
    }
}
