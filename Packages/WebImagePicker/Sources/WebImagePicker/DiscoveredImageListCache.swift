import Foundation

/// In-memory LRU cache of raw ``DiscoveredImage`` lists keyed by page URL, scoped to one picker session.
///
/// Used when ``WebImagePickerCachePolicy/maximumDiscoveryEntries`` is positive. Thread-safe. TTL and per-domain eviction use the policy limits from ``WebImagePickerCachePolicy``.
final class DiscoveredImageListCache: @unchecked Sendable {
    private let lock = NSLock()
    private let maximumEntries: Int
    private let timeToLive: TimeInterval?
    private let perDomainMaximumEntries: Int?
    private var clock: @Sendable () -> Date

    private struct Entry {
        let images: [DiscoveredImage]
        let insertedAt: Date
        let hostKey: String
    }

    private var storage: [URL: Entry] = [:]
    /// Global order from least- to most-recently used.
    private var globalOrder: [URL] = []
    /// Per-host order from least- to most-recently used.
    private var domainOrder: [String: [URL]] = [:]

    /// - Parameter maximumEntries: Must be at least `1` (callers that disable caching use `makeIfEnabled` instead).
    /// - Parameter clock: Injectable for tests; defaults to `Date.init`.
    init(
        maximumEntries: Int,
        timeToLive: TimeInterval?,
        perDomainMaximumEntries: Int?,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        precondition(maximumEntries > 0, "DiscoveredImageListCache requires a positive entry cap")
        self.maximumEntries = maximumEntries
        self.timeToLive = timeToLive
        self.perDomainMaximumEntries = perDomainMaximumEntries
        self.clock = clock
    }

    /// Returns the cached raw discovery list for `pageURL`, or `nil` on miss / expiry. Updates recency on hit.
    func lookup(_ pageURL: URL) -> [DiscoveredImage]? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = storage[pageURL] else { return nil }
        if let ttl = timeToLive, clock().timeIntervalSince(entry.insertedAt) > ttl {
            removeLocked(pageURL)
            return nil
        }
        touchLocked(pageURL)
        return entry.images
    }

    /// Inserts or replaces the raw list for `pageURL`. Evicts by per-domain and global LRU when over capacity.
    func store(_ pageURL: URL, images: [DiscoveredImage]) {
        lock.lock()
        defer { lock.unlock() }
        let host = Self.hostKey(for: pageURL)
        if let existing = storage[pageURL] {
            storage[pageURL] = Entry(images: images, insertedAt: existing.insertedAt, hostKey: existing.hostKey)
            touchLocked(pageURL)
            return
        }
        while let cap = perDomainMaximumEntries, (domainOrder[host]?.count ?? 0) >= cap {
            guard let victim = domainOrder[host]?.first else { break }
            removeLocked(victim)
        }
        while storage.count >= maximumEntries, !globalOrder.isEmpty {
            guard let victim = globalOrder.first else { break }
            removeLocked(victim)
        }
        let now = clock()
        storage[pageURL] = Entry(images: images, insertedAt: now, hostKey: host)
        globalOrder.append(pageURL)
        domainOrder[host, default: []].append(pageURL)
    }

    /// Clears all entries (for example when the user changes the page URL in the picker).
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll(keepingCapacity: false)
        globalOrder.removeAll(keepingCapacity: false)
        domainOrder.removeAll(keepingCapacity: false)
    }

    private func touchLocked(_ pageURL: URL) {
        if let i = globalOrder.firstIndex(of: pageURL) {
            globalOrder.remove(at: i)
        }
        globalOrder.append(pageURL)
        guard let host = storage[pageURL]?.hostKey else { return }
        if var order = domainOrder[host], let j = order.firstIndex(of: pageURL) {
            order.remove(at: j)
            order.append(pageURL)
            domainOrder[host] = order
        }
    }

    private func removeLocked(_ pageURL: URL) {
        let host = storage[pageURL]?.hostKey ?? Self.hostKey(for: pageURL)
        storage.removeValue(forKey: pageURL)
        globalOrder.removeAll { $0 == pageURL }
        if var order = domainOrder[host] {
            order.removeAll { $0 == pageURL }
            if order.isEmpty {
                domainOrder[host] = nil
            } else {
                domainOrder[host] = order
            }
        }
    }

    private static func hostKey(for url: URL) -> String {
        (url.host ?? "").lowercased()
    }
}

extension DiscoveredImageListCache {
    /// Constructs a cache only when ``WebImagePickerCachePolicy/maximumDiscoveryEntries`` is positive.
    static func makeIfEnabled(for policy: WebImagePickerCachePolicy) -> DiscoveredImageListCache? {
        guard policy.maximumDiscoveryEntries > 0 else { return nil }
        return DiscoveredImageListCache(
            maximumEntries: policy.maximumDiscoveryEntries,
            timeToLive: policy.discoveryEntryTimeToLive,
            perDomainMaximumEntries: policy.perDomainMaximumEntries
        )
    }
}
