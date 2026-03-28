import SwiftUI
import AVFoundation
import PhotosUI

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
            .ignoresSafeArea()
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
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                dotCount = (dotCount + 1) % 4
            }
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

// MARK: - Photo Picker

private struct PhotoPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage) -> Void
        init(onPick: @escaping (UIImage) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async { self?.onPick(image) }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InputView()
    }
}
