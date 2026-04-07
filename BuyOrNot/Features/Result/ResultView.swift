import SwiftUI
import SwiftData
import UserNotifications

struct ResultView: View {
    @StateObject private var viewModel: ResultViewModel
    @State private var showBuyConfirm = false
    @State private var showPaywall = false
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var premiumManager: PremiumManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JudgementHistory.date, order: .reverse) private var history: [JudgementHistory]
    @State private var historyItem: JudgementHistory?
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

                        // リマインダー（プレミアムのみ）
                        if premiumManager.isPremium, let product = viewModel.product {
                            ReminderSection(productName: product.name)
                                .padding(.top, 4)
                        }

                        // 「それでも買う」ボタン
                        BuyAnywayButton(showConfirm: $showBuyConfirm)
                            .padding(.top, 4)

                        // プレミアムCTAバナー（広告が表示された未加入ユーザーにのみ表示）
                        if adWasShown && !premiumManager.isPremium {
                            PremiumCTABanner {
                                showPaywall = true
                            }
                            .padding(.top, 8)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.vertical)
                }
            }
        }
        .task {
            await viewModel.startLoading(
                history: history,
                isPremium: premiumManager.isPremium
            )
        }
        .navigationTitle("イルカソレ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(premiumManager)
        }
        .sheet(isPresented: $showBuyConfirm) {
            BuyConfirmSheet(
                product: viewModel.product,
                onDismiss: { showBuyConfirm = false },
                onDidBuy: {
                    historyItem?.didBuy = true
                }
            )
            .presentationDetents([.medium])
        }
        .onChange(of: viewModel.judgement) { _, judgement in
            guard let judgement, let product = viewModel.product else { return }
            // 二重保存防止: 既に保存済みならフィールドを更新するだけ
            if let existing = historyItem {
                existing.irukaComment = judgement.irukaComment
                existing.stopPointTitles = judgement.stopPoints.map { $0.title }
                return
            }
            let item = JudgementHistory(
                productName: product.name,
                productCategory: product.category,
                estimatedPrice: product.estimatedPrice,
                isVague: product.isVague,
                priceRangeMin: product.priceRangeMin,
                priceRangeMax: product.priceRangeMax,
                irukaComment: judgement.irukaComment,
                stopPointTitles: judgement.stopPoints.map { $0.title }
            )
            modelContext.insert(item)
            historyItem = item
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
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Color(hex: "4A90D9"))
                            Text("広告なしで調べられるのは1日1回までだよ")
                                .font(.caption)
                                .foregroundColor(Color(.secondaryLabel))
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundColor(Color(hex: "F5A623"))
                            Text("プレミアムなら広告なし＋あなたをよく知るイルカになるよ")
                                .font(.caption)
                                .foregroundColor(Color(.secondaryLabel))
                        }
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

// MARK: - Reminder Section

private struct ReminderSection: View {
    let productName: String

    @State private var daysText: String = ""
    @State private var isScheduling = false
    @State private var isScheduled = false
    @State private var showPermissionAlert = false
    @State private var showScheduleErrorAlert = false
    @FocusState private var isFocused: Bool

    private var days: Int? {
        guard let n = Int(daysText), n > 0 else { return nil }
        return n
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 12)

            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(Color(hex: "F39C12"))
                Text("少し時間をあけて考えてみる？")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.label))
                Spacer()
            }
            .padding(.horizontal)

            HStack(spacing: 8) {
                TextField("3", text: $daysText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 64)
                    .focused($isFocused)
                    .disabled(isScheduled)
                    .onChange(of: daysText) { _, new in
                        // 数字以外を除去、3桁まで
                        let filtered = new.filter { $0.isNumber }
                        daysText = String(filtered.prefix(3))
                    }

                Text("日後")
                    .font(.subheadline)
                    .foregroundColor(Color(.label))

                Spacer()

                Button {
                    isFocused = false
                    Task { await schedule() }
                } label: {
                    Group {
                        if isScheduling {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else if isScheduled {
                            Label("リマインド済み", systemImage: "checkmark")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        } else {
                            Text("リマインドする")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isScheduled ? Color(hex: "2ECC71") : Color(hex: "F39C12"))
                    )
                }
                .disabled(days == nil || isScheduling || isScheduled)
                .animation(.easeInOut(duration: 0.2), value: isScheduled)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .alert("通知が許可されていません", isPresented: $showPermissionAlert) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("設定 → 通知 からイルカソレの通知を許可してください")
        }
        .alert("リマインドの設定に失敗しました", isPresented: $showScheduleErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("しばらく時間をおいてからもう一度お試しください")
        }
    }

    private func schedule() async {
        guard let days else { return }
        isScheduling = true
        let success = await ReminderManager.shared.scheduleReminder(
            for: productName,
            afterDays: days
        )
        isScheduling = false
        if success {
            withAnimation { isScheduled = true }
        } else {
            // 通知権限が拒否されている場合のみ設定を促す。それ以外はスケジュール失敗として通知する
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .denied {
                showPermissionAlert = true
            } else {
                showScheduleErrorAlert = true
            }
        }
    }
}

// MARK: - Premium CTA Banner

private struct PremiumCTABanner: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("👑")
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("もっとするどく止めてほしい？")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(.label))
                    Text("広告なし＋あなただけの判定")
                        .font(.caption)
                        .foregroundColor(Color(.secondaryLabel))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "F5A623").opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color(hex: "F5A623").opacity(0.3), lineWidth: 1)
                    )
            )
        }
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
    var onDidBuy: (() -> Void)? = nil
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
                        // ASIN優先で正規URLを構築。amazonURLはホスト検証後のみ使用
                        if let asin = product.amazonASIN {
                            urlString = "https://www.amazon.co.jp/dp/\(asin)"
                        } else if let raw = product.amazonURL,
                                  let host = URL(string: raw)?.host,
                                  host == "amazon.co.jp" || host == "www.amazon.co.jp" {
                            urlString = raw
                        } else {
                            let query = product.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            urlString = "https://www.amazon.co.jp/s?k=\(query)"
                        }
                        if let url = URL(string: urlString) {
                            openURL(url) { accepted in
                                if accepted { onDidBuy?() }
                            }
                        }
                    }

                    AffiliateLinkButton(
                        title: "楽天で探す",
                        color: Color(hex: "BF0000"),
                        icon: "cart.fill"
                    ) {
                        guard let product else { return }
                        let urlString: String
                        // itemCode優先で正規URLを構築。rakutenURLはホスト検証後のみ使用
                        let trustedRakutenHosts = ["item.rakuten.co.jp", "www.rakuten.co.jp", "search.rakuten.co.jp"]
                        if let code = product.rakutenItemCode {
                            urlString = "https://item.rakuten.co.jp/\(code)/"
                        } else if let raw = product.rakutenURL,
                                  let host = URL(string: raw)?.host,
                                  trustedRakutenHosts.contains(host) {
                            urlString = raw
                        } else {
                            let query = product.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            urlString = "https://search.rakuten.co.jp/search/mall/\(query)/"
                        }
                        if let url = URL(string: urlString) {
                            openURL(url) { accepted in
                                if accepted { onDidBuy?() }
                            }
                        }
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
        ResultView(adWasShown: true)
    }
    .environmentObject(NavigationCoordinator())
    .environmentObject(PremiumManager.shared)
    .modelContainer(for: JudgementHistory.self, inMemory: true)
}
