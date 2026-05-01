import Foundation

extension WebImageExtractionMode {
    /// Default extractor for this mode. Additional modes keep this API stable for callers.
    public func makeExtractor() -> any PageImageExtractor {
        switch self {
        case .staticHTML:
            StaticHTMLExtractor()
        case .webView:
            WebViewPageImageExtractor()
        }
    }
}
