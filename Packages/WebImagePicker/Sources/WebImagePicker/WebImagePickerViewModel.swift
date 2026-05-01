import Foundation
import Observation

@MainActor
@Observable
final class WebImagePickerViewModel {
    var urlString: String = ""
    var discovered: [DiscoveredImage] = []
    var selectedURLs: Set<URL> = []
    var phase: Phase = .urlEntry
    var errorMessage: String?
    var isConfirming: Bool = false

    enum Phase: Equatable {
        case urlEntry
        case loadingPage
        case browsing
    }

    let configuration: WebImagePickerConfiguration
    private let extractor: any PageImageExtractor

    init(configuration: WebImagePickerConfiguration) {
        self.configuration = configuration
        extractor = configuration.extractionMode.makeExtractor()
    }

    func loadPage() async {
        errorMessage = nil
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else {
            errorMessage = "Enter a valid URL."
            return
        }
        guard let scheme = url.scheme?.lowercased(), configuration.allowedURLSchemes.contains(scheme) else {
            errorMessage = "This URL scheme is not allowed."
            return
        }

        phase = .loadingPage
        do {
            let items = try await extractor.discoverImages(from: url, configuration: configuration)
            if items.isEmpty {
                errorMessage = "No images were found on this page."
                phase = .urlEntry
                return
            }
            discovered = items
            selectedURLs = []
            phase = .browsing
        } catch {
            errorMessage = Self.userMessage(for: error)
            phase = .urlEntry
        }
    }

    func toggleSelection(_ item: DiscoveredImage) {
        let url = item.sourceURL
        if selectedURLs.contains(url) {
            selectedURLs.remove(url)
            return
        }
        guard selectedURLs.count < configuration.selectionLimit else { return }
        selectedURLs.insert(url)
    }

    func orderedSelection() -> [URL] {
        discovered.map(\.sourceURL).filter { selectedURLs.contains($0) }
    }

    func beginChangingURL() {
        phase = .urlEntry
        discovered = []
        selectedURLs = []
        errorMessage = nil
    }

    static func userMessage(for error: Error) -> String {
        if let err = error as? WebImagePickerError {
            switch err {
            case .invalidURL:
                return "That URL is not allowed or invalid."
            case .invalidHTTPResponse:
                return "The server did not return the page."
            case .htmlTooLarge:
                return "The page is too large to load safely."
            case .htmlDecodingFailed:
                return "Could not read the page text."
            case .extractionFailed:
                return "Could not read images from this page."
            case .noImagesFound:
                return "No images were found on this page."
            case .imageTooLarge:
                return "An image was too large to download."
            case .downloadFailed:
                return "Could not download an image."
            }
        }
        return "Something went wrong."
    }
}
