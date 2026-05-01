import Foundation

/// Sort order applied to each page’s deduplicated discovery results before ``WebImagePickerConfiguration/maximumDiscoveredImagesPerPage`` truncation and cross-page merge.
///
/// The default is ``discoveryOrder``, which preserves the order from the active ``PageImageExtractor`` (DOM order for static HTML). Sorting uses a stable tie-break on original discovery index when comparison keys match.
public enum DiscoveredImageSort: Sendable, Hashable {
    /// Preserve extractor order (no reordering).
    case discoveryOrder

    /// Lexicographic ascending on ``DiscoveredImage/sourceURL`` (`absoluteString`, UTF-8 code units).
    case sourceURLAscending

    /// Descending inferred pixel width from URL query parameters `w` or `width` (first positive integer wins). Unknown width sorts as `0` (after positive widths). This approximates “largest srcset candidate” when dimensions are reflected in the URL, not from raw `srcset` text (which is not retained on ``DiscoveredImage``).
    case inferredPixelWidthDescending

    /// Portrait-like URLs first, then unknown or square, then landscape, using `w`/`width` and `h`/`height` query integers when both exist. URLs missing either dimension go in the middle bucket (same as square).
    case aspectRatioBucketPortraitFirst

    func orderedImages(_ images: [DiscoveredImage]) -> [DiscoveredImage] {
        switch self {
        case .discoveryOrder:
            return images
        case .sourceURLAscending:
            return images.enumerated().sorted { lhs, rhs in
                let l = lhs.element.sourceURL.absoluteString
                let r = rhs.element.sourceURL.absoluteString
                if l != r { return l < r }
                return lhs.offset < rhs.offset
            }.map(\.element)
        case .inferredPixelWidthDescending:
            return images.enumerated().sorted { lhs, rhs in
                let lw = Self.pixelWidthHint(for: lhs.element.sourceURL)
                let rw = Self.pixelWidthHint(for: rhs.element.sourceURL)
                if lw != rw { return lw > rw }
                return lhs.offset < rhs.offset
            }.map(\.element)
        case .aspectRatioBucketPortraitFirst:
            return images.enumerated().sorted { lhs, rhs in
                let lb = Self.aspectRatioBucket(for: lhs.element.sourceURL)
                let rb = Self.aspectRatioBucket(for: rhs.element.sourceURL)
                if lb != rb { return lb < rb }
                return lhs.offset < rhs.offset
            }.map(\.element)
        }
    }

    private static func pixelWidthHint(for url: URL) -> Int {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return 0
        }
        for name in ["w", "width"] {
            if let raw = items.first(where: { $0.name.lowercased() == name })?.value,
               let n = Int(raw), n > 0 {
                return n
            }
        }
        return 0
    }

    /// 0 = portrait, 1 = square or unknown, 2 = landscape
    private static func aspectRatioBucket(for url: URL) -> Int {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return 1
        }
        func positiveInt(names: [String]) -> Int? {
            for name in names {
                if let raw = items.first(where: { $0.name.lowercased() == name })?.value,
                   let n = Int(raw), n > 0 {
                    return n
                }
            }
            return nil
        }
        guard let w = positiveInt(names: ["w", "width"]),
              let h = positiveInt(names: ["h", "height"]) else {
            return 1
        }
        let ratio = Double(w) / Double(h)
        if ratio < 0.95 { return 0 }
        if ratio <= 1.05 { return 1 }
        return 2
    }
}
