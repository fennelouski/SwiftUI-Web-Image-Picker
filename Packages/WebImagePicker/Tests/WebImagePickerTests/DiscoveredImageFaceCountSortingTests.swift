import XCTest
@testable import WebImagePicker

final class DiscoveredImageFaceCountSortingTests: XCTestCase {
    func testSortStableByFaceCountDescending() {
        let u1 = URL(string: "https://cdn.example/1.jpg")!
        let u2 = URL(string: "https://cdn.example/2.jpg")!
        let u3 = URL(string: "https://cdn.example/3.jpg")!
        let images = [
            DiscoveredImage(sourceURL: u1, accessibilityLabel: nil),
            DiscoveredImage(sourceURL: u2, accessibilityLabel: nil),
            DiscoveredImage(sourceURL: u3, accessibilityLabel: nil),
        ]
        let counts = [u1: 1, u2: 3, u3: 2]
        let out = DiscoveredImageFaceCountSorting.sortStableByFaceCount(images, counts: counts, descending: true)
        XCTAssertEqual(out.map(\.sourceURL), [u2, u3, u1])
    }

    func testSortStableByFaceCountAscendingTieBreaker() {
        let u1 = URL(string: "https://cdn.example/a.jpg")!
        let u2 = URL(string: "https://cdn.example/b.jpg")!
        let u3 = URL(string: "https://cdn.example/c.jpg")!
        let images = [
            DiscoveredImage(sourceURL: u1, accessibilityLabel: nil),
            DiscoveredImage(sourceURL: u2, accessibilityLabel: nil),
            DiscoveredImage(sourceURL: u3, accessibilityLabel: nil),
        ]
        let counts = [u1: 2, u2: 2, u3: 1]
        let out = DiscoveredImageFaceCountSorting.sortStableByFaceCount(images, counts: counts, descending: false)
        XCTAssertEqual(out.map(\.sourceURL), [u3, u1, u2])
    }
}
