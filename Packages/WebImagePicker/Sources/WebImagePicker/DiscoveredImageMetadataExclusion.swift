import Foundation

/// Hides discovered images when URL, alt text, `title`, or optional OCR text matches integrator blocklists.
///
/// Runs **before** the user’s browsing search (``DiscoveredImageMetadataSearch``). When OCR is enabled and a URL is indexed,
/// recognized text participates in matching; URLs not yet indexed are still checked against URL and HTML metadata only.
enum DiscoveredImageMetadataExclusion {
    static func filter(
        _ images: [DiscoveredImage],
        configuration: WebImagePickerConfiguration,
        recognizedTextByURL: [URL: String]?
    ) -> [DiscoveredImage] {
        let substrings = normalizedSubstrings(configuration.excludedImageMetadataSubstrings)
        let regexes = compileRegularExpressions(configuration.excludedImageMetadataRegularExpressionPatterns)
        guard !substrings.isEmpty || !regexes.isEmpty else { return images }
        return images.filter { !isBlocked($0, substrings: substrings, regexes: regexes, ocr: recognizedTextByURL) }
    }

    private static func normalizedSubstrings(_ raw: [String]) -> [String] {
        raw.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }
    }

    private static func compileRegularExpressions(_ patterns: [String]) -> [NSRegularExpression] {
        patterns.compactMap { pattern in
            let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return try? NSRegularExpression(pattern: trimmed, options: [.caseInsensitive])
        }
    }

    private static func isBlocked(
        _ image: DiscoveredImage,
        substrings: [String],
        regexes: [NSRegularExpression],
        ocr: [URL: String]?
    ) -> Bool {
        let haystacks = haystacks(for: image, ocr: ocr)
        if !substrings.isEmpty {
            for h in haystacks {
                let lower = h.lowercased()
                for s in substrings where lower.contains(s) {
                    return true
                }
            }
        }
        if !regexes.isEmpty {
            for h in haystacks {
                let ns = h as NSString
                let full = NSRange(location: 0, length: ns.length)
                for regex in regexes where regex.firstMatch(in: h, options: [], range: full) != nil {
                    return true
                }
            }
        }
        return false
    }

    private static func haystacks(for image: DiscoveredImage, ocr: [URL: String]?) -> [String] {
        var parts: [String] = [image.sourceURL.absoluteString, image.sourceURL.path]
        if let alt = image.accessibilityLabel, !alt.isEmpty { parts.append(alt) }
        if let title = image.title, !title.isEmpty { parts.append(title) }
        if let t = ocr?[image.sourceURL], !t.isEmpty { parts.append(t) }
        return parts
    }
}
