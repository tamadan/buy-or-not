import SwiftUI
import StoreKit

// MARK: - PaywallView

struct PaywallView: View {
    @EnvironmentObject private var premiumManager: PremiumManager
    @Environment(\.dismiss) private var dismiss

    @State private var errorMessage: String?
    @State private var showError = false

    // MARK: Body

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // ヘッダー
                    headerSection
                        .padding(.top, 32)

                    // 機能一覧
                    featuresSection
                        .padding(.top, 32)
                        .padding(.horizontal)

                    // 購入ボタン
                    purchaseSection
                        .padding(.top, 32)
                        .padding(.horizontal)
                        .padding(.bottom, 48)
                }
            }

            // 閉じるボタン
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(.secondaryLabel))
                            .padding(16)
                    }
                    .accessibilityLabel("閉じる")
                }
                Spacer()
            }
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            // イルカ + 王冠
            ZStack(alignment: .topTrailing) {
                Text("🐬")
                    .font(.system(size: 72))
                Text("👑")
                    .font(.system(size: 32))
                    .offset(x: 8, y: -8)
            }

            Text("イルカソレ プレミアム")
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(Color(.label))

            Text("広告なしで、あなたをよく知るイルカに")
                .font(.subheadline)
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
    }

    private var featuresSection: some View {
        VStack(spacing: 0) {
            ForEach(PremiumFeature.all) { feature in
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(feature.color.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: feature.icon)
                            .font(.body)
                            .foregroundColor(feature.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(.label))
                        Text(feature.description)
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "2ECC71"))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)

                if feature.id != PremiumFeature.all.last?.id {
                    Divider().padding(.leading, 76)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            // 購入ボタン
            Button {
                Task { await doPurchase() }
            } label: {
                ZStack {
                    if premiumManager.isLoading || premiumManager.isLoadingProduct {
                        ProgressView().tint(.white)
                    } else {
                        Text("\(premiumManager.formattedPrice) で始める")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "4A90D9"), Color(hex: "2C5F8A")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color(hex: "4A90D9").opacity(0.4), radius: 8, y: 4)
            }
            .disabled(premiumManager.isLoading || premiumManager.isLoadingProduct)

            // プロダクト取得失敗時のリトライ
            if !premiumManager.isLoadingProduct && premiumManager.product == nil {
                Button {
                    Task { await premiumManager.loadProduct() }
                } label: {
                    Label("再読み込み", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(Color(hex: "4A90D9"))
                }
            }

            // 復元ボタン
            Button {
                Task { await doRestore() }
            } label: {
                Text("購入を復元する")
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel))
            }
            .disabled(premiumManager.isLoading || premiumManager.isLoadingProduct)

            // 注記
            Text("いつでもキャンセル可能。\nキャンセルしない限り自動更新されます。")
                .font(.caption2)
                .foregroundColor(Color(.tertiaryLabel))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    // MARK: - Actions

    private func doPurchase() async {
        do {
            try await premiumManager.purchase()
            if premiumManager.isPremium { dismiss() }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func doRestore() async {
        do {
            try await premiumManager.restore()
            if premiumManager.isPremium { dismiss() }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Premium Feature Model

private struct PremiumFeature: Identifiable {
    let id: String
    let icon: String
    let title: String
    let description: String
    let color: Color

    static let all: [PremiumFeature] = [
        PremiumFeature(
            id: "ad",
            icon: "hand.raised.slash.fill",
            title: "広告を完全削除",
            description: "判定のたびに表示される広告が完全になくなります",
            color: Color(hex: "E74C3C")
        ),
        PremiumFeature(
            id: "personalize",
            icon: "brain.head.profile",
            title: "あなた専用の判定",
            description: "同じカテゴリを何度もチェックする癖など、あなたのパターンを踏まえてよりするどく止めます",
            color: Color(hex: "9B59B6")
        ),
        PremiumFeature(
            id: "reminder",
            icon: "bell.badge.fill",
            title: "リマインダー機能",
            description: "「3日後も欲しければ買えばいい」を通知でサポート",
            color: Color(hex: "F39C12")
        ),
        PremiumFeature(
            id: "widget",
            icon: "rectangle.stack.fill",
            title: "ホーム画面ウィジェット",
            description: "今月守った金額をホーム画面でいつでも確認",
            color: Color(hex: "2ECC71")
        ),
    ]
}

// MARK: - Preview

#Preview {
    PaywallView()
        .environmentObject(PremiumManager.shared)
}
