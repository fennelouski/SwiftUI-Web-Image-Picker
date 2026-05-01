import XCTest
@testable import WebImagePicker

final class DiscoveredImageMetadataExclusionTests: XCTestCase {
    private let cfg = WebImagePickerConfiguration.default

    func testNoRulesReturnsAll() {
        let a = DiscoveredImage(sourceURL: URL(string: "https://x.com/a.png")!, accessibilityLabel: "hi", title: nil)
        let out = DiscoveredImageMetadataExclusion.filter([a], configuration: cfg, recognizedTextByURL: nil)
        XCTAssertEqual(out.count, 1)
    }

    func testSubstringBlocksByURL() {
        var c = WebImagePickerConfiguration.default
        c.excludedImageMetadataSubstrings = ["badhost"]
        let bad = DiscoveredImage(sourceURL: URL(string: "https://badhost.example/img.png")!, accessibilityLabel: nil, title: nil)
        let good = DiscoveredImage(sourceURL: URL(string: "https://good.example/img.png")!, accessibilityLabel: nil, title: nil)
        let out = DiscoveredImageMetadataExclusion.filter([bad, good], configuration: c, recognizedTextByURL: nil)
        XCTAssertEqual(out.map(\.sourceURL.host), ["good.example"])
    }

    func testSubstringIsCaseInsensitive() {
        var c = WebImagePickerConfiguration.default
        c.excludedImageMetadataSubstrings = ["TRACK"]
        let img = DiscoveredImage(sourceURL: URL(string: "https://cdn.example/pixel.gif")!, accessibilityLabel: "tracking", title: nil)
        let out = DiscoveredImageMetadataExclusion.filter([img], configuration: c, recognizedTextByURL: nil)
        XCTAssertTrue(out.isEmpty)
    }

    func testSubstringBlocksByTitleAndAlt() {
        var c = WebImagePickerConfiguration.default
        c.excludedImageMetadataSubstrings = ["spam"]
        let byAlt = DiscoveredImage(sourceURL: URL(string: "https://x.com/1.png")!, accessibilityLabel: "Spam banner", title: nil)
        let byTitle = DiscoveredImage(sourceURL: URL(string: "https://x.com/2.png")!, accessibilityLabel: nil, title: "Hero")
        let clean = DiscoveredImage(sourceURL: URL(string: "https://x.com/3.png")!, accessibilityLabel: "logo", title: nil)
        let out = DiscoveredImageMetadataExclusion.filter([byAlt, byTitle, clean], configuration: c, recognizedTextByURL: nil)
        XCTAssertEqual(out.map(\.sourceURL.lastPathComponent), ["2.png", "3.png"])
    }

    func testRegexBlocks() {
        var c = WebImagePickerConfiguration.default
        c.excludedImageMetadataRegularExpressionPatterns = ["\\d{4,}-\\d{2}-\\d{2}"]
        let stamped = DiscoveredImage(sourceURL: URL(string: "https://x.com/photo-2024-01-01.jpg")!, accessibilityLabel: nil, title: nil)
        let plain = DiscoveredImage(sourceURL: URL(string: "https://x.com/hero.jpg")!, accessibilityLabel: nil, title: nil)
        let out = DiscoveredImageMetadataExclusion.filter([stamped, plain], configuration: c, recognizedTextByURL: nil)
        XCTAssertEqual(out.map(\.sourceURL.lastPathComponent), ["hero.jpg"])
    }

    func testOCRHaystackUsedWhenProvided() {
        var c = WebImagePickerConfiguration.default
        c.excludedImageMetadataSubstrings = ["secretcode"]
        let url = URL(string: "https://x.com/q.png")!
        let img = DiscoveredImage(sourceURL: url, accessibilityLabel: "x", title: nil)
        let ocr: [URL: String] = [url: "User secretcode visible"]
        let out = DiscoveredImageMetadataExclusion.filter([img], configuration: c, recognizedTextByURL: ocr)
        XCTAssertTrue(out.isEmpty)
    }

    func testInvalidRegexPatternIgnored() {
        var c = WebImagePickerConfiguration.default
        c.excludedImageMetadataRegularExpressionPatterns = ["("]
        let img = DiscoveredImage(sourceURL: URL(string: "https://x.com/ok.png")!, accessibilityLabel: nil, title: nil)
        let out = DiscoveredImageMetadataExclusion.filter([img], configuration: c, recognizedTextByURL: nil)
        XCTAssertEqual(out.count, 1)
    }
}
