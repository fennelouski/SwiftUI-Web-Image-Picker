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
    /// Filters the browsing grid by alt text, optional `title`, and URL (case-insensitive substring).
    var imageMetadataSearchQuery: String = ""
    var selectedURLs: Set<URL> = []
    var phase: Phase = .urlEntry
    var errorMessage: String?
    /// Shown in the browsing grid when at least one page failed but others yielded images.
    var aggregationNotice: String?
    /// Shown when discovery skipped HTTP image URLs because `http` is not in ``WebImagePickerConfiguration/allowedURLSchemes``.
    var httpSkippedImagesNotice: String?
    var isConfirming: Bool = false

    /// Recognized in-image text per ``DiscoveredImage/sourceURL`` when ``WebImagePickerConfiguration/isImageTextSearchEnabled`` is `true`. Filled asynchronously after load.
    internal private(set) var imageRecognizedTextByURL: [URL: String] = [:]

    enum Phase: Equatable {
        case urlEntry
        case loadingPage
        case browsing
    }

    let configuration: WebImagePickerConfiguration
    private let extractor: any PageImageExtractor
    private let discoveryListCache: DiscoveredImageListCache?
    private var imageTextSearchTask: Task<Void, Never>?

    init(configuration: WebImagePickerConfiguration) {
        self.configuration = configuration
        extractor = configuration.extractionMode.makeExtractor()
        discoveryListCache = DiscoveredImageListCache.makeIfEnabled(for: configuration.cachePolicy)
        applyInitialURLString(from: configuration)
    }

    /// Test hook to inject a mock ``PageImageExtractor``.
    internal init(configuration: WebImagePickerConfiguration, extractorOverride: any PageImageExtractor) {
        self.configuration = configuration
        extractor = extractorOverride
        discoveryListCache = DiscoveredImageListCache.makeIfEnabled(for: configuration.cachePolicy)
        applyInitialURLString(from: configuration)
    }

    private func applyInitialURLString(from configuration: WebImagePickerConfiguration) {
        if let raw = configuration.initialURLString?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            urlString = raw
        }
    }

    /// Images shown in the grid after applying ``imageMetadataSearchQuery``.
    var discoveredForDisplay: [DiscoveredImage] {
        let ocr = configuration.isImageTextSearchEnabled ? imageRecognizedTextByURL : nil
        let eligible = DiscoveredImageMetadataExclusion.filter(
            discovered,
            configuration: configuration,
            recognizedTextByURL: ocr
        )
        return DiscoveredImageMetadataSearch.filteredDiscoveries(
            eligible,
            rawQuery: imageMetadataSearchQuery,
            configuration: configuration,
            recognizedTextByURL: ocr
        )
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
        httpSkippedImagesNotice = nil
        guard let pageURLs = resolveOrderedPageURLsOrSetError() else { return }

        phase = .loadingPage
        let merge = await AggregatedPageImageDiscovery.discoverImages(
            pageURLs: pageURLs,
            configuration: configuration,
            extractor: extractor,
            discoveryListCache: discoveryListCache
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
        imageMetadataSearchQuery = ""
        selectedURLs = []
        phase = .browsing
        scheduleImageTextSearchIfNeeded()
        if !merge.failedPageURLs.isEmpty {
            let format = String(
                localized: String.LocalizationValue("webimage.partialPageFailuresFormat"),
                bundle: WebImagePickerBundle.module
            )
            aggregationNotice = String.localizedStringWithFormat(format, merge.failedPageURLs.count)
        }
        if merge.skippedHTTPImageURLsDueToAllowedSchemes > 0 {
            let format = String(
                localized: String.LocalizationValue("webimage.skippedHTTPImagesNoticeFormat"),
                bundle: WebImagePickerBundle.module
            )
            httpSkippedImagesNotice = String.localizedStringWithFormat(
                format,
                merge.skippedHTTPImageURLsDueToAllowedSchemes
            )
        }
    }

    private enum ResolveFailureRank: Int, Comparable {
        case invalid = 1
        case disallowedNonHTTP = 2
        case disallowedHTTP = 3

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// Builds the ordered, de-duplicated list of page URLs, or sets ``errorMessage`` and returns `nil`.
    private func resolveOrderedPageURLsOrSetError() -> [URL]? {
        errorMessage = nil
        let allowed = Set(configuration.allowedURLSchemes.map { $0.lowercased() })

        var urls: [URL] = []
        var seenPages = Set<String>()
        var worstFailure: (rank: ResolveFailureRank, sampleInput: String)?

        func recordFailure(trimmedInput: String, result: PageURLNormalization.ResolveResult) {
            let trimmed = trimmedInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let rank: ResolveFailureRank
            switch result {
            case .success: return
            case .invalid:
                rank = .invalid
            case .disallowedScheme:
                if PageURLNormalization.isHTTPExplicitlyDisallowed(
                    trimmedInput: trimmed,
                    allowedURLSchemes: configuration.allowedURLSchemes
                ) {
                    rank = .disallowedHTTP
                } else {
                    rank = .disallowedNonHTTP
                }
            }
            if worstFailure == nil || rank > worstFailure!.rank {
                worstFailure = (rank, trimmed)
            }
        }

        func appendPage(_ url: URL) {
            guard let scheme = url.scheme?.lowercased(), allowed.contains(scheme) else { return }
            let key = url.absoluteString
            guard !seenPages.contains(key) else { return }
            seenPages.insert(key)
            urls.append(url)
        }

        let trimmedPrimary = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrimary.isEmpty {
            let resolved = PageURLNormalization.resolve(
                trimmedInput: trimmedPrimary,
                allowedURLSchemes: configuration.allowedURLSchemes
            )
            switch resolved {
            case .success(let u):
                appendPage(u)
            case .invalid, .disallowedScheme:
                recordFailure(trimmedInput: trimmedPrimary, result: resolved)
            }
        }

        for u in configuration.additionalPageURLs {
            appendPage(u)
        }

        for row in extraPageRows {
            let t = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            let resolved = PageURLNormalization.resolve(trimmedInput: t, allowedURLSchemes: configuration.allowedURLSchemes)
            switch resolved {
            case .success(let u):
                appendPage(u)
            case .invalid, .disallowedScheme:
                recordFailure(trimmedInput: t, result: resolved)
            }
        }

        if !urls.isEmpty {
            return urls
        }

        if let failure = worstFailure {
            switch failure.rank {
            case .invalid:
                errorMessage = String(
                    localized: String.LocalizationValue("webimage.error.enterValidURL"),
                    bundle: WebImagePickerBundle.module
                )
            case .disallowedNonHTTP:
                errorMessage = String(
                    localized: String.LocalizationValue("webimage.error.schemeNotAllowed"),
                    bundle: WebImagePickerBundle.module
                )
            case .disallowedHTTP:
                errorMessage = String(
                    localized: String.LocalizationValue("webimage.error.httpNotAllowed"),
                    bundle: WebImagePickerBundle.module
                )
            }
            return nil
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
        cancelImageTextSearchTask()
        discoveryListCache?.clear()
        imageRecognizedTextByURL = [:]
        phase = .urlEntry
        discovered = []
        imageMetadataSearchQuery = ""
        selectedURLs = []
        errorMessage = nil
        aggregationNotice = nil
        httpSkippedImagesNotice = nil
    }

    private func cancelImageTextSearchTask() {
        imageTextSearchTask?.cancel()
        imageTextSearchTask = nil
    }

    private func scheduleImageTextSearchIfNeeded() {
        cancelImageTextSearchTask()
        imageRecognizedTextByURL = [:]
        guard configuration.isImageTextSearchEnabled else { return }
        let limit = configuration.maximumImageTextSearchImages
        guard limit > 0 else { return }
        let urls = Array(discovered.prefix(limit).map(\.sourceURL))
        let cfg = configuration
        imageTextSearchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let index = await DiscoveredImageTextRecognition.buildIndex(urls: urls, configuration: cfg)
            guard !Task.isCancelled else { return }
            self.imageRecognizedTextByURL = index
        }
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
            case .imageDecodeFailed:
                return String(
                    localized: String.LocalizationValue("webimage.error.imageDecodeFailed"),
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
