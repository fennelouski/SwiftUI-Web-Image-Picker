import Foundation

/// Pluggable strategy for discovering image URLs on a page. Hosts may supply custom extractors in the future.
public protocol PageImageExtractor: Sendable {
    func discoverImages(from pageURL: URL, configuration: WebImagePickerConfiguration) async throws -> [DiscoveredImage]

    /// Discover images and report HTTP URLs omitted because `http` is not in ``WebImagePickerConfiguration/allowedURLSchemes``.
    ///
    /// Conformers may rely on the default implementation, which wraps ``discoverImages(from:configuration:)`` and reports zero skipped HTTP URLs.
    func discoverImagesWithOutcome(from pageURL: URL, configuration: WebImagePickerConfiguration) async throws -> PageImageDiscoveryOutcome
}

extension PageImageExtractor {
    public func discoverImagesWithOutcome(from pageURL: URL, configuration: WebImagePickerConfiguration) async throws -> PageImageDiscoveryOutcome {
        let images = try await discoverImages(from: pageURL, configuration: configuration)
        return PageImageDiscoveryOutcome(images: images)
    }
}
