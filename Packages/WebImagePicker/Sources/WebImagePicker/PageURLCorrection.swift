import Foundation

/// Generates alternate page URL strings when the user's first load attempt fails.
enum PageURLCorrection {
    /// Whether smart fallback heuristics may run for this input.
    static func isEligibleForCorrection(trimmedInput: String) -> Bool {
        let trimmed = trimmedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.contains(where: \.isWhitespace) { return false }
        if trimmed.contains("@") { return false }
        guard let host = parsedHost(from: trimmed), !host.isEmpty else { return false }
        if host.localizedCaseInsensitiveContains("localhost") { return false }
        if isIPv4Literal(host) { return false }
        return host.range(of: #"^[a-zA-Z0-9\-\.]+$"#, options: .regularExpression) != nil
    }

    /// Ordered, deduplicated alternate strings (excluding the original input). Pass each through ``PageURLNormalization/resolve``.
    static func correctionCandidates(
        trimmedInput: String,
        strategy: SmartURLFallbackTLDStrategy,
        maximumCandidates: Int
    ) -> [String] {
        let trimmed = trimmedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEligibleForCorrection(trimmedInput: trimmed) else { return [] }
        guard maximumCandidates > 0 else { return [] }

        let parsed = parseInput(trimmed)
        guard let host = parsed.host, !host.isEmpty else { return [] }

        var hosts: [String] = []
        let suffix = parsed.pathSuffix

        switch strategy {
        case .conservative, .moderate:
            hosts.append(contentsOf: hostsByAppendingTLDs(to: host, tlds: moderateTLDSuffixes(for: host)))
            if shouldReplaceSuspiciousShortTLD(host: host) {
                let base = registrableDomainLabel(from: host)
                hosts.append(contentsOf: hostsByAppendingTLDs(to: base, tlds: [".com"]))
            }
        case .aggressive:
            if !host.contains(".") {
                hosts.append(contentsOf: hostsByAppendingTLDs(to: host, tlds: aggressiveTLDSuffixes()))
            } else if shouldReplaceSuspiciousShortTLD(host: host) {
                let base = registrableDomainLabel(from: host)
                hosts.append(contentsOf: hostsByAppendingTLDs(to: base, tlds: aggressiveTLDSuffixes()))
            }
            if !host.lowercased().hasPrefix("www.") {
                let wwwHost = "www.\(host.contains(".") ? host : host + ".com")"
                hosts.append(wwwHost)
                if shouldReplaceSuspiciousShortTLD(host: host) {
                    let base = registrableDomainLabel(from: host)
                    hosts.append("www.\(base).com")
                }
            }
        }

        var results: [String] = []
        var seen = Set<String>()
        let originalNormalized = trimmed.lowercased()

        func appendCandidate(host candidateHost: String) {
            let combined = candidateHost + suffix
            let lowered = combined.lowercased()
            guard lowered != originalNormalized else { return }
            guard seen.insert(lowered).inserted else { return }
            results.append(reconstruct(trimmedInput: trimmed, parsed: parsed, host: candidateHost, pathSuffix: suffix))
        }

        for candidateHost in hosts {
            appendCandidate(host: candidateHost)
            if results.count >= maximumCandidates { break }
        }

        return Array(results.prefix(maximumCandidates))
    }

    /// Display-friendly host + path for updating the URL field after a successful correction.
    static func displayString(for url: URL) -> String {
        var display = url.host ?? url.absoluteString
        if let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path,
           path != "/", !path.isEmpty {
            display += path
        }
        if let query = url.query, !query.isEmpty {
            display += "?\(query)"
        }
        return display
    }

    // MARK: - Parsing

    private struct ParsedInput {
        var schemePrefix: String?
        var host: String?
        var pathSuffix: String
    }

    private static func parseInput(_ trimmed: String) -> ParsedInput {
        if let schemeRange = trimmed.range(of: "://") {
            let scheme = String(trimmed[..<schemeRange.lowerBound])
            let remainder = String(trimmed[schemeRange.upperBound...])
            let split = splitHostAndPath(remainder)
            return ParsedInput(schemePrefix: "\(scheme)://", host: split.host, pathSuffix: split.pathSuffix)
        }
        if trimmed.hasPrefix("//") {
            let remainder = String(trimmed.dropFirst(2))
            let split = splitHostAndPath(remainder)
            return ParsedInput(schemePrefix: "//", host: split.host, pathSuffix: split.pathSuffix)
        }
        let split = splitHostAndPath(trimmed)
        return ParsedInput(schemePrefix: nil, host: split.host, pathSuffix: split.pathSuffix)
    }

    private static func splitHostAndPath(_ remainder: String) -> (host: String?, pathSuffix: String) {
        let hostEnd = remainder.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) ?? remainder.endIndex
        let hostPort = String(remainder[..<hostEnd])
        let pathSuffix = hostEnd < remainder.endIndex ? String(remainder[hostEnd...]) : ""
        let host: String
        if let colon = hostPort.lastIndex(of: ":"),
           hostPort[hostPort.index(after: colon)...].allSatisfy(\.isNumber) {
            host = String(hostPort[..<colon])
        } else {
            host = hostPort
        }
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmedHost.isEmpty ? nil : trimmedHost, pathSuffix)
    }

    private static func parsedHost(from trimmed: String) -> String? {
        parseInput(trimmed).host
    }

    private static func reconstruct(trimmedInput: String, parsed: ParsedInput, host: String, pathSuffix: String) -> String {
        if let scheme = parsed.schemePrefix {
            return scheme + host + pathSuffix
        }
        return host + pathSuffix
    }

    // MARK: - TLD heuristics

    private static func hostsByAppendingTLDs(to label: String, tlds: [String]) -> [String] {
        tlds.map { label + $0 }
    }

    private static func aggressiveTLDSuffixes() -> [String] {
        var tlds = [".com", ".net", ".org"]
        if let region = Locale.current.region?.identifier.lowercased(), region.count == 2 {
            let regional = ".\(region)"
            if !tlds.contains(regional) {
                tlds.append(regional)
            }
        }
        tlds.append(contentsOf: [".io", ".co"])
        return tlds
    }

    private static func moderateTLDSuffixes(for host: String) -> [String] {
        if host.contains(".") {
            return [".com"]
        }
        return [".com", ".net"]
    }

    private static func registrableDomainLabel(from host: String) -> String {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return host }
        return String(parts[0])
    }

    private static func shouldReplaceSuspiciousShortTLD(host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2, let tld = parts.last else { return !host.contains(".") }
        let tldString = String(tld).lowercased()
        if tldString.count <= 2 {
            return !knownCCTLDs.contains(tldString)
        }
        return false
    }

    /// Common ISO 3166-1 alpha-2 ccTLDs; used to avoid rewriting intentional short TLDs like `.co`.
    private static let knownCCTLDs: Set<String> = [
        "ac", "ad", "ae", "af", "ag", "ai", "al", "am", "ao", "aq", "ar", "as", "at", "au", "aw", "ax", "az",
        "ba", "bb", "bd", "be", "bf", "bg", "bh", "bi", "bj", "bm", "bn", "bo", "br", "bs", "bt", "bw", "by", "bz",
        "ca", "cc", "cd", "cf", "cg", "ch", "ci", "ck", "cl", "cm", "cn", "co", "cr", "cu", "cv", "cw", "cx", "cy", "cz",
        "de", "dj", "dk", "dm", "do", "dz",
        "ec", "ee", "eg", "er", "es", "et", "eu",
        "fi", "fj", "fk", "fm", "fo", "fr",
        "ga", "gb", "gd", "ge", "gf", "gg", "gh", "gi", "gl", "gm", "gn", "gp", "gq", "gr", "gs", "gt", "gu", "gw", "gy",
        "hk", "hm", "hn", "hr", "ht", "hu",
        "id", "ie", "il", "im", "in", "io", "iq", "ir", "is", "it",
        "je", "jm", "jo", "jp",
        "ke", "kg", "kh", "ki", "km", "kn", "kp", "kr", "kw", "ky", "kz",
        "la", "lb", "lc", "li", "lk", "lr", "ls", "lt", "lu", "lv", "ly",
        "ma", "mc", "md", "me", "mg", "mh", "mk", "ml", "mm", "mn", "mo", "mp", "mq", "mr", "ms", "mt", "mu", "mv", "mw", "mx", "my", "mz",
        "na", "nc", "ne", "nf", "ng", "ni", "nl", "no", "np", "nr", "nu", "nz",
        "om",
        "pa", "pe", "pf", "pg", "ph", "pk", "pl", "pm", "pn", "pr", "ps", "pt", "pw", "py",
        "qa",
        "re", "ro", "rs", "ru", "rw",
        "sa", "sb", "sc", "sd", "se", "sg", "sh", "si", "sk", "sl", "sm", "sn", "so", "sr", "ss", "st", "sv", "sx", "sy", "sz",
        "tc", "td", "tf", "tg", "th", "tj", "tk", "tl", "tm", "tn", "to", "tr", "tt", "tv", "tw", "tz",
        "ua", "ug", "uk", "us", "uy", "uz",
        "va", "vc", "ve", "vg", "vi", "vn", "vu",
        "wf", "ws",
        "ye", "yt",
        "za", "zm", "zw",
    ]

    private static func isIPv4Literal(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let value = Int(part), value >= 0, value <= 255 else { return false }
            return true
        }
    }
}
