import XCTest
@testable import WebImagePicker

final class WebImagePickerConfigurationTests: XCTestCase {
    func testDefaultSelectionLimit() {
        XCTAssertEqual(WebImagePickerConfiguration.default.selectionLimit, 10)
    }

    func testDefaultAllowedSchemesHTTPSOnly() {
        XCTAssertEqual(WebImagePickerConfiguration.default.allowedURLSchemes, ["https"])
    }

    func testDefaultExtractionModeIsStaticHTML() {
        XCTAssertEqual(WebImagePickerConfiguration.default.extractionMode, .staticHTML)
    }

    func testSelectionLimitClampedToAtLeastOne() {
        let config = WebImagePickerConfiguration(selectionLimit: 0)
        XCTAssertEqual(config.selectionLimit, 1)
    }

    func testMaximumConcurrentImageLoadsClampedToAtLeastOne() {
        let config = WebImagePickerConfiguration(maximumConcurrentImageLoads: 0)
        XCTAssertEqual(config.maximumConcurrentImageLoads, 1)
    }

    func testEqualityMatchesVisibleFields() {
        let a = WebImagePickerConfiguration(
            selectionLimit: 3,
            maximumConcurrentImageLoads: 2,
            requestTimeout: 12,
            allowedURLSchemes: ["https", "http"],
            userAgent: "TestAgent",
            maximumHTMLDownloadBytes: 100,
            maximumImageDownloadBytes: 200,
            extractionMode: .webView
        )
        let b = WebImagePickerConfiguration(
            selectionLimit: 3,
            maximumConcurrentImageLoads: 2,
            requestTimeout: 12,
            allowedURLSchemes: ["http", "https"],
            userAgent: "TestAgent",
            maximumHTMLDownloadBytes: 100,
            maximumImageDownloadBytes: 200,
            extractionMode: .webView
        )
        XCTAssertEqual(a, b)
    }

    /// `URLSession` is intentionally excluded from ``WebImagePickerConfiguration`` equality (and hashing).
    func testEqualityIgnoresURLSession() {
        let custom = URLSession(configuration: .ephemeral)
        let a = WebImagePickerConfiguration(urlSession: .shared)
        let b = WebImagePickerConfiguration(urlSession: custom)
        XCTAssertEqual(a, b)
    }

    func testInitialURLStringAffectsEquality() {
        let a = WebImagePickerConfiguration(initialURLString: "https://a.example")
        let b = WebImagePickerConfiguration(initialURLString: "https://b.example")
        XCTAssertNotEqual(a, b)
    }

    func testDefaultInitialURLStringIsNil() {
        XCTAssertNil(WebImagePickerConfiguration.default.initialURLString)
    }

    func testDefaultAdditionalPageURLsEmpty() {
        XCTAssertTrue(WebImagePickerConfiguration.default.additionalPageURLs.isEmpty)
    }

    func testDefaultMaximumDiscoveredImagesPerPageIsNil() {
        XCTAssertNil(WebImagePickerConfiguration.default.maximumDiscoveredImagesPerPage)
    }

    func testMaximumDiscoveredImagesPerPageNonPositiveBecomesNil() {
        XCTAssertNil(WebImagePickerConfiguration(maximumDiscoveredImagesPerPage: 0).maximumDiscoveredImagesPerPage)
        XCTAssertNil(WebImagePickerConfiguration(maximumDiscoveredImagesPerPage: -1).maximumDiscoveredImagesPerPage)
    }

    func testMaximumDiscoveredImagesPerPageAffectsEquality() {
        let capped = WebImagePickerConfiguration(maximumDiscoveredImagesPerPage: 5)
        let uncapped = WebImagePickerConfiguration(maximumDiscoveredImagesPerPage: nil)
        XCTAssertNotEqual(capped, uncapped)
    }

    func testAdditionalPageURLsAffectsEquality() throws {
        let u = try XCTUnwrap(URL(string: "https://a.example/"))
        let withExtra = WebImagePickerConfiguration(additionalPageURLs: [u])
        let without = WebImagePickerConfiguration(additionalPageURLs: [])
        XCTAssertNotEqual(withExtra, without)
    }
}
