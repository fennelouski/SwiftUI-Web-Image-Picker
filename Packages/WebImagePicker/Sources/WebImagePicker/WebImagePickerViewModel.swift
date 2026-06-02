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
    /// Shown after a successful smart URL fallback (e.g. loaded `google.com` instead of `google.c`).
    var urlCorrectionNotice: String?
    var isConfirming: Bool = false
    /// Page URLs that were successfully loaded in the most recent ``loadPage()`` call.
    var loadedPageURLs: [URL] = []

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

    // MARK: - WiFi prefetch state

    private let wifiMonitor = WiFiMonitor()
    private var prefetchTask: Task<Void, Never>?
    private var prefetchedResult: AggregatedPageImageDiscovery.MergeResult?
    private var prefetchedPageURLs: [URL]?
    private var lastPrefetchStartTime: Date?

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

    /// The primary host used for favicon display.
    var primaryHost: String? {
        loadedPageURLs.first?.host
    }

    /// Favicon URL derived from the first loaded page.
    var faviconURL: URL? {
        guard let host = primaryHost else { return nil }
        return URL(string: "https://\(host)/favicon.ico")
    }

    /// Display string for the source page URL(s) shown below the search bar.
    var sourceURLDisplayString: String? {
        guard !loadedPageURLs.isEmpty else { return nil }
        if loadedPageURLs.count == 1, let url = loadedPageURLs.first {
            var display = url.host ?? url.absoluteString
            if let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path,
               path != "/", !path.isEmpty {
                display += path
            }
            return display
        }
        return loadedPageURLs.compactMap(\.host).joined(separator: ", ")
    }

    var canStartLoad: Bool {
        if phase == .loadingPage { return false }
        let primary = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty { return true }
        guard configuration.isMultiplePageEntryEnabled else { return false }
        if !configuration.additionalPageURLs.isEmpty { return true }
        return extraPageRows.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func addExtraPageRow() {
        guard configuration.isMultiplePageEntryEnabled else { return }
        extraPageRows.append(WebImagePickerExtraPageRow())
    }

    func removeExtraPageRows(at offsets: IndexSet) {
        extraPageRows.remove(atOffsets: offsets)
    }

    func loadPage() async {
        aggregationNotice = nil
        httpSkippedImagesNotice = nil
        urlCorrectionNotice = nil
        errorMessage = nil

        let batch = buildPageURLBatchResolution()
        phase = .loadingPage

        var triedURLs = Set<String>()
        var merge: AggregatedPageImageDiscovery.MergeResult?
        var loadedURLs: [URL] = []

        if batch.entries.isEmpty {
            if let fallback = await attemptSmartURLFallback(
                failedEntries: [],
                triedURLs: &triedURLs
            ) {
                applyBrowsingSuccess(
                    merge: fallback.merge,
                    loadedPageURLs: fallback.loadedPageURLs,
                    urlCorrection: fallback.urlCorrection
                )
                return
            }
            applyResolveFailureMessage(worstFailure: batch.worstFailure)
            phase = .urlEntry
            return
        }

        triedURLs = Set(batch.urls.map(\.absoluteString))
        merge = await discoverImages(for: batch.urls)
        loadedURLs = batch.urls

        if merge!.images.isEmpty {
            if let fallback = await attemptSmartURLFallback(
                failedEntries: batch.entries,
                triedURLs: &triedURLs
            ) {
                applyBrowsingSuccess(
                    merge: fallback.merge,
                    loadedPageURLs: fallback.loadedPageURLs,
                    urlCorrection: fallback.urlCorrection
                )
                return
            }
            applyEmptyMergeError(merge: merge!, pageCount: batch.urls.count)
            phase = .urlEntry
            return
        }

        var finalMerge = merge!
        var finalLoaded = loadedURLs
        let failedSet = Set(finalMerge.failedPageURLs)

        var correctionNotice: String?
        var finalFailedPageCount = finalMerge.failedPageURLs.count
        if !failedSet.isEmpty,
           configuration.isSmartURLFallbackEnabled,
           let supplemental = await attemptSmartURLFallback(
               failedEntries: batch.entries.filter { failedSet.contains($0.url) },
               triedURLs: &triedURLs
           ) {
            finalMerge = mergePartialRecovery(
                existing: finalMerge,
                supplemental: supplemental.merge,
                recoveredPageURLs: supplemental.loadedPageURLs
            )
            finalLoaded = batch.urls.filter { !failedSet.contains($0) } + supplemental.loadedPageURLs
            correctionNotice = supplemental.urlCorrection
            finalFailedPageCount = max(0, finalFailedPageCount - supplemental.recoveredFailedPageCount)
        }

        applyBrowsingSuccess(
            merge: finalMerge,
            loadedPageURLs: finalLoaded,
            failedPageCount: finalFailedPageCount,
            urlCorrection: correctionNotice
        )
    }

    private struct ResolvedPageEntry {
        enum Source: Hashable {
            case primaryField
            case extraRow(UUID)
            case configurationAdditional
        }

        let url: URL
        let source: Source
        /// Present for user-typed primary and extra-row fields.
        let originalUserText: String?
    }

    private struct PageURLBatchResolution {
        let entries: [ResolvedPageEntry]
        let worstFailure: (rank: WebImagePickerViewModel.ResolveFailureRank, sampleInput: String)?

        var urls: [URL] { entries.map(\.url) }
    }

    private struct SmartURLFallbackResult {
        let merge: AggregatedPageImageDiscovery.MergeResult
        let loadedPageURLs: [URL]
        let urlCorrection: String?
        let recoveredFailedPageCount: Int
    }

    private func applyBrowsingSuccess(
        merge: AggregatedPageImageDiscovery.MergeResult,
        loadedPageURLs: [URL],
        failedPageCount: Int = 0,
        urlCorrection: String? = nil
    ) {
        discovered = merge.images
        imageMetadataSearchQuery = ""
        selectedURLs = []
        self.loadedPageURLs = loadedPageURLs
        phase = .browsing
        urlCorrectionNotice = urlCorrection
        scheduleImageTextSearchIfNeeded()

        if failedPageCount > 0 {
            let format = String(
                localized: String.LocalizationValue("webimage.partialPageFailuresFormat"),
                bundle: WebImagePickerBundle.module
            )
            aggregationNotice = String.localizedStringWithFormat(format, failedPageCount)
        }

        if merge.skippedHTTPImageURLsDueToAllowedSchemes > 0 {
            applyHTTPSkippedNotice(count: merge.skippedHTTPImageURLsDueToAllowedSchemes)
        }
    }

    private func applyEmptyMergeError(
        merge: AggregatedPageImageDiscovery.MergeResult,
        pageCount: Int
    ) {
        if merge.failedPageURLs.count == pageCount {
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
    }

    private func applyHTTPSkippedNotice(count: Int) {
        let formatKey: String
#if DEBUG
        formatKey = "webimage.skippedHTTPImagesNoticeFormat"
#else
        formatKey = "webimage.skippedHTTPImagesNoticeFormat.release"
#endif
        let format = String(
            localized: String.LocalizationValue(formatKey),
            bundle: WebImagePickerBundle.module
        )
        httpSkippedImagesNotice = String.localizedStringWithFormat(format, count)
#if DEBUG
        let debugFormat = String(
            localized: String.LocalizationValue("webimage.skippedHTTPImagesNoticeFormat"),
            bundle: WebImagePickerBundle.module
        )
        let debugMessage = String.localizedStringWithFormat(debugFormat, count)
        print("[WebImagePicker] \(debugMessage)")
#endif
    }

    private func discoverImages(for pageURLs: [URL], useDiscoveryCache: Bool = true) async -> AggregatedPageImageDiscovery.MergeResult {
        if useDiscoveryCache,
           let cached = prefetchedResult,
           prefetchedPageURLs == pageURLs {
            cancelPrefetch()
            return cached
        }
        cancelPrefetch()
        return await AggregatedPageImageDiscovery.discoverImages(
            pageURLs: pageURLs,
            configuration: configuration,
            extractor: extractor,
            discoveryListCache: useDiscoveryCache ? discoveryListCache : nil
        )
    }

    private func mergePartialRecovery(
        existing: AggregatedPageImageDiscovery.MergeResult,
        supplemental: AggregatedPageImageDiscovery.MergeResult,
        recoveredPageURLs: [URL]
    ) -> AggregatedPageImageDiscovery.MergeResult {
        var seen = Set<String>()
        var mergedImages: [DiscoveredImage] = []
        for item in existing.images + supplemental.images {
            let key = DiscoveredImageDeduplicationKey.string(
                for: item.sourceURL,
                strategy: configuration.similarImageDeduplication
            )
            guard seen.insert(key).inserted else { continue }
            mergedImages.append(item)
        }
        let recoveredKeys = Set(recoveredPageURLs.map(\.absoluteString))
        let remainingFailed = existing.failedPageURLs.filter { !recoveredKeys.contains($0.absoluteString) }
        return AggregatedPageImageDiscovery.MergeResult(
            images: mergedImages,
            failedPageURLs: remainingFailed,
            skippedHTTPImageURLsDueToAllowedSchemes:
                existing.skippedHTTPImageURLsDueToAllowedSchemes
                + supplemental.skippedHTTPImageURLsDueToAllowedSchemes
        )
    }

    private func attemptSmartURLFallback(
        failedEntries: [ResolvedPageEntry],
        triedURLs: inout Set<String>
    ) async -> SmartURLFallbackResult? {
        guard configuration.isSmartURLFallbackEnabled else { return nil }
        let attemptCap = configuration.maximumSmartURLFallbackAttempts
        guard attemptCap > 0 else { return nil }

        struct FieldRetry {
            let source: ResolvedPageEntry.Source
            let text: String
        }

        var fields: [FieldRetry] = []
        if failedEntries.isEmpty {
            for field in userEnteredFieldsForCorrection() {
                fields.append(FieldRetry(source: field.source, text: field.text))
            }
        } else {
            for entry in failedEntries {
                guard let text = entry.originalUserText else { continue }
                fields.append(FieldRetry(source: entry.source, text: text))
            }
        }

        guard !fields.isEmpty else { return nil }

        var attemptsLeft = attemptCap
        let failedSources = Set(failedEntries.map(\.source))

        for field in fields {
            let candidates = PageURLCorrection.correctionCandidates(
                trimmedInput: field.text,
                strategy: configuration.smartURLFallbackTLDStrategy,
                maximumCandidates: attemptsLeft
            )
            for candidate in candidates {
                guard attemptsLeft > 0 else { return nil }
                guard case .success(let url) = PageURLNormalization.resolve(
                    trimmedInput: candidate,
                    allowedURLSchemes: configuration.allowedURLSchemes
                ) else { continue }
                guard triedURLs.insert(url.absoluteString).inserted else { continue }
                attemptsLeft -= 1

                let merge = await discoverImages(for: [url], useDiscoveryCache: false)
                guard !merge.images.isEmpty else { continue }

                applyFieldUpdate(source: field.source, correctedURL: url)
                let correction = makeURLCorrectionNotice(
                    originalText: field.text,
                    correctedURL: url
                )
                return SmartURLFallbackResult(
                    merge: merge,
                    loadedPageURLs: [url],
                    urlCorrection: correction,
                    recoveredFailedPageCount: failedSources.contains(field.source) ? 1 : 0
                )
            }
        }

        return nil
    }

    private func userEnteredFieldsForCorrection() -> [(source: ResolvedPageEntry.Source, text: String)] {
        var fields: [(ResolvedPageEntry.Source, String)] = []
        let primary = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty {
            fields.append((.primaryField, primary))
        }
        guard configuration.isMultiplePageEntryEnabled else { return fields }
        for row in extraPageRows {
            let trimmed = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            fields.append((.extraRow(row.id), trimmed))
        }
        return fields
    }

    private func applyFieldUpdate(source: ResolvedPageEntry.Source, correctedURL: URL) {
        let display = PageURLCorrection.displayString(for: correctedURL)
        switch source {
        case .primaryField:
            urlString = display
        case .extraRow(let id):
            if let index = extraPageRows.firstIndex(where: { $0.id == id }) {
                extraPageRows[index].text = display
            }
        case .configurationAdditional:
            break
        }
    }

    private func makeURLCorrectionNotice(originalText: String, correctedURL: URL) -> String {
        let format = String(
            localized: String.LocalizationValue("webimage.urlCorrectedFormat"),
            bundle: WebImagePickerBundle.module
        )
        return String.localizedStringWithFormat(
            format,
            originalText,
            PageURLCorrection.displayString(for: correctedURL)
        )
    }

    private func buildPageURLBatchResolution() -> PageURLBatchResolution {
        let allowed = Set(configuration.allowedURLSchemes.map { $0.lowercased() })
        var entries: [ResolvedPageEntry] = []
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

        func appendPage(_ url: URL, source: ResolvedPageEntry.Source, originalUserText: String?) {
            guard let scheme = url.scheme?.lowercased(), allowed.contains(scheme) else { return }
            let key = url.absoluteString
            guard !seenPages.contains(key) else { return }
            seenPages.insert(key)
            entries.append(ResolvedPageEntry(url: url, source: source, originalUserText: originalUserText))
        }

        let trimmedPrimary = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrimary.isEmpty {
            let resolved = PageURLNormalization.resolve(
                trimmedInput: trimmedPrimary,
                allowedURLSchemes: configuration.allowedURLSchemes
            )
            switch resolved {
            case .success(let u):
                appendPage(u, source: .primaryField, originalUserText: trimmedPrimary)
            case .invalid, .disallowedScheme:
                recordFailure(trimmedInput: trimmedPrimary, result: resolved)
            }
        }

        if configuration.isMultiplePageEntryEnabled {
            for u in configuration.additionalPageURLs {
                appendPage(u, source: .configurationAdditional, originalUserText: nil)
            }

            for row in extraPageRows {
                let t = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { continue }
                let resolved = PageURLNormalization.resolve(
                    trimmedInput: t,
                    allowedURLSchemes: configuration.allowedURLSchemes
                )
                switch resolved {
                case .success(let u):
                    appendPage(u, source: .extraRow(row.id), originalUserText: t)
                case .invalid, .disallowedScheme:
                    recordFailure(trimmedInput: t, result: resolved)
                }
            }
        }

        return PageURLBatchResolution(entries: entries, worstFailure: worstFailure)
    }

    private func applyResolveFailureMessage(
        worstFailure: (rank: ResolveFailureRank, sampleInput: String)?
    ) {
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
                let httpErrorKey: String
#if DEBUG
                httpErrorKey = "webimage.error.httpNotAllowed"
                let debugMsg = String(
                    localized: String.LocalizationValue(httpErrorKey),
                    bundle: WebImagePickerBundle.module
                )
                print("[WebImagePicker] \(debugMsg)")
#else
                httpErrorKey = "webimage.error.httpNotAllowed.release"
#endif
                errorMessage = String(
                    localized: String.LocalizationValue(httpErrorKey),
                    bundle: WebImagePickerBundle.module
                )
            }
            return
        }

        errorMessage = String(
            localized: String.LocalizationValue("webimage.error.enterValidURL"),
            bundle: WebImagePickerBundle.module
        )
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
        let batch = buildPageURLBatchResolution()
        guard !batch.entries.isEmpty else {
            applyResolveFailureMessage(worstFailure: batch.worstFailure)
            return nil
        }
        return batch.urls
    }

    // MARK: - WiFi prefetch

    /// Resolves page URLs using the same logic as ``resolveOrderedPageURLsOrSetError()``
    /// but without mutating ``errorMessage``. Used by the prefetch path.
    private func resolvePageURLsQuietly() -> [URL]? {
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
        if !trimmedPrimary.isEmpty {
            if case .success(let u) = PageURLNormalization.resolve(
                trimmedInput: trimmedPrimary,
                allowedURLSchemes: configuration.allowedURLSchemes
            ) {
                appendPage(u)
            }
        }

        if configuration.isMultiplePageEntryEnabled {
            for u in configuration.additionalPageURLs {
                appendPage(u)
            }
            for row in extraPageRows {
                let t = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { continue }
                if case .success(let u) = PageURLNormalization.resolve(
                    trimmedInput: t,
                    allowedURLSchemes: configuration.allowedURLSchemes
                ) {
                    appendPage(u)
                }
            }
        }

        return urls.isEmpty ? nil : urls
    }

    func schedulePrefetch() {
        prefetchTask?.cancel()
        prefetchTask = nil

        let monitor = wifiMonitor
        let cfg = configuration
        let ext = extractor
        let cache = discoveryListCache

        prefetchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self else { return }

            guard let pageURLs = self.resolvePageURLsQuietly() else { return }
            guard !Task.isCancelled else { return }

            guard monitor.isOnWiFi else { return }

            if let last = self.lastPrefetchStartTime {
                let elapsed = Date().timeIntervalSince(last)
                if elapsed < 1 {
                    try? await Task.sleep(for: .seconds(1 - elapsed))
                    guard !Task.isCancelled else { return }
                }
            }

            self.lastPrefetchStartTime = Date()

            let merge = await AggregatedPageImageDiscovery.discoverImages(
                pageURLs: pageURLs,
                configuration: cfg,
                extractor: ext,
                discoveryListCache: cache
            )
            guard !Task.isCancelled else { return }

            self.prefetchedResult = merge
            self.prefetchedPageURLs = pageURLs
        }
    }

    private func cancelPrefetch() {
        prefetchTask?.cancel()
        prefetchTask = nil
        prefetchedResult = nil
        prefetchedPageURLs = nil
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
        cancelPrefetch()
        cancelImageTextSearchTask()
        discoveryListCache?.clear()
        imageRecognizedTextByURL = [:]
        phase = .urlEntry
        discovered = []
        imageMetadataSearchQuery = ""
        selectedURLs = []
        loadedPageURLs = []
        errorMessage = nil
        aggregationNotice = nil
        httpSkippedImagesNotice = nil
        urlCorrectionNotice = nil
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
            case .pasteboardCopyFailed:
                return String(
                    localized: String.LocalizationValue("webimage.error.pasteboardCopyFailed"),
                    bundle: WebImagePickerBundle.module
                )
            case .subjectLiftFailed:
                return String(
                    localized: String.LocalizationValue("webimage.error.subjectLiftFailed"),
                    bundle: WebImagePickerBundle.module
                )
            case .subjectLiftUnavailable:
                return String(
                    localized: String.LocalizationValue("webimage.error.subjectLiftUnavailable"),
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
