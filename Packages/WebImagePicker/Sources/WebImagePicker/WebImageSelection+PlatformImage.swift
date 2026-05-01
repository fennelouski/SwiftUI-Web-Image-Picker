import Foundation

#if canImport(UIKit)
import UIKit

extension WebImageSelection {
    /// Decodes the downloaded bytes as a `UIImage` when possible.
    public func makeUIImage() -> UIImage? {
        if data.isEmpty, let temp = temporaryFileURL, let fileData = try? Data(contentsOf: temp) {
            return UIImage(data: fileData)
        }
        return UIImage(data: data)
    }
}
#endif

#if os(macOS)
import AppKit

extension WebImageSelection {
    /// Decodes the downloaded bytes as an `NSImage` when possible.
    public func makeNSImage() -> NSImage? {
        if data.isEmpty, let temp = temporaryFileURL, let fileData = try? Data(contentsOf: temp) {
            return NSImage(data: fileData)
        }
        return NSImage(data: data)
    }
}
#endif
