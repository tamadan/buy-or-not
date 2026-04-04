import SwiftUI

struct ConfirmView: View {
    @StateObject private var viewModel: ConfirmViewModel
    @State private var navigateToResult = false
    @State private var isShowingAd = false
    @State private var adWasShown = false
    @Environment(\.dismiss) private var dismiss

    var openCamera: (() -> Void)? = nil

    init(product: Product, capturedImage: UIImage? = nil, openCamera: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ConfirmViewModel(product: product, capturedImage: capturedImage))
        self.openCamera = openCamera
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    IrukaCharacter(mood: .concerned, comment: "この商品で合ってる？")
                        .padding(.top, 8)

                    // 商品確認カード
                    ProductConfirmCard(
                        product: viewModel.product,
                        image: viewModel.capturedImage
                    )

                    // ボタン
                    VStack(spacing: 12) {
                        Button {
                            // 日付リセットを先に実行してから shouldShowAd を評価
                            AdManager.shared.ensureDailyReset()
                            if AdManager.shared.shouldShowAd {
                                isShowingAd = true
                                AdManager.shared.showAdIfNeeded { wasShown in
                                    // 広告表示後にのみカウントを増やす
                                    AdManager.shared.incrementCount()
                                    isShowingAd = false
                                    adWasShown = wasShown  // 実際に広告が表示された場合のみ true
                                    navigateToResult = true
                                }
                            } else {
                                // 広告不要時は即カウントアップして遷移
                                AdManager.shared.incrementCount()
                                adWasShown = false
                                navigateToResult = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("これで調べる")
                                    .fontWeight(.bold)
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(hex: "4A90D9"))
                            )
                        }
                        .disabled(isShowingAd)

                        Button {
                            viewModel.showRetrySheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("違う、やり直す")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }

            // やり直し中オーバーレイ
            if viewModel.isRetrying {
                Color.black.opacity(0.5).ignoresSafeArea()
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "69B4E8"), Color(hex: "4A90D9")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                        ProgressView().tint(.white).scaleEffect(1.2)
                    }
                    Text("再検索中...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .navigationTitle("商品の確認")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToResult) {
            ResultView(product: viewModel.product, adWasShown: adWasShown)
        }
        .sheet(isPresented: $viewModel.showRetrySheet) {
            RetrySheet(
                viewModel: viewModel,
                showRetakeOption: true,
                onRetakePhoto: {
                    viewModel.showRetrySheet = false
                    if let openCamera {
                        // テキスト入力フロー: dismissしてからカメラを開く
                        dismiss()
                        openCamera()
                    } else {
                        // カメラフロー: InputViewに戻る
                        dismiss()
                    }
                }
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

// MARK: - Product Confirm Card

private struct ProductConfirmCard: View {
    let product: Product
    let image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 撮影写真（あれば）
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 商品情報
            VStack(alignment: .leading, spacing: 8) {
                if let category = product.category {
                    Text(category)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color(.secondaryLabel))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(.systemGray6)))
                }

                Text(product.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Color(.label))

                if product.isVague {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(Color(hex: "F39C12"))
                        if let min = product.priceRangeMin, let max = product.priceRangeMax {
                            Text("大体 ¥\(min.formatted()) 〜 ¥\(max.formatted()) くらい")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(hex: "E74C3C"))
                        }
                    }
                } else if let price = product.estimatedPrice {
                    Text("推定 ¥\(price.formatted())")
                        .font(.headline)
                        .foregroundColor(Color(hex: "E74C3C"))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
        .padding(.horizontal)
    }
}

// MARK: - Retry Sheet

private struct RetrySheet: View {
    @ObservedObject var viewModel: ConfirmViewModel
    let showRetakeOption: Bool
    let onRetakePhoto: () -> Void
    @State private var showInput = false
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            Text("どうやってやり直す？")
                .font(.headline)
                .foregroundColor(Color(.label))

            if !showInput {
                VStack(spacing: 12) {
                    RetryOptionButton(
                        icon: "camera.fill",
                        title: "写真を撮り直す",
                        subtitle: "カメラ画面に戻って撮り直す",
                        color: Color(hex: "27AE60")
                    ) { onRetakePhoto() }

                    RetryOptionButton(
                        icon: "magnifyingglass",
                        title: "商品名またはURLで検索",
                        subtitle: "商品名かAmazon・RakutenのURLを入力",
                        color: Color(hex: "4A90D9")
                    ) { showInput = true }
                }
                .padding(.horizontal)
            } else {
                let trimmed = inputText.trimmingCharacters(in: .whitespaces)
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        TextField("例: SONY WH-1000XM5 または https://...", text: $inputText)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(trimmed.hasPrefix("http") ? .URL : .default)
                            .focused($isInputFocused)

                        Text("URLも使えます（Amazon、Rakutenなど）")
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                    }
                    .padding(.horizontal)

                    Button {
                        Task {
                            if trimmed.hasPrefix("http") {
                                await viewModel.retryWithURL(trimmed)
                            } else {
                                await viewModel.retryWithName(trimmed)
                            }
                        }
                    } label: {
                        Text("再検索する")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "4A90D9"))
                            )
                    }
                    .disabled(trimmed.isEmpty || viewModel.isRetrying)
                    .padding(.horizontal)

                    RetryOptionButton(
                        icon: "camera.fill",
                        title: "写真を撮り直す",
                        subtitle: "カメラ画面に戻って撮り直す",
                        color: Color(hex: "27AE60")
                    ) { onRetakePhoto() }
                    .padding(.horizontal)

                    Button {
                        showInput = false
                        inputText = ""
                        isInputFocused = false
                    } label: {
                        Text("戻る")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .onAppear { isInputFocused = true }
            }

            Spacer()
        }
    }
}

// MARK: - Retry Option Button

private struct RetryOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(.label))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color(.secondaryLabel))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ConfirmView(
            product: Product(
                name: "SONY WH-1000XM5",
                category: "ヘッドホン",
                estimatedPrice: 44800
            )
        )
    }
}
