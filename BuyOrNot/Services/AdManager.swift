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
    /// 広告表示後のコールバック。adWasShown=true なら実際に広告が表示されて閉じられた
    private var adDismissedCompletion: ((_ adWasShown: Bool) -> Void)?
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

    /// 広告を表示する。
    /// - completion: adWasShown=true なら広告が実際に表示・閉じられた。
    ///               false はロード未完了・VC取得失敗などで広告がスキップされた場合
    func showAdIfNeeded(completion: @escaping (_ adWasShown: Bool) -> Void) {
        guard shouldShowAd, let interstitial else {
            // 広告不要 or まだロードされていない場合はスキップ
            completion(false)
            return
        }
        // フォアグラウンドアクティブなシーンのキーウィンドウを選択
        guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            completion(false)
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
            self.adDismissedCompletion?(true)   // 広告が実際に表示・閉じられた
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
            self.adDismissedCompletion?(false)  // 表示失敗（広告は見せられていない）
            self.adDismissedCompletion = nil
            await self.loadAd()
        }
    }
}
