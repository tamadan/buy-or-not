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
        この商品画像を分析して、以下のJSON形式のみで返してください。余分な説明は不要です。

        ## 最優先タスク：ブランド名・型番・商品名の特定
        - 画像に写っているロゴ、ブランド名、型番、モデル名を可能な限り読み取ってください
        - 例: "SONY WH-1000XM5"、"Apple AirPods Pro (第2世代)"、"Dyson V15 Detect"
        - ブランドが特定できれば、そのブランドの該当モデルとして回答してください
        - バーコード、型番シール、ロゴなどあらゆる手がかりを使ってください

        ## isVague の判定基準
        - isVague: false → ブランド名＋商品名（または型番）が特定できた場合
        - isVague: true → カテゴリ程度しかわからない、または「ダイニングテーブル」「ソファ」のように
                         同カテゴリ内で価格帯が数倍以上異なる場合

        ## isVague=false の場合
        {
          "name": "ブランド名＋商品名（例: SONY WH-1000XM5）",
          "category": "カテゴリ（例: ヘッドホン、スマートフォン、家電）",
          "estimatedPrice": 推定価格（円・整数）または null,
          "isVague": false,
          "priceRangeMin": null,
          "priceRangeMax": null
        }

        ## isVague=true の場合
        {
          "name": "わかる範囲でのカテゴリ名（例: ダイニングテーブル、革製ソファ）",
          "category": "大カテゴリ（例: 家具、インテリア）",
          "estimatedPrice": null,
          "isVague": true,
          "priceRangeMin": おおよその最低価格（円・整数）,
          "priceRangeMax": おおよその最高価格（円・整数）
        }
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 512,
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

        let priceInfo: String
        if product.isVague {
            let min = product.priceRangeMin.map { "¥\($0)" } ?? "不明"
            let max = product.priceRangeMax.map { "¥\($0)" } ?? "不明"
            priceInfo = "おおよその価格帯: \(min) 〜 \(max)（ざっくりしか特定できていない商品）"
        } else {
            // estimatedPrice は identifyProduct 時点では nil のまま渡される設計。
            // 実際の価格は searchResults（Tavily検索結果）に含まれており、
            // Claude がそこから読み取って judgement を生成する。
            // with(estimatedPrice:) による enrichment は judgeProduct の戻り値を受けて呼び元が行う。
            priceInfo = product.estimatedPrice.map { "¥\($0)" } ?? "不明（Web検索結果を参照）"
        }

        let productInfo = """
        商品名: \(product.name)
        カテゴリ: \(product.category ?? "不明")
        推定価格: \(priceInfo)
        ざっくり識別: \(product.isVague ? "はい（カテゴリ程度しかわかっていない）" : "いいえ（商品名・ブランド特定済み）")
        """

        let searchContext = searchResults.isEmpty
            ? "（検索結果なし）"
            : searchResults.prefix(4).joined(separator: "\n\n")

        let prompt = """
        あなたはユーザーの「本当にこれが必要か？」という自問を全力でサポートするアシスタントです。
        商品そのものを批判したり欠点を指摘したりしてはいけません。
        「ユーザー自身の生活・習慣・財布」に照らして、本当に必要かを問いかけてください。

        ## ルール
        - 商品・メーカーを批判しない。欠点指摘も禁止
        - 「あなたに本当に必要か？」という問いかけに徹する
        - stopPoints は必ず4個。下記の切り口から商品に合うものを選ぶ
          ・必要性  ：今持っているもので本当に代替できない？
          ・使用場面：具体的にいつ・どこで・誰と使う？
          ・時間軸  ：3日後も同じ熱量で欲しいと思える？
          ・安価代替：似たことが安くできるもので代用できない？
          ・レンタル：高額品なら一旦借りて試せないか？（使用頻度が不明な場合に特に有効）
          ・機会費用：同じ金額で他に何ができる？
        - 各 stopPoint は問いかけ形式で。title 20字以内・detail 60字以内
        - irukaComment は砕けた口調30字以内
          【禁止】月額換算・1回あたり換算は絶対に使わない
                  例：「月2回使うなら1回○円」「週3回なら1回△円」
                  → 長期耐久品では購買を正当化する効果になるため
          【推奨】時間軸・代替・使用場面など換算に依存しない切り口を使う
                  例：「3日後も同じくらい欲しい？」「似たの持ってない？」「どんな場面で使う想定？」
        - icon は SF Symbols 名（例: questionmark.circle, yensign.circle, clock.arrow.circlepath）
        - currentPrice は検索結果に価格があれば必ず設定
        - 抽象的な表現を避け、この商品の価格・用途に具体的に紐づけた問いかけにする

        ## 出力例（AirPods Proの場合）
        {
          "currentPrice": 39800,
          "productDescription": "...",
          "stopPoints": [
            { "icon": "headphones", "title": "今のイヤホンで本当に困ってる？", "detail": "直近1ヶ月で今のイヤホンに不満を感じた場面は具体的に何回あった？" },
            { "icon": "yensign.circle", "title": "同じ金額で何ができる？", "detail": "4万円あれば他に何ができる？旅行・別のガジェット・貯金と比べてみて" },
            { "icon": "archivebox", "title": "似たの持ってない？", "detail": "今使ってるイヤホンやヘッドホン、何個ある？全部使い切ってる？" },
            { "icon": "clock.arrow.circlepath", "title": "1週間後も欲しい？", "detail": "今感じてる欲しい気持ち、セール終わっても同じくらいある？" }
          ],
          "irukaComment": "1週間後も同じくらい欲しいと思えたら買えばいい",
          "alternativeSuggestion": "今持ってるイヤホンのノイキャンモード、ちゃんと試した？",
          "waitSuggestion": "次のセールまで待てば5,000円くらい安くなるかも"
        }

        ## 商品情報
        \(productInfo)

        ## 参考情報（Web検索結果：スペック・特徴・価格）
        \(searchContext)

        ## 出力形式（JSONのみ。説明不要）
        {
          "currentPrice": 販売価格（円・整数。不明な場合は null）,
          "productDescription": スペック・特徴・他製品との違いを200字程度,
          "stopPoints": [{"icon": "SF Symbol名", "title": "見出し", "detail": "問いかけ"}],
          "irukaComment": "イルカの一言",
          "alternativeSuggestion": "代替案。なければ null",
          "waitSuggestion": "待つ提案。なければ null"
        }
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
        // プロンプトで4個必須と指定しているため3個未満は不正レスポンスとみなす
        guard stopPoints.count >= 3 else { throw ClaudeError.parseError }

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
        let isVague = json["isVague"] as? Bool ?? false
        let priceRangeMin: Int? = (json["priceRangeMin"] as? Int)
            ?? (json["priceRangeMin"] as? Double).map { Int($0) }
        let priceRangeMax: Int? = (json["priceRangeMax"] as? Int)
            ?? (json["priceRangeMax"] as? Double).map { Int($0) }
        // 価格は Tavily 検索後に judgeProduct で取得するため、ここでは設定しない
        return Product(
            name: name,
            category: category,
            estimatedPrice: nil,
            isVague: isVague,
            priceRangeMin: priceRangeMin,
            priceRangeMax: priceRangeMax
        )
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
