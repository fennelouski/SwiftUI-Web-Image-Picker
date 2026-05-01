import Foundation

/// Collects raw URL strings from CSS `url(...)` tokens in inline styles and simple stylesheet text.
enum CSSImageURLExtractor {
    /// Every `url(...)` argument in `cssFragment` (e.g. one declaration value or an inline `style` attribute).
    static func urlArguments(from cssFragment: String) -> [String] {
        var results: [String] = []
        var searchStart = cssFragment.startIndex
        urlScan: while searchStart < cssFragment.endIndex,
                       let urlOpen = cssFragment[searchStart...].range(of: "url(", options: .caseInsensitive)
        {
            var idx = urlOpen.upperBound
            while idx < cssFragment.endIndex, cssFragment[idx].isWhitespace {
                idx = cssFragment.index(after: idx)
            }
            guard idx < cssFragment.endIndex else { break urlScan }

            let parseResult: (Substring, String.Index)? = {
                switch cssFragment[idx] {
                case "\"":
                    let contentStart = cssFragment.index(after: idx)
                    guard contentStart < cssFragment.endIndex,
                          let endQuote = cssFragment[contentStart...].firstIndex(of: "\"")
                    else { return nil }
                    var j = cssFragment.index(after: endQuote)
                    while j < cssFragment.endIndex, cssFragment[j].isWhitespace {
                        j = cssFragment.index(after: j)
                    }
                    guard j < cssFragment.endIndex, cssFragment[j] == ")" else { return nil }
                    let inner = cssFragment[contentStart..<endQuote]
                    return (inner, cssFragment.index(after: j))
                case "'":
                    let contentStart = cssFragment.index(after: idx)
                    guard contentStart < cssFragment.endIndex,
                          let endQuote = cssFragment[contentStart...].firstIndex(of: "'")
                    else { return nil }
                    var j = cssFragment.index(after: endQuote)
                    while j < cssFragment.endIndex, cssFragment[j].isWhitespace {
                        j = cssFragment.index(after: j)
                    }
                    guard j < cssFragment.endIndex, cssFragment[j] == ")" else { return nil }
                    let inner = cssFragment[contentStart..<endQuote]
                    return (inner, cssFragment.index(after: j))
                default:
                    guard let close = cssFragment[idx...].firstIndex(of: ")") else { return nil }
                    return (cssFragment[idx..<close], cssFragment.index(after: close))
                }
            }()

            guard let (extracted, resumeFrom) = parseResult else {
                searchStart = cssFragment.index(after: urlOpen.lowerBound)
                continue urlScan
            }

            let raw = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty {
                results.append(raw)
            }
            searchStart = resumeFrom
        }
        return results
    }

    /// `url(...)` arguments appearing in `background-image` and `background` declaration values inside stylesheet text.
    static func urlArgumentsFromBackgroundDeclarations(in stylesheet: String) -> [String] {
        var collected: [String] = []
        let patterns = [
            #"background-image\s*:\s*([^;}{\n]+)"#,
            #"background\s*:\s*([^;}{\n]+)"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let ns = stylesheet as NSString
            let full = NSRange(location: 0, length: ns.length)
            regex.enumerateMatches(in: stylesheet, options: [], range: full) { match, _, _ in
                guard let match, match.numberOfRanges >= 2 else { return }
                let valueRange = match.range(at: 1)
                guard valueRange.location != NSNotFound else { return }
                let value = ns.substring(with: valueRange)
                collected.append(contentsOf: urlArguments(from: value))
            }
        }
        return collected
    }
}
