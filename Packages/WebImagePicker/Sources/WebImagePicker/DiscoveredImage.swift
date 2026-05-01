import Foundation

/// An image URL discovered on a web page, suitable for display and selection.
public struct DiscoveredImage: Identifiable, Hashable, Sendable {
    public var id: String { sourceURL.absoluteString }

    public let sourceURL: URL
    public let accessibilityLabel: String?
    /// HTML `title` attribute when present (typically from `<img title="…">`).
    public let title: String?

    public init(sourceURL: URL, accessibilityLabel: String?, title: String? = nil) {
        self.sourceURL = sourceURL
        self.accessibilityLabel = accessibilityLabel
        self.title = title
    }
}
