import Foundation

struct Product: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let imageURL: String?
    let category: String?
    let estimatedPrice: Int?
    let amazonASIN: String?
    let rakutenItemCode: String?
    let amazonURL: String?
    let rakutenURL: String?
    /// ブランド・型番が特定できずカテゴリ程度しかわからない場合 true
    let isVague: Bool
    /// ざっくり価格の下限（isVague=true のとき使用）
    let priceRangeMin: Int?
    /// ざっくり価格の上限（isVague=true のとき使用）
    let priceRangeMax: Int?

    init(
        id: UUID = UUID(),
        name: String,
        imageURL: String? = nil,
        category: String? = nil,
        estimatedPrice: Int? = nil,
        amazonASIN: String? = nil,
        rakutenItemCode: String? = nil,
        amazonURL: String? = nil,
        rakutenURL: String? = nil,
        isVague: Bool = false,
        priceRangeMin: Int? = nil,
        priceRangeMax: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.category = category
        self.estimatedPrice = estimatedPrice
        self.amazonASIN = amazonASIN
        self.rakutenItemCode = rakutenItemCode
        self.amazonURL = amazonURL
        self.rakutenURL = rakutenURL
        self.isVague = isVague
        self.priceRangeMin = priceRangeMin
        self.priceRangeMax = priceRangeMax
    }

    func with(estimatedPrice: Int?) -> Product {
        Product(
            id: id, name: name, imageURL: imageURL, category: category,
            estimatedPrice: estimatedPrice, amazonASIN: amazonASIN,
            rakutenItemCode: rakutenItemCode, amazonURL: amazonURL, rakutenURL: rakutenURL,
            isVague: isVague, priceRangeMin: priceRangeMin, priceRangeMax: priceRangeMax
        )
    }
}
