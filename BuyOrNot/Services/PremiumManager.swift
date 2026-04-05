import StoreKit
import SwiftUI

// MARK: - PremiumManager

/// サブスクリプション状態を管理するシングルトン
/// StoreKit2 を使用。Transaction.currentEntitlements で常に最新状態を保証する
@MainActor
final class PremiumManager: ObservableObject {

    static let shared = PremiumManager()

    // MARK: - Constants

    /// App Store Connect で登録するプロダクトID
    static let productID = "com.irukasore.app.premium.monthly"

    // MARK: - Published State

    /// プレミアム有効かどうか（UI の切り替えに使う）
    @Published private(set) var isPremium: Bool = false
    /// 購入可能なプロダクト情報（価格表示などに使う）
    @Published private(set) var product: StoreKit.Product?
    /// 購入・復元中のローディング状態
    @Published private(set) var isLoading: Bool = false

    // MARK: - Private

    private var transactionListenerTask: Task<Void, Error>?

    // MARK: - Init

    private init() {
        // バックグラウンドでトランザクション更新を監視
        transactionListenerTask = listenForTransactions()
        Task {
            await loadProduct()
            await refreshPremiumStatus()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Load Product

    /// App Store からプロダクト情報を取得する
    func loadProduct() async {
        do {
            let products = try await StoreKit.Product.products(for: [Self.productID])
            product = products.first
        } catch {
            print("⚠️ [PremiumManager] プロダクト取得失敗: \(error)")
        }
    }

    // MARK: - Purchase

    /// サブスクリプションを購入する
    /// - Throws: PremiumError.productNotFound / StoreKit エラー
    func purchase() async throws {
        guard let product: StoreKit.Product else { throw PremiumError.productNotFound }
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification as VerificationResult<StoreKit.Transaction>)
            await refreshPremiumStatus()
            await transaction.finish()
        case .userCancelled:
            break
        case .pending:
            // 保護者の承認待ちなど。ステータスは Transaction.updates で後から通知される
            break
        @unknown default:
            break
        }
    }

    // MARK: - Restore

    /// 過去の購入を復元する
    func restore() async {
        isLoading = true
        defer { isLoading = false }
        // App Store と同期して最新のエンタイトルメントを取得
        try? await AppStore.sync()
        await refreshPremiumStatus()
    }

    // MARK: - Status

    /// 現在のエンタイトルメントを確認して isPremium を更新する
    func refreshPremiumStatus() async {
        var hasActive = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                hasActive = true
                break
            }
        }
        isPremium = hasActive
    }

    // MARK: - Formatted Price

    /// 価格を「¥250/月」形式で返す
    var formattedPrice: String {
        guard let product: StoreKit.Product else { return "¥250/月" }
        return "\(product.displayPrice)/月"
    }

    // MARK: - Private Helpers

    /// トランザクション更新をリアルタイムで監視する（解約・更新など）
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await self.refreshPremiumStatus()
                    await transaction.finish()
                }
            }
        }
    }

    /// StoreKit の検証結果を確認する
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PremiumError.failedVerification
        case .verified(let value):
            return value
        }
    }
}

// MARK: - PremiumError

enum PremiumError: LocalizedError {
    case productNotFound
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "プロダクト情報を取得できませんでした。通信状況を確認してください。"
        case .failedVerification:
            return "購入の検証に失敗しました。"
        }
    }
}
