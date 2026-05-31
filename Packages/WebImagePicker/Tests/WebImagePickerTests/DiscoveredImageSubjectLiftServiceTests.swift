import CoreGraphics
import XCTest
@testable import WebImagePicker

#if os(iOS) || os(macOS)
final class DiscoveredImageSubjectLiftServiceTests: XCTestCase {
    func testLiftedSubjectPNGFromSyntheticImage() throws {
        guard DiscoveredImageSubjectLiftService.isSupported else {
            throw XCTSkip("Foreground instance mask requires iOS 17 / macOS 14")
        }
        let cgImage = try makeSyntheticPhotoLikeImage()
        if #available(iOS 17.0, macOS 14.0, *) {
            let png = try DiscoveredImageSubjectLiftService.liftedSubjectPNGData(from: cgImage)
            XCTAssertGreaterThan(png.count, 0)
            XCTAssertNotNil(ImagePixelDimensions.read(from: png))
        }
    }

    private func makeSyntheticPhotoLikeImage() throws -> CGImage {
        let width = 64
        let height = 64
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "test", code: 1)
        }
        context.setFillColor(CGColor(gray: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1))
        context.fillEllipse(in: CGRect(x: 16, y: 12, width: 32, height: 40))
        guard let image = context.makeImage() else {
            throw NSError(domain: "test", code: 2)
        }
        return image
    }
}
#endif
