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

    init(
        id: UUID = UUID(),
        name: String,
        imageURL: String? = nil,
        category: String? = nil,
        estimatedPrice: Int? = nil,
        amazonASIN: String? = nil,
        rakutenItemCode: String? = nil,
        amazonURL: String? = nil,
        rakutenURL: String? = nil
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
    }
}
