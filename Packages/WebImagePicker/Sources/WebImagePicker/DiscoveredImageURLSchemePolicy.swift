import Foundation

enum DiscoveredImageURLSchemePolicy {
    static func allowedSchemesLowercased(_ configuration: WebImagePickerConfiguration) -> Set<String> {
        Set(configuration.allowedURLSchemes.map { $0.lowercased() })
    }

    /// Whether `resolvedURL` is omitted from discovery solely because it uses HTTP while `http` is not allowed.
    static func shouldCountSkippedHTTPImage(resolvedURL: URL, allowedLowercased: Set<String>) -> Bool {
        guard let sch = resolvedURL.scheme?.lowercased(), sch == "http" else { return false }
        return !allowedLowercased.contains("http")
    }
}
