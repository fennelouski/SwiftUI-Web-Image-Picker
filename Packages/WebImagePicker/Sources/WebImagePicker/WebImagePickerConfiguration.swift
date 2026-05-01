import CoreGraphics
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
/// Use ``default`` for HTTPS-only pages, single-tap selection (``selectionLimit`` `1`), static HTML extraction, and shared `URLSession`. Set a higher ``selectionLimit`` for multi-select.
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

    /// Optional text pre-filled in the URL field when the picker appears (whitespace trimmed). Empty or `nil` means a blank field.
    public var initialURLString: String?

    /// Extra page URLs to load after the primary field (and any user-added rows), in order. Images are merged into one grid with duplicates removed.
    ///
    /// Host apps can pre-seed several pages; invalid schemes are skipped. Discovery runs sequentially to keep ordering predictable.
    public var additionalPageURLs: [URL]

    /// Upper bound on how many images to keep from each page after discovery, before they are merged into the grid.
    ///
    /// When `nil` (the default), no truncation is applied. When set to a positive value, only the first N candidates from that page are kept **after** ``discoveredImageSort`` is applied (default ``DiscoveredImageSort/discoveryOrder`` matches extractor order; see package documentation for static HTML ordering). The cap applies **per page**: in multi-URL mode, each loaded page contributes at most N images (after per-page deduplication).
    public var maximumDiscoveredImagesPerPage: Int?

    /// How to order each page’s deduplicated images before ``maximumDiscoveredImagesPerPage`` truncation. Default ``DiscoveredImageSort/discoveryOrder`` preserves extractor order.
    public var discoveredImageSort: DiscoveredImageSort

    /// Optional collapsing of URLs that likely name the same resource (for example cache-busting query pairs). See ``SimilarImageDeduplicationStrategy``.
    public var similarImageDeduplication: SimilarImageDeduplicationStrategy

    /// Optional minimum pixel width and height. When non-`nil`, a component `<= 0` means no minimum on that axis. Applied after discovery sort and before ``maximumDiscoveredImagesPerPage`` using a lightweight ranged GET per candidate (see ``DiscoveredImageDimensionFiltering``).
    public var minimumImageDimensions: CGSize?

    /// Optional maximum pixel width and height. When non-`nil`, a component `<= 0` means no maximum on that axis. Applied after discovery sort and before ``maximumDiscoveredImagesPerPage`` using a lightweight ranged GET per candidate (see ``DiscoveredImageDimensionFiltering``).
    public var maximumImageDimensions: CGSize?

    /// Allowed image formats as `UTType` identifier strings (for example ``UTType/jpeg`` `.identifier`). When `nil` or empty, discovery and downloads do not filter by type. When non-empty, URLs whose extension maps to a non-image type are dropped; image types must conform to at least one listed type. Extension-less URLs follow ``unknownImageTypePolicy``.
    public var allowedImageTypeIdentifiers: Set<String>?

    /// When ``allowedImageTypeIdentifiers`` is active, controls handling of types that cannot be inferred from the URL or from `Content-Type`. Default ``WebImageUnknownTypePolicy/allow``.
    public var unknownImageTypePolicy: WebImageUnknownTypePolicy

    /// How completed downloads are exposed in ``WebImageSelection`` (default ``WebImageSelectionOutputMode/dataOnly``).
    public var selectionOutputMode: WebImageSelectionOutputMode

    /// When using ``DiscoveredImageSort/faceCountDescending`` or ``faceCountAscending``, the maximum number of images **per page** (in discovery order) to probe and analyze with on-device Vision. Additional images keep discovery order after the sorted prefix. Use `0` to skip analysis (no face-based reordering). Default `40`.
    public var maximumFaceCountAnalysisImages: Int

    /// When `true`, runs on-device text recognition (Vision) on up to ``maximumImageTextSearchImages`` discovered images so the browsing search field can match text **inside** raster images. Default `false` (privacy / performance).
    public var isImageTextSearchEnabled: Bool

    /// Upper bound on how many discovered images (in discovery order) receive OCR when ``isImageTextSearchEnabled`` is `true`. `0` skips OCR. Default `32`.
    public var maximumImageTextSearchImages: Int

    /// Optional BCP-47 language identifiers for ``VNRecognizeTextRequest`` (for example `"en-US"`). `nil` or empty lets Vision choose defaults.
    public var imageTextRecognitionLanguages: [String]?

    /// Parallel ranged GET + Vision requests while building the in-image text index. Default `2`.
    public var maximumConcurrentImageTextRecognition: Int

    /// Case-insensitive substring blocklist: images whose absolute URL, path, alt text, `title`, or OCR text (when available) contains **any** entry are omitted from the browsing grid. Applied after discovery (and uses OCR text when ``isImageTextSearchEnabled`` has populated the index). Runs **before** the user’s search field. Default empty.
    public var excludedImageMetadataSubstrings: [String]

    /// Regular-expression blocklist using ``NSRegularExpression`` syntax, matched case-insensitively against the same haystacks as ``excludedImageMetadataSubstrings``. Invalid patterns are ignored. Regex evaluation adds CPU cost proportional to the number of patterns and candidate strings—keep this list short.
    public var excludedImageMetadataRegularExpressionPatterns: [String]

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
    ///   - initialURLString: Optional URL string shown in the entry field when the picker first appears.
    ///   - additionalPageURLs: Ordered extra pages to aggregate with the primary URL and any user-added URLs.
    ///   - maximumDiscoveredImagesPerPage: Optional maximum images retained per page after discovery; `nil` means unlimited.
    ///   - discoveredImageSort: Order applied per page after deduplication and before the per-page cap.
    ///   - similarImageDeduplication: How aggressively to merge URLs that may reference the same asset.
    ///   - minimumImageDimensions: Optional lower pixel bounds per axis (`<= 0` on an axis disables that side).
    ///   - maximumImageDimensions: Optional upper pixel bounds per axis (`<= 0` on an axis disables that side).
    ///   - allowedImageTypeIdentifiers: Optional `UTType` identifier allowlist; `nil` or empty disables type filtering.
    ///   - unknownImageTypePolicy: Behavior for unknown types when an allowlist is active.
    ///   - selectionOutputMode: How ``WebImageSelection`` values are filled after download.
    ///   - maximumFaceCountAnalysisImages: Vision face-sort budget per page; `0` disables analysis.
    ///   - isImageTextSearchEnabled: When `true`, OCR indexes a prefix of discovered images for search.
    ///   - maximumImageTextSearchImages: Cap on OCR’d images when image text search is enabled.
    ///   - imageTextRecognitionLanguages: Optional Vision recognition language tags.
    ///   - maximumConcurrentImageTextRecognition: Parallelism for OCR ranged GETs + Vision.
    ///   - excludedImageMetadataSubstrings: Substrings that hide matching images from the grid.
    ///   - excludedImageMetadataRegularExpressionPatterns: Regex patterns that hide matching images.
    ///   - urlSession: Session used for fetches; defaults to `URLSession.shared`.
    public init(
        selectionLimit: Int = 1,
        maximumConcurrentImageLoads: Int = 4,
        requestTimeout: TimeInterval = 30,
        allowedURLSchemes: Set<String> = ["https"],
        userAgent: String? = nil,
        maximumHTMLDownloadBytes: Int = 2_000_000,
        maximumImageDownloadBytes: Int = 25_000_000,
        extractionMode: WebImageExtractionMode = .staticHTML,
        initialURLString: String? = nil,
        additionalPageURLs: [URL] = [],
        maximumDiscoveredImagesPerPage: Int? = nil,
        discoveredImageSort: DiscoveredImageSort = .discoveryOrder,
        similarImageDeduplication: SimilarImageDeduplicationStrategy = .disabled,
        minimumImageDimensions: CGSize? = nil,
        maximumImageDimensions: CGSize? = nil,
        allowedImageTypeIdentifiers: Set<String>? = nil,
        unknownImageTypePolicy: WebImageUnknownTypePolicy = .allow,
        selectionOutputMode: WebImageSelectionOutputMode = .dataOnly,
        maximumFaceCountAnalysisImages: Int = 40,
        isImageTextSearchEnabled: Bool = false,
        maximumImageTextSearchImages: Int = 32,
        imageTextRecognitionLanguages: [String]? = nil,
        maximumConcurrentImageTextRecognition: Int = 2,
        excludedImageMetadataSubstrings: [String] = [],
        excludedImageMetadataRegularExpressionPatterns: [String] = [],
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
        self.initialURLString = initialURLString
        self.additionalPageURLs = additionalPageURLs
        self.maximumDiscoveredImagesPerPage = maximumDiscoveredImagesPerPage.flatMap { $0 > 0 ? $0 : nil }
        self.discoveredImageSort = discoveredImageSort
        self.similarImageDeduplication = similarImageDeduplication
        self.minimumImageDimensions = minimumImageDimensions
        self.maximumImageDimensions = maximumImageDimensions
        self.allowedImageTypeIdentifiers = allowedImageTypeIdentifiers.flatMap { $0.isEmpty ? nil : $0 }
        self.unknownImageTypePolicy = unknownImageTypePolicy
        self.selectionOutputMode = selectionOutputMode
        self.maximumFaceCountAnalysisImages = max(0, maximumFaceCountAnalysisImages)
        self.isImageTextSearchEnabled = isImageTextSearchEnabled
        self.maximumImageTextSearchImages = max(0, maximumImageTextSearchImages)
        self.imageTextRecognitionLanguages = imageTextRecognitionLanguages.flatMap { $0.isEmpty ? nil : $0 }
        self.maximumConcurrentImageTextRecognition = max(1, maximumConcurrentImageTextRecognition)
        self.excludedImageMetadataSubstrings = excludedImageMetadataSubstrings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.excludedImageMetadataRegularExpressionPatterns = excludedImageMetadataRegularExpressionPatterns
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
            && lhs.initialURLString == rhs.initialURLString
            && lhs.additionalPageURLs == rhs.additionalPageURLs
            && lhs.maximumDiscoveredImagesPerPage == rhs.maximumDiscoveredImagesPerPage
            && lhs.discoveredImageSort == rhs.discoveredImageSort
            && lhs.similarImageDeduplication == rhs.similarImageDeduplication
            && lhs.minimumImageDimensions == rhs.minimumImageDimensions
            && lhs.maximumImageDimensions == rhs.maximumImageDimensions
            && lhs.allowedImageTypeIdentifiers == rhs.allowedImageTypeIdentifiers
            && lhs.unknownImageTypePolicy == rhs.unknownImageTypePolicy
            && lhs.selectionOutputMode == rhs.selectionOutputMode
            && lhs.maximumFaceCountAnalysisImages == rhs.maximumFaceCountAnalysisImages
            && lhs.isImageTextSearchEnabled == rhs.isImageTextSearchEnabled
            && lhs.maximumImageTextSearchImages == rhs.maximumImageTextSearchImages
            && lhs.imageTextRecognitionLanguages == rhs.imageTextRecognitionLanguages
            && lhs.maximumConcurrentImageTextRecognition == rhs.maximumConcurrentImageTextRecognition
            && lhs.excludedImageMetadataSubstrings == rhs.excludedImageMetadataSubstrings
            && lhs.excludedImageMetadataRegularExpressionPatterns == rhs.excludedImageMetadataRegularExpressionPatterns
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
        hasher.combine(initialURLString)
        hasher.combine(additionalPageURLs)
        hasher.combine(maximumDiscoveredImagesPerPage)
        hasher.combine(discoveredImageSort)
        hasher.combine(similarImageDeduplication)
        Self.hashCGSizeOptional(minimumImageDimensions, into: &hasher)
        Self.hashCGSizeOptional(maximumImageDimensions, into: &hasher)
        hasher.combine(allowedImageTypeIdentifiers)
        hasher.combine(unknownImageTypePolicy)
        hasher.combine(selectionOutputMode)
        hasher.combine(maximumFaceCountAnalysisImages)
        hasher.combine(isImageTextSearchEnabled)
        hasher.combine(maximumImageTextSearchImages)
        hasher.combine(imageTextRecognitionLanguages)
        hasher.combine(maximumConcurrentImageTextRecognition)
        hasher.combine(excludedImageMetadataSubstrings)
        hasher.combine(excludedImageMetadataRegularExpressionPatterns)
    }

    private static func hashCGSizeOptional(_ size: CGSize?, into hasher: inout Hasher) {
        guard let size else {
            hasher.combine(0 as UInt8)
            return
        }
        hasher.combine(1 as UInt8)
        hasher.combine(Double(size.width))
        hasher.combine(Double(size.height))
    }
}
