import XCTest
@testable import WebImagePicker

private struct MockPageImageExtractor: PageImageExtractor {
    var pageResults: [URL: Result<[DiscoveredImage], Error>]
    private static let missing = NSError(domain: "test", code: 0)

    func discoverImages(from pageURL: URL, configuration: WebImagePickerConfiguration) async throws -> [DiscoveredImage] {
        guard let result = pageResults[pageURL] else {
            throw Self.missing
        }
        return try result.get()
    }
}

final class AggregatedPageImageDiscoveryTests: XCTestCase {
    func testMergePreservesPageOrderAndDedupesImageURLs() async throws {
        let a = URL(string: "https://one.example/")!
        let b = URL(string: "https://two.example/")!
        let img1 = URL(string: "https://cdn.example/1.png")!
        let img2 = URL(string: "https://cdn.example/2.png")!
        let img3 = URL(string: "https://cdn.example/3.png")!

        let extractor = MockPageImageExtractor(pageResults: [
            a: .success([
                DiscoveredImage(sourceURL: img1, accessibilityLabel: nil),
                DiscoveredImage(sourceURL: img2, accessibilityLabel: nil),
            ]),
            b: .success([
                DiscoveredImage(sourceURL: img2, accessibilityLabel: "dup"),
                DiscoveredImage(sourceURL: img3, accessibilityLabel: nil),
            ]),
        ])

        let merge = await AggregatedPageImageDiscovery.discoverImages(
            pageURLs: [a, b],
            configuration: .default,
            extractor: extractor
        )

        XCTAssertTrue(merge.failedPageURLs.isEmpty)
        XCTAssertEqual(merge.images.map(\.sourceURL), [img1, img2, img3])
        XCTAssertNil(merge.images[1].accessibilityLabel)
    }

    func testOneFailingPageDoesNotDropImagesFromOthers() async throws {
        let good = URL(string: "https://good.example/")!
        let bad = URL(string: "https://bad.example/")!
        let img = URL(string: "https://cdn.example/x.jpg")!

        struct E: Error {}
        let extractor = MockPageImageExtractor(pageResults: [
            good: .success([DiscoveredImage(sourceURL: img, accessibilityLabel: nil)]),
            bad: .failure(E()),
        ])

        let merge = await AggregatedPageImageDiscovery.discoverImages(
            pageURLs: [good, bad],
            configuration: .default,
            extractor: extractor
        )

        XCTAssertEqual(merge.failedPageURLs, [bad])
        XCTAssertEqual(merge.images.count, 1)
        XCTAssertEqual(merge.images.first?.sourceURL, img)
    }

    func testAllPagesThrowMarksEveryFailure() async throws {
        let u1 = URL(string: "https://a.example/")!
        let u2 = URL(string: "https://b.example/")!
        struct E: Error {}
        let extractor = MockPageImageExtractor(pageResults: [
            u1: .failure(E()),
            u2: .failure(E()),
        ])

        let merge = await AggregatedPageImageDiscovery.discoverImages(
            pageURLs: [u1, u2],
            configuration: .default,
            extractor: extractor
        )

        XCTAssertEqual(Set(merge.failedPageURLs), Set([u1, u2]))
        XCTAssertTrue(merge.images.isEmpty)
    }
}
