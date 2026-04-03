import SwiftUI
import AVFoundation
import Photos

struct InputView: View {
    @StateObject private var viewModel = InputViewModel()
    @State private var navigateToResult = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // カメラプレビュー
            if viewModel.cameraPermission == .authorized {
                CameraPreview(session: viewModel.session)
                    .ignoresSafeArea()
            }

            // 権限拒否画面
            if viewModel.cameraPermission == .denied || viewModel.cameraPermission == .restricted {
                CameraPermissionView()
            } else {
                // メインオーバーレイ
                CameraOverlay(viewModel: viewModel)
            }

            // 解析中オーバーレイ
            if viewModel.isAnalyzing {
                AnalyzingOverlay(barcode: viewModel.detectedBarcode)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isAnalyzing)
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToResult) {
            if let product = viewModel.identifiedProduct {
                ConfirmView(product: product, capturedImage: viewModel.capturedImage)
            }
        }
        .onChange(of: viewModel.identifiedProduct) { _, product in
            if product != nil { navigateToResult = true }
        }
        .alert("エラー", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            viewModel.restartSessionIfNeeded()
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }
}

// MARK: - Camera Overlay

private struct CameraOverlay: View {
    @ObservedObject var viewModel: InputViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPhotoPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // 上部グラデーション + タイトル + 戻るボタン
            LinearGradient(
                colors: [.black.opacity(0.6), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .overlay(alignment: .topLeading) {
                Button {
                    viewModel.stopSession()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                        Text("戻る")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .padding(.top, 52)
            }
            .overlay(alignment: .bottom) {
                Text("イルカソレ")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 16)
            }

            Spacer()

            // スキャンフレーム + ヒント
            VStack(spacing: 20) {
                ScanFrame(isDetected: viewModel.detectedBarcode != nil)
                    .frame(width: 280, height: 160)

                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.subheadline)
                        Text("バーコードがあれば枠内に写してください")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white)

                    Text("または下のボタンで商品を撮影")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                }
            }

            Spacer()

            // 下部グラデーション + シャッターボタン + ライブラリボタン
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)
            .overlay(alignment: .center) {
                HStack(spacing: 0) {
                    // フォトライブラリボタン
                    Button {
                        showPhotoPicker = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                                .foregroundColor(.white)
                            Text("ライブラリ")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(width: 80)
                    }
                    .disabled(viewModel.isAnalyzing)

                    ShutterButton {
                        viewModel.capturePhoto()
                    }
                    .disabled(viewModel.isAnalyzing)
                    .frame(width: 80)

                    // バランス用スペーサー
                    Spacer()
                        .frame(width: 80)
                }
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker { image in
                viewModel.stopSession()
                viewModel.capturedImage = image
                viewModel.analyzePhoto(image)
            }
        }
    }
}

// MARK: - Scan Frame

private struct ScanFrame: View {
    let isDetected: Bool
    private let cornerLength: CGFloat = 24
    private let lineWidth: CGFloat = 3

    var frameColor: Color {
        isDetected ? Color(hex: "2ECC71") : .white
    }

    var body: some View {
        ZStack {
            // 半透明内側
            RoundedRectangle(cornerRadius: 4)
                .fill(.white.opacity(0.06))

            // 四隅のコーナーマーカー
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    // 左上
                    CornerMark(rotation: 0)
                        .position(x: cornerLength / 2, y: cornerLength / 2)
                    // 右上
                    CornerMark(rotation: 90)
                        .position(x: w - cornerLength / 2, y: cornerLength / 2)
                    // 右下
                    CornerMark(rotation: 180)
                        .position(x: w - cornerLength / 2, y: h - cornerLength / 2)
                    // 左下
                    CornerMark(rotation: 270)
                        .position(x: cornerLength / 2, y: h - cornerLength / 2)
                }
            }
            .foregroundColor(frameColor)
        }
        .animation(.easeInOut(duration: 0.25), value: isDetected)
    }

    private struct CornerMark: View {
        let rotation: Double
        private let length: CGFloat = 24
        private let width: CGFloat = 3

        var body: some View {
            ZStack {
                Rectangle()
                    .frame(width: length, height: width)
                    .offset(x: length / 2 - width / 2)
                Rectangle()
                    .frame(width: width, height: length)
                    .offset(y: length / 2 - width / 2)
            }
            .frame(width: length, height: length)
            .rotationEffect(.degrees(rotation))
        }
    }
}

// MARK: - Shutter Button

private struct ShutterButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.5), lineWidth: 4)
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(.white)
                    .frame(width: 66, height: 66)
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Analyzing Overlay

private struct AnalyzingOverlay: View {
    let barcode: String?
    @State private var dotCount = 0
    @State private var loadingTimer: Timer?

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            VStack(spacing: 24) {
                // イルカ風ローディング
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "69B4E8"), Color(hex: "4A90D9")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                }

                VStack(spacing: 8) {
                    Text("イルカが調べています\(String(repeating: ".", count: dotCount))")
                        .font(.headline)
                        .foregroundColor(.white)
                        .animation(nil, value: dotCount)

                    if let barcode {
                        HStack(spacing: 4) {
                            Image(systemName: "barcode")
                                .font(.caption)
                            Text(barcode)
                                .font(.caption)
                                .fontDesign(.monospaced)
                        }
                        .foregroundColor(.white.opacity(0.55))
                    }
                }
            }
        }
        .onAppear {
            let timer = Timer(timeInterval: 0.5, repeats: true) { _ in
                dotCount = (dotCount + 1) % 4
            }
            // .common モードで登録することでスクロール中でも止まらずに動作する
            RunLoop.main.add(timer, forMode: .common)
            loadingTimer = timer
        }
        .onDisappear {
            loadingTimer?.invalidate()
            loadingTimer = nil
        }
    }
}

// MARK: - Camera Permission View

private struct CameraPermissionView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text("カメラへのアクセスが必要です")
                .font(.headline)

            Text("設定アプリから「イルカソレ」のカメラアクセスを許可してください")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Photo Picker（カスタムグリッド + 選択確認ボタン）

private struct PhotoPicker: View {
    let onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var assets: [PHAsset] = []
    @State private var selectedID: String? = nil
    @State private var isLoading = false       // 選択した写真の高解像度読み込み中
    @State private var isPhotosLoading = true  // 写真一覧の初期読み込み中
    @State private var showPermissionAlert = false
    @State private var showImageLoadError = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    private let imageManager = PHCachingImageManager()

    var body: some View {
        NavigationStack {
            Group {
                if isPhotosLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if assets.isEmpty {
                    Text("写真が見つかりませんでした")
                        .foregroundColor(Color(.secondaryLabel))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(assets, id: \.localIdentifier) { asset in
                                PhotoCell(
                                    asset: asset,
                                    isSelected: selectedID == asset.localIdentifier,
                                    imageManager: imageManager
                                )
                                .onTapGesture {
                                    selectedID = asset.localIdentifier
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("写真を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("選択") {
                        guard let id = selectedID,
                              let asset = assets.first(where: { $0.localIdentifier == id }) else { return }
                        isLoading = true
                        let options = PHImageRequestOptions()
                        options.deliveryMode = .highQualityFormat
                        options.isNetworkAccessAllowed = true
                        imageManager.requestImage(
                            for: asset,
                            targetSize: PHImageManagerMaximumSize,
                            contentMode: .aspectFit,
                            options: options
                        ) { image, info in
                            // 低画質の中間コールバックはスキップ
                            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                            guard !isDegraded else { return }
                            DispatchQueue.main.async {
                                isLoading = false
                                if let image {
                                    onPick(image)
                                    dismiss()
                                } else {
                                    // 画像の読み込みに失敗した場合はエラー表示（dismiss しない）
                                    showImageLoadError = true
                                }
                            }
                        }
                    }
                    .disabled(selectedID == nil || isLoading)
                    .fontWeight(.bold)
                }
            }
            .onAppear { loadAssets() }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView().tint(.white)
                }
            }
            .alert("写真の読み込みに失敗しました", isPresented: $showImageLoadError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("別の写真を選んでもう一度お試しください")
            }
            .alert("写真へのアクセスが必要です", isPresented: $showPermissionAlert) {
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("キャンセル", role: .cancel) { dismiss() }
            } message: {
                Text("設定アプリから「イルカソレ」の写真アクセスを許可してください")
            }
        }
    }

    private func loadAssets() {
        // PHAccessLevel は .addOnly / .readWrite のみ存在（.readOnly は無効）
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            fetchAssets()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        fetchAssets()
                    } else {
                        isPhotosLoading = false
                        showPermissionAlert = true
                    }
                }
            }
        default:
            // denied / restricted: アラートで設定への誘導
            DispatchQueue.main.async {
                isPhotosLoading = false
                showPermissionAlert = true
            }
        }
    }

    private func fetchAssets() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 500 // 最新500件に制限してメモリ圧迫を防ぐ
        let results = PHAsset.fetchAssets(with: .image, options: options)
        var loaded: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in loaded.append(asset) }
        assets = loaded
        isPhotosLoading = false
    }
}

private struct PhotoCell: View {
    let asset: PHAsset
    let isSelected: Bool
    let imageManager: PHCachingImageManager
    @State private var thumbnail: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                Group {
                    if let thumb = thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(.systemGray5)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width)
                .clipped()

                // チェックマーク
                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "4A90D9"))
                            .frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(5)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(hex: "4A90D9"), lineWidth: isSelected ? 3 : 0)
            )
            .onAppear {
                let size = CGSize(width: geo.size.width * 2, height: geo.size.width * 2)
                requestID = imageManager.requestImage(
                    for: asset,
                    targetSize: size,
                    contentMode: .aspectFill,
                    options: nil
                ) { image, _ in
                    DispatchQueue.main.async { thumbnail = image }
                }
            }
            .onDisappear {
                if let id = requestID {
                    imageManager.cancelImageRequest(id)
                    requestID = nil
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InputView()
    }
}
