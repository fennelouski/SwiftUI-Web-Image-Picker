import Foundation

/// Policy when an image’s type cannot be inferred from the URL path or from HTTP `Content-Type` while an allowlist is active.
public enum WebImageUnknownTypePolicy: Sendable, Hashable {
    /// Keep discovery candidates and allow downloads when the type is unknown (for example extension-less URLs or servers that omit `Content-Type`).
    case allow
    /// Drop extension-less or unmapped discovery URLs; fail downloads when `Content-Type` is missing or cannot be mapped to an image type.
    case reject
}
