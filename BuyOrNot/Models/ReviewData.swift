import Foundation

enum ReviewSource: String, Codable {
    case amazon
    case rakuten
}

struct PricePoint: Codable {
    let date: Date
    let price: Int
}

/// 悪いレビューのピックアップ
struct NegativeReview: Identifiable, Codable {
    let id: UUID
    let source: ReviewSource
    let rating: Int           // 1〜2
    let title: String?
    let excerpt: String       // 抜粋
    let date: Date?

    init(
        id: UUID = UUID(),
        source: ReviewSource,
        rating: Int,
        title: String? = nil,
        excerpt: String,
        date: Date? = nil
    ) {
        self.id = id
        self.source = source
        self.rating = rating
        self.title = title
        self.excerpt = excerpt
        self.date = date
    }
}

struct ReviewData: Codable {
    let source: ReviewSource
    let rating: Double
    let reviewCount: Int
    let currentPrice: Int?
    let negativeRatio: Double?       // 星1-2の割合
    let negativeReviews: [NegativeReview]?
}
