import Foundation
import UIKit

// MARK: - API Key
// Anthropic Console でAPIキーを取得: https://console.anthropic.com/
// 環境変数 ANTHROPIC_API_KEY に設定するか、下記に直接記入してください
private let anthropicAPIKey: String = {
    if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty {
        return key
    }
    return "YOUR_ANTHROPIC_API_KEY"
}()

// MARK: - Claude Service

final class ClaudeService {
    static let shared = ClaudeService()
    private init() {}

    /// true にするとAPIを叩かずモックデータを返す
    private let useMock = true

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
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
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

    // MARK: - 共通リクエスト処理

    private func sendRequest(body: [String: Any]) async throws -> Product {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ClaudeError.apiError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (json["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String else {
            throw ClaudeError.parseError
        }

        // レスポンステキストからJSONブロックを抽出
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let startIdx = raw.firstIndex(of: "{"),
              let endIdx = raw.lastIndex(of: "}") else {
            throw ClaudeError.parseError
        }
        let jsonString = String(raw[startIdx...endIdx])

        guard let jsonData = jsonString.data(using: .utf8),
              let productJSON = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw ClaudeError.parseError
        }

        let name = productJSON["name"] as? String ?? "不明な商品"
        let category = productJSON["category"] as? String
        let estimatedPrice = productJSON["estimatedPrice"] as? Int

        return Product(name: name, category: category, estimatedPrice: estimatedPrice)
    }

    // MARK: - エラー定義

    enum ClaudeError: LocalizedError {
        case invalidImage
        case apiError
        case parseError

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "画像の処理に失敗しました"
            case .apiError:     return "API通信エラーが発生しました"
            case .parseError:   return "レスポンスの解析に失敗しました"
            }
        }
    }
}
