import XCTest
@testable import WebImagePicker

private final class PageCallLog: @unchecked Sendable {
    var urls: [URL] = []
}

private struct OrderedMockExtractor: PageImageExtractor {
    let log: PageCallLog
    let imagesByPage: [URL: [DiscoveredImage]]

    func discoverImages(from pageURL: URL, configuration: WebImagePickerConfiguration) async throws -> [DiscoveredImage] {
        log.urls.append(pageURL)
        return imagesByPage[pageURL] ?? []
    }
}

private struct SplitSuccessFailureExtractor: PageImageExtractor {
    let successPage: URL
    let images: [DiscoveredImage]
    struct Boom: Error {}

    func discoverImages(from pageURL: URL, configuration: WebImagePickerConfiguration) async throws -> [DiscoveredImage] {
        if pageURL == successPage {
            return images
        }
        throw Boom()
    }
}

@MainActor
final class WebImagePickerViewModelMultiURLTests: XCTestCase {
    func testConfigOnlyAdditionalURLsLoadsWithoutPrimaryField() async throws {
        let p1 = URL(string: "https://one.example/")!
        let p2 = URL(string: "https://two.example/")!
        let i1 = URL(string: "https://cdn.example/a.png")!
        let i2 = URL(string: "https://cdn.example/b.png")!

        let log = PageCallLog()
        let extractor = OrderedMockExtractor(
            log: log,
            imagesByPage: [
                p1: [DiscoveredImage(sourceURL: i1, accessibilityLabel: nil)],
                p2: [DiscoveredImage(sourceURL: i2, accessibilityLabel: nil)],
            ]
        )

        let config = WebImagePickerConfiguration(additionalPageURLs: [p1, p2])
        let model = WebImagePickerViewModel(configuration: config, extractorOverride: extractor)
        XCTAssertTrue(model.urlString.isEmpty)
        XCTAssertTrue(model.canStartLoad)

        await model.loadPage()

        XCTAssertEqual(model.phase, .browsing)
        XCTAssertEqual(model.discovered.map(\.sourceURL), [i1, i2])
        XCTAssertEqual(log.urls, [p1, p2])
    }

    func testPartialFailureStillBrowsesWithNotice() async throws {
        let p1 = URL(string: "https://ok.example/")!
        let p2 = URL(string: "https://fail.example/")!
        let i1 = URL(string: "https://cdn.example/a.png")!

        let extractor = SplitSuccessFailureExtractor(
            successPage: p1,
            images: [DiscoveredImage(sourceURL: i1, accessibilityLabel: nil)]
        )

        let config = WebImagePickerConfiguration(additionalPageURLs: [p1, p2])
        let model = WebImagePickerViewModel(configuration: config, extractorOverride: extractor)
        await model.loadPage()

        XCTAssertEqual(model.phase, .browsing)
        XCTAssertEqual(model.discovered.count, 1)
        XCTAssertNotNil(model.aggregationNotice)
    }
}
