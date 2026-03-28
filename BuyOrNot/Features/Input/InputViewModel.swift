import Foundation
@preconcurrency import AVFoundation
import UIKit

@MainActor
final class InputViewModel: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var cameraPermission: AVAuthorizationStatus = .notDetermined
    @Published var detectedBarcode: String?
    @Published var isAnalyzing = false
    @Published var identifiedProduct: Product?
    @Published var capturedImage: UIImage?
    @Published var errorMessage: String?

    // MARK: - Camera Session

    let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.irukasore.camera.session", qos: .userInitiated)
    private let metadataQueue = DispatchQueue(label: "com.irukasore.camera.metadata", qos: .userInitiated)

    // MARK: - Init

    override init() {
        super.init()
        checkPermission()
    }

    // MARK: - Permission

    func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraPermission = status
        switch status {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.cameraPermission = granted ? .authorized : .denied
                    if granted { self?.setupSession() }
                }
            }
        default:
            break
        }
    }

    // MARK: - Session Setup

    private func setupSession() {
        let session = self.session
        let metadataOutput = self.metadataOutput
        let photoOutput = self.photoOutput
        let metadataQueue = self.metadataQueue

        sessionQueue.async { [weak self] in
            guard let self else { return }

            session.beginConfiguration()
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)
                metadataOutput.metadataObjectTypes = [.ean13, .ean8, .code128, .upce, .qr]
            }

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            session.commitConfiguration()
            session.startRunning()
        }
    }

    func stopSession() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    // MARK: - Photo Capture

    func capturePhoto() {
        guard !isAnalyzing else { return }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Analysis

    private func analyzeBarcode(_ barcode: String) {
        guard !isAnalyzing else { return }
        isAnalyzing = true

        Task {
            do {
                identifiedProduct = try await ClaudeService.shared.identifyProduct(barcode: barcode)
            } catch {
                errorMessage = error.localizedDescription
                detectedBarcode = nil
            }
            isAnalyzing = false
        }
    }

    func analyzePhoto(_ image: UIImage) {
        guard !isAnalyzing else { return }
        isAnalyzing = true

        Task {
            do {
                identifiedProduct = try await ClaudeService.shared.identifyProduct(from: image)
            } catch {
                errorMessage = error.localizedDescription
            }
            isAnalyzing = false
        }
    }

    func dismissError() {
        errorMessage = nil
        detectedBarcode = nil
    }
}

// MARK: - Barcode Delegate

extension InputViewModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let barcode = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = barcode.stringValue else { return }

        Task { @MainActor [weak self] in
            guard let self, self.detectedBarcode == nil, !self.isAnalyzing else { return }
            self.detectedBarcode = value
            // 少し間を置いてから解析（検出アニメーションを見せるため）
            try? await Task.sleep(nanoseconds: 400_000_000)
            self.analyzeBarcode(value)
        }
    }
}

// MARK: - Photo Delegate

extension InputViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        Task { @MainActor [weak self] in
            self?.capturedImage = image
            self?.analyzePhoto(image)
        }
    }
}
