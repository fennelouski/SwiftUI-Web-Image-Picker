import Foundation

/// An image URL discovered on a web page, suitable for display and selection.
public struct DiscoveredImage: Identifiable, Hashable, Sendable {
    public var id: String { sourceURL.absoluteString }

    public let sourceURL: URL
    public let accessibilityLabel: String?

    public init(sourceURL: URL, accessibilityLabel: String?) {
        self.sourceURL = sourceURL
        self.accessibilityLabel = accessibilityLabel
    }
}
