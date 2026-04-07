import StoreKit
import SwiftUI

// MARK: - PremiumManager

/// サブスクリプション状態を管理するシングルトン
/// StoreKit2 を使用。Transaction.currentEntitlements で常に最新状態を保証する
///
/// ⚠️ 型衝突メモ:
///   アプリ独自の `Product` モデルと `StoreKit.Product` が同名のため、
///   このファイル内では StoreKit.Product を必ず明示修飾して使用する。
///   プロパティアクセスも混同しないよう注意:
///     StoreKit.Product   → .id          (プロダクトID)
///     StoreKit.Transaction → .productID  (プロダクトID)
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
    /// プロダクト情報取得中かどうか
    @Published private(set) var isLoadingProduct: Bool = false
    /// 起動直後の entitlement チェックが完了するまで true
    @Published private(set) var isInitializing: Bool = true

    // MARK: - Private

    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Init

    private init() {
        SKLog.info("=== PremiumManager 初期化開始 ===")
        SKLog.info("対象プロダクトID: \(Self.productID)")
        let simName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? ""
        SKLog.info("実行環境: \(simName.isEmpty ? "Real Device" : "Simulator (\(simName))")")

        // バックグラウンドでトランザクション更新を監視
        transactionListenerTask = listenForTransactions()
        Task {
            // entitlement チェックを先行させて isPremium を即時確定する
            await refreshPremiumStatus()
            isInitializing = false
            // プロダクト情報（価格表示）は後で取得
            await loadProduct()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Load Product

    /// App Store からプロダクト情報を取得する（最大3回リトライ）
    func loadProduct() async {
        SKLog.info("--- loadProduct() 開始 ---")
        isLoadingProduct = true
        defer {
            isLoadingProduct = false
            let loadedID = product?.id ?? "nil"
            SKLog.info("--- loadProduct() 終了 (product.id: \(loadedID)) ---")
        }

        // ── 診断①: 実行環境の詳細 ──────────────────────────────
        let env = ProcessInfo.processInfo.environment
        SKLog.info("[診断①] 実行環境")
        SKLog.info("  isSimulator: \(env["SIMULATOR_DEVICE_NAME"] != nil)")
        SKLog.info("  SIMULATOR_DEVICE_NAME: \(env["SIMULATOR_DEVICE_NAME"] ?? "nil")")
        SKLog.info("  SIMULATOR_OS_VERSION: \(env["SIMULATOR_OS_VERSION"] ?? "nil")")
        SKLog.info("  SIMULATOR_RUNTIME_VERSION: \(env["SIMULATOR_RUNTIME_VERSION"] ?? "nil")")

        // ── 診断②: レシートURL（Sandbox か Local Testing かの判別） ──
        SKLog.info("[診断②] レシートURL")
        let receiptURL = Bundle.main.appStoreReceiptURL
        SKLog.info("  appStoreReceiptURL: \(receiptURL?.path ?? "nil")")
        if let path = receiptURL?.path {
            if path.contains("sandboxReceipt") {
                SKLog.warn("  → Sandbox モード (.storekit ファイルが無視されている)")
                SKLog.warn("    対処: Edit Scheme > Run > Options > StoreKit Configuration を確認")
            } else if path.contains("LocalTesting") || path.contains("storekit") {
                SKLog.info("  → StoreKit Local Testing モード ✅ (.storekit ファイルが有効)")
            } else {
                SKLog.warn("  → 判別不明なパス: \(path)")
            }
        }

        // ── 診断③: Storefront（どのストアに接続しているか） ────────
        SKLog.info("[診断③] Storefront")
        if let storefront = await Storefront.current {
            SKLog.info("  countryCode: \(storefront.countryCode)")
            SKLog.info("  id: \(storefront.id)")
        } else {
            SKLog.warn("  Storefront.current = nil (StoreKit サービスに到達できていない可能性)")
        }

        // ── 診断④: 既存トランザクション全件確認 ─────────────────
        SKLog.info("[診断④] Transaction.all (既存トランザクション)")
        var txCount = 0
        for await result in Transaction.all {
            txCount += 1
            switch result {
            case .verified(let tx):
                SKLog.info("  TX[\(txCount)] verified: \(tx.productID), date=\(tx.purchaseDate)")
            case .unverified(let tx, let err):
                SKLog.warn("  TX[\(txCount)] unverified: \(tx.productID), err=\(err)")
            }
        }
        if txCount == 0 { SKLog.info("  トランザクション: 0件") }

        // ── 診断⑤: ProductID のバイト列確認（不可視文字・エンコード混入チェック） ─
        SKLog.info("[診断⑤] ProductID バイト列確認")
        let pid = Self.productID
        SKLog.info("  productID: '\(pid)'")
        SKLog.info("  文字数: \(pid.count)")
        SKLog.info("  UTF8: \(pid.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))")

        // ── プロダクト取得ループ ──────────────────────────────────
        for attempt in 1...3 {
            SKLog.info("試行 \(attempt)/3: StoreKit.Product.products(for:) を呼び出し中...")
            do {
                let products: [StoreKit.Product] = try await StoreKit.Product.products(for: [Self.productID])

                SKLog.info("試行 \(attempt)/3: レスポンス受信 - 件数: \(products.count)")
                if products.isEmpty {
                    SKLog.warn("試行 \(attempt)/3: 空配列が返却されました")
                    SKLog.warn("  考えられる原因:")
                    SKLog.warn("  A) Edit Scheme > Run > Options > StoreKit Configuration が未設定")
                    SKLog.warn("  B) .storekit ファイルのパスが Xcode から解決できていない")
                    SKLog.warn("  C) Product ID が .storekit ファイルと不一致")
                    SKLog.warn("  D) シミュレーターの StoreKit デーモンが壊れている → Erase All Content")
                    SKLog.warn("  E) Xcode の Derived Data が古い → Product > Clean Build Folder")
                }

                for p in products {
                    SKLog.info("  プロダクト: id=\(p.id), name=\(p.displayName), price=\(p.displayPrice), type=\(p.type)")
                }

                if let first = products.first {
                    product = first
                    SKLog.info("✅ プロダクト取得成功: \(first.displayName) (\(first.displayPrice))")
                    return
                }

            } catch let skError as StoreKitError {
                SKLog.error("試行 \(attempt)/3: StoreKitError = \(skError)")
                SKLog.error("  localizedDescription: \(skError.localizedDescription)")
                switch skError {
                case .unknown:
                    SKLog.error("  → unknown エラー")
                case .userCancelled:
                    SKLog.error("  → ユーザーキャンセル")
                case .networkError(let e):
                    SKLog.error("  → ネットワークエラー: \(e)")
                case .systemError(let e):
                    SKLog.error("  → システムエラー: \(e)")
                case .notAvailableInStorefront:
                    SKLog.error("  → このストアフロントでは利用不可")
                case .notEntitled:
                    SKLog.error("  → エンタイトルメントなし")
                default:
                    SKLog.error("  → その他: \(skError)")
                }
            } catch {
                SKLog.error("試行 \(attempt)/3: 予期しないエラー")
                SKLog.error("  type: \(type(of: error))")
                SKLog.error("  description: \(error)")
                SKLog.error("  localizedDescription: \(error.localizedDescription)")
                let nsError = error as NSError
                SKLog.error("  NSError domain: \(nsError.domain), code: \(nsError.code)")
                SKLog.error("  userInfo: \(nsError.userInfo)")
            }

            if attempt < 3 {
                SKLog.info("3秒後に再試行します...")
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }

        SKLog.error("❌ 全試行失敗: プロダクトを取得できませんでした")
    }

    // MARK: - Purchase

    /// サブスクリプションを購入する
    /// - Throws: PremiumError.productNotFound / StoreKit エラー
    func purchase() async throws {
        SKLog.info("--- purchase() 開始 ---")
        guard let skProduct: StoreKit.Product = product else {
            SKLog.error("purchase() 失敗: product が nil")
            throw PremiumError.productNotFound
        }
        SKLog.info("購入対象: \(skProduct.id)")
        isLoading = true
        defer {
            isLoading = false
            SKLog.info("--- purchase() 終了 ---")
        }

        let result = try await skProduct.purchase()
        SKLog.info("purchase() 結果: \(result)")
        switch result {
        case .success(let verification):
            SKLog.info("purchase() success - 検証中...")
            let transaction = try checkVerified(verification as VerificationResult<StoreKit.Transaction>)
            SKLog.info("検証完了: transactionID=\(transaction.id), productID=\(transaction.productID)")
            await refreshPremiumStatus()
            await transaction.finish()
        case .userCancelled:
            SKLog.info("purchase() userCancelled")
        case .pending:
            SKLog.info("purchase() pending (保護者承認待ちなど)")
        @unknown default:
            SKLog.warn("purchase() unknown result")
        }
    }

    // MARK: - Restore

    /// 過去の購入を復元する
    func restore() async throws {
        SKLog.info("--- restore() 開始 ---")
        isLoading = true
        defer {
            isLoading = false
            SKLog.info("--- restore() 終了 (isPremium: \(self.isPremium)) ---")
        }
        SKLog.info("AppStore.sync() を呼び出し中...")
        try await AppStore.sync()
        SKLog.info("AppStore.sync() 完了")
        await refreshPremiumStatus()
    }

    // MARK: - Status

    /// 現在のエンタイトルメントを確認して isPremium を更新する
    func refreshPremiumStatus() async {
        SKLog.info("--- refreshPremiumStatus() 開始 ---")
        var hasActive = false
        var entitlementCount = 0
        for await result in Transaction.currentEntitlements {
            entitlementCount += 1
            switch result {
            case .verified(let transaction):
                SKLog.info("エンタイトルメント[\(entitlementCount)]: productID=\(transaction.productID), revocationDate=\(String(describing: transaction.revocationDate))")
                if transaction.productID == Self.productID,
                   transaction.revocationDate == nil {
                    hasActive = true
                    SKLog.info("  → プレミアム有効と判定")
                }
            case .unverified(let transaction, let error):
                SKLog.warn("エンタイトルメント[\(entitlementCount)]: 未検証 productID=\(transaction.productID), error=\(error)")
            }
        }
        if entitlementCount == 0 {
            SKLog.info("エンタイトルメント: 0件 (購入履歴なし)")
        }
        // 値が変わった場合のみ WidgetDataStore を更新してリロードコストを抑える
        if isPremium != hasActive {
            isPremium = hasActive
            WidgetDataStore.updatePremiumStatus(hasActive)
        } else {
            isPremium = hasActive
        }
        SKLog.info("isPremium = \(isPremium)")
        SKLog.info("--- refreshPremiumStatus() 終了 ---")
    }

    // MARK: - Formatted Price

    /// 価格を「¥250/月」形式で返す。プロダクト未取得時は取得中プレースホルダーを返す
    var formattedPrice: String {
        guard let p: StoreKit.Product = product else { return "価格を取得中..." }
        return "\(p.displayPrice)/月"
    }

    // MARK: - Private Helpers

    /// トランザクション更新をリアルタイムで監視する（解約・更新など）
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            SKLog.info("Transaction.updates 監視開始")
            for await result in Transaction.updates {
                guard let self else { return }
                SKLog.info("Transaction.updates: 新しいトランザクション受信")
                if case .verified(let transaction) = result {
                    SKLog.info("  verified: \(transaction.productID)")
                    await self.refreshPremiumStatus()
                    await transaction.finish()
                }
            }
        }
    }

    /// StoreKit の検証結果を確認する
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            SKLog.error("checkVerified: 検証失敗 \(error)")
            throw PremiumError.failedVerification
        case .verified(let value):
            return value
        }
    }
}

// MARK: - SKLog (簡易ロガー・DEBUG ビルドのみ出力)

private enum SKLog {
    static func info(_ msg: String) {
        #if DEBUG
        print("ℹ️ [StoreKit] \(msg)")
        #endif
    }
    static func warn(_ msg: String) {
        #if DEBUG
        print("⚠️ [StoreKit] \(msg)")
        #endif
    }
    static func error(_ msg: String) {
        #if DEBUG
        print("🔴 [StoreKit] \(msg)")
        #endif
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
