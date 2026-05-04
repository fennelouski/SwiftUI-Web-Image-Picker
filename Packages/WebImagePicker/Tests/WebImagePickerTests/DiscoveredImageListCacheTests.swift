import XCTest
@testable import WebImagePicker

private final class MutableClock: @unchecked Sendable {
    var timeIntervalSince1970: TimeInterval = 0
    func date() -> Date { Date(timeIntervalSince1970: timeIntervalSince1970) }
}

final class DiscoveredImageListCacheTests: XCTestCase {
    private let sampleImage = DiscoveredImage(sourceURL: URL(string: "https://cdn.example/image.png")!, accessibilityLabel: nil)

    func testMakeIfEnabledReturnsNilWhenDiscoveryCacheDisabled() {
        XCTAssertNil(DiscoveredImageListCache.makeIfEnabled(for: .ephemeral))
    }

    func testMakeIfEnabledConstructsWhenEntriesPositive() {
        let policy = WebImagePickerCachePolicy(maximumDiscoveryEntries: 4)
        XCTAssertNotNil(DiscoveredImageListCache.makeIfEnabled(for: policy))
    }

    func testLRUEvictsLeastRecentlyUsedGlobally() {
        let cache = DiscoveredImageListCache(maximumEntries: 2, timeToLive: nil, perDomainMaximumEntries: nil)
        let u1 = URL(string: "https://a.example/p1")!
        let u2 = URL(string: "https://b.example/p2")!
        let u3 = URL(string: "https://c.example/p3")!
        cache.store(u1, outcome: PageImageDiscoveryOutcome(images: [sampleImage]))
        cache.store(u2, outcome: PageImageDiscoveryOutcome(images: [sampleImage]))
        cache.store(u3, outcome: PageImageDiscoveryOutcome(images: [sampleImage]))
        XCTAssertNil(cache.lookup(u1))
        XCTAssertNotNil(cache.lookup(u2))
        XCTAssertNotNil(cache.lookup(u3))
    }

    func testLookupPromotesEntrySoItIsNotEvictedNext() {
        let cache = DiscoveredImageListCache(maximumEntries: 2, timeToLive: nil, perDomainMaximumEntries: nil)
        let u1 = URL(string: "https://a.example/p1")!
        let u2 = URL(string: "https://b.example/p2")!
        let u3 = URL(string: "https://c.example/p3")!
        cache.store(u1, outcome: PageImageDiscoveryOutcome(images: [sampleImage]))
        cache.store(u2, outcome: PageImageDiscoveryOutcome(images: [sampleImage]))
        _ = cache.lookup(u1)
        cache.store(u3, outcome: PageImageDiscoveryOutcome(images: [sampleImage]))
        XCTAssertNil(cache.lookup(u2))
        XCTAssertNotNil(cache.lookup(u1))
        XCTAssertNotNil(cache.lookup(u3))
    }

    func testTTLExpiresEntries() {
        let clock = MutableClock()
        let cache = DiscoveredImageListCache(
            maximumEntries: 4,
            timeToLive: 60,
            perDomainMaximumEntries: nil,
            clock: { clock.date() }
        )
        let page = URL(string: "https://a.example/")!
        cache.store(page, outcome: PageImageDiscoveryOutcome(images: [sampleImage]))
        XCTAssertNotNil(cache.lookup(page))
        clock.timeIntervalSince1970 += 61
        XCTAssertNil(cache.lookup(page))
    }

    func testPerDomainCapEvictsLRUWithinHostBeforeGlobal() {
        let cache = DiscoveredImageListCache(
            maximumEntries: 10,
            timeToLive: nil,
            perDomainMaximumEntries: 1
        )
        let p1 = URL(string: "https://same.example/path1")!
        let p2 = URL(string: "https://same.example/path2")!
        let other = URL(string: "https://other.example/")!
        cache.store(p1, outcome: PageImageDiscoveryOutcome(images: [sampleImage]))
        cache.store(other, outcome: PageImageDiscoveryOutcome(images: [sampleImage]))
        cache.store(p2, outcome: PageImageDiscoveryOutcome(images: [sampleImage]))
        XCTAssertNil(cache.lookup(p1))
        XCTAssertNotNil(cache.lookup(p2))
        XCTAssertNotNil(cache.lookup(other))
    }

    func testSessionBoundedMatchesPresetNumbers() {
        let s = WebImagePickerCachePolicy.sessionBounded
        XCTAssertEqual(s.maximumDiscoveryEntries, 32)
        XCTAssertEqual(s.discoveryEntryTimeToLive, 600)
        XCTAssertEqual(s.perDomainMaximumEntries, 8)
    }

    func testClearRemovesAllEntries() {
        let cache = DiscoveredImageListCache(maximumEntries: 3, timeToLive: nil, perDomainMaximumEntries: nil)
        let u = URL(string: "https://a.example/")!
        cache.store(u, outcome: PageImageDiscoveryOutcome(images: [sampleImage]))
        cache.clear()
        XCTAssertNil(cache.lookup(u))
    }

    func testLookupReturnsSkippedHTTPCountFromStoredOutcome() throws {
        let cache = DiscoveredImageListCache(maximumEntries: 3, timeToLive: nil, perDomainMaximumEntries: nil)
        let u = URL(string: "https://a.example/")!
        cache.store(
            u,
            outcome: PageImageDiscoveryOutcome(images: [sampleImage], skippedHTTPImageURLsDueToAllowedSchemes: 4)
        )
        let got = try XCTUnwrap(cache.lookup(u))
        XCTAssertEqual(got.images.count, 1)
        XCTAssertEqual(got.skippedHTTPImageURLsDueToAllowedSchemes, 4)
    }
}
