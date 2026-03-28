import Foundation

final class TavilyService {
    static let shared = TavilyService()
    private init() {}

    private let baseURL = URL(string: "https://api.tavily.com/search")!

    /// 商品名でスペック・特徴・価格を並列検索し、テキスト抜粋の配列を返す
    func searchProductInfo(productName: String) async throws -> [String] {
        async let specsResults = search(query: "\(productName) スペック 特徴 詳細")
        async let priceResults = search(query: "\(productName) 価格 定価 実勢価格")

        var specs: [String] = []
        var price: [String] = []

        do { specs = try await specsResults } catch {
            print("⚠️ [TavilyService] specs search failed: \(error)")
        }
        do { price = try await priceResults } catch {
            print("⚠️ [TavilyService] price search failed: \(error)")
        }

        // スペック3件・価格3件を確保して結合
        let combined = Array(specs.prefix(3)) + Array(price.prefix(3))
        guard !combined.isEmpty else { throw TavilyError.noResults }
        return combined
    }

    private func search(query: String) async throws -> [String] {
        let body: [String: Any] = [
            "api_key": Secrets.tavilyAPIKey,
            "query": query,
            "search_depth": "basic",
            "max_results": 5,
            "include_answer": false,
            "include_raw_content": false
        ]

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode
            throw TavilyError.apiError(statusCode: status)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            throw TavilyError.parseError
        }

        // 各検索結果のタイトル＋スニペットを結合して返す
        return results.compactMap { result in
            let title = result["title"] as? String ?? ""
            let snippet = result["content"] as? String ?? ""
            guard !snippet.isEmpty else { return nil }
            return "【\(title)】\(snippet)"
        }
    }

    enum TavilyError: LocalizedError {
        case apiError(statusCode: Int?)
        case parseError
        case noResults

        var errorDescription: String? {
            switch self {
            case .apiError(let code):
                return "検索APIエラー（HTTP \(code.map(String.init) ?? "不明")）"
            case .parseError:
                return "検索結果の解析に失敗しました"
            case .noResults:
                return "検索結果が見つかりませんでした"
            }
        }
    }
}
