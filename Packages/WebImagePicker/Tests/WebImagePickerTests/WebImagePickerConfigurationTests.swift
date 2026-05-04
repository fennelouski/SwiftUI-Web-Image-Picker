import CoreGraphics
import UniformTypeIdentifiers
import XCTest
@testable import WebImagePicker

final class WebImagePickerConfigurationTests: XCTestCase {
    func testDefaultSelectionLimit() {
        XCTAssertEqual(WebImagePickerConfiguration.default.selectionLimit, 1)
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

    func testDefaultSimilarImageDeduplicationIsDisabled() {
        XCTAssertEqual(WebImagePickerConfiguration.default.similarImageDeduplication, .disabled)
    }

    func testDefaultImageDimensionBoundsAreNil() {
        XCTAssertNil(WebImagePickerConfiguration.default.minimumImageDimensions)
        XCTAssertNil(WebImagePickerConfiguration.default.maximumImageDimensions)
    }

    func testImageDimensionBoundsAffectEquality() {
        let a = WebImagePickerConfiguration(minimumImageDimensions: CGSize(width: 10, height: 10))
        let b = WebImagePickerConfiguration(minimumImageDimensions: CGSize(width: 11, height: 10))
        XCTAssertNotEqual(a, b)
    }

    func testDefaultAllowedImageTypeIdentifiersNil() {
        XCTAssertNil(WebImagePickerConfiguration.default.allowedImageTypeIdentifiers)
    }

    func testDefaultUnknownImageTypePolicyAllow() {
        XCTAssertEqual(WebImagePickerConfiguration.default.unknownImageTypePolicy, .allow)
    }

    func testEmptyImageTypeAllowlistNormalizedToNil() {
        XCTAssertNil(WebImagePickerConfiguration(allowedImageTypeIdentifiers: []).allowedImageTypeIdentifiers)
    }

    func testImageTypeAllowlistAffectsEquality() {
        let a = WebImagePickerConfiguration(allowedImageTypeIdentifiers: [UTType.jpeg.identifier])
        let b = WebImagePickerConfiguration(allowedImageTypeIdentifiers: [UTType.png.identifier])
        XCTAssertNotEqual(a, b)
    }

    func testUnknownImageTypePolicyAffectsEquality() {
        let a = WebImagePickerConfiguration(unknownImageTypePolicy: .allow)
        let b = WebImagePickerConfiguration(unknownImageTypePolicy: .reject)
        XCTAssertNotEqual(a, b)
    }

    func testDefaultSelectionOutputModeIsDataOnly() {
        XCTAssertEqual(WebImagePickerConfiguration.default.selectionOutputMode, .dataOnly)
    }

    func testSelectionOutputModeAffectsEquality() {
        let a = WebImagePickerConfiguration(selectionOutputMode: .dataOnly)
        let b = WebImagePickerConfiguration(selectionOutputMode: .temporaryFileURL)
        XCTAssertNotEqual(a, b)
    }

    func testDefaultDiscoveredImageSortIsDiscoveryOrder() {
        XCTAssertEqual(WebImagePickerConfiguration.default.discoveredImageSort, .discoveryOrder)
    }

    func testDiscoveredImageSortAffectsEquality() {
        let a = WebImagePickerConfiguration(discoveredImageSort: .discoveryOrder)
        let b = WebImagePickerConfiguration(discoveredImageSort: .sourceURLAscending)
        XCTAssertNotEqual(a, b)
    }

    func testFaceCountSortModesAffectEquality() {
        let a = WebImagePickerConfiguration(discoveredImageSort: .faceCountDescending)
        let b = WebImagePickerConfiguration(discoveredImageSort: .faceCountAscending)
        XCTAssertNotEqual(a, b)
    }

    func testDefaultMaximumFaceCountAnalysisImages() {
        XCTAssertEqual(WebImagePickerConfiguration.default.maximumFaceCountAnalysisImages, 40)
    }

    func testMaximumFaceCountAnalysisImagesClampedNonNegative() {
        XCTAssertEqual(WebImagePickerConfiguration(maximumFaceCountAnalysisImages: -5).maximumFaceCountAnalysisImages, 0)
    }

    func testMaximumFaceCountAnalysisImagesAffectsEquality() {
        let a = WebImagePickerConfiguration(maximumFaceCountAnalysisImages: 10)
        let b = WebImagePickerConfiguration(maximumFaceCountAnalysisImages: 20)
        XCTAssertNotEqual(a, b)
    }

    func testDefaultImageTextSearchDisabled() {
        XCTAssertFalse(WebImagePickerConfiguration.default.isImageTextSearchEnabled)
        XCTAssertEqual(WebImagePickerConfiguration.default.maximumImageTextSearchImages, 32)
        XCTAssertNil(WebImagePickerConfiguration.default.imageTextRecognitionLanguages)
        XCTAssertEqual(WebImagePickerConfiguration.default.maximumConcurrentImageTextRecognition, 2)
    }

    func testMaximumImageTextSearchImagesClampedNonNegative() {
        XCTAssertEqual(WebImagePickerConfiguration(maximumImageTextSearchImages: -3).maximumImageTextSearchImages, 0)
    }

    func testMaximumConcurrentImageTextRecognitionClampedToAtLeastOne() {
        XCTAssertEqual(WebImagePickerConfiguration(maximumConcurrentImageTextRecognition: 0).maximumConcurrentImageTextRecognition, 1)
    }

    func testEmptyImageTextRecognitionLanguagesNormalizedToNil() {
        XCTAssertNil(WebImagePickerConfiguration(imageTextRecognitionLanguages: []).imageTextRecognitionLanguages)
    }

    func testImageTextSearchFlagsAffectEquality() {
        let a = WebImagePickerConfiguration(isImageTextSearchEnabled: true)
        let b = WebImagePickerConfiguration(isImageTextSearchEnabled: false)
        XCTAssertNotEqual(a, b)
    }

    func testDefaultMetadataExclusionListsEmpty() {
        XCTAssertTrue(WebImagePickerConfiguration.default.excludedImageMetadataSubstrings.isEmpty)
        XCTAssertTrue(WebImagePickerConfiguration.default.excludedImageMetadataRegularExpressionPatterns.isEmpty)
    }

    func testMetadataExclusionSubstringsAffectEquality() {
        let a = WebImagePickerConfiguration(excludedImageMetadataSubstrings: ["ads"])
        let b = WebImagePickerConfiguration(excludedImageMetadataSubstrings: ["tracker"])
        XCTAssertNotEqual(a, b)
    }

    func testWhitespaceOnlyMetadataExclusionNormalizedAway() {
        let c = WebImagePickerConfiguration(excludedImageMetadataSubstrings: ["  ", "\t"])
        XCTAssertTrue(c.excludedImageMetadataSubstrings.isEmpty)
    }

    func testSimilarImageDeduplicationAffectsEquality() {
        let a = WebImagePickerConfiguration(similarImageDeduplication: .disabled)
        let b = WebImagePickerConfiguration(similarImageDeduplication: .normalizedResourceURL)
        XCTAssertNotEqual(a, b)
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

    func testDefaultCachePolicyIsEphemeral() {
        XCTAssertEqual(WebImagePickerConfiguration.default.cachePolicy, .ephemeral)
    }

    func testCachePolicyAffectsEquality() {
        let noReload = WebImagePickerConfiguration()
        var reload = WebImagePickerConfiguration()
        reload.cachePolicy = WebImagePickerCachePolicy(requestCachePolicy: .reloadIgnoringLocalCacheData)
        XCTAssertEqual(noReload, WebImagePickerConfiguration())
        XCTAssertNotEqual(noReload, reload)
    }

    func testCachePolicyNormalizesNonPositiveDiscoveryTTL() {
        let p = WebImagePickerCachePolicy(discoveryEntryTimeToLive: 0)
        XCTAssertNil(p.discoveryEntryTimeToLive)
    }

    func testCachePolicyNormalizesNonPositivePerDomainCap() {
        let p = WebImagePickerCachePolicy(maximumDiscoveryEntries: 2, perDomainMaximumEntries: -1)
        XCTAssertNil(p.perDomainMaximumEntries)
    }

    func testCachePolicyClampsNegativeMaximumDiscoveryEntries() {
        let p = WebImagePickerCachePolicy(maximumDiscoveryEntries: -5)
        XCTAssertEqual(p.maximumDiscoveryEntries, 0)
    }
}
