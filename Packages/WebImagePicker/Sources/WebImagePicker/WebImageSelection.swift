import Foundation

/// A downloaded image chosen by the user, including raw bytes and metadata.
///
/// Decode with ``makeUIImage()`` on iOS, tvOS, or visionOS, or ``makeNSImage()`` on macOS when those APIs are available.
public struct WebImageSelection: Sendable, Hashable {
    /// Raw image bytes returned by the network response.
    public let data: Data
    /// MIME type from the response, when provided (e.g. `image/jpeg`).
    public let contentType: String?
    /// Absolute URL of the downloaded image.
    public let sourceURL: URL

    /// Creates a selection value (primarily for tests and advanced integration).
    public init(data: Data, contentType: String?, sourceURL: URL) {
        self.data = data
        self.contentType = contentType
        self.sourceURL = sourceURL
    }
}
