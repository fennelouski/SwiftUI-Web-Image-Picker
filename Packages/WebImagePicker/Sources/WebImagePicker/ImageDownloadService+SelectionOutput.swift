import Foundation
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

extension ImageDownloadService {
    static func makeSelection(
        data: Data,
        contentType: String?,
        sourceURL: URL,
        configuration: WebImagePickerConfiguration
    ) throws -> WebImageSelection {
        switch configuration.selectionOutputMode {
        case .dataOnly:
            return WebImageSelection(data: data, contentType: contentType, sourceURL: sourceURL, temporaryFileURL: nil)

        case .platformImage:
            #if canImport(UIKit)
            guard UIImage(data: data) != nil else {
                throw WebImagePickerError.imageDecodeFailed
            }
            #elseif os(macOS)
            guard NSImage(data: data) != nil else {
                throw WebImagePickerError.imageDecodeFailed
            }
            #else
            throw WebImagePickerError.imageDecodeFailed
            #endif
            return WebImageSelection(data: data, contentType: contentType, sourceURL: sourceURL, temporaryFileURL: nil)

        case .temporaryFileURL:
            let ext = Self.filenameExtensionHint(contentType: contentType, sourceURL: sourceURL)
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("WebImagePicker-\(UUID().uuidString)", isDirectory: false)
                .appendingPathExtension(ext)
            try data.write(to: dest, options: .atomic)
            return WebImageSelection(data: Data(), contentType: contentType, sourceURL: sourceURL, temporaryFileURL: dest)
        }
    }

    private static func filenameExtensionHint(contentType: String?, sourceURL: URL) -> String {
        let mime = contentType?
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        if let mime, let ut = UTType(mimeType: mime), let pref = ut.preferredFilenameExtension, !pref.isEmpty {
            return pref
        }
        let pathExt = sourceURL.pathExtension.lowercased()
        if !pathExt.isEmpty {
            return pathExt
        }
        return "bin"
    }
}
