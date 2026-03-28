import Foundation
import UIKit

@MainActor
final class ConfirmViewModel: ObservableObject {
    @Published var product: Product
    @Published var capturedImage: UIImage?
    @Published var showRetrySheet = false
    @Published var isRetrying = false
    @Published var errorMessage: String?

    init(product: Product, capturedImage: UIImage? = nil) {
        self.product = product
        self.capturedImage = capturedImage
    }

    func retryWithName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isRetrying = true
        defer { isRetrying = false }
        do {
            product = try await ClaudeService.shared.identifyProduct(name: trimmed)
            showRetrySheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func retryWithURL(_ urlString: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isRetrying = true
        defer { isRetrying = false }
        do {
            product = try await ClaudeService.shared.identifyProduct(url: trimmed)
            showRetrySheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
