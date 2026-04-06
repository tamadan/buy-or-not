import SwiftUI

private let stopBuyingComments: [String] = [
    "えらい！\nその判断、正解だぞ🐬",
    "よく踏みとどまった！\nイルカも誇らしいぞ🐬",
    "その自制心、\nすばらしい！🐬",
    "賢い選択だ！\n財布も喜んでるぞ🐬",
    "衝動買い回避！\n今日もいい仕事したな🐬",
    "お金を守ったね！\nグッジョブ🐬",
]

struct HomeView: View {
    @State private var showTextInput = false
    @State private var showCamera = false
    @State private var isIdentifying = false
    @State private var identifiedProduct: Product?
    @State private var navigateToConfirm = false
    @State private var identifyError: String?
    @State private var stopBuyingComment: String = stopBuyingComments[0]
    @State private var showPaywall = false
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var premiumManager: PremiumManager

    var body: some View {
        ZStack {
            // 背景（ダークモード対応）
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // NOTE: イルカキャラクターの差し替えはここ（IrukaCharacter struct をまるごと置き換え）
                    IrukaCharacter(
                        mood: navigationCoordinator.didStopBuying ? .smug : .greeting,
                        comment: navigationCoordinator.didStopBuying
                            ? stopBuyingComment
                            : "その買い物、\nほんとにいるか？"
                    )
                    .id(navigationCoordinator.didStopBuying)
                    .padding(.top, 32)

                    // タイトル
                    VStack(spacing: 6) {
                        Text("イルカソレ")
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .foregroundColor(Color(.label))
                        Text("買う前にイルカに止めてもらおう")
                            .font(.subheadline)
                            .foregroundColor(Color(.secondaryLabel))
                    }

                    // 使い方
                    HowToSection()
                        .padding(.horizontal)

                    // アクションボタン
                    VStack(spacing: 12) {
                        Button {
                            navigationCoordinator.didStopBuying = false
                            showCamera = true
                        } label: {
                            ActionCard(
                                icon: "camera.fill",
                                title: "撮影して調べる",
                                subtitle: "バーコードや商品を撮影する",
                                color: Color(hex: "4A90D9")
                            )
                        }

                        Button {
                            navigationCoordinator.didStopBuying = false
                            showTextInput = true
                        } label: {
                            ActionCard(
                                icon: "text.magnifyingglass",
                                title: "商品名で調べる",
                                subtitle: "商品名やURLを入力して検索する",
                                color: Color(hex: "9B59B6")
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 48)
                }
            }

            // 商品名識別中オーバーレイ
            if isIdentifying {
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
                    Text("イルカが調べています...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !premiumManager.isPremium {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundColor(Color(hex: "F5A623"))
                            Text("プレミアム")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(hex: "4A90D9"))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color(hex: "4A90D9").opacity(0.1))
                        )
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            NavigationStack {
                InputView()
            }
            .environmentObject(navigationCoordinator)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(premiumManager)
        }
        .sheet(isPresented: $showTextInput) {
            TextInputSheet { input in
                showTextInput = false
                Task {
                    isIdentifying = true
                    do {
                        let product = if input.hasPrefix("http") {
                            try await ClaudeService.shared.identifyProduct(url: input)
                        } else {
                            try await ClaudeService.shared.identifyProduct(name: input)
                        }
                        identifiedProduct = product
                    } catch {
                        identifyError = error.localizedDescription
                    }
                    isIdentifying = false
                }
            }
            .presentationDetents([.height(220)])
        }
        .navigationDestination(isPresented: $navigateToConfirm) {
            if let product = identifiedProduct {
                ConfirmView(
                    product: product,
                    openCamera: {
                        navigateToConfirm = false
                        showCamera = true
                    }
                )
            }
        }
        .onChange(of: identifiedProduct) { _, product in
            if product != nil { navigateToConfirm = true }
        }
        .onChange(of: navigationCoordinator.shouldDismissToRoot) { _, should in
            if should {
                stopBuyingComment = stopBuyingComments.randomElement() ?? stopBuyingComments[0]
                navigateToConfirm = false  // テキスト入力フロー
                showCamera = false          // カメラフロー（fullScreenCover）
                navigationCoordinator.shouldDismissToRoot = false
            }
        }
        .alert("エラー", isPresented: .init(
            get: { identifyError != nil },
            set: { if !$0 { identifyError = nil } }
        )) {
            Button("OK") { identifyError = nil }
        } message: {
            Text(identifyError ?? "")
        }
    }
}

// MARK: - How To Section

private struct HowToSection: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 14) {
                    // ステップ番号
                    ZStack {
                        Circle()
                            .fill(step.color.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundColor(step.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(.label))
                        Text(step.description)
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                    }

                    Spacer()

                    Image(systemName: step.icon)
                        .font(.title3)
                        .foregroundColor(step.color.opacity(0.7))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

                if index < steps.count - 1 {
                    Divider().padding(.leading, 70)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }

    private let steps: [(title: String, description: String, icon: String, color: Color)] = [
        ("撮影 or 入力", "バーコードか商品名で商品を特定", "barcode.viewfinder", Color(hex: "4A90D9")),
        ("商品を確認", "イルカが識別した商品を確認する", "checkmark.circle", Color(hex: "2ECC71")),
        ("やめとけ判定", "イルカが本当に必要か教えてくれる", "hand.raised.fill", Color(hex: "E74C3C")),
    ]
}

// MARK: - Action Card

private struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color(.label))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundColor(Color(.secondaryLabel))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        )
    }
}

// MARK: - Text Input Sheet

fileprivate struct TextInputSheet: View {
    let onSubmit: (String) -> Void
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            Text("商品名またはURLを入力")
                .font(.headline)

            VStack(spacing: 6) {
                TextField("例: SONY WH-1000XM5 または https://...", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(text.hasPrefix("http") ? .URL : .default)
                    .onSubmit { submitIfValid() }

                Text("AmazonやRakutenなどのURLも使えます")
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
            }
            .padding(.horizontal)

            Button {
                submitIfValid()
            } label: {
                Text("調べる")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "4A90D9"))
                    )
            }
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal)

            Spacer()
        }
    }

    private func submitIfValid() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HomeView()
    }
    .environmentObject(NavigationCoordinator())
    .environmentObject(PremiumManager.shared)
}
