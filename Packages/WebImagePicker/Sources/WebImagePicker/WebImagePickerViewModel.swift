import Foundation
import Observation

/// One optional extra URL row in the URL entry form (stable identity for `ForEach`).
struct WebImagePickerExtraPageRow: Identifiable, Equatable, Sendable {
    let id: UUID
    var text: String

    init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }
}

@MainActor
@Observable
final class WebImagePickerViewModel {
    var urlString: String = ""
    var extraPageRows: [WebImagePickerExtraPageRow] = []
    var discovered: [DiscoveredImage] = []
    var selectedURLs: Set<URL> = []
    var phase: Phase = .urlEntry
    var errorMessage: String?
    /// Shown in the browsing grid when at least one page failed but others yielded images.
    var aggregationNotice: String?
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
        applyInitialURLString(from: configuration)
    }

    /// Test hook to inject a mock ``PageImageExtractor``.
    internal init(configuration: WebImagePickerConfiguration, extractorOverride: any PageImageExtractor) {
        self.configuration = configuration
        extractor = extractorOverride
        applyInitialURLString(from: configuration)
    }

    private func applyInitialURLString(from configuration: WebImagePickerConfiguration) {
        if let raw = configuration.initialURLString?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            urlString = raw
        }
    }

    var canStartLoad: Bool {
        if phase == .loadingPage { return false }
        let primary = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty { return true }
        if !configuration.additionalPageURLs.isEmpty { return true }
        return extraPageRows.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func addExtraPageRow() {
        extraPageRows.append(WebImagePickerExtraPageRow())
    }

    func removeExtraPageRows(at offsets: IndexSet) {
        extraPageRows.remove(atOffsets: offsets)
    }

    func loadPage() async {
        aggregationNotice = nil
        guard let pageURLs = resolveOrderedPageURLsOrSetError() else { return }

        phase = .loadingPage
        let merge = await AggregatedPageImageDiscovery.discoverImages(
            pageURLs: pageURLs,
            configuration: configuration,
            extractor: extractor
        )

        if merge.images.isEmpty {
            if merge.failedPageURLs.count == pageURLs.count {
                errorMessage = String(
                    localized: String.LocalizationValue("webimage.error.allPagesFailed"),
                    bundle: WebImagePickerBundle.module
                )
            } else {
                errorMessage = String(
                    localized: String.LocalizationValue("webimage.error.noImagesFound"),
                    bundle: WebImagePickerBundle.module
                )
            }
            phase = .urlEntry
            return
        }

        discovered = merge.images
        selectedURLs = []
        phase = .browsing
        if !merge.failedPageURLs.isEmpty {
            let format = String(
                localized: String.LocalizationValue("webimage.partialPageFailuresFormat"),
                bundle: WebImagePickerBundle.module
            )
            aggregationNotice = String.localizedStringWithFormat(format, merge.failedPageURLs.count)
        }
    }

    /// Builds the ordered, de-duplicated list of page URLs, or sets ``errorMessage`` and returns `nil`.
    private func resolveOrderedPageURLsOrSetError() -> [URL]? {
        errorMessage = nil
        let allowed = Set(configuration.allowedURLSchemes.map { $0.lowercased() })

        var urls: [URL] = []
        var seenPages = Set<String>()

        func appendPage(_ url: URL) {
            guard let scheme = url.scheme?.lowercased(), allowed.contains(scheme) else { return }
            let key = url.absoluteString
            guard !seenPages.contains(key) else { return }
            seenPages.insert(key)
            urls.append(url)
        }

        let trimmedPrimary = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        var primaryResolution: PageURLNormalization.ResolveResult?
        if !trimmedPrimary.isEmpty {
            let resolved = PageURLNormalization.resolve(
                trimmedInput: trimmedPrimary,
                allowedURLSchemes: configuration.allowedURLSchemes
            )
            primaryResolution = resolved
            switch resolved {
            case .success(let u):
                appendPage(u)
            case .disallowedScheme, .invalid:
                break
            }
        }

        for u in configuration.additionalPageURLs {
            appendPage(u)
        }

        for row in extraPageRows {
            let t = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            switch PageURLNormalization.resolve(trimmedInput: t, allowedURLSchemes: configuration.allowedURLSchemes) {
            case .success(let u):
                appendPage(u)
            default:
                break
            }
        }

        if !urls.isEmpty {
            return urls
        }

        if let r = primaryResolution {
            switch r {
            case .disallowedScheme:
                errorMessage = String(
                    localized: String.LocalizationValue("webimage.error.schemeNotAllowed"),
                    bundle: WebImagePickerBundle.module
                )
                return nil
            case .invalid:
                errorMessage = String(
                    localized: String.LocalizationValue("webimage.error.enterValidURL"),
                    bundle: WebImagePickerBundle.module
                )
                return nil
            case .success:
                break
            }
        }

        errorMessage = String(
            localized: String.LocalizationValue("webimage.error.enterValidURL"),
            bundle: WebImagePickerBundle.module
        )
        return nil
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
        aggregationNotice = nil
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
            case .unsupportedImageType:
                return String(
                    localized: String.LocalizationValue("webimage.error.unsupportedImageType"),
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
