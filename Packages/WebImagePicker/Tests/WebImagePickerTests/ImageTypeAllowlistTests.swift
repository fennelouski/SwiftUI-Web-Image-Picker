import UniformTypeIdentifiers
import XCTest
@testable import WebImagePicker

final class ImageTypeAllowlistTests: XCTestCase {
    private var jpegOnly: WebImagePickerConfiguration {
        var c = WebImagePickerConfiguration.default
        c.allowedImageTypeIdentifiers = [UTType.jpeg.identifier]
        return c
    }

    func testDiscoveryAllowsJPEGWhenJPEGAllowlisted() {
        let u = URL(string: "https://cdn.example/a.jpg")!
        XCTAssertTrue(ImageTypeAllowlist.passesDiscovery(url: u, configuration: jpegOnly))
    }

    func testDiscoveryDropsPNGWhenOnlyJPEGAllowlisted() {
        let u = URL(string: "https://cdn.example/a.png")!
        XCTAssertFalse(ImageTypeAllowlist.passesDiscovery(url: u, configuration: jpegOnly))
    }

    func testDiscoveryDropsNonImageExtension() {
        let u = URL(string: "https://cdn.example/doc.html")!
        XCTAssertFalse(ImageTypeAllowlist.passesDiscovery(url: u, configuration: jpegOnly))
    }

    func testDiscoveryExtensionlessAllowsWhenPolicyAllow() {
        let u = URL(string: "https://cdn.example/resize/123")!
        XCTAssertTrue(ImageTypeAllowlist.passesDiscovery(url: u, configuration: jpegOnly))
    }

    func testDiscoveryExtensionlessRejectsWhenPolicyReject() {
        var c = jpegOnly
        c.unknownImageTypePolicy = .reject
        let u = URL(string: "https://cdn.example/resize/123")!
        XCTAssertFalse(ImageTypeAllowlist.passesDiscovery(url: u, configuration: c))
    }

    func testDiscoveryPublicImageIdentifierAllowsJPEG() {
        var c = WebImagePickerConfiguration.default
        c.allowedImageTypeIdentifiers = [UTType.image.identifier]
        let u = URL(string: "https://cdn.example/a.jpg")!
        XCTAssertTrue(ImageTypeAllowlist.passesDiscovery(url: u, configuration: c))
    }

    func testDownloadPNGRejectedWhenOnlyJPEGAllowlisted() {
        XCTAssertFalse(ImageTypeAllowlist.passesDownload(contentTypeHeader: "image/png", configuration: jpegOnly))
    }

    func testDownloadJPEGPassesWhenJPEGAllowlisted() {
        XCTAssertTrue(ImageTypeAllowlist.passesDownload(contentTypeHeader: "image/jpeg", configuration: jpegOnly))
    }

    func testDownloadParsesMimeWithCharset() {
        XCTAssertTrue(ImageTypeAllowlist.passesDownload(contentTypeHeader: "image/jpeg; charset=binary", configuration: jpegOnly))
    }

    func testDownloadMissingTypeAllowsWhenPolicyAllow() {
        XCTAssertTrue(ImageTypeAllowlist.passesDownload(contentTypeHeader: nil, configuration: jpegOnly))
    }

    func testDownloadMissingTypeRejectsWhenPolicyReject() {
        var c = jpegOnly
        c.unknownImageTypePolicy = .reject
        XCTAssertFalse(ImageTypeAllowlist.passesDownload(contentTypeHeader: nil, configuration: c))
    }

    func testNoAllowlistPassesArbitraryDiscovery() {
        let u = URL(string: "https://cdn.example/a.gif")!
        XCTAssertTrue(ImageTypeAllowlist.passesDiscovery(url: u, configuration: .default))
    }

    func testNoAllowlistPassesArbitraryDownloadMime() {
        XCTAssertTrue(ImageTypeAllowlist.passesDownload(contentTypeHeader: "image/webp", configuration: .default))
    }
}
