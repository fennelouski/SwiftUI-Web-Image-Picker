import XCTest
@testable import WebImagePicker

final class DiscoveredImageTileContextMenuBuilderTests: XCTestCase {
    func testDisabledConfigProducesNoEntries() {
        let config = WebImageTileContextMenuConfiguration.disabled
        XCTAssertTrue(DiscoveredImageTileContextMenuBuilder.menuEntries(config: config).isEmpty)
    }

    func testEnabledWithNoActionsProducesNoEntries() {
        var config = WebImageTileContextMenuConfiguration(isEnabled: true, actions: [])
        XCTAssertTrue(DiscoveredImageTileContextMenuBuilder.menuEntries(config: config).isEmpty)
        config.actions = [.preview]
        XCTAssertEqual(
            DiscoveredImageTileContextMenuBuilder.menuEntries(config: config),
            [.preview]
        )
    }

    func testSeparateClipboardMenuItems() {
        let config = WebImageTileContextMenuConfiguration(
            isEnabled: true,
            actions: [.copyImage, .copyImageURL, .preview],
            clipboardPresentation: .separateMenuItems
        )
        XCTAssertEqual(
            DiscoveredImageTileContextMenuBuilder.menuEntries(config: config),
            [.copyImage, .copyImageURL, .preview]
        )
    }

    func testGroupedClipboardPicker() {
        let config = WebImageTileContextMenuConfiguration(
            isEnabled: true,
            actions: [.copyImage, .copyImageURL, .liftSubject, .showMetadata],
            clipboardPresentation: .groupedPicker
        )
        XCTAssertEqual(
            DiscoveredImageTileContextMenuBuilder.menuEntries(config: config),
            [.groupedClipboardActions, .showMetadata]
        )
        XCTAssertEqual(
            DiscoveredImageTileContextMenuBuilder.groupedClipboardEntries(config: config),
            [.copyImage, .copyImageURL, .liftSubject]
        )
    }

    func testLiftSubjectStrippedWhenUnsupported() {
        let config = WebImageTileContextMenuConfiguration(
            isEnabled: true,
            actions: [.liftSubject, .preview],
            clipboardPresentation: .separateMenuItems
        )
        let effective = DiscoveredImageTileContextMenuBuilder.effectiveActions(from: config)
#if os(iOS) || os(macOS)
        if DiscoveredImageTileContextMenuBuilder.isLiftSubjectSupported {
            XCTAssertTrue(effective.contains(.liftSubject))
        } else {
            XCTAssertFalse(effective.contains(.liftSubject))
        }
#else
        XCTAssertFalse(effective.contains(.liftSubject))
#endif
    }
}
