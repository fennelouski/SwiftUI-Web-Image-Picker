import Foundation

public enum WebImagePickerError: Error, Sendable, Equatable {
    case invalidURL
    case invalidHTTPResponse
    case htmlTooLarge
    case htmlDecodingFailed
    case extractionFailed
    case noImagesFound
    case imageTooLarge
    case downloadFailed
    /// Response `Content-Type` is not allowed by ``WebImagePickerConfiguration/allowedImageTypeIdentifiers`` (or is missing when ``WebImagePickerConfiguration/unknownImageTypePolicy`` is ``WebImageUnknownTypePolicy/reject``).
    case unsupportedImageType
    /// Payload could not be decoded as a platform image while ``WebImagePickerConfiguration/selectionOutputMode`` is ``WebImageSelectionOutputMode/platformImage``.
    case imageDecodeFailed
    /// Could not copy image data to the pasteboard.
    case pasteboardCopyFailed
    /// On-device subject lift did not produce a usable mask.
    case subjectLiftFailed
    /// Subject lift is not available on this platform or OS version.
    case subjectLiftUnavailable
}
