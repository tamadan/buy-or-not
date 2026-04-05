import Foundation
import SwiftData

/// 判定履歴1件分
@Model
final class JudgementHistory {
    var id: UUID
    var date: Date

    // 商品情報
    var productName: String
    var productCategory: String?
    var estimatedPrice: Int?
    var isVague: Bool
    var priceRangeMin: Int?
    var priceRangeMax: Int?

    // 判定結果
    var irukaComment: String
    /// stopPoints のタイトル一覧（表示用）
    var stopPointTitles: [String]

    /// 「それでも買う」を押したか
    var didBuy: Bool

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        productName: String,
        productCategory: String? = nil,
        estimatedPrice: Int? = nil,
        isVague: Bool = false,
        priceRangeMin: Int? = nil,
        priceRangeMax: Int? = nil,
        irukaComment: String,
        stopPointTitles: [String],
        didBuy: Bool = false
    ) {
        self.id = id
        self.date = date
        self.productName = productName
        self.productCategory = productCategory
        self.estimatedPrice = estimatedPrice
        self.isVague = isVague
        self.priceRangeMin = priceRangeMin
        self.priceRangeMax = priceRangeMax
        self.irukaComment = irukaComment
        self.stopPointTitles = stopPointTitles
        self.didBuy = didBuy
    }

    /// 守った金額（didBuy=false かつ価格あり の場合）
    var savedAmount: Int? {
        guard !didBuy else { return nil }
        if let price = estimatedPrice { return price }
        if let min = priceRangeMin, let max = priceRangeMax { return (min + max) / 2 }
        return nil
    }
}
