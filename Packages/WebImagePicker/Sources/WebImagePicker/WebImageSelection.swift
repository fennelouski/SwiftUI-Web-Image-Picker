import Foundation

/// A downloaded image chosen by the user, including raw bytes and metadata.
///
/// Decode with ``makeUIImage()`` on iOS, tvOS, or visionOS, or ``makeNSImage()`` on macOS when those APIs are available. When ``temporaryFileURL`` is set (``WebImageSelectionOutputMode/temporaryFileURL``), ``data`` is typically empty and bitmap helpers read from that file.
public struct WebImageSelection: Sendable, Hashable {
    /// Raw image bytes returned by the network response.
    public let data: Data
    /// MIME type from the response, when provided (e.g. `image/jpeg`).
    public let contentType: String?
    /// Absolute URL of the downloaded image.
    public let sourceURL: URL
    /// When using ``WebImageSelectionOutputMode/temporaryFileURL``, the path to a file in the system temporary directory. Copy or move it soon; the file may be removed by the system.
    public let temporaryFileURL: URL?

    /// Creates a selection value (primarily for tests and advanced integration).
    public init(data: Data, contentType: String?, sourceURL: URL, temporaryFileURL: URL? = nil) {
        self.data = data
        self.contentType = contentType
        self.sourceURL = sourceURL
        self.temporaryFileURL = temporaryFileURL
    }
}
