import XCTest
@testable import WebImagePicker

final class StaticHTMLExtractorTests: XCTestCase {
    private let defaultConfig = WebImagePickerConfiguration(allowedURLSchemes: ["https", "http"])

    func testResolvesRelativeImgSrc() throws {
        let html = #"<html><body><img src="/a.png" alt="Logo"></body></html>"#
        let page = URL(string: "https://example.com/page")!
        let items = try StaticHTMLExtractor.discover(from: html, pageURL: page, configuration: defaultConfig)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].sourceURL.absoluteString, "https://example.com/a.png")
        XCTAssertEqual(items[0].accessibilityLabel, "Logo")
    }

    func testSrcsetPicksLargestWidth() throws {
        let html = #"""
        <img src="/tiny.png" srcset="https://cdn.example.com/small.png 480w, https://cdn.example.com/big.png 800w" alt="">
        """#
        let page = URL(string: "https://example.com/")!
        let items = try StaticHTMLExtractor.discover(from: html, pageURL: page, configuration: defaultConfig)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].sourceURL.absoluteString, "https://cdn.example.com/big.png")
    }

    func testDedupesSameAbsoluteURL() throws {
        let html = #"""
        <meta property="og:image" content="https://example.com/x.png">
        <img src="https://example.com/x.png" alt="">
        """#
        let page = URL(string: "https://example.com/")!
        let items = try StaticHTMLExtractor.discover(from: html, pageURL: page, configuration: defaultConfig)
        XCTAssertEqual(items.count, 1)
    }

    func testFiltersByAllowedScheme() throws {
        let html = #"<img src="ftp://bad.example/a.png">"#
        let page = URL(string: "https://example.com/")!
        let config = WebImagePickerConfiguration(allowedURLSchemes: ["https"])
        let items = try StaticHTMLExtractor.discover(from: html, pageURL: page, configuration: config)
        XCTAssertTrue(items.isEmpty)
    }

    func testFixtureSamplePage() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "sample", withExtension: "html", subdirectory: "Fixtures"))
        let html = try String(contentsOf: url)
        let page = URL(string: "https://news.example.com/article")!
        let items = try StaticHTMLExtractor.discover(from: html, pageURL: page, configuration: defaultConfig)
        XCTAssertGreaterThanOrEqual(items.count, 3)
        XCTAssertTrue(items.contains { $0.sourceURL.absoluteString.contains("hero.jpg") })
        XCTAssertTrue(items.contains { $0.sourceURL.absoluteString.contains("og-card.png") })
    }

    func testSrcSetParserUnit() {
        let base = URL(string: "https://example.com/")!
        let srcset = "/a.png 320w, /b.png 640w"
        let picked = SrcSetParser.bestURL(from: srcset, baseURL: base)
        XCTAssertEqual(picked?.absoluteString, "https://example.com/b.png")
    }
}
