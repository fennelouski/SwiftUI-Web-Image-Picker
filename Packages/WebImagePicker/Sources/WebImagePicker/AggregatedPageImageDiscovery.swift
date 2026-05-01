import Foundation

/// Loads image candidates from several page URLs, merges them in page order, and deduplicates using ``WebImagePickerConfiguration/similarImageDeduplication``.
enum AggregatedPageImageDiscovery {
    struct MergeResult: Sendable {
        let images: [DiscoveredImage]
        /// Page URLs whose extraction threw; empty when every page completed without throwing.
        let failedPageURLs: [URL]
    }

    /// Fetches pages **sequentially** so grid ordering stays stable (first page’s images first, then new images from later pages).
    static func discoverImages(
        pageURLs: [URL],
        configuration: WebImagePickerConfiguration,
        extractor: any PageImageExtractor
    ) async -> MergeResult {
        var merged: [DiscoveredImage] = []
        var seenImageKeys = Set<String>()
        var failed: [URL] = []

        for pageURL in pageURLs {
            do {
                var items = try await extractor.discoverImages(from: pageURL, configuration: configuration)
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

        return MergeResult(images: merged, failedPageURLs: failed)
    }
}
