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
            let searchResults = (try? await TavilyService.shared.searchProductInfo(productName: product.name)) ?? []

            // Claude で「買わない理由」を生成（currentPrice も取得）
            let result = try await ClaudeService.shared.judgeProduct(
                product: product,
                searchResults: searchResults
            )
            judgement = result.judgement

            // 検索結果から正確な価格が取れた場合は更新する
            if let currentPrice = result.currentPrice {
                self.product = Product(
                    id: product.id,
                    name: product.name,
                    imageURL: product.imageURL,
                    category: product.category,
                    estimatedPrice: currentPrice,
                    amazonASIN: product.amazonASIN,
                    rakutenItemCode: product.rakutenItemCode,
                    amazonURL: product.amazonURL,
                    rakutenURL: product.rakutenURL
                )
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
