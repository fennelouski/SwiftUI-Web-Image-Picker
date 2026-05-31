import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

enum DiscoveredImageClipboardService {
    static func copyURLString(_ urlString: String) {
#if canImport(UIKit)
        UIPasteboard.general.string = urlString
#elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
#endif
    }

    static func copyImage(from selection: WebImageSelection) throws {
        let pngData = try pngDataForPasteboard(from: selection)
        copyPNGData(pngData)
    }

    static func copyPNGData(_ data: Data) {
#if canImport(UIKit)
        UIPasteboard.general.setData(data, forPasteboardType: UTType.png.identifier)
#elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data, forType: .png)
#endif
    }

    static func pngDataForPasteboard(from selection: WebImageSelection) throws -> Data {
        let imageData = selectionImageData(selection)
        guard !imageData.isEmpty else {
            throw WebImagePickerError.imageDecodeFailed
        }
        if let cg = cgImage(from: imageData) {
            if let png = pngData(from: cg) {
                return png
            }
        }
        throw WebImagePickerError.imageDecodeFailed
    }

    static func cgImage(from selection: WebImageSelection) throws -> CGImage {
        let imageData = selectionImageData(selection)
        guard let cg = cgImage(from: imageData) else {
            throw WebImagePickerError.imageDecodeFailed
        }
        return cg
    }

    private static func selectionImageData(_ selection: WebImageSelection) -> Data {
        if !selection.data.isEmpty {
            return selection.data
        }
        if let temp = selection.temporaryFileURL, let fileData = try? Data(contentsOf: temp) {
            return fileData
        }
        return Data()
    }

    private static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func pngData(from cgImage: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
