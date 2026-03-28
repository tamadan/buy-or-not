import Foundation

/// やめとけ根拠の強さ
/// - evidenceBased: 実データ（悪レビュー・価格高騰等）に基づく「マジでやめとけ」
/// - logicBased: 論理的にこねくり回した「マジでやめとけ」
enum StopReason: String, Codable {
    case evidenceBased  // 悪いレビュー・高値掴み等の実データあり
    case logicBased     // データはないが理屈で止める
}

/// イルカの止め方のポイント1つ分
struct StopPoint: Identifiable, Codable {
    let id: UUID
    let icon: String        // SF Symbol名
    let title: String       // 見出し（例: "レビューが荒れてる"）
    let detail: String      // 詳細説明
    let source: String?     // 出典（例: "Amazon レビュー", nil = AIの意見）

    init(
        id: UUID = UUID(),
        icon: String,
        title: String,
        detail: String,
        source: String? = nil
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.detail = detail
        self.source = source
    }
}

/// イルカの最終判定
struct Judgement: Codable {
    let stopReason: StopReason
    let stopPoints: [StopPoint]         // やめとけポイント（複数）
    let irukaComment: String            // イルカの一言（メインの吹き出し）
    let alternativeSuggestion: String?  // 「これでよくない？」代替提案
    let waitSuggestion: String?         // 「3日待ってみ？」系
}
