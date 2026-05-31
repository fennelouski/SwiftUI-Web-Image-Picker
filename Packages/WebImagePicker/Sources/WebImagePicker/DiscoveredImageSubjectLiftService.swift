import CoreGraphics
import CoreImage
import Foundation
import Vision

#if os(iOS) || os(macOS)

enum DiscoveredImageSubjectLiftService {
    static var isSupported: Bool {
        if #available(iOS 17.0, macOS 14.0, *) {
            return true
        }
        return false
    }

    @available(iOS 17.0, macOS 14.0, *)
    static func liftedSubjectPNGData(from cgImage: CGImage) throws -> Data {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first else {
            throw WebImagePickerError.subjectLiftFailed
        }
        let instances = observation.allInstances
        guard !instances.isEmpty else {
            throw WebImagePickerError.subjectLiftFailed
        }
        let maskBuffer = try observation.generateScaledMaskForImage(forInstances: instances, from: handler)
        let maskImage = CIImage(cvPixelBuffer: maskBuffer)
        let sourceImage = CIImage(cgImage: cgImage)
        let composited = sourceImage.applyingFilter(
            "CIBlendWithMask",
            parameters: [
                kCIInputMaskImageKey: maskImage,
                kCIInputBackgroundImageKey: CIImage.empty(),
            ]
        )
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let output = context.createCGImage(composited, from: composited.extent) else {
            throw WebImagePickerError.subjectLiftFailed
        }
        guard let png = DiscoveredImageClipboardService.pngData(from: output) else {
            throw WebImagePickerError.subjectLiftFailed
        }
        return png
    }

    static func copyLiftedSubject(from selection: WebImageSelection) throws {
        guard isSupported else {
            throw WebImagePickerError.subjectLiftUnavailable
        }
        let cgImage = try DiscoveredImageClipboardService.cgImage(from: selection)
        if #available(iOS 17.0, macOS 14.0, *) {
            let png = try liftedSubjectPNGData(from: cgImage)
            DiscoveredImageClipboardService.copyPNGData(png)
        } else {
            throw WebImagePickerError.subjectLiftUnavailable
        }
    }
}

#endif
