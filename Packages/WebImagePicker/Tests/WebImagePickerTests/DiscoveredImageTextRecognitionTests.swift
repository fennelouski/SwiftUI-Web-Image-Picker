#if os(macOS)
import AppKit
#endif
import XCTest
@testable import WebImagePicker

final class DiscoveredImageTextRecognitionTests: XCTestCase {
    func testRecognizedTextFromSyntheticPNG() throws {
        #if os(macOS)
        let data = try XCTUnwrap(Self.makePNGWithBoldText("OCRFINDME"))
        let text = DiscoveredImageTextRecognition.recognizedText(fromImageData: data, languages: ["en-US"])
        XCTAssertNotNil(text, "Vision OCR returned nil for synthetic PNG")
        XCTAssertTrue(text!.localizedCaseInsensitiveContains("OCRFINDME"), "Vision OCR text was: \(text ?? "nil")")
        #else
        throw XCTSkip("Synthetic PNG fixture is macOS-only (AppKit).")
        #endif
    }
}

#if os(macOS)
private extension DiscoveredImageTextRecognitionTests {
    static func makePNGWithBoldText(_ string: String) -> Data? {
        let size = NSSize(width: 480, height: 120)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 48),
            .foregroundColor: NSColor.black,
        ]
        (string as NSString).draw(at: NSPoint(x: 20, y: 36), withAttributes: attrs)
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        return png
    }
}
#endif
