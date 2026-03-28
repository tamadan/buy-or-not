import SwiftUI
import SafariServices

struct ResultView: View {
    @StateObject private var viewModel: ResultViewModel
    @State private var showBuyConfirm = false

    init(product: Product? = nil) {
        _viewModel = StateObject(wrappedValue: ResultViewModel(product: product))
    }

    var body: some View {
        ZStack {
            // 背景
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // 商品名
                    if let product = viewModel.product {
                        ProductHeader(product: product)
                    }

                    // イルカ + メインコメント
                    if let judgement = viewModel.judgement {
                        IrukaCharacter(
                            mood: judgement.stopReason == .evidenceBased ? .alarmed : .smug,
                            comment: judgement.irukaComment
                        )
                        .padding(.top, 8)
                    }

                    // やめとけポイント
                    if let judgement = viewModel.judgement {
                        StopPointsSection(
                            stopPoints: judgement.stopPoints,
                            isEvidenceBased: judgement.stopReason == .evidenceBased
                        )
                    }

                    // 悪いレビュー抜粋
                    if !viewModel.negativeReviews.isEmpty {
                        NegativeReviewsSection(reviews: viewModel.negativeReviews)
                    }

                    // 代替提案 & 待て提案
                    if let judgement = viewModel.judgement {
                        SuggestionsSection(judgement: judgement)
                    }

                    // 「それでも買う」ボタン
                    BuyAnywayButton(showConfirm: $showBuyConfirm)
                        .padding(.top, 8)

                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("イルカソレ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBuyConfirm) {
            BuyConfirmSheet(
                product: viewModel.product,
                onDismiss: { showBuyConfirm = false }
            )
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Product Header

private struct ProductHeader: View {
    let product: Product

    var body: some View {
        VStack(spacing: 8) {
            if let category = product.category {
                Text(category)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color(.secondaryLabel))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(.systemGray6)))
            }

            Text(product.name)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Color(.label))
                .multilineTextAlignment(.center)

            if let price = product.estimatedPrice {
                Text("¥\(price.formatted())")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(Color(hex: "E74C3C"))
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Stop Points Section

private struct StopPointsSection: View {
    let stopPoints: [StopPoint]
    let isEvidenceBased: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // セクションヘッダー
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(Color(hex: "E74C3C"))
                Text("やめとけポイント")
                    .font(.headline)

                Spacer()

                // 根拠バッジ
                Text(isEvidenceBased ? "実データあり" : "AI分析")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(isEvidenceBased ? Color(hex: "E74C3C") : Color(hex: "F39C12"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            isEvidenceBased
                                ? Color(hex: "E74C3C").opacity(0.12)
                                : Color(hex: "F39C12").opacity(0.12)
                        )
                    )
            }
            .padding(.horizontal)

            // ポイントカード
            ForEach(stopPoints) { point in
                StopPointCard(point: point)
            }
        }
    }
}

private struct StopPointCard: View {
    let point: StopPoint

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // アイコン
            Image(systemName: point.icon)
                .font(.title3)
                .foregroundColor(Color(hex: "E74C3C"))
                .frame(width: 36, height: 36)
                .background(Color(hex: "E74C3C").opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(point.title)
                    .font(.subheadline)
                    .fontWeight(.bold)

                Text(point.detail)
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
                    .lineSpacing(3)

                if let source = point.source {
                    Text("出典: \(source)")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "3498DB"))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
        .padding(.horizontal)
    }
}

// MARK: - Negative Reviews Section

private struct NegativeReviewsSection: View {
    let reviews: [NegativeReview]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundColor(Color(hex: "E67E22"))
                Text("実際のレビューより")
                    .font(.headline)
            }
            .padding(.horizontal)

            ForEach(reviews) { review in
                NegativeReviewCard(review: review)
            }
        }
    }
}

private struct NegativeReviewCard: View {
    let review: NegativeReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 星
                let clampedRating = min(max(review.rating, 0), 5)
                HStack(spacing: 2) {
                    ForEach(0..<clampedRating, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(Color(hex: "E74C3C"))
                    }
                    ForEach(0..<(5 - clampedRating), id: \.self) { _ in
                        Image(systemName: "star")
                            .font(.caption2)
                            .foregroundColor(Color(.systemGray4))
                    }
                }

                Spacer()

                Text(review.source == .amazon ? "Amazon" : "楽天")
                    .font(.caption2)
                    .foregroundColor(Color(.secondaryLabel))
            }

            if let title = review.title {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            Text("「\(review.excerpt)」")
                .font(.caption)
                .foregroundColor(Color(.secondaryLabel))
                .italic()
                .lineSpacing(3)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "E74C3C").opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Suggestions Section

private struct SuggestionsSection: View {
    let judgement: Judgement

    var body: some View {
        VStack(spacing: 12) {
            if let alt = judgement.alternativeSuggestion {
                SuggestionCard(
                    icon: "arrow.triangle.2.circlepath",
                    title: "これでよくない？",
                    detail: alt,
                    color: Color(hex: "3498DB")
                )
            }

            if let wait = judgement.waitSuggestion {
                SuggestionCard(
                    icon: "clock.arrow.circlepath",
                    title: "ちょっと待ってみ？",
                    detail: wait,
                    color: Color(hex: "9B59B6")
                )
            }
        }
    }
}

private struct SuggestionCard: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(color)

                Text(detail)
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
                    .lineSpacing(3)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
        .padding(.horizontal)
    }
}

// MARK: - Buy Anyway Button

private struct BuyAnywayButton: View {
    @Binding var showConfirm: Bool

    var body: some View {
        Button {
            showConfirm = true
        } label: {
            HStack(spacing: 8) {
                Text("それでも買う")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "cart.fill")
                    .font(.subheadline)
            }
            .foregroundColor(Color(.secondaryLabel))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
}

// MARK: - Buy Confirm Sheet

private struct BuyConfirmSheet: View {
    let product: Product?
    let onDismiss: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 24) {
            // イルカの最後の抵抗
            IrukaCharacter(
                mood: .pleading,
                comment: "ほんとに買うの…？",
                size: 90
            )

            Text("イルカは止めたからね…")
                .font(.subheadline)
                .foregroundColor(Color(.secondaryLabel))

            // アフィリンクボタン
            VStack(spacing: 12) {
                if product?.amazonURL != nil || product?.amazonASIN != nil {
                    AffiliateLinkButton(
                        title: "Amazonで買う",
                        color: Color(hex: "FF9900"),
                        icon: "cart.fill"
                    ) {
                        let urlString = product?.amazonURL
                            ?? product?.amazonASIN.map { "https://www.amazon.co.jp/dp/\($0)" }
                        if let urlString, let url = URL(string: urlString) {
                            openURL(url)
                        }
                    }
                }

                if product?.rakutenURL != nil || product?.rakutenItemCode != nil {
                    AffiliateLinkButton(
                        title: "楽天で買う",
                        color: Color(hex: "BF0000"),
                        icon: "cart.fill"
                    ) {
                        let urlString = product?.rakutenURL
                            ?? product?.rakutenItemCode.map { "https://item.rakuten.co.jp/\($0)/" }
                        if let urlString, let url = URL(string: urlString) {
                            openURL(url)
                        }
                    }
                }
            }
            .padding(.horizontal)

            Button("やっぱりやめる") {
                onDismiss()
            }
            .font(.headline)
            .foregroundColor(Color(hex: "3498DB"))
            .padding(.bottom, 8)
        }
        .padding(.top, 24)
    }
}

private struct AffiliateLinkButton: View {
    let title: String
    let color: Color
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
            )
        }
    }
}

// MARK: - Preview

#Preview("実データ根拠") {
    NavigationStack {
        ResultView()
    }
}
