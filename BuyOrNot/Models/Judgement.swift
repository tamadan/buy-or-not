import Foundation

/// 「買わない理由」1つ分
struct StopPoint: Identifiable, Codable {
    let id: UUID
    let icon: String        // SF Symbol名
    let title: String       // 見出し（例: "本当に音質の違いがわかる？"）
    let detail: String      // 詳細説明

    init(id: UUID = UUID(), icon: String, title: String, detail: String) {
        self.id = id
        self.icon = icon
        self.title = title
        self.detail = detail
    }
}

/// イルカの最終判定
struct Judgement: Codable {
    let productDescription: String?     // 商品の説明・特徴まとめ
    let stopPoints: [StopPoint]         // 買わない理由（複数）
    let irukaComment: String            // イルカの一言（メインの吹き出し）
    let alternativeSuggestion: String?  // 「これでよくない？」代替提案
    let waitSuggestion: String?         // 「少し待ってみ？」系
}
