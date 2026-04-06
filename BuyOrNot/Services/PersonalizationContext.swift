import Foundation

/// 履歴からユーザーの購買パターンを分析し、プロンプトに挿入するコンテキストを生成する
enum PersonalizationContext {

    /// 必要な最低履歴件数
    static let minimumHistoryCount = 7
    /// 同カテゴリ繰り返しとみなす件数
    static let repeatCategoryThreshold = 3

    /// 個人化コンテキスト文字列を生成する
    /// - Returns: プロンプトに挿入する文字列。条件未達の場合は nil
    static func build(
        for product: Product,
        history: [JudgementHistory],
        isPremium: Bool
    ) -> String? {
        guard isPremium, history.count >= minimumHistoryCount else { return nil }

        var signals: [String] = []

        // ① 同商品の再チェック
        let sameProduct = history.filter { item in
            item.productName.lowercased().contains(product.name.lowercased()) ||
            product.name.lowercased().contains(item.productName.lowercased())
        }
        if let prev = sameProduct.sorted(by: { $0.date > $1.date }).first {
            if prev.didBuy {
                signals.append("このユーザーは以前「\(prev.productName)」を購入しています（同じ商品を再検討している）")
            } else {
                signals.append("このユーザーは以前「\(prev.productName)」をチェックして購入を止めています（再度同じ商品に興味を持っている）")
            }
        }

        // ② 同カテゴリの繰り返しチェック（3回以上）
        if let category = product.category {
            let sameCategory = history.filter { $0.productCategory == category }
            if sameCategory.count >= repeatCategoryThreshold {
                let boughtCount = sameCategory.filter { $0.didBuy }.count
                let stoppedCount = sameCategory.count - boughtCount
                signals.append(
                    "このユーザーは「\(category)」カテゴリを過去\(sameCategory.count)回チェックしています" +
                    "（購入\(boughtCount)回・止めた\(stoppedCount)回）。" +
                    (stoppedCount >= boughtCount ? "このカテゴリへの衝動的な関心が高い可能性があります。" : "")
                )
            }
        }

        guard !signals.isEmpty else { return nil }

        return """

        ## このユーザーの購買パターン（個人化情報・重要）
        以下のパターンを踏まえ、より的確でパーソナルな問いかけをしてください。
        \(signals.map { "- \($0)" }.joined(separator: "\n"))
        """
    }
}
