import XCTest
@testable import WebImagePicker

private final class SmartFallbackCallLog: @unchecked Sendable {
    var urls: [URL] = []
}

private struct SmartFallbackExtractor: PageImageExtractor {
    let log: SmartFallbackCallLog
    let imagesByPage: [URL: [DiscoveredImage]]

    struct Boom: Error {}

    func discoverImages(from pageURL: URL, configuration: WebImagePickerConfiguration) async throws -> [DiscoveredImage] {
        log.urls.append(pageURL)
        guard let images = imagesByPage[pageURL] else {
            throw Boom()
        }
        return images
    }
}

@MainActor
final class WebImagePickerViewModelSmartURLFallbackTests: XCTestCase {
    func testShortTLDRetriesWithCorrectedURL() async throws {
        let correctedPage = URL(string: "https://google.com")!
        let imageURL = URL(string: "https://cdn.example.com/fallback.png")!
        let log = SmartFallbackCallLog()
        let extractor = SmartFallbackExtractor(
            log: log,
            imagesByPage: [correctedPage: [DiscoveredImage(sourceURL: imageURL, accessibilityLabel: nil)]]
        )
        let model = WebImagePickerViewModel(
            configuration: WebImagePickerConfiguration(),
            extractorOverride: extractor
        )
        model.urlString = "google.c"

        await model.loadPage()

        XCTAssertEqual(model.phase, .browsing)
        XCTAssertEqual(model.discovered.map(\.sourceURL), [imageURL])
        XCTAssertEqual(model.urlString, "google.com")
        let notice = try XCTUnwrap(model.urlCorrectionNotice)
        XCTAssertTrue(notice.contains("google.c"))
        XCTAssertTrue(notice.contains("google.com"))
        XCTAssertEqual(
            log.urls.prefix(2),
            [URL(string: "https://google.c")!, correctedPage]
        )
    }

    func testFallbackDisabledDoesNotRetry() async throws {
        let log = SmartFallbackCallLog()
        let extractor = SmartFallbackExtractor(log: log, imagesByPage: [:])
        let model = WebImagePickerViewModel(
            configuration: WebImagePickerConfiguration(isSmartURLFallbackEnabled: false),
            extractorOverride: extractor
        )
        model.urlString = "google.c"

        await model.loadPage()

        XCTAssertEqual(model.phase, .urlEntry)
        XCTAssertEqual(log.urls, [URL(string: "https://google.c")!])
        XCTAssertNil(model.urlCorrectionNotice)
    }

    func testPartialFailureRetriesOnlyFailedUserRows() async throws {
        let primaryPage = URL(string: "https://ok.example/")!
        let correctedPage = URL(string: "https://google.com")!
        let i1 = URL(string: "https://cdn.example/one.png")!
        let i2 = URL(string: "https://cdn.example/two.png")!
        let log = SmartFallbackCallLog()
        let extractor = SmartFallbackExtractor(
            log: log,
            imagesByPage: [
                primaryPage: [DiscoveredImage(sourceURL: i1, accessibilityLabel: nil)],
                correctedPage: [DiscoveredImage(sourceURL: i2, accessibilityLabel: nil)],
            ]
        )
        let config = WebImagePickerConfiguration(isMultiplePageEntryEnabled: true)
        let model = WebImagePickerViewModel(configuration: config, extractorOverride: extractor)
        model.urlString = primaryPage.absoluteString
        model.addExtraPageRow()
        model.extraPageRows[0].text = "google.c"

        await model.loadPage()

        XCTAssertEqual(model.phase, .browsing)
        XCTAssertEqual(Set(model.discovered.map(\.sourceURL)), Set([i1, i2]))
        XCTAssertEqual(log.urls, [primaryPage, URL(string: "https://google.c")!, correctedPage])
        XCTAssertNil(model.aggregationNotice)
        XCTAssertEqual(model.extraPageRows[0].text, "google.com")
    }
}
