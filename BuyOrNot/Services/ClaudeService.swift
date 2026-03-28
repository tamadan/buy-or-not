import Foundation
import UIKit

// MARK: - API Key
// Anthropic Console でAPIキーを取得: https://console.anthropic.com/
// 環境変数 ANTHROPIC_API_KEY に設定するか、下記 "YOUR_ANTHROPIC_API_KEY" を実際のキーに書き換えてください
private let anthropicAPIKey: String = Secrets.anthropicAPIKey

// MARK: - Claude Service

final class ClaudeService {
    static let shared = ClaudeService()
    private init() {
        if !useMock && anthropicAPIKey.isEmpty {
            print("⚠️ [ClaudeService] Secrets.anthropicAPIKey が空です。Secrets.swift を確認してください。")
        }
    }

    /// true にするとAPIを叩かずモックデータを返す
    private let useMock = false

    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-haiku-4-5-20251001"

    // MARK: - Mock

    private func mockProduct(hint: String = "") -> Product {
        Product(
            name: "SONY WH-1000XM5",
            category: "ヘッドホン",
            estimatedPrice: 44800
        )
    }

    // MARK: - Vision: 写真から商品を識別

    func identifyProduct(from image: UIImage) async throws -> Product {
        if useMock {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return mockProduct()
        }
        let resized = image.resizedForAPI(maxDimension: 1024)
        guard let imageData = resized.jpegData(compressionQuality: 0.7) else {
            throw ClaudeError.invalidImage
        }
        let base64 = imageData.base64EncodedString()

        let prompt = """
        この商品の画像を見て、以下のJSON形式のみで返してください。余分な説明は不要です。

        {
          "name": "商品名",
          "category": "カテゴリ（例: イヤホン, スマートフォン, 本, 食品, 家電）",
          "estimatedPrice": 推定価格（円、整数。不明な場合は null）
        }
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 256,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": base64
                        ]
                    ],
                    ["type": "text", "text": prompt]
                ]
            ]]
        ]

        return try await sendRequest(body: body)
    }

    // MARK: - Text: 商品名から識別

    func identifyProduct(name: String) async throws -> Product {
        if useMock {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return mockProduct(hint: name)
        }
        let prompt = """
        商品名「\(name)」について、以下のJSON形式のみで返してください。余分な説明は不要です。

        {
          "name": "正式な商品名（フルネーム）",
          "category": "カテゴリ（例: イヤホン, スマートフォン, 本, 食品, 家電）",
          "estimatedPrice": 推定価格（円、整数。不明な場合は null）
        }
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 256,
            "messages": [["role": "user", "content": prompt]]
        ]

        return try await sendRequest(body: body)
    }

    // MARK: - URL: AmazonまたはRakutenのURLから識別

    func identifyProduct(url urlString: String) async throws -> Product {
        if useMock {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return mockProduct(hint: urlString)
        }
        let urlInfo = parseProductURL(urlString)

        var contextLines: [String] = ["URL: \(urlString)"]
        if let asin = urlInfo.amazonASIN { contextLines.append("Amazon ASIN: \(asin)") }
        if let shop = urlInfo.rakutenShopCode, let item = urlInfo.rakutenItemCode {
            contextLines.append("楽天 ショップ: \(shop), 商品コード: \(item)")
        }

        let prompt = """
        以下のEC商品URLから商品を特定して、JSON形式のみで返してください。余分な説明は不要です。

        \(contextLines.joined(separator: "\n"))

        {
          "name": "商品名",
          "category": "カテゴリ（例: イヤホン, スマートフォン, 本, 食品, 家電）",
          "estimatedPrice": 推定価格（円、整数。不明な場合は null）
        }
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 256,
            "messages": [["role": "user", "content": prompt]]
        ]

        var product = try await sendRequest(body: body)

        // URLとASINをProductに付加
        if let asin = urlInfo.amazonASIN {
            product = Product(
                name: product.name,
                category: product.category,
                estimatedPrice: product.estimatedPrice,
                amazonASIN: asin,
                amazonURL: urlString
            )
        } else if let shop = urlInfo.rakutenShopCode, let item = urlInfo.rakutenItemCode {
            product = Product(
                name: product.name,
                category: product.category,
                estimatedPrice: product.estimatedPrice,
                rakutenItemCode: "\(shop)/\(item)",
                rakutenURL: urlString
            )
        }

        return product
    }

    // MARK: - URL解析

    private struct URLProductInfo {
        var amazonASIN: String?
        var rakutenShopCode: String?
        var rakutenItemCode: String?
    }

    private func parseProductURL(_ urlString: String) -> URLProductInfo {
        var info = URLProductInfo()
        guard let url = URL(string: urlString) else { return info }
        let host = url.host?.lowercased() ?? ""
        let path = url.path

        if host.contains("amazon") {
            // /dp/BXXXXXXXXX or /gp/product/BXXXXXXXXX
            let pattern = #"/(?:dp|gp/product)/([A-Z0-9]{10})"#
            if let range = path.range(of: pattern, options: .regularExpression) {
                let segment = String(path[range])
                let asinPattern = #"[A-Z0-9]{10}"#
                if let asinRange = segment.range(of: asinPattern, options: .regularExpression) {
                    info.amazonASIN = String(segment[asinRange])
                }
            }
        } else if host.contains("rakuten") {
            // item.rakuten.co.jp/shopcode/itemcode/
            let components = path.split(separator: "/").map(String.init).filter { !$0.isEmpty }
            if components.count >= 2 {
                info.rakutenShopCode = components[0]
                info.rakutenItemCode = components[1]
            }
        }

        return info
    }

    // MARK: - Text: バーコードから商品を識別

    func identifyProduct(barcode: String) async throws -> Product {
        if useMock {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return mockProduct(hint: barcode)
        }
        let prompt = """
        JANコード（バーコード）「\(barcode)」の商品を教えてください。
        知っている場合は正確に、不明な場合は推測で構いません。
        以下のJSON形式のみで返してください。余分な説明は不要です。

        {
          "name": "商品名",
          "category": "カテゴリ（例: イヤホン, スマートフォン, 本, 食品, 家電）",
          "estimatedPrice": 推定価格（円、整数。不明な場合は null）
        }
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 256,
            "messages": [[
                "role": "user",
                "content": prompt
            ]]
        ]

        return try await sendRequest(body: body)
    }

    // MARK: - 判定: 買わない理由を生成

    func judgeProduct(product: Product, searchResults: [String]) async throws -> (judgement: Judgement, currentPrice: Int?) {
        if useMock {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return (mockJudgement(product: product), nil)
        }

        let productInfo = """
        商品名: \(product.name)
        カテゴリ: \(product.category ?? "不明")
        推定価格: \(product.estimatedPrice.map { "¥\($0)" } ?? "不明")
        """

        let searchContext = searchResults.isEmpty
            ? "（検索結果なし）"
            : searchResults.prefix(4).joined(separator: "\n\n")

        let prompt = """
        あなたは「本当にその買い物は必要か？」をユーザーに問いかけるアシスタントです。
        商品を批判するのではなく、ユーザー自身が「本当に必要か」を考えるきっかけを与えてください。

        ## 商品情報
        \(productInfo)

        ## 参考情報（Web検索結果：スペック・特徴・価格）
        \(searchContext)

        ## 出力形式（JSONのみ。説明不要）
        {
          "currentPrice": 検索結果から判明した日本での現在の販売価格（円・整数。不明な場合は null）,
          "productDescription": 検索結果をもとにした商品の特徴・スペックまとめ（100字以内）,
          "stopPoints": [
            {
              "icon": "SF Symbol名",
              "title": "問いかけの見出し（20字以内）",
              "detail": "具体的な説明（60字以内）"
            }
          ],
          "irukaComment": "イルカの一言（30字以内、フレンドリーに）",
          "alternativeSuggestion": "代替案（あれば。なければ null）",
          "waitSuggestion": "「少し待ってみては？」系のアドバイス（あれば。なければ null）"
        }

        ## ルール
        - currentPrice は検索結果に価格情報があれば必ず設定する
        - stopPoints は3〜4個。検索結果から得たスペックや特徴を根拠にして具体的に書く
          例：「重量680gで長時間装着すると首に負担」「ノイキャンは前世代より20%向上だが旧モデルで代用可」
        - 商品や企業を批判しない。「ユーザー自身に問いかける」視点で書く
        - irukaComment は「ほんとにいるか？」のようなキャラクターらしい口調
        - icon は SF Symbols の名前（例: questionmark.circle, yensign.circle, clock.arrow.circlepath）
        - 価格が高い場合はコスパの問いかけを必ず含める
        - 抽象的な表現を避け、この商品固有の具体的な数値・特徴を使う
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
        ]

        let json = try await sendRequestRaw(body: body)

        guard let stopPointsJSON = json["stopPoints"] as? [[String: Any]] else {
            throw ClaudeError.parseError
        }

        let stopPoints = stopPointsJSON.compactMap { sp -> StopPoint? in
            guard let title = sp["title"] as? String,
                  let detail = sp["detail"] as? String else { return nil }
            let icon = sp["icon"] as? String ?? "questionmark.circle"
            return StopPoint(icon: icon, title: title, detail: detail)
        }
        guard !stopPoints.isEmpty else { throw ClaudeError.parseError }

        let productDescription = json["productDescription"] as? String
        let irukaComment = json["irukaComment"] as? String ?? "ほんとにいるか？"
        let alternativeSuggestion = json["alternativeSuggestion"] as? String
        let waitSuggestion = json["waitSuggestion"] as? String
        // Claude は整数を Double で返すことがあるため両方対応
        let currentPrice: Int? = (json["currentPrice"] as? Int)
            ?? (json["currentPrice"] as? Double).map { Int($0) }

        let judgement = Judgement(
            productDescription: productDescription,
            stopPoints: stopPoints,
            irukaComment: irukaComment,
            alternativeSuggestion: alternativeSuggestion,
            waitSuggestion: waitSuggestion
        )
        return (judgement, currentPrice)
    }

    private func mockJudgement(product: Product) -> Judgement {
        let price = product.estimatedPrice ?? 0
        return Judgement(
            productDescription: "\(product.name)のモック説明です。実際の検索結果から特徴・スペックが表示されます。",
            stopPoints: [
                StopPoint(icon: "questionmark.circle", title: "今すぐ必要？", detail: "壊れたわけでもないのに、今買う理由は何？"),
                StopPoint(icon: "yensign.circle", title: "¥\(price)の価値ある？", detail: "月に何時間使う？1時間あたりのコストを計算してみて"),
                StopPoint(icon: "clock.arrow.circlepath", title: "3日待てる？", detail: "3日後にまだ欲しければ、それは本物の欲求かも"),
                StopPoint(icon: "arrow.down.circle", title: "代替手段ない？", detail: "今持っているもので代用できないか考えてみて"),
            ],
            irukaComment: "ほんとにいるか？\nちょっと待って考えてみ？",
            alternativeSuggestion: nil,
            waitSuggestion: "3日間カートに入れたまま待ってみよう。まだ欲しければ買えばいい。"
        )
    }

    // MARK: - 共通リクエスト処理

    /// レスポンスのJSONブロックを [String: Any] で返す汎用メソッド
    private func sendRequestRaw(body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeError.apiError(statusCode: nil, body: nil)
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)
            print("⚠️ [ClaudeService] HTTP \(http.statusCode): \(body ?? "no body")")
            throw ClaudeError.apiError(statusCode: http.statusCode, body: body)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (json["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String else {
            throw ClaudeError.parseError
        }

        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let startIdx = raw.firstIndex(of: "{"),
              let endIdx = raw.lastIndex(of: "}") else {
            throw ClaudeError.parseError
        }
        let jsonString = String(raw[startIdx...endIdx])

        guard let jsonData = jsonString.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw ClaudeError.parseError
        }

        return parsed
    }

    private func sendRequest(body: [String: Any]) async throws -> Product {
        let json = try await sendRequestRaw(body: body)
        let name = json["name"] as? String ?? "不明な商品"
        let category = json["category"] as? String
        // 価格は Tavily 検索後に judgeProduct で取得するため、ここでは設定しない
        return Product(name: name, category: category, estimatedPrice: nil)
    }

    // MARK: - エラー定義

    enum ClaudeError: LocalizedError {
        case invalidImage
        case apiError(statusCode: Int?, body: String?)
        case parseError

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "画像の処理に失敗しました"
            case .apiError(let statusCode, let body):
                var msg = "API通信エラー"
                if let statusCode { msg += "（HTTP \(statusCode)）" }
                if let body {
                    // Anthropic エラーの type/message を抽出して表示
                    if let data = body.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorObj = json["error"] as? [String: Any],
                       let message = errorObj["message"] as? String {
                        msg += "\n\(message)"
                    } else {
                        msg += "\n\(body.prefix(200))"
                    }
                }
                return msg
            case .parseError:
                return "レスポンスの解析に失敗しました"
            }
        }
    }
}
