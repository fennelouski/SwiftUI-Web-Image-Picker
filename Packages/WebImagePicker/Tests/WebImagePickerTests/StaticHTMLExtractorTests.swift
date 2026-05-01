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

    /// Document order for static extraction: `<img>` elements (DOM order) before Open Graph / Twitter meta images.
    func testImgElementsPrecedeOgImageInDiscoveryOrder() throws {
        let html = #"""
        <html><body>
        <img src="https://example.com/first.png" alt="">
        <meta property="og:image" content="https://example.com/og.png">
        </body></html>
        """#
        let page = URL(string: "https://example.com/")!
        let items = try StaticHTMLExtractor.discover(from: html, pageURL: page, configuration: defaultConfig)
        XCTAssertEqual(items.map(\.sourceURL.absoluteString), [
            "https://example.com/first.png",
            "https://example.com/og.png",
        ])
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

    func testInlineStyleBackgroundImageURL() throws {
        let html = #"""
        <div style="background-image: url('/root.png'), url(tile.png); color: red"></div>
        """#
        let page = URL(string: "https://example.com/dir/page")!
        let items = try StaticHTMLExtractor.discover(from: html, pageURL: page, configuration: defaultConfig)
        XCTAssertEqual(items.count, 2)
        let urls = Set(items.map(\.sourceURL.absoluteString))
        XCTAssertEqual(urls, ["https://example.com/root.png", "https://example.com/dir/tile.png"])
        XCTAssertTrue(items.allSatisfy { $0.accessibilityLabel == nil })
    }

    func testStyleTagBackgroundDeclarations() throws {
        let html = #"""
        <style>
          .hero { background-image: url("https://cdn.example.com/hero.webp"); }
          .banner { background: no-repeat center url(/tile.png); }
        </style>
        """#
        let page = URL(string: "https://example.com/")!
        let items = try StaticHTMLExtractor.discover(from: html, pageURL: page, configuration: defaultConfig)
        XCTAssertEqual(items.count, 2)
        let urls = Set(items.map(\.sourceURL.absoluteString))
        XCTAssertEqual(urls, [
            "https://cdn.example.com/hero.webp",
            "https://example.com/tile.png",
        ])
    }

    func testDataAndFragmentURLsInCSSAreIgnored() throws {
        let html = #"""
        <div style="background-image: url(data:image/png;base64,AAAA), url(#sprite), url('https://example.com/ok.png')"></div>
        """#
        let page = URL(string: "https://example.com/")!
        let items = try StaticHTMLExtractor.discover(from: html, pageURL: page, configuration: defaultConfig)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].sourceURL.absoluteString, "https://example.com/ok.png")
    }

    func testCSSURLExtractorUnit() {
        let css = #"url( /a.png ), URL("https://x.test/b.png")"#
        let args = CSSImageURLExtractor.urlArguments(from: css)
        XCTAssertEqual(args, ["/a.png", "https://x.test/b.png"])
    }
}
