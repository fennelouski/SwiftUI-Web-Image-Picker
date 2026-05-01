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

    func testPerPageCapKeepsFirstImagesInDiscoveryOrder() async throws {
        let page = URL(string: "https://one.example/")!
        let u1 = URL(string: "https://cdn.example/1.png")!
        let u2 = URL(string: "https://cdn.example/2.png")!
        let u3 = URL(string: "https://cdn.example/3.png")!

        let extractor = MockPageImageExtractor(pageResults: [
            page: .success([
                DiscoveredImage(sourceURL: u1, accessibilityLabel: "a"),
                DiscoveredImage(sourceURL: u2, accessibilityLabel: "b"),
                DiscoveredImage(sourceURL: u3, accessibilityLabel: "c"),
            ]),
        ])

        var config = WebImagePickerConfiguration.default
        config.maximumDiscoveredImagesPerPage = 2

        let merge = await AggregatedPageImageDiscovery.discoverImages(
            pageURLs: [page],
            configuration: config,
            extractor: extractor
        )

        XCTAssertTrue(merge.failedPageURLs.isEmpty)
        XCTAssertEqual(merge.images.map(\.sourceURL), [u1, u2])
        XCTAssertEqual(merge.images.map(\.accessibilityLabel), ["a", "b"])
    }

    func testPerPageCapAppliesIndependentlyForEachPage() async throws {
        let a = URL(string: "https://a.example/")!
        let b = URL(string: "https://b.example/")!
        let imgsA = (1 ... 4).map { URL(string: "https://cdn.example/a\($0).png")! }
        let imgsB = (1 ... 3).map { URL(string: "https://cdn.example/b\($0).png")! }

        let extractor = MockPageImageExtractor(pageResults: [
            a: .success(imgsA.map { DiscoveredImage(sourceURL: $0, accessibilityLabel: nil) }),
            b: .success(imgsB.map { DiscoveredImage(sourceURL: $0, accessibilityLabel: nil) }),
        ])

        var config = WebImagePickerConfiguration.default
        config.maximumDiscoveredImagesPerPage = 2

        let merge = await AggregatedPageImageDiscovery.discoverImages(
            pageURLs: [a, b],
            configuration: config,
            extractor: extractor
        )

        XCTAssertEqual(
            merge.images.map(\.sourceURL),
            [imgsA[0], imgsA[1], imgsB[0], imgsB[1]]
        )
    }

    func testSimilarityDedupMergesQueryVariantsAcrossPages() async throws {
        let a = URL(string: "https://one.example/")!
        let b = URL(string: "https://two.example/")!
        let wide = URL(string: "https://cdn.example.com/photo.jpg?w=800")!
        let narrow = URL(string: "https://cdn.example.com/photo.jpg?w=400")!

        let extractor = MockPageImageExtractor(pageResults: [
            a: .success([DiscoveredImage(sourceURL: wide, accessibilityLabel: "a")]),
            b: .success([DiscoveredImage(sourceURL: narrow, accessibilityLabel: "b")]),
        ])

        var config = WebImagePickerConfiguration.default
        config.similarImageDeduplication = .normalizedResourceURL

        let merge = await AggregatedPageImageDiscovery.discoverImages(
            pageURLs: [a, b],
            configuration: config,
            extractor: extractor
        )

        XCTAssertTrue(merge.failedPageURLs.isEmpty)
        XCTAssertEqual(merge.images.count, 1)
        XCTAssertEqual(merge.images[0].sourceURL, wide)
        XCTAssertEqual(merge.images[0].accessibilityLabel, "a")
    }
}
