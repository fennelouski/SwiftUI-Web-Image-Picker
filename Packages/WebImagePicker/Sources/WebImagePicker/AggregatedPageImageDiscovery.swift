import Foundation

/// Loads image candidates from several page URLs, merges them in page order, and deduplicates by image URL.
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
                let items = try await extractor.discoverImages(from: pageURL, configuration: configuration)
                for item in items {
                    let key = item.sourceURL.absoluteString
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
