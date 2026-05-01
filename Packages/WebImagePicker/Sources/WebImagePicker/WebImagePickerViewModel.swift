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
        if let raw = configuration.initialURLString?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            urlString = raw
        }
    }

    func loadPage() async {
        errorMessage = nil
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolution = PageURLNormalization.resolve(
            trimmedInput: trimmed,
            allowedURLSchemes: configuration.allowedURLSchemes
        )
        let url: URL
        switch resolution {
        case .success(let resolved):
            url = resolved
        case .disallowedScheme:
            errorMessage = String(
                localized: String.LocalizationValue("webimage.error.schemeNotAllowed"),
                bundle: WebImagePickerBundle.module
            )
            return
        case .invalid:
            errorMessage = String(
                localized: String.LocalizationValue("webimage.error.enterValidURL"),
                bundle: WebImagePickerBundle.module
            )
            return
        }

        phase = .loadingPage
        do {
            let items = try await extractor.discoverImages(from: url, configuration: configuration)
            if items.isEmpty {
                errorMessage = String(
                    localized: String.LocalizationValue("webimage.error.noImagesFound"),
                    bundle: WebImagePickerBundle.module
                )
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
                return String(
                    localized: String.LocalizationValue("webimage.error.invalidURL"),
                    bundle: WebImagePickerBundle.module
                )
            case .invalidHTTPResponse:
                return String(
                    localized: String.LocalizationValue("webimage.error.invalidHTTPResponse"),
                    bundle: WebImagePickerBundle.module
                )
            case .htmlTooLarge:
                return String(
                    localized: String.LocalizationValue("webimage.error.htmlTooLarge"),
                    bundle: WebImagePickerBundle.module
                )
            case .htmlDecodingFailed:
                return String(
                    localized: String.LocalizationValue("webimage.error.htmlDecodingFailed"),
                    bundle: WebImagePickerBundle.module
                )
            case .extractionFailed:
                return String(
                    localized: String.LocalizationValue("webimage.error.extractionFailed"),
                    bundle: WebImagePickerBundle.module
                )
            case .noImagesFound:
                return String(
                    localized: String.LocalizationValue("webimage.error.noImagesFound"),
                    bundle: WebImagePickerBundle.module
                )
            case .imageTooLarge:
                return String(
                    localized: String.LocalizationValue("webimage.error.imageTooLarge"),
                    bundle: WebImagePickerBundle.module
                )
            case .downloadFailed:
                return String(
                    localized: String.LocalizationValue("webimage.error.downloadFailed"),
                    bundle: WebImagePickerBundle.module
                )
            }
        }
        return String(
            localized: String.LocalizationValue("webimage.error.generic"),
            bundle: WebImagePickerBundle.module
        )
    }
}
