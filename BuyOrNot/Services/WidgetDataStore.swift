import WidgetKit
import Foundation

/// アプリとウィジェット間で月次データを共有する
/// App Group UserDefaults にデータを書き込み、WidgetKit に更新を通知する
struct WidgetDataStore {

    static let appGroupID = "group.com.irukasore.app"

    private enum Key {
        static let savedAmount  = "widget.savedAmount"
        static let stoppedCount = "widget.stoppedCount"
        static let updatedAt    = "widget.updatedAt"
    }

    /// 履歴から今月の集計を計算して App Group に保存し、ウィジェットを更新する
    static func update(history: [JudgementHistory]) {
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
        defaults?.set(now,          forKey: Key.updatedAt)

        WidgetCenter.shared.reloadAllTimelines()
    }
}
