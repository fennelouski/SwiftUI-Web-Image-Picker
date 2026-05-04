import XCTest
@testable import WebImagePicker

final class PageURLNormalizationTests: XCTestCase {
    private let httpsOnly: Set<String> = ["https"]
    private let httpAndHttps: Set<String> = ["https", "http"]

    func testBareHostPrependsHTTPSWhenAllowed() {
        let result = PageURLNormalization.resolve(trimmedInput: "example.com/news", allowedURLSchemes: httpsOnly)
        XCTAssertEqual(result, .success(URL(string: "https://example.com/news")!))
    }

    func testProtocolRelativePrependsHTTPS() {
        let result = PageURLNormalization.resolve(trimmedInput: "//example.com/a", allowedURLSchemes: httpsOnly)
        XCTAssertEqual(result, .success(URL(string: "https://example.com/a")!))
    }

    func testExplicitHTTPSUnchanged() {
        let result = PageURLNormalization.resolve(
            trimmedInput: "https://example.com/",
            allowedURLSchemes: httpsOnly
        )
        XCTAssertEqual(result, .success(URL(string: "https://example.com/")!))
    }

    func testBareHostUsesHTTPWhenOnlyHTTPAllowed() {
        let result = PageURLNormalization.resolve(trimmedInput: "example.com", allowedURLSchemes: ["http"])
        XCTAssertEqual(result, .success(URL(string: "http://example.com")!))
    }

    func testHTTPPreferredAfterHTTPSForBareHostWhenBothAllowed() {
        let result = PageURLNormalization.resolve(trimmedInput: "example.com", allowedURLSchemes: httpAndHttps)
        XCTAssertEqual(result, .success(URL(string: "https://example.com")!))
    }

    func testExplicitHTTPWhenHTTPAllowed() {
        let result = PageURLNormalization.resolve(
            trimmedInput: "http://example.com/path",
            allowedURLSchemes: httpAndHttps
        )
        XCTAssertEqual(result, .success(URL(string: "http://example.com/path")!))
    }

    func testExplicitHTTPDisallowedWhenHTTPSOnly() {
        let result = PageURLNormalization.resolve(
            trimmedInput: "http://example.com/",
            allowedURLSchemes: httpsOnly
        )
        XCTAssertEqual(result, .disallowedScheme)
    }

    func testExplicitFTPDisallowedWhenHTTPSOnly() {
        let result = PageURLNormalization.resolve(
            trimmedInput: "ftp://example.com/r",
            allowedURLSchemes: httpsOnly
        )
        XCTAssertEqual(result, .disallowedScheme)
    }

    func testIsHTTPExplicitlyDisallowedWhenHTTPSOnly() {
        XCTAssertTrue(
            PageURLNormalization.isHTTPExplicitlyDisallowed(
                trimmedInput: "http://example.com/",
                allowedURLSchemes: httpsOnly
            )
        )
        XCTAssertFalse(
            PageURLNormalization.isHTTPExplicitlyDisallowed(
                trimmedInput: "https://example.com/",
                allowedURLSchemes: httpsOnly
            )
        )
        XCTAssertFalse(
            PageURLNormalization.isHTTPExplicitlyDisallowed(
                trimmedInput: "http://example.com/",
                allowedURLSchemes: httpAndHttps
            )
        )
    }

    func testMalformedWithSchemeFragmentDoesNotPrefix() {
        let result = PageURLNormalization.resolve(
            trimmedInput: "https://not a host",
            allowedURLSchemes: httpsOnly
        )
        XCTAssertEqual(result, .invalid)
    }

    func testEmptyInvalid() {
        XCTAssertEqual(
            PageURLNormalization.resolve(trimmedInput: "", allowedURLSchemes: httpsOnly),
            .invalid
        )
        XCTAssertEqual(
            PageURLNormalization.resolve(trimmedInput: "   ", allowedURLSchemes: httpsOnly),
            .invalid
        )
    }

    func testBareHostInvalidWhenNoSchemesMatchURLParser() {
        let result = PageURLNormalization.resolve(
            trimmedInput: "not\nvalid",
            allowedURLSchemes: httpsOnly
        )
        XCTAssertEqual(result, .invalid)
    }
}
