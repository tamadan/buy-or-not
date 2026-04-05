import SwiftUI

struct ResultView: View {
    @StateObject private var viewModel: ResultViewModel
    @State private var showBuyConfirm = false
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    let adWasShown: Bool

    init(product: Product? = nil, adWasShown: Bool = false) {
        _viewModel = StateObject(wrappedValue: ResultViewModel(product: product))
        self.adWasShown = adWasShown
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if viewModel.isLoading {
                LoadingView(showAdMessage: adWasShown)
            } else {
                ScrollView {
                    VStack(spacing: 28) {
                        // 商品名
                        if let product = viewModel.product {
                            ProductHeader(product: product)
                        }

                        // 商品説明
                        if let description = viewModel.judgement?.productDescription {
                            ProductDescriptionCard(description: description)
                        }

                        // イルカ + メインコメント
                        if let judgement = viewModel.judgement {
                            IrukaCharacter(
                                mood: .alarmed,
                                comment: judgement.irukaComment
                            )
                            .padding(.top, 8)
                        }

                        // 買わない理由
                        if let judgement = viewModel.judgement {
                            StopPointsSection(stopPoints: judgement.stopPoints)
                        }

                        // 代替提案 & 待て提案
                        if let judgement = viewModel.judgement {
                            SuggestionsSection(judgement: judgement)
                        }

                        // 「買うのをやめる」ボタン
                        Button {
                            navigationCoordinator.dismissToRoot()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                Text("買うのをやめる")
                                    .fontWeight(.bold)
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(hex: "2ECC71"))
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // 「それでも買う」ボタン
                        BuyAnywayButton(showConfirm: $showBuyConfirm)
                            .padding(.top, 4)

                        Spacer(minLength: 40)
                    }
                    .padding(.vertical)
                }
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
        .alert("エラー", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Loading View

private struct LoadingView: View {
    let showAdMessage: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let dotCount = Int(context.date.timeIntervalSinceReferenceDate * 2) % 4
            VStack(spacing: 24) {
                IrukaCharacter(
                    mood: .concerned,
                    comment: "調べています\(String(repeating: ".", count: dotCount))"
                )
                Text("イルカが考えています...")
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel))

                if showAdMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(Color(hex: "4A90D9"))
                        Text("広告なしで調べられるのは1日1回までだよ")
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                    }
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
                }
            }
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

            if product.isVague {
                // ざっくりしか特定できなかった場合
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(Color(hex: "F39C12"))
                        Text("ざっくりしか特定できなかったよ")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color(hex: "F39C12"))
                    }
                    Group {
                        if let min = product.priceRangeMin, let max = product.priceRangeMax {
                            Text("大体 ¥\(min.formatted()) 〜 ¥\(max.formatted()) くらい")
                        } else if let min = product.priceRangeMin {
                            Text("大体 ¥\(min.formatted()) 〜")
                        } else if let max = product.priceRangeMax {
                            Text("〜 ¥\(max.formatted()) くらい")
                        } else {
                            Text("価格不明")
                        }
                    }
                    .font(.title3)
                    .fontWeight(.heavy)
                    .foregroundColor(Color(hex: "E74C3C"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "F39C12").opacity(0.08))
                )
            } else if let price = product.estimatedPrice {
                Text("¥\(price.formatted())")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(Color(hex: "E74C3C"))
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Product Description Card

private struct ProductDescriptionCard: View {
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color(.secondaryLabel))
                Text("商品について")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.secondaryLabel))
            }

            Text(description)
                .font(.subheadline)
                .foregroundColor(Color(.label))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }
}

// MARK: - Stop Points Section

private struct StopPointsSection: View {
    let stopPoints: [StopPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(Color(hex: "E74C3C"))
                Text("買わない理由")
                    .font(.headline)
            }
            .padding(.horizontal)

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
                    .foregroundColor(Color(.label))

                Text(point.detail)
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
    @FocusState private var isReasonFocused: Bool

    @State private var reason: String = ""
    @State private var canPurchase: Bool = false

    private var canSubmitReason: Bool {
        reason.trimmingCharacters(in: .whitespacesAndNewlines).count >= 1
    }

    var body: some View {
        VStack(spacing: 24) {
            IrukaCharacter(
                mood: .pleading,
                comment: canPurchase ? "…後悔しないでね" : "なんで欲しいの？",
                size: 90
            )

            if canPurchase {
                // 理由入力済み → 購入リンクを表示
                VStack(spacing: 4) {
                    Text("「\(reason.trimmingCharacters(in: .whitespacesAndNewlines))」")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(.label))
                        .multilineTextAlignment(.center)
                    Text("…わかった。イルカは止めたからね")
                        .font(.caption)
                        .foregroundColor(Color(.secondaryLabel))
                }
                .padding(.horizontal)

                VStack(spacing: 12) {
                    AffiliateLinkButton(
                        title: "Amazonで探す",
                        color: Color(hex: "FF9900"),
                        icon: "cart.fill"
                    ) {
                        guard let product else { return }
                        let urlString: String
                        if let url = product.amazonURL {
                            urlString = url
                        } else if let asin = product.amazonASIN {
                            urlString = "https://www.amazon.co.jp/dp/\(asin)"
                        } else {
                            let query = product.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            urlString = "https://www.amazon.co.jp/s?k=\(query)"
                        }
                        if let url = URL(string: urlString) { openURL(url) }
                    }

                    AffiliateLinkButton(
                        title: "楽天で探す",
                        color: Color(hex: "BF0000"),
                        icon: "cart.fill"
                    ) {
                        guard let product else { return }
                        let urlString: String
                        if let url = product.rakutenURL {
                            urlString = url
                        } else if let code = product.rakutenItemCode {
                            urlString = "https://item.rakuten.co.jp/\(code)/"
                        } else {
                            let query = product.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            urlString = "https://search.rakuten.co.jp/search/mall/\(query)/"
                        }
                        if let url = URL(string: urlString) { openURL(url) }
                    }
                }
                .padding(.horizontal)

            } else {
                // 理由入力フェーズ
                VStack(spacing: 12) {
                    Text("一言でいいので理由を教えて")
                        .font(.caption)
                        .foregroundColor(Color(.secondaryLabel))

                    TextField("例：仕事で毎日使うから", text: $reason, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .focused($isReasonFocused)
                        .padding(.horizontal)

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            canPurchase = true
                            isReasonFocused = false
                        }
                    } label: {
                        Text("これで買う")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(canSubmitReason ? Color(hex: "E74C3C") : Color(.systemGray4))
                            )
                    }
                    .disabled(!canSubmitReason)
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.2), value: canSubmitReason)
                }
            }

            Button("やっぱりやめる") {
                onDismiss()
            }
            .font(.headline)
            .foregroundColor(Color(hex: "3498DB"))
            .padding(.bottom, 8)
        }
        .padding(.top, 24)
        .onAppear { isReasonFocused = true }
    }
}

private struct AffiliateLinkButton: View {
    let title: String
    let color: Color
    let icon: String
    var disabled: Bool = false
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
        .disabled(disabled)
        .animation(.easeInOut(duration: 0.3), value: disabled)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ResultView()
    }
    .environmentObject(NavigationCoordinator())
}
