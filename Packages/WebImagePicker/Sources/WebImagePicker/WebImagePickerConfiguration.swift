import Foundation

/// How HTML is processed to find image URLs. Additional modes may be added without breaking the public enum.
public enum WebImageExtractionMode: Sendable, Hashable {
    /// Parse the raw HTML response (no JavaScript execution).
    case staticHTML
}

public struct WebImagePickerConfiguration: Sendable, Hashable {
    /// Maximum number of images the user may select. Use `1` for single selection.
    public var selectionLimit: Int

    /// Parallel image downloads when confirming a selection.
    public var maximumConcurrentImageLoads: Int

    /// Timeout for each network request (HTML and image bytes).
    public var requestTimeout: TimeInterval

    /// Allowed schemes for both page URLs and discovered image URLs. Default is HTTPS only.
    public var allowedURLSchemes: Set<String>

    /// Optional `User-Agent` for HTML and image requests.
    public var userAgent: String?

    /// Safety cap on HTML document size (bytes).
    public var maximumHTMLDownloadBytes: Int

    /// Safety cap on each image download (bytes).
    public var maximumImageDownloadBytes: Int

    public var extractionMode: WebImageExtractionMode

    public init(
        selectionLimit: Int = 10,
        maximumConcurrentImageLoads: Int = 4,
        requestTimeout: TimeInterval = 30,
        allowedURLSchemes: Set<String> = ["https"],
        userAgent: String? = nil,
        maximumHTMLDownloadBytes: Int = 2_000_000,
        maximumImageDownloadBytes: Int = 25_000_000,
        extractionMode: WebImageExtractionMode = .staticHTML
    ) {
        self.selectionLimit = max(1, selectionLimit)
        self.maximumConcurrentImageLoads = max(1, maximumConcurrentImageLoads)
        self.requestTimeout = requestTimeout
        self.allowedURLSchemes = allowedURLSchemes
        self.userAgent = userAgent
        self.maximumHTMLDownloadBytes = maximumHTMLDownloadBytes
        self.maximumImageDownloadBytes = maximumImageDownloadBytes
        self.extractionMode = extractionMode
    }

    public static let `default` = WebImagePickerConfiguration()
}
