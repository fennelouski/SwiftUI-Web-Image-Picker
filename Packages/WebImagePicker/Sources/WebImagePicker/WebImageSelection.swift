import Foundation

/// A downloaded image chosen by the user, including raw bytes and metadata.
public struct WebImageSelection: Sendable, Hashable {
    public let data: Data
    public let contentType: String?
    public let sourceURL: URL

    public init(data: Data, contentType: String?, sourceURL: URL) {
        self.data = data
        self.contentType = contentType
        self.sourceURL = sourceURL
    }
}
