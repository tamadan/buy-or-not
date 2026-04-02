import SwiftUI

/// アプリ全体のナビゲーション状態を管理する EnvironmentObject
final class NavigationCoordinator: ObservableObject {
    @Published var shouldDismissToRoot = false
    /// 「買うのをやめる」ボタンで戻ってきた場合 true
    @Published var didStopBuying = false

    /// 「買うのをやめる」でルートに戻る際に呼ぶ
    /// shouldDismissToRoot と didStopBuying を原子的にセットし、状態不整合を防ぐ
    func dismissToRoot() {
        didStopBuying = true
        shouldDismissToRoot = true
    }
}
