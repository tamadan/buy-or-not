import Foundation

@MainActor
final class ResultViewModel: ObservableObject {
    @Published var product: Product?
    @Published var judgement: Judgement?
    @Published var isLoading = false
    @Published var errorMessage: String?

    init(product: Product? = nil) {
        self.product = product
        Task { await loadJudgement() }
    }

    func loadJudgement() async {
        guard let product else { return }
        isLoading = true
        errorMessage = nil

        do {
            // Tavily で商品情報を検索
            var searchResults: [String] = []
            do {
                searchResults = try await TavilyService.shared.searchProductInfo(productName: product.name)
            } catch {
                print("⚠️ [ResultViewModel] Tavily search failed: \(error)")
                // 検索失敗時は空配列で Claude に進む（致命的エラーではない）
            }

            // Claude で「買わない理由」を生成（currentPrice も取得）
            let result = try await ClaudeService.shared.judgeProduct(
                product: product,
                searchResults: searchResults
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
