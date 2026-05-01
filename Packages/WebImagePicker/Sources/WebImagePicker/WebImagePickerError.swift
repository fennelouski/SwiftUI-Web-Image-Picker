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
}
