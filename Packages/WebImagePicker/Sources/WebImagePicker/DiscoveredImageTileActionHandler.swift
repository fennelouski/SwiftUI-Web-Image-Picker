import Foundation

@MainActor
enum DiscoveredImageTileActionHandler {
    static func copyImageURL(_ item: DiscoveredImage) {
        DiscoveredImageClipboardService.copyURLString(item.sourceURL.absoluteString)
    }

    static func copyImage(
        item: DiscoveredImage,
        configuration: WebImagePickerConfiguration
    ) async throws {
        let selection = try await ImageDownloadService.download(from: item.sourceURL, configuration: configuration)
        try DiscoveredImageClipboardService.copyImage(from: selection)
    }

    static func liftSubject(
        item: DiscoveredImage,
        configuration: WebImagePickerConfiguration
    ) async throws {
#if os(iOS) || os(macOS)
        let selection = try await ImageDownloadService.download(from: item.sourceURL, configuration: configuration)
        try DiscoveredImageSubjectLiftService.copyLiftedSubject(from: selection)
#else
        throw WebImagePickerError.subjectLiftUnavailable
#endif
    }

    static func downloadForPreview(
        item: DiscoveredImage,
        configuration: WebImagePickerConfiguration
    ) async throws -> WebImageSelection {
        try await ImageDownloadService.download(from: item.sourceURL, configuration: configuration)
    }
}
