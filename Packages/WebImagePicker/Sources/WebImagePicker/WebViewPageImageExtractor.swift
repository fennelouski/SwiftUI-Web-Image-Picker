import Foundation

#if canImport(WebKit)
import WebKit
#endif

/// Extracts image URLs from a JavaScript-rendered DOM via `WKWebView`.
public struct WebViewPageImageExtractor: PageImageExtractor {
    public init() {}

    public func discoverImages(from pageURL: URL, configuration: WebImagePickerConfiguration) async throws -> [DiscoveredImage] {
        guard let scheme = pageURL.scheme?.lowercased(), configuration.allowedURLSchemes.contains(scheme) else {
            throw WebImagePickerError.invalidURL
        }

        #if canImport(WebKit)
        let rawCandidates = try await loadWithWebKit(
            from: pageURL,
            timeout: configuration.requestTimeout,
            userAgent: configuration.userAgent
        )

        return Self.normalize(rawCandidates: rawCandidates, pageURL: pageURL, configuration: configuration)
        #else
        throw WebImagePickerError.extractionFailed
        #endif
    }

    internal static func normalize(
        rawCandidates: [WebViewRawCandidate],
        pageURL: URL,
        configuration: WebImagePickerConfiguration
    ) -> [DiscoveredImage] {
        var seen = Set<String>()
        var images: [DiscoveredImage] = []

        func normalizedURL(from raw: String, kind: WebViewRawCandidate.Kind) -> URL? {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if trimmed.lowercased().hasPrefix("data:") { return nil }

            let resolvedURL: URL?
            switch kind {
            case .srcset:
                resolvedURL = SrcSetParser.bestURL(from: trimmed, baseURL: pageURL)
            case .url:
                resolvedURL = URL(string: trimmed, relativeTo: pageURL)?.absoluteURL
            }

            guard var resolved = resolvedURL else { return nil }
            guard let scheme = resolved.scheme?.lowercased(), configuration.allowedURLSchemes.contains(scheme) else {
                return nil
            }

            if var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false) {
                components.fragment = nil
                if let fragmentStripped = components.url {
                    resolved = fragmentStripped
                }
            }

            return resolved
        }

        for candidate in rawCandidates {
            guard let url = normalizedURL(from: candidate.value, kind: candidate.kind) else { continue }
            let key = url.absoluteString
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            let label = candidate.altText?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedLabel = label?.isEmpty == true ? nil : label

            images.append(DiscoveredImage(sourceURL: url, accessibilityLabel: cleanedLabel))
        }

        return images
    }
}

internal struct WebViewRawCandidate: Equatable, Sendable {
    internal enum Kind: String, Equatable, Sendable {
        case url
        case srcset
    }

    internal var value: String
    internal var altText: String?
    internal var kind: Kind
}

#if canImport(WebKit)
@MainActor
private func loadWithWebKit(from pageURL: URL, timeout: TimeInterval, userAgent: String?) async throws -> [WebViewRawCandidate] {
    let loader = WebViewDOMLoader()
    return try await loader.loadAndCollect(from: pageURL, timeout: timeout, userAgent: userAgent)
}

@MainActor
private final class WebViewDOMLoader: NSObject {
    private var continuation: CheckedContinuation<Void, Error>?
    private var webView: WKWebView?

    func loadAndCollect(from pageURL: URL, timeout: TimeInterval, userAgent: String?) async throws -> [WebViewRawCandidate] {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.customUserAgent = userAgent
        self.webView = webView

        let request = URLRequest(
            url: pageURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: timeout
        )
        webView.load(request)

        try await waitForNavigation(timeout: timeout)

        // Allow one runloop turn for post-load DOM updates.
        try await Task.sleep(nanoseconds: 300_000_000)

        return try await evaluateCandidates(in: webView)
    }

    private func waitForNavigation(timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(max(1, timeout) * 1_000_000_000))
                guard let self else { return }
                guard let continuation = self.continuation else { return }
                self.continuation = nil
                continuation.resume(throwing: WebImagePickerError.extractionFailed)
            }
        }
    }

    private func evaluateCandidates(in webView: WKWebView) async throws -> [WebViewRawCandidate] {
        let script = #"""
        (() => {
          const out = [];
          const push = (value, alt, kind) => {
            if (typeof value !== 'string') return;
            out.push({ value, altText: typeof alt === 'string' ? alt : null, kind });
          };

          document.querySelectorAll('img').forEach((img) => {
            push(img.currentSrc || img.src || '', img.alt || null, 'url');
            const srcset = img.getAttribute('srcset');
            if (srcset) push(srcset, img.alt || null, 'srcset');
          });

          document.querySelectorAll('picture source[srcset]').forEach((source) => {
            const srcset = source.getAttribute('srcset');
            if (srcset) push(srcset, null, 'srcset');
          });

          document.querySelectorAll('meta[property="og:image"],meta[name="twitter:image"],meta[name="twitter:image:src"]').forEach((meta) => {
            const content = meta.getAttribute('content');
            if (content) push(content, null, 'url');
          });

          return out;
        })();
        """#

        let any = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Any, Error>) in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result as Any)
            }
        }

        guard let items = any as? [[String: Any]] else {
            throw WebImagePickerError.extractionFailed
        }

        return items.compactMap { item in
            guard let value = item["value"] as? String else { return nil }
            let kindString = item["kind"] as? String ?? WebViewRawCandidate.Kind.url.rawValue
            let kind = WebViewRawCandidate.Kind(rawValue: kindString) ?? .url
            let altText = item["altText"] as? String
            return WebViewRawCandidate(value: value, altText: altText, kind: kind)
        }
    }
}

extension WebViewDOMLoader: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
#endif
