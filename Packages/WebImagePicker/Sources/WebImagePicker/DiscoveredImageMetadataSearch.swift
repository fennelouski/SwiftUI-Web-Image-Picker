import Foundation

/// Case-insensitive substring filtering of ``DiscoveredImage`` for the browsing grid search field.
enum DiscoveredImageMetadataSearch {
    static func normalizedQuery(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Returns `true` when the trimmed query is empty or when the image matches alt, title, URL path, or full URL string (case-insensitive).
    static func matches(_ image: DiscoveredImage, rawQuery: String) -> Bool {
        let q = normalizedQuery(rawQuery)
        guard !q.isEmpty else { return true }
        if let alt = image.accessibilityLabel, alt.lowercased().contains(q) {
            return true
        }
        if let title = image.title, title.lowercased().contains(q) {
            return true
        }
        if image.sourceURL.path.lowercased().contains(q) {
            return true
        }
        if image.sourceURL.absoluteString.lowercased().contains(q) {
            return true
        }
        return false
    }

    static func filteredDiscoveries(_ images: [DiscoveredImage], rawQuery: String) -> [DiscoveredImage] {
        let q = normalizedQuery(rawQuery)
        guard !q.isEmpty else { return images }
        return images.filter { matches($0, rawQuery: q) }
    }
}
