import XCTest
@testable import WebImagePicker

private struct EmptyExtractor: PageImageExtractor {
    func discoverImages(from pageURL: URL, configuration: WebImagePickerConfiguration) async throws -> [DiscoveredImage] {
        []
    }
}

@MainActor
final class WebImagePickerViewModelHTTPSchemeTests: XCTestCase {
    func testHTTPSOnlyAndExplicitHTTPShowsLocalizedHTTPNotAllowedMessage() async throws {
        let config = WebImagePickerConfiguration(allowedURLSchemes: ["https"])
        let model = WebImagePickerViewModel(configuration: config, extractorOverride: EmptyExtractor())
        model.urlString = "http://example.com/"
        await model.loadPage()
        XCTAssertEqual(model.phase, .urlEntry)
        let msg = try XCTUnwrap(model.errorMessage)
        XCTAssertTrue(msg.contains("HTTP"), "Expected HTTP guidance, got: \(msg)")
        XCTAssertTrue(msg.contains("HTTPS") || msg.contains("https"), "Expected HTTPS guidance, got: \(msg)")
    }

    func testExtraRowOnlyHTTPShowsHTTPNotAllowed() async throws {
        let config = WebImagePickerConfiguration(allowedURLSchemes: ["https"])
        let model = WebImagePickerViewModel(configuration: config, extractorOverride: EmptyExtractor())
        model.urlString = ""
        model.addExtraPageRow()
        model.extraPageRows[0].text = "http://example.com/"
        await model.loadPage()
        XCTAssertEqual(model.phase, .urlEntry)
        let msg = try XCTUnwrap(model.errorMessage)
        XCTAssertTrue(msg.contains("HTTP"))
    }

    func testHTTPAllowedLoadsAndDoesNotSetSchemeError() async throws {
        let page = URL(string: "http://example.com/")!
        let img = URL(string: "http://example.com/a.png")!
        struct OneImageExtractor: PageImageExtractor {
            let page: URL
            let img: URL
            func discoverImages(from pageURL: URL, configuration: WebImagePickerConfiguration) async throws -> [DiscoveredImage] {
                XCTAssertEqual(pageURL, page)
                return [DiscoveredImage(sourceURL: img, accessibilityLabel: nil)]
            }
        }
        let config = WebImagePickerConfiguration(allowedURLSchemes: ["http", "https"])
        let model = WebImagePickerViewModel(
            configuration: config,
            extractorOverride: OneImageExtractor(page: page, img: img)
        )
        model.urlString = "http://example.com/"
        await model.loadPage()
        XCTAssertEqual(model.phase, .browsing)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.discovered.map(\.sourceURL), [img])
    }

    func testFTPDisallowedUsesGenericSchemeMessage() async throws {
        let config = WebImagePickerConfiguration(allowedURLSchemes: ["https"])
        let model = WebImagePickerViewModel(configuration: config, extractorOverride: EmptyExtractor())
        model.urlString = "ftp://example.com/r"
        await model.loadPage()
        XCTAssertEqual(model.phase, .urlEntry)
        let msg = try XCTUnwrap(model.errorMessage)
        XCTAssertEqual(
            msg,
            String(
                localized: String.LocalizationValue("webimage.error.schemeNotAllowed"),
                bundle: WebImagePickerBundle.module
            )
        )
    }

    func testSkippedHTTPImagesNoticeAfterDiscovery() async throws {
        let page = URL(string: "https://example.com/")!
        let okImage = URL(string: "https://example.com/ok.png")!
        struct SkippingExtractor: PageImageExtractor {
            let okImage: URL
            func discoverImages(from pageURL: URL, configuration: WebImagePickerConfiguration) async throws -> [DiscoveredImage] {
                [DiscoveredImage(sourceURL: okImage, accessibilityLabel: nil)]
            }
            func discoverImagesWithOutcome(from pageURL: URL, configuration: WebImagePickerConfiguration) async throws -> PageImageDiscoveryOutcome {
                PageImageDiscoveryOutcome(
                    images: [DiscoveredImage(sourceURL: okImage, accessibilityLabel: nil)],
                    skippedHTTPImageURLsDueToAllowedSchemes: 2
                )
            }
        }
        let model = WebImagePickerViewModel(
            configuration: .default,
            extractorOverride: SkippingExtractor(okImage: okImage)
        )
        model.urlString = page.absoluteString
        await model.loadPage()
        XCTAssertEqual(model.phase, .browsing)
        let notice = try XCTUnwrap(model.httpSkippedImagesNotice)
        XCTAssertTrue(notice.contains("2"))
    }
}
