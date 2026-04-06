import Foundation

@MainActor
final class ResultViewModel: ObservableObject {
    @Published var product: Product?
    @Published var judgement: Judgement?
    @Published var isLoading = true  // 初期からローディング表示
    @Published var errorMessage: String?

    init(product: Product? = nil) {
        self.product = product
        // auto-start しない。ResultView の .task から startLoading() を呼ぶ
    }

    /// 判定を開始する。履歴と isPremium を受け取り個人化コンテキストを生成する
    func startLoading(history: [JudgementHistory] = [], isPremium: Bool = false) async {
        guard let product else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil

        // 個人化コンテキストを生成（プレミアム + 履歴7件以上の場合のみ）
        let personalization = PersonalizationContext.build(
            for: product,
            history: history,
            isPremium: isPremium
        )

        do {
            // Tavily で商品情報を検索
            var searchResults: [String] = []
            do {
                searchResults = try await TavilyService.shared.searchProductInfo(productName: product.name)
            } catch {
                print("⚠️ [ResultViewModel] Tavily search failed: \(error)")
            }

            // Claude で「買わない理由」を生成（currentPrice も取得）
            let result = try await ClaudeService.shared.judgeProduct(
                product: product,
                searchResults: searchResults,
                personalizationContext: personalization
            )
            judgement = result.judgement

            // 検索結果から正確な価格が取れた場合は更新する
            if let currentPrice = result.currentPrice {
                self.product = product.with(estimatedPrice: currentPrice)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func dismissError() {
        errorMessage = nil
    }
}
