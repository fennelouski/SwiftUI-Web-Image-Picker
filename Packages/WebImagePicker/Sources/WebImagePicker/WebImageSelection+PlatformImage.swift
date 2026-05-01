import Foundation

#if canImport(UIKit)
import UIKit

extension WebImageSelection {
    /// Decodes the downloaded bytes as a `UIImage` when possible.
    public func makeUIImage() -> UIImage? {
        UIImage(data: data)
    }
}
#endif

#if os(macOS)
import AppKit

extension WebImageSelection {
    /// Decodes the downloaded bytes as an `NSImage` when possible.
    public func makeNSImage() -> NSImage? {
        NSImage(data: data)
    }
}
#endif
