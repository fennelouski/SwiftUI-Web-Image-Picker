import Foundation

/// How HTML is processed to find image URLs. Additional modes may be added without breaking the public enum.
public enum WebImageExtractionMode: Sendable, Hashable {
    /// Parse the raw HTML response (no JavaScript execution).
    case staticHTML

    /// Load the page in `WKWebView` and collect image URLs after JavaScript runs.
    ///
    /// Use this for client-rendered pages where images are injected at runtime.
    /// This mode has higher memory/runtime cost than `.staticHTML`.
    case webView
}

/// Tunable behavior for ``WebImagePicker`` and ``View/webImagePicker(isPresented:configuration:onPick:)``.
///
/// Use ``default`` for HTTPS-only pages, multi-select up to 10, static HTML extraction, and shared `URLSession`.
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

    /// Session used for HTML fetches and image downloads. Defaults to `URLSession.shared`.
    public var urlSession: URLSession

    /// Creates a configuration with explicit limits and networking options.
    /// - Parameters:
    ///   - selectionLimit: Maximum selections; clamped to at least `1`.
    ///   - maximumConcurrentImageLoads: Parallel downloads when confirming a multi-select.
    ///   - requestTimeout: Per-request timeout for HTML and image fetches.
    ///   - allowedURLSchemes: Schemes allowed for page and image URLs (e.g. `https` only by default).
    ///   - userAgent: Optional HTTP `User-Agent` header.
    ///   - maximumHTMLDownloadBytes: Upper bound on HTML response size.
    ///   - maximumImageDownloadBytes: Upper bound on each image response.
    ///   - extractionMode: ``WebImageExtractionMode/staticHTML`` or ``WebImageExtractionMode/webView``.
    ///   - urlSession: Session used for fetches; defaults to `URLSession.shared`.
    public init(
        selectionLimit: Int = 10,
        maximumConcurrentImageLoads: Int = 4,
        requestTimeout: TimeInterval = 30,
        allowedURLSchemes: Set<String> = ["https"],
        userAgent: String? = nil,
        maximumHTMLDownloadBytes: Int = 2_000_000,
        maximumImageDownloadBytes: Int = 25_000_000,
        extractionMode: WebImageExtractionMode = .staticHTML,
        urlSession: URLSession = .shared
    ) {
        self.selectionLimit = max(1, selectionLimit)
        self.maximumConcurrentImageLoads = max(1, maximumConcurrentImageLoads)
        self.requestTimeout = requestTimeout
        self.allowedURLSchemes = allowedURLSchemes
        self.userAgent = userAgent
        self.maximumHTMLDownloadBytes = maximumHTMLDownloadBytes
        self.maximumImageDownloadBytes = maximumImageDownloadBytes
        self.extractionMode = extractionMode
        self.urlSession = urlSession
    }

    public static let `default` = WebImagePickerConfiguration()

    public static func == (lhs: WebImagePickerConfiguration, rhs: WebImagePickerConfiguration) -> Bool {
        lhs.selectionLimit == rhs.selectionLimit
            && lhs.maximumConcurrentImageLoads == rhs.maximumConcurrentImageLoads
            && lhs.requestTimeout == rhs.requestTimeout
            && lhs.allowedURLSchemes == rhs.allowedURLSchemes
            && lhs.userAgent == rhs.userAgent
            && lhs.maximumHTMLDownloadBytes == rhs.maximumHTMLDownloadBytes
            && lhs.maximumImageDownloadBytes == rhs.maximumImageDownloadBytes
            && lhs.extractionMode == rhs.extractionMode
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(selectionLimit)
        hasher.combine(maximumConcurrentImageLoads)
        hasher.combine(requestTimeout)
        hasher.combine(allowedURLSchemes)
        hasher.combine(userAgent)
        hasher.combine(maximumHTMLDownloadBytes)
        hasher.combine(maximumImageDownloadBytes)
        hasher.combine(extractionMode)
    }
}
