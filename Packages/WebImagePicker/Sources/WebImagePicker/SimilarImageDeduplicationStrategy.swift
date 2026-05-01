import Foundation

/// How the picker treats different URLs that may refer to the same raster asset.
///
/// Byte-level or perceptual hashing is not implemented yet; only URL normalization is available today.
public enum SimilarImageDeduplicationStrategy: Sendable, Hashable {
    /// Deduplicate using the full absolute URL string only (default). URLs that differ only by query or fragment stay distinct.
    case disabled
    /// Collapse URLs that share scheme, host, and path after stripping **query** and **fragment**.
    ///
    /// The first occurrence in discovery order is kept (including its original query string on ``DiscoveredImage/sourceURL``).
    ///
    /// **Tradeoff:** Some CDNs and signed URLs encode distinct variants or different images entirely in the query string. Those assets may be incorrectly merged; use ``disabled`` when queries carry resource identity.
    case normalizedResourceURL
}

enum DiscoveredImageDeduplicationKey {
    static func string(for url: URL, strategy: SimilarImageDeduplicationStrategy) -> String {
        switch strategy {
        case .disabled:
            return url.absoluteString
        case .normalizedResourceURL:
            return normalizedResourceURLString(for: url)
        }
    }

    private static func normalizedResourceURLString(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        components.fragment = nil
        components.query = nil
        if let host = components.host {
            components.host = host.lowercased()
        }
        if let canonical = components.url {
            return canonical.absoluteString
        }
        return components.string ?? url.absoluteString
    }
}
