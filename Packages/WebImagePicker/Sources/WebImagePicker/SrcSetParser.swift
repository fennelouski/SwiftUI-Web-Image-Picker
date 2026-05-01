import Foundation

enum SrcSetParser {
    /// Picks the highest-resolution candidate from a `srcset` string, resolving relative URLs against `baseURL`.
    static func bestURL(from srcset: String, baseURL: URL) -> URL? {
        let parts = srcset.split(separator: ",")
        var bestURL: URL?
        var bestScore: Double = -1

        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let tokens = trimmed.split(whereSeparator: { $0.isWhitespace })
            guard let first = tokens.first else { continue }
            let urlString = String(first)
            guard let candidate = URL(string: urlString, relativeTo: baseURL)?.absoluteURL else { continue }

            var score = 0.0
            if tokens.count > 1 {
                let descriptor = String(tokens[1]).lowercased()
                if descriptor.hasSuffix("w"), let w = Double(descriptor.dropLast()) {
                    score = w
                } else if descriptor.hasSuffix("x"), let x = Double(descriptor.dropLast()) {
                    score = x * 10_000
                }
            }

            if score > bestScore {
                bestScore = score
                bestURL = candidate
            }
        }

        return bestURL
    }
}
