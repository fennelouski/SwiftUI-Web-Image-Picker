import Foundation

/// Raw discovery result from a ``PageImageExtractor``, including images omitted because their URL used HTTP while the configuration did not allow `http`.
public struct PageImageDiscoveryOutcome: Sendable {
    public var images: [DiscoveredImage]
    /// Distinct discovered image URLs dropped because they resolved to `http:` and ``WebImagePickerConfiguration/allowedURLSchemes`` did not include `http`.
    public var skippedHTTPImageURLsDueToAllowedSchemes: Int

    public init(images: [DiscoveredImage], skippedHTTPImageURLsDueToAllowedSchemes: Int = 0) {
        self.images = images
        self.skippedHTTPImageURLsDueToAllowedSchemes = skippedHTTPImageURLsDueToAllowedSchemes
    }
}
