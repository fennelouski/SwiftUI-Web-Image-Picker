import Foundation
import UniformTypeIdentifiers

/// Case-insensitive substring filtering of ``DiscoveredImage`` for the browsing grid search field.
///
/// Supports `format:<extension>` tokens (for example `format:png`, `format:webp`) anywhere in the query.
/// Tokens are removed before alt/title/URL text matching. Format filters use OR when multiple tokens appear.
/// Format choices intersect ``WebImagePickerConfiguration/allowedImageTypeIdentifiers`` when that allowlist is active.
enum DiscoveredImageMetadataSearch {
    static func normalizedQuery(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Strips `format:` tokens and returns remaining text plus extracted extensions (lowercased alphanumerics).
    internal static func splitFormatTokens(from raw: String) -> (text: String, tokens: [String]) {
        let pattern = try! NSRegularExpression(pattern: #"(?i)\bformat:\s*([a-z0-9]+)\b"#, options: [])
        var s = raw
        var tokens: [String] = []
        while let m = pattern.firstMatch(in: s, options: [], range: NSRange(s.startIndex..., in: s)) {
            guard let capR = Range(m.range(at: 1), in: s),
                  let fullR = Range(m.range, in: s) else { break }
            tokens.append(String(s[capR]).lowercased())
            s.removeSubrange(fullR)
        }
        return (s, tokens)
    }

    /// Returns `true` when the trimmed query is empty or when the image matches alt, title, URL path, full URL string, or optional Vision OCR text (case-insensitive).
    static func matches(
        _ image: DiscoveredImage,
        rawQuery: String,
        recognizedTextByURL: [URL: String]? = nil
    ) -> Bool {
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
        if let blob = recognizedTextByURL?[image.sourceURL], blob.lowercased().contains(q) {
            return true
        }
        return false
    }

    static func filteredDiscoveries(
        _ images: [DiscoveredImage],
        rawQuery: String,
        configuration: WebImagePickerConfiguration = .default,
        recognizedTextByURL: [URL: String]? = nil
    ) -> [DiscoveredImage] {
        let (textPart, formatTokens) = splitFormatTokens(from: rawQuery)
        let trimmedText = textPart.trimmingCharacters(in: .whitespacesAndNewlines)
        let normText = normalizedQuery(trimmedText)
        let hasText = !normText.isEmpty
        let hasFormats = !formatTokens.isEmpty

        if !hasText && !hasFormats {
            return images
        }

        return images.filter { image in
            if hasFormats, !urlMatchesAnyFormatToken(image.sourceURL, tokens: formatTokens, configuration: configuration) {
                return false
            }
            if hasText, !matches(image, rawQuery: trimmedText, recognizedTextByURL: recognizedTextByURL) {
                return false
            }
            return true
        }
    }

    private static func urlMatchesAnyFormatToken(
        _ url: URL,
        tokens: [String],
        configuration: WebImagePickerConfiguration
    ) -> Bool {
        for tok in tokens where urlMatchesFormatToken(url, token: tok, configuration: configuration) {
            return true
        }
        return false
    }

    private static func urlMatchesFormatToken(
        _ url: URL,
        token: String,
        configuration: WebImagePickerConfiguration
    ) -> Bool {
        guard let wanted = UTType(filenameExtension: token), wanted.conforms(to: .image) else {
            return false
        }
        guard ImageTypeAllowlist.passesDiscovery(url: url, configuration: configuration) else {
            return false
        }
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, let got = UTType(filenameExtension: ext), got.conforms(to: .image) else {
            return false
        }
        return got.conforms(to: wanted) || wanted.conforms(to: got)
    }
}
