import XCTest
import UniformTypeIdentifiers
@testable import WebImagePicker

final class DiscoveredImageMetadataSearchTests: XCTestCase {
    private let base = URL(string: "https://example.com/photos/sunset.jpg")!

    func testEmptyQueryReturnsAll() {
        let images = [
            DiscoveredImage(sourceURL: base, accessibilityLabel: "Sun", title: nil),
            DiscoveredImage(sourceURL: URL(string: "https://other.test/a.png")!, accessibilityLabel: nil, title: nil),
        ]
        let out = DiscoveredImageMetadataSearch.filteredDiscoveries(images, rawQuery: "")
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out.map(\.id), images.map(\.id))
    }

    func testWhitespaceOnlyQueryReturnsAll() {
        let images = [DiscoveredImage(sourceURL: base, accessibilityLabel: "A", title: nil)]
        let out = DiscoveredImageMetadataSearch.filteredDiscoveries(images, rawQuery: "  \t")
        XCTAssertEqual(out.count, 1)
    }

    func testMatchesAltCaseInsensitive() {
        let img = DiscoveredImage(sourceURL: base, accessibilityLabel: "Golden Hour", title: nil)
        XCTAssertTrue(DiscoveredImageMetadataSearch.matches(img, rawQuery: "golden"))
        XCTAssertFalse(DiscoveredImageMetadataSearch.matches(img, rawQuery: "moon"))
    }

    func testMatchesTitleCaseInsensitive() {
        let img = DiscoveredImage(sourceURL: base, accessibilityLabel: nil, title: "Beach at dusk")
        XCTAssertTrue(DiscoveredImageMetadataSearch.matches(img, rawQuery: "BEACH"))
        XCTAssertFalse(DiscoveredImageMetadataSearch.matches(img, rawQuery: "mountain"))
    }

    func testMatchesURLPathAndFullString() {
        let img = DiscoveredImage(sourceURL: base, accessibilityLabel: nil, title: nil)
        XCTAssertTrue(DiscoveredImageMetadataSearch.matches(img, rawQuery: "photos"))
        XCTAssertTrue(DiscoveredImageMetadataSearch.matches(img, rawQuery: "example.com"))
    }

    func testFilteredListExcludesNonMatching() {
        let a = DiscoveredImage(sourceURL: URL(string: "https://x.com/one.png")!, accessibilityLabel: "cat", title: nil)
        let b = DiscoveredImage(sourceURL: URL(string: "https://x.com/two.png")!, accessibilityLabel: "dog", title: nil)
        let out = DiscoveredImageMetadataSearch.filteredDiscoveries([a, b], rawQuery: "cat")
        XCTAssertEqual(out.map(\.sourceURL.absoluteString), [a.sourceURL.absoluteString])
    }

    // MARK: - format: tokens

    func testSplitFormatTokensCaseInsensitiveAndStripsFromText() {
        let parsed = DiscoveredImageMetadataSearch.splitFormatTokens(from: "logo FORMAT:PNG extra")
        XCTAssertEqual(parsed.tokens, ["png"])
        XCTAssertEqual(parsed.text.trimmingCharacters(in: .whitespacesAndNewlines), "logo  extra")
    }

    func testSplitFormatTokensMultipleOrSemantics() {
        let parsed = DiscoveredImageMetadataSearch.splitFormatTokens(from: "format:png format:webp")
        XCTAssertEqual(parsed.tokens, ["png", "webp"])
        XCTAssertTrue(parsed.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testFormatTokenFiltersByExtension() {
        let jpg = DiscoveredImage(sourceURL: URL(string: "https://x.com/a.jpg")!, accessibilityLabel: "a", title: nil)
        let png = DiscoveredImage(sourceURL: URL(string: "https://x.com/b.png")!, accessibilityLabel: "b", title: nil)
        let out = DiscoveredImageMetadataSearch.filteredDiscoveries([jpg, png], rawQuery: "format:png")
        XCTAssertEqual(out.map(\.sourceURL.lastPathComponent), ["b.png"])
    }

    func testFormatTokenJpegMatchesJpgExtension() {
        let jpg = DiscoveredImage(sourceURL: URL(string: "https://x.com/a.jpg")!, accessibilityLabel: nil, title: nil)
        let png = DiscoveredImage(sourceURL: URL(string: "https://x.com/b.png")!, accessibilityLabel: nil, title: nil)
        let out = DiscoveredImageMetadataSearch.filteredDiscoveries([jpg, png], rawQuery: "format:jpeg")
        XCTAssertEqual(out.map(\.sourceURL.lastPathComponent), ["a.jpg"])
    }

    func testTextPlusFormatTokenRequiresBoth() {
        let catPng = DiscoveredImage(sourceURL: URL(string: "https://x.com/cat.png")!, accessibilityLabel: "x", title: nil)
        let dogPng = DiscoveredImage(sourceURL: URL(string: "https://x.com/dog.png")!, accessibilityLabel: "x", title: nil)
        let catJpg = DiscoveredImage(sourceURL: URL(string: "https://x.com/cat.jpg")!, accessibilityLabel: "x", title: nil)
        let out = DiscoveredImageMetadataSearch.filteredDiscoveries([catPng, dogPng, catJpg], rawQuery: "cat format:png")
        XCTAssertEqual(out.map(\.sourceURL.lastPathComponent), ["cat.png"])
    }

    func testFormatTokenIntersectsAllowlist() {
        var cfg = WebImagePickerConfiguration(allowedURLSchemes: ["https"])
        cfg.allowedImageTypeIdentifiers = [UTType.jpeg.identifier]
        let jpg = DiscoveredImage(sourceURL: URL(string: "https://x.com/a.jpg")!, accessibilityLabel: nil, title: nil)
        let png = DiscoveredImage(sourceURL: URL(string: "https://x.com/b.png")!, accessibilityLabel: nil, title: nil)
        let onlyPng = DiscoveredImageMetadataSearch.filteredDiscoveries([jpg, png], rawQuery: "format:png", configuration: cfg)
        XCTAssertTrue(onlyPng.isEmpty)
        let onlyJpeg = DiscoveredImageMetadataSearch.filteredDiscoveries([jpg, png], rawQuery: "format:jpeg", configuration: cfg)
        XCTAssertEqual(onlyJpeg.count, 1)
        XCTAssertEqual(onlyJpeg[0].sourceURL.lastPathComponent, "a.jpg")
    }

    func testUnknownFormatTokenMatchesNothingWhenOnlyTokens() {
        let png = DiscoveredImage(sourceURL: URL(string: "https://x.com/b.png")!, accessibilityLabel: nil, title: nil)
        let out = DiscoveredImageMetadataSearch.filteredDiscoveries([png], rawQuery: "format:notarealext")
        XCTAssertTrue(out.isEmpty)
    }

    func testRecognizedImageTextParticipatesInSearch() {
        let url = URL(string: "https://x.com/photo.jpg")!
        let img = DiscoveredImage(sourceURL: url, accessibilityLabel: nil, title: nil)
        let ocr: [URL: String] = [url: "Quarterly Report 2024"]
        XCTAssertTrue(DiscoveredImageMetadataSearch.matches(img, rawQuery: "quarterly", recognizedTextByURL: ocr))
        let out = DiscoveredImageMetadataSearch.filteredDiscoveries([img], rawQuery: "2024", recognizedTextByURL: ocr)
        XCTAssertEqual(out.count, 1)
    }
}
