import XCTest
@testable import WebImagePicker

final class WebImageTileContextMenuConfigurationTests: XCTestCase {
    func testDisabledDefault() {
        XCTAssertEqual(WebImageTileContextMenuConfiguration.disabled.isEnabled, false)
        XCTAssertTrue(WebImageTileContextMenuConfiguration.disabled.actions.isEmpty)
    }

    func testConfigurationEqualityIncludesTileContextMenu() {
        var a = WebImagePickerConfiguration.default
        var b = WebImagePickerConfiguration.default
        XCTAssertEqual(a, b)

        b.imageTileContextMenu = WebImageTileContextMenuConfiguration(
            isEnabled: true,
            actions: [.preview],
            clipboardPresentation: .groupedPicker
        )
        XCTAssertNotEqual(a, b)

        a.imageTileContextMenu = b.imageTileContextMenu
        XCTAssertEqual(a, b)
    }

    func testConfigurationHashIncludesTileContextMenu() {
        var cfg = WebImagePickerConfiguration.default
        cfg.imageTileContextMenu = WebImageTileContextMenuConfiguration(
            isEnabled: true,
            actions: [.copyImage, .showMetadata]
        )
        XCTAssertNotEqual(cfg.hashValue, WebImagePickerConfiguration.default.hashValue)
    }

    func testOptionSetClipboardIntersection() {
        let actions: WebImageTileContextMenuAction = [.copyImage, .preview]
        XCTAssertEqual(actions.intersection(.clipboardActions), .copyImage)
    }
}
