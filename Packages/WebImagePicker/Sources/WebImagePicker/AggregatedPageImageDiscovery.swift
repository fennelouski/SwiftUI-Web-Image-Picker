import Foundation

/// Loads image candidates from several page URLs, merges them in page order, and deduplicates using ``WebImagePickerConfiguration/similarImageDeduplication``.
enum AggregatedPageImageDiscovery {
    struct MergeResult: Sendable {
        let images: [DiscoveredImage]
        /// Page URLs whose extraction threw; empty when every page completed without throwing.
        let failedPageURLs: [URL]
        /// Sum of distinct HTTP image URLs skipped per page because `http` was not in ``WebImagePickerConfiguration/allowedURLSchemes``.
        let skippedHTTPImageURLsDueToAllowedSchemes: Int
    }

    /// Fetches pages **sequentially** so grid ordering stays stable (first page’s images first, then new images from later pages).
    ///
    /// When `discoveryListCache` is non-`nil`, raw extractor output per `pageURL` may be reused so HTML/network extraction runs once per cached URL; sorting, type filtering, dimension filtering, and caps always apply using the current ``WebImagePickerConfiguration``.
    static func discoverImages(
        pageURLs: [URL],
        configuration: WebImagePickerConfiguration,
        extractor: any PageImageExtractor,
        discoveryListCache: DiscoveredImageListCache? = nil
    ) async -> MergeResult {
        var merged: [DiscoveredImage] = []
        var seenImageKeys = Set<String>()
        var failed: [URL] = []
        var skippedHTTPTotal = 0
        var httpSkipCountedForPage = Set<URL>()

        for pageURL in pageURLs {
            do {
                var items: [DiscoveredImage]
                if let cache = discoveryListCache, let cached = cache.lookup(pageURL) {
                    items = cached.images
                    if httpSkipCountedForPage.insert(pageURL).inserted {
                        skippedHTTPTotal += cached.skippedHTTPImageURLsDueToAllowedSchemes
                    }
                } else {
                    let outcome = try await extractor.discoverImagesWithOutcome(from: pageURL, configuration: configuration)
                    discoveryListCache?.store(pageURL, outcome: outcome)
                    items = outcome.images
                    if httpSkipCountedForPage.insert(pageURL).inserted {
                        skippedHTTPTotal += outcome.skippedHTTPImageURLsDueToAllowedSchemes
                    }
                }
                switch configuration.discoveredImageSort {
                case .faceCountDescending:
                    items = await DiscoveredImageFaceCountSorting.orderedImages(
                        items,
                        descending: true,
                        configuration: configuration
                    )
                case .faceCountAscending:
                    items = await DiscoveredImageFaceCountSorting.orderedImages(
                        items,
                        descending: false,
                        configuration: configuration
                    )
                default:
                    items = configuration.discoveredImageSort.orderedImages(items)
                }
                items = items.filter { ImageTypeAllowlist.passesDiscovery(url: $0.sourceURL, configuration: configuration) }
                items = await DiscoveredImageDimensionFiltering.filtered(images: items, configuration: configuration)
                if let cap = configuration.maximumDiscoveredImagesPerPage {
                    items = Array(items.prefix(cap))
                }
                for item in items {
                    let key = DiscoveredImageDeduplicationKey.string(
                        for: item.sourceURL,
                        strategy: configuration.similarImageDeduplication
                    )
                    guard !seenImageKeys.contains(key) else { continue }
                    seenImageKeys.insert(key)
                    merged.append(item)
                }
            } catch {
                failed.append(pageURL)
            }
        }

        return MergeResult(
            images: merged,
            failedPageURLs: failed,
            skippedHTTPImageURLsDueToAllowedSchemes: skippedHTTPTotal
        )
    }
}
