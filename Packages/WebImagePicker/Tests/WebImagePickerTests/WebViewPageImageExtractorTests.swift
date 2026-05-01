import XCTest
@testable import WebImagePicker

final class WebViewPageImageExtractorTests: XCTestCase {
    private let config = WebImagePickerConfiguration(allowedURLSchemes: ["https", "http"])

    func testNormalizeResolvesRelativeAndStripsFragments() {
        let pageURL = URL(string: "https://example.com/news/post")!
        let candidates: [WebViewRawCandidate] = [
            .init(value: "/img/hero.png#section", altText: "Hero", kind: .url),
        ]

        let results = WebViewPageImageExtractor.normalize(
            rawCandidates: candidates,
            pageURL: pageURL,
            configuration: config
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].sourceURL.absoluteString, "https://example.com/img/hero.png")
        XCTAssertEqual(results[0].accessibilityLabel, "Hero")
    }

    func testNormalizePicksLargestSrcSetCandidate() {
        let pageURL = URL(string: "https://example.com/")!
        let candidates: [WebViewRawCandidate] = [
            .init(
                value: "/a.png 320w, https://cdn.example.com/b.png 1024w",
                altText: nil,
                kind: .srcset
            ),
        ]

        let results = WebViewPageImageExtractor.normalize(
            rawCandidates: candidates,
            pageURL: pageURL,
            configuration: config
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].sourceURL.absoluteString, "https://cdn.example.com/b.png")
    }

    func testNormalizeDedupesAndFiltersDisallowedSchemes() {
        let pageURL = URL(string: "https://example.com/page")!
        let restrictedConfig = WebImagePickerConfiguration(allowedURLSchemes: ["https"])
        let candidates: [WebViewRawCandidate] = [
            .init(value: "https://example.com/a.png", altText: nil, kind: .url),
            .init(value: "https://example.com/a.png", altText: "Duplicate", kind: .url),
            .init(value: "ftp://example.com/b.png", altText: nil, kind: .url),
        ]

        let results = WebViewPageImageExtractor.normalize(
            rawCandidates: candidates,
            pageURL: pageURL,
            configuration: restrictedConfig
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].sourceURL.absoluteString, "https://example.com/a.png")
    }

    func testNormalizeCollapsesQueryVariantsWhenSimilarityDedupEnabled() {
        var cfg = WebImagePickerConfiguration(allowedURLSchemes: ["https", "http"])
        cfg.similarImageDeduplication = .normalizedResourceURL
        let pageURL = URL(string: "https://example.com/")!
        let candidates: [WebViewRawCandidate] = [
            .init(value: "https://cdn.example.com/z.png?a=1", altText: "one", kind: .url),
            .init(value: "https://cdn.example.com/z.png?b=2", altText: "two", kind: .url),
        ]

        let results = WebViewPageImageExtractor.normalize(
            rawCandidates: candidates,
            pageURL: pageURL,
            configuration: cfg
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].sourceURL.absoluteString, "https://cdn.example.com/z.png?a=1")
        XCTAssertEqual(results[0].accessibilityLabel, "one")
    }
}
