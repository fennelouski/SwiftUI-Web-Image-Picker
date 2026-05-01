import XCTest
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
}
