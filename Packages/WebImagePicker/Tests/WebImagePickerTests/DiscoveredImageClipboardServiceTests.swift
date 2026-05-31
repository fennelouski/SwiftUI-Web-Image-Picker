import CoreGraphics
import XCTest
@testable import WebImagePicker

final class DiscoveredImageClipboardServiceTests: XCTestCase {
    func testPNGDataRoundTripFromSolidColorImage() {
        let size = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Could not create CGContext")
            return
        }
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        guard let cgImage = context.makeImage() else {
            XCTFail("Could not make CGImage")
            return
        }
        let png = DiscoveredImageClipboardService.pngData(from: cgImage)
        XCTAssertNotNil(png)
        XCTAssertGreaterThan(png!.count, 0)
        let dims = ImagePixelDimensions.read(from: png!)
        XCTAssertEqual(dims?.width, size)
        XCTAssertEqual(dims?.height, size)
    }

    func testSelectionPNGDataForPasteboard() throws {
        let size = 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        let cgImage = try XCTUnwrap(context.makeImage())
        let png = try XCTUnwrap(DiscoveredImageClipboardService.pngData(from: cgImage))
        let selection = WebImageSelection(
            data: png,
            contentType: "image/png",
            sourceURL: URL(string: "https://example.com/test.png")!,
            temporaryFileURL: nil
        )
        let out = try DiscoveredImageClipboardService.pngDataForPasteboard(from: selection)
        XCTAssertFalse(out.isEmpty)
    }
}
