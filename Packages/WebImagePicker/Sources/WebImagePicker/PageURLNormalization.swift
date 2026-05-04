import Foundation

enum PageURLNormalization {
    enum ResolveResult: Equatable {
        case success(URL)
        case disallowedScheme
        case invalid
    }

    /// Resolves user-typed page locations into an absolute URL, prefixing a scheme when the user omits one (e.g. `example.com` → `https://example.com`).
    ///
    /// `true` when `trimmedInput` parses as an explicit `http` URL and `http` is not present in `allowedURLSchemes` (compared case-insensitively).
    static func isHTTPExplicitlyDisallowed(trimmedInput: String, allowedURLSchemes: Set<String>) -> Bool {
        let loweredAllowed = Set(allowedURLSchemes.map { $0.lowercased() })
        guard !loweredAllowed.contains("http") else { return false }
        let trimmed = trimmedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme == "http" else { return false }
        return true
    }

    /// Scheme choice follows `allowedURLSchemes` (`https` preferred, then `http`, then other allowed schemes). Protocol-relative URLs (`//host/path`) are resolved the same way.
    static func resolve(trimmedInput: String, allowedURLSchemes: Set<String>) -> ResolveResult {
        let trimmed = trimmedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .invalid }

        let loweredSchemes = Set(allowedURLSchemes.map { $0.lowercased() })

        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), !scheme.isEmpty {
            return loweredSchemes.contains(scheme) ? .success(url) : .disallowedScheme
        }

        if trimmed.hasPrefix("//") {
            return absoluteURL(byPrefixingSchemeToProtocolRelative: trimmed, allowedURLSchemes: loweredSchemes)
                .map { .success($0) } ?? .invalid
        }

        guard !trimmed.contains("://") else { return .invalid }

        return absoluteURL(byPrefixingSchemeToBareInput: trimmed, allowedURLSchemes: loweredSchemes)
            .map { .success($0) } ?? .invalid
    }

    private static func absoluteURL(byPrefixingSchemeToProtocolRelative path: String, allowedURLSchemes: Set<String>) -> URL? {
        for scheme in schemePrefixCandidates(for: allowedURLSchemes) {
            let combined = "\(scheme):" + path
            if let url = URL(string: combined), let s = url.scheme?.lowercased(), allowedURLSchemes.contains(s) {
                return url
            }
        }
        return nil
    }

    private static func absoluteURL(byPrefixingSchemeToBareInput path: String, allowedURLSchemes: Set<String>) -> URL? {
        for scheme in schemePrefixCandidates(for: allowedURLSchemes) {
            let combined = "\(scheme)://\(path)"
            if let url = URL(string: combined), let s = url.scheme?.lowercased(), allowedURLSchemes.contains(s) {
                return url
            }
        }
        return nil
    }

    private static func schemePrefixCandidates(for allowedURLSchemes: Set<String>) -> [String] {
        var ordered: [String] = []
        if allowedURLSchemes.contains("https") { ordered.append("https") }
        if allowedURLSchemes.contains("http") { ordered.append("http") }
        ordered.append(contentsOf: allowedURLSchemes.subtracting(["https", "http"]).sorted())
        return ordered
    }
}
