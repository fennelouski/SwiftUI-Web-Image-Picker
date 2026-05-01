import CoreGraphics
import Foundation
import ImageIO

/// Reads embedded width/height from image container bytes (PNG, JPEG, GIF, HEIF, WebP when supported, etc.) via Image I/O.
enum ImagePixelDimensions {
    static func read(from data: Data) -> (width: Int, height: Int)? {
        guard !data.isEmpty else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        guard CGImageSourceGetCount(source) > 0 else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        guard let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int
        else {
            return nil
        }
        guard width > 0, height > 0 else { return nil }
        return (width, height)
    }
}
