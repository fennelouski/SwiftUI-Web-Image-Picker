import Foundation

/// Pluggable strategy for discovering image URLs on a page. Hosts may supply custom extractors in the future.
public protocol PageImageExtractor: Sendable {
    func discoverImages(from pageURL: URL, configuration: WebImagePickerConfiguration) async throws -> [DiscoveredImage]
}
