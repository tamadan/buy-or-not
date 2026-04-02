import SwiftUI

/// アプリ全体のナビゲーション状態を管理する EnvironmentObject
final class NavigationCoordinator: ObservableObject {
    @Published var shouldDismissToRoot = false
    /// 「買うのをやめる」ボタンで戻ってきた場合 true
    @Published var didStopBuying = false
}
