import GoogleMobileAds
import SwiftUI

/// 広告管理シングルトン
/// - 1日の判定回数をトラッキングし、freeJudgmentsPerDay 回を超えたら広告を表示する
@MainActor
final class AdManager: NSObject, ObservableObject {

    static let shared = AdManager()

    // MARK: - Constants

    /// 広告ユニットID（DEBUG時はテスト用、RELEASE時は本番用）
    private let interstitialUnitID: String = {
        #if DEBUG
        return "ca-app-pub-3940256099942544/4411468910" // テスト用
        #else
        return "ca-app-pub-3238843741111012/5288929851" // 本番用
        #endif
    }()

    /// 1日あたりの無料判定回数（1 = 1回目は無料、2回目から広告）
    private let freeJudgmentsPerDay = 1

    // MARK: - UserDefaults Keys

    private let dailyCountKey  = "adManager.dailyJudgmentCount"
    private let lastDateKey    = "adManager.lastJudgmentDate"

    // MARK: - State

    private var interstitial: InterstitialAd?
    private var adDismissedCompletion: (() -> Void)?
    private var isInitialized = false

    @Published private(set) var isAdReady = false

    // MARK: - Init

    private override init() { super.init() }

    // MARK: - Setup

    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true
        #if DEBUG
        // テスト広告の設定（デバッグ時のみ）
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "4eefe672f7a37b68f660e415fd414806"
        ]
        #endif
        // start 完了後に loadAd を呼ぶことでレースコンディションを回避
        MobileAds.shared.start { [weak self] _ in
            Task { await self?.loadAd() }
        }
    }

    // MARK: - Daily Count

    /// 今日の判定回数（純粋なゲッター）
    var todayCount: Int {
        UserDefaults.standard.integer(forKey: dailyCountKey)
    }

    /// 広告を表示すべきか（無料枠を超えている場合 true）
    /// 呼び出し前に ensureDailyReset() を実行すること
    var shouldShowAd: Bool {
        todayCount >= freeJudgmentsPerDay
    }

    /// 日付をまたいでいた場合にカウントをリセットする（副作用を明示的に管理）
    func ensureDailyReset() {
        resetIfNewDay()
    }

    /// 判定回数を1増やす
    func incrementCount() {
        resetIfNewDay()
        let count = UserDefaults.standard.integer(forKey: dailyCountKey)
        UserDefaults.standard.set(count + 1, forKey: dailyCountKey)
    }

    private func resetIfNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = UserDefaults.standard.object(forKey: lastDateKey) as? Date ?? .distantPast
        if today > Calendar.current.startOfDay(for: lastDate) {
            UserDefaults.standard.set(0, forKey: dailyCountKey)
            UserDefaults.standard.set(today, forKey: lastDateKey)
        }
    }

    // MARK: - Interstitial Ad

    private func loadAd() async {
        do {
            interstitial = try await InterstitialAd.load(
                with: interstitialUnitID,
                request: Request()
            )
            interstitial?.fullScreenContentDelegate = self
            isAdReady = true
        } catch {
            print("AdManager: 広告の読み込みに失敗しました: \(error.localizedDescription)")
            isAdReady = false
        }
    }

    /// 広告を表示する。完了（または広告なし）時に completion を呼ぶ
    func showAdIfNeeded(completion: @escaping () -> Void) {
        guard shouldShowAd, let interstitial else {
            // 広告不要 or まだロードされていない場合はそのまま進む
            completion()
            return
        }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            completion()
            return
        }
        // 一番上に表示されているVCを取得
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        adDismissedCompletion = completion
        interstitial.present(from: topVC)
    }
}

// MARK: - FullScreenContentDelegate

extension AdManager: FullScreenContentDelegate {

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.interstitial = nil
            self.isAdReady = false
            self.adDismissedCompletion?()
            self.adDismissedCompletion = nil
            await self.loadAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd,
                        didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("AdManager: 広告の表示に失敗しました: \(error.localizedDescription)")
            self.interstitial = nil
            self.isAdReady = false
            self.adDismissedCompletion?()
            self.adDismissedCompletion = nil
            await self.loadAd()
        }
    }
}
