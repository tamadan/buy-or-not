import Foundation

@MainActor
final class ResultViewModel: ObservableObject {
    @Published var product: Product?
    @Published var judgement: Judgement?
    @Published var negativeReviews: [NegativeReview] = []
    @Published var isLoading = false

    init(product: Product? = nil) {
        self.product = product
        loadDummyData_evidenceBased()
    }

    // MARK: - パターン1: 実データ根拠（悪いレビューあり）

    func loadDummyData_evidenceBased() {
        // カメラから商品が渡された場合はそちらを優先
        if product == nil {
            product = Product(
                name: "SOUNDMAX ワイヤレスイヤホン Pro X",
                category: "イヤホン",
                estimatedPrice: 4980,
                amazonASIN: "B0EXAMPLE1",
                rakutenItemCode: "soundmax-prox",
                amazonURL: "https://amazon.co.jp/dp/B0EXAMPLE1?tag=irukasore-22",
                rakutenURL: "https://item.rakuten.co.jp/soundmax/prox/?scid=af_irukasore"
            )
        }

        negativeReviews = [
            NegativeReview(
                source: .amazon,
                rating: 1,
                title: "2ヶ月で片耳聞こえなくなった",
                excerpt: "充電はできるのに右耳だけ音が出なくなりました。保証もまともに対応してもらえず最悪です。"
            ),
            NegativeReview(
                source: .amazon,
                rating: 2,
                title: "ノイキャンが全く効かない",
                excerpt: "ノイズキャンセリング搭載と書いてあるが、ONにしても違いがわからないレベル。電車では使い物にならない。"
            ),
            NegativeReview(
                source: .rakuten,
                rating: 1,
                title: "サクラレビューだらけ",
                excerpt: "高評価レビューの日本語が不自然。実際使ってみると音質も接続安定性もひどい。"
            ),
        ]

        judgement = Judgement(
            stopReason: .evidenceBased,
            stopPoints: [
                StopPoint(
                    icon: "star.slash.fill",
                    title: "低評価レビューが多すぎる",
                    detail: "星1〜2のレビューが全体の34%。特に「故障」「接続不良」の報告が目立つ。",
                    source: "Amazon レビュー分析"
                ),
                StopPoint(
                    icon: "exclamationmark.triangle.fill",
                    title: "耐久性に深刻な問題",
                    detail: "「2〜3ヶ月で壊れた」という報告が複数。メーカー保証の対応も悪い。",
                    source: "Amazon / 楽天 レビュー"
                ),
                StopPoint(
                    icon: "yensign.circle.fill",
                    title: "この価格帯ならもっと良いのがある",
                    detail: "¥4,980出すならAnker Soundcore P40iの方が評価4.4で信頼性が高い。",
                    source: "価格帯比較"
                ),
                StopPoint(
                    icon: "person.fill.questionmark",
                    title: "サクラレビューの疑い",
                    detail: "高評価レビューの投稿日が集中しており、不自然な日本語のレビューが多い。",
                    source: "レビュー分析"
                ),
            ],
            irukaComment: "いるか？これ？\nレビュー荒れすぎだって！",
            alternativeSuggestion: "同じ価格帯のAnker Soundcore P40iはレビュー4.4（8,200件）で故障報告も少ない。こっちでよくない？",
            waitSuggestion: nil
        )
    }

    // MARK: - パターン2: 論理こねくり回し（データは悪くないけど止める）

    func loadDummyData_logicBased() {
        product = Product(
            name: "SONY WH-1000XM5 ワイヤレスノイズキャンセリングヘッドホン",
            category: "ヘッドホン",
            estimatedPrice: 44800,
            amazonASIN: "B0BX2L8PBS",
            amazonURL: "https://amazon.co.jp/dp/B0BX2L8PBS?tag=irukasore-22"
        )

        negativeReviews = []

        judgement = Judgement(
            stopReason: .logicBased,
            stopPoints: [
                StopPoint(
                    icon: "yensign.circle.fill",
                    title: "¥44,800は衝動買いの金額じゃない",
                    detail: "手取り25万として月収の18%。これ、衝動で決めていい額？"
                ),
                StopPoint(
                    icon: "headphones",
                    title: "今のイヤホン、まだ使えるよね？",
                    detail: "今使ってるやつが壊れたわけじゃないでしょ？壊れてから考えても遅くない。"
                ),
                StopPoint(
                    icon: "calendar",
                    title: "年末セールまであと2ヶ月",
                    detail: "過去のデータだと11月のブラックフライデーで¥35,000前後まで下がってる。¥10,000浮くよ？",
                    source: "価格履歴データ"
                ),
                StopPoint(
                    icon: "arrow.down.circle.fill",
                    title: "XM4の中古という手もある",
                    detail: "前モデルXM4は中古¥22,000前後。音質の差は一般人にはほぼわからない。"
                ),
            ],
            irukaComment: "いるか？それ？\n…いや良い商品なのは認める。\nでも今じゃなくない？",
            alternativeSuggestion: "前モデルWH-1000XM4の中古なら半額以下。ノイキャン性能の差はほとんどの人が気づかないレベル。",
            waitSuggestion: "ブラックフライデーまで2ヶ月。カレンダーに「XM5チェック」って入れて、その時まだ欲しかったら買えばいい。それで¥10,000浮く。"
        )
    }
}
