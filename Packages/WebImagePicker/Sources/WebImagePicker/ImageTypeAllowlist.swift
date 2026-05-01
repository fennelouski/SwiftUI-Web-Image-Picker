import Foundation
import UniformTypeIdentifiers

/// Filters discovered image URLs by path extension and completed downloads by `Content-Type`, using ``WebImagePickerConfiguration/allowedImageTypeIdentifiers`` as `UTType` identifiers (for example ``UTType/jpeg`` `.identifier`).
enum ImageTypeAllowlist {
    static func isFilteringEnabled(for configuration: WebImagePickerConfiguration) -> Bool {
        guard let ids = configuration.allowedImageTypeIdentifiers, !ids.isEmpty else { return false }
        return true
    }

    private static func resolvedAllowedTypes(for configuration: WebImagePickerConfiguration) -> [UTType] {
        guard let ids = configuration.allowedImageTypeIdentifiers else { return [] }
        return ids.compactMap { UTType($0) }
    }

    /// Discovery-time filter using the URL’s path extension.
    static func passesDiscovery(url: URL, configuration: WebImagePickerConfiguration) -> Bool {
        guard isFilteringEnabled(for: configuration) else { return true }

        let ext = url.pathExtension.lowercased()
        if ext.isEmpty {
            return configuration.unknownImageTypePolicy == .allow
        }

        guard let inferred = UTType(filenameExtension: ext) else {
            return configuration.unknownImageTypePolicy == .allow
        }

        if !inferred.conforms(to: .image) {
            return false
        }

        return matchesAllowlist(imageType: inferred, configuration: configuration)
    }

    /// Download-time filter using the response `Content-Type` header (parameters such as `charset` are ignored).
    static func passesDownload(contentTypeHeader: String?, configuration: WebImagePickerConfiguration) -> Bool {
        guard isFilteringEnabled(for: configuration) else { return true }

        let mime = contentTypeHeader?
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        guard let mime, !mime.isEmpty else {
            return configuration.unknownImageTypePolicy == .allow
        }

        guard let inferred = UTType(mimeType: mime) else {
            return configuration.unknownImageTypePolicy == .allow
        }

        if !inferred.conforms(to: .image) {
            return false
        }

        return matchesAllowlist(imageType: inferred, configuration: configuration)
    }

    private static func matchesAllowlist(imageType: UTType, configuration: WebImagePickerConfiguration) -> Bool {
        let allowed = resolvedAllowedTypes(for: configuration)
        if allowed.isEmpty {
            return true
        }
        for a in allowed where imageType.conforms(to: a) {
            return true
        }
        return false
    }
}
