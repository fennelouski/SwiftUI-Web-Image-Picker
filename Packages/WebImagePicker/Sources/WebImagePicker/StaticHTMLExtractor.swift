import Foundation
import SwiftSoup

/// Extracts image URLs from the server-rendered HTML of a page.
public struct StaticHTMLExtractor: PageImageExtractor {
    public init() {}

    public func discoverImages(from pageURL: URL, configuration: WebImagePickerConfiguration) async throws -> [DiscoveredImage] {
        guard let scheme = pageURL.scheme?.lowercased(), configuration.allowedURLSchemes.contains(scheme) else {
            throw WebImagePickerError.invalidURL
        }

        let html: String
        do {
            html = try await HTMLDocumentFetcher.fetchString(from: pageURL, configuration: configuration)
        } catch {
            throw error
        }

        do {
            return try Self.discover(from: html, pageURL: pageURL, configuration: configuration)
        } catch {
            throw WebImagePickerError.extractionFailed
        }
    }

    /// Exposed for `@testable` unit tests (HTML fixtures without networking).
    internal static func discover(
        from html: String,
        pageURL: URL,
        configuration: WebImagePickerConfiguration
    ) throws -> [DiscoveredImage] {
        let doc = try SwiftSoup.parse(html, pageURL.absoluteString)
        var seen = Set<String>()
        var images: [DiscoveredImage] = []

        func normalizedURL(from raw: String) -> URL? {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if trimmed.hasPrefix("#") { return nil }
            if trimmed.lowercased().hasPrefix("data:") { return nil }
            guard var resolved = URL(string: trimmed, relativeTo: pageURL)?.absoluteURL else { return nil }
            guard let sch = resolved.scheme?.lowercased(), configuration.allowedURLSchemes.contains(sch) else { return nil }
            if var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false) {
                components.fragment = nil
                if let withoutFragment = components.url {
                    resolved = withoutFragment
                }
            }
            return resolved
        }

        func append(raw: String?, alt: String?, title: String?) {
            guard let raw else { return }
            guard let url = normalizedURL(from: raw) else { return }
            let key = DiscoveredImageDeduplicationKey.string(
                for: url,
                strategy: configuration.similarImageDeduplication
            )
            guard !seen.contains(key) else { return }
            seen.insert(key)
            let label = alt.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
            let titleLabel = title.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
            images.append(DiscoveredImage(sourceURL: url, accessibilityLabel: label, title: titleLabel))
        }

        let imgs = try doc.select("img[src], img[srcset]")
        for element in imgs.array() {
            let alt = try? element.attr("alt")
            let imgTitle = try? element.attr("title")
            if let srcset = try? element.attr("srcset"), !srcset.isEmpty,
               let picked = SrcSetParser.bestURL(from: srcset, baseURL: pageURL)
            {
                append(raw: picked.absoluteString, alt: alt, title: imgTitle)
            } else if let src = try? element.attr("src") {
                append(raw: src, alt: alt, title: imgTitle)
            }
        }

        let pictureSources = try doc.select("picture source[srcset]")
        for element in pictureSources.array() {
            if let srcset = try? element.attr("srcset"), !srcset.isEmpty,
               let picked = SrcSetParser.bestURL(from: srcset, baseURL: pageURL)
            {
                append(raw: picked.absoluteString, alt: nil, title: nil)
            }
        }

        let ogImages = try doc.select("meta[property=og:image]")
        for element in ogImages.array() {
            if let content = try? element.attr("content") {
                append(raw: content, alt: nil, title: nil)
            }
        }

        let twitterImages = try doc.select("meta[name=twitter:image], meta[name=twitter:image:src]")
        for element in twitterImages.array() {
            if let content = try? element.attr("content") {
                append(raw: content, alt: nil, title: nil)
            }
        }

        let inlineStyled = try doc.select("[style]")
        for element in inlineStyled.array() {
            if let style = try? element.attr("style"), !style.isEmpty {
                for raw in CSSImageURLExtractor.urlArguments(from: style) {
                    append(raw: raw, alt: nil, title: nil)
                }
            }
        }

        let styleBlocks = try doc.select("style")
        for element in styleBlocks.array() {
            let css = (try? element.html()) ?? ""
            if css.isEmpty { continue }
            for raw in CSSImageURLExtractor.urlArgumentsFromBackgroundDeclarations(in: css) {
                append(raw: raw, alt: nil, title: nil)
            }
        }

        return images
    }
}
