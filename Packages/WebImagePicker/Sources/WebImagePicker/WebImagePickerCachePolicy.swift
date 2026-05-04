import Foundation

/// Tunable caching for ``WebImagePicker``.
///
/// The policy controls two distinct layers:
///
/// 1. ``requestCachePolicy`` is applied to every `URLRequest` the package issues — HTML page fetches, image-dimension probes, and final image downloads. It sits on top of whatever `URLCache` the integrator's ``WebImagePickerConfiguration/urlSession`` uses, so the disk-cache footprint depends on that session's `URLSessionConfiguration.urlCache`.
/// 2. The remaining knobs configure an in-memory, per-session **discovered image list** cache. Each entry stores the raw output of ``PageImageExtractor/discoverImages(from:configuration:)`` for one page URL so a re-load (or revisit during multi-URL aggregation) skips HTML fetch + parse work. Sort, dimension filtering, and per-page caps still re-run on every load, so changing those configuration knobs reflects without invalidating the cache.
///
/// Defaults match the behavior of versions before this policy existed: `URLRequest`s use ``URLRequest/CachePolicy/useProtocolCachePolicy`` and the discovery-list cache is **disabled** (``maximumDiscoveryEntries`` `0`). Use ``ephemeral`` to be explicit about that, or ``sessionBounded`` for a sane bounded-cache preset.
///
/// ### Privacy
///
/// This package's discovery-list cache lives only in process memory and is cleared when the picker is dismissed or the user changes URLs. Any **on-disk** caching of page bytes or images comes from the integrator's `URLSession`/`URLCache` choice — not from this policy. Sensitive URLs may still touch disk through the system `URLCache` if the supplied session is configured with a disk cache.
public struct WebImagePickerCachePolicy: Sendable, Hashable {
    /// Cache policy applied to all `URLRequest`s issued by the package (HTML fetch, image probe, image download).
    ///
    /// Default ``URLRequest/CachePolicy/useProtocolCachePolicy`` matches the URL-loading-system default and the package's behavior before this policy was introduced.
    public var requestCachePolicy: URLRequest.CachePolicy

    /// Maximum number of cached discovered-image lists kept across page reloads in the current picker session.
    ///
    /// `0` (default) **disables** the discovery cache — every load runs the extractor again. Positive values cap the in-memory entries; the least-recently-used entry is evicted when the cap would be exceeded.
    public var maximumDiscoveryEntries: Int

    /// Optional age cap for cached discovery-list entries. `nil` (default) means entries never expire by age.
    ///
    /// Stored entries record their insertion time using the cache's clock; ``DiscoveredImageListCache`` accepts an injectable clock to make TTL behavior testable.
    public var discoveryEntryTimeToLive: TimeInterval?

    /// Optional cap on cached discovery-list entries per registrable host (the request `URL`'s lowercased `host`). `nil` (default) disables per-domain limits.
    ///
    /// Useful when one noisy site could otherwise fill the global LRU. Per-domain eviction runs before the global ``maximumDiscoveryEntries`` eviction.
    public var perDomainMaximumEntries: Int?

    /// Creates a cache policy. Negative or zero `maximumDiscoveryEntries` is clamped to `0` (cache disabled). Non-positive TTL or per-domain caps are normalized to `nil`.
    public init(
        requestCachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        maximumDiscoveryEntries: Int = 0,
        discoveryEntryTimeToLive: TimeInterval? = nil,
        perDomainMaximumEntries: Int? = nil
    ) {
        self.requestCachePolicy = requestCachePolicy
        self.maximumDiscoveryEntries = max(0, maximumDiscoveryEntries)
        self.discoveryEntryTimeToLive = discoveryEntryTimeToLive.flatMap { $0 > 0 ? $0 : nil }
        self.perDomainMaximumEntries = perDomainMaximumEntries.flatMap { $0 > 0 ? $0 : nil }
    }

    /// No caching beyond what the protocol cache already provides. Equivalent to the defaults and the behavior before this policy existed.
    public static let ephemeral = WebImagePickerCachePolicy()

    /// A bounded cache appropriate for multi-URL browsing sessions: keeps the most recent 32 page extractions, expires entries after ten minutes, and prevents any single host from holding more than 8 entries.
    public static let sessionBounded = WebImagePickerCachePolicy(
        requestCachePolicy: .useProtocolCachePolicy,
        maximumDiscoveryEntries: 32,
        discoveryEntryTimeToLive: 600,
        perDomainMaximumEntries: 8
    )
}
