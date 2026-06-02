import XCTest
@testable import WebImagePicker

final class PageURLCorrectionTests: XCTestCase {
    func testGoogleShortTLDProducesComFirst() {
        let candidates = PageURLCorrection.correctionCandidates(
            trimmedInput: "google.c",
            strategy: .aggressive,
            maximumCandidates: 8
        )
        XCTAssertFalse(candidates.isEmpty)
        XCTAssertTrue(candidates.contains("google.com"))
        XCTAssertFalse(candidates.contains("google.c"))
    }

    func testGoogleWithoutDotAppendsMultipleTLDs() {
        let candidates = PageURLCorrection.correctionCandidates(
            trimmedInput: "google",
            strategy: .aggressive,
            maximumCandidates: 8
        )
        XCTAssertTrue(candidates.contains("google.com"))
        XCTAssertTrue(candidates.contains("google.net"))
        XCTAssertTrue(candidates.contains("google.org"))
    }

    func testPreservesPath() {
        let candidates = PageURLCorrection.correctionCandidates(
            trimmedInput: "google.c/search",
            strategy: .aggressive,
            maximumCandidates: 8
        )
        XCTAssertTrue(candidates.contains("google.com/search"))
    }

    func testPreservesExplicitScheme() {
        let candidates = PageURLCorrection.correctionCandidates(
            trimmedInput: "https://google.c",
            strategy: .aggressive,
            maximumCandidates: 8
        )
        XCTAssertTrue(candidates.contains("https://google.com"))
    }

    func testSearchPhraseNotEligible() {
        XCTAssertFalse(PageURLCorrection.isEligibleForCorrection(trimmedInput: "best pizza near me"))
        XCTAssertTrue(PageURLCorrection.correctionCandidates(
            trimmedInput: "best pizza near me",
            strategy: .aggressive,
            maximumCandidates: 8
        ).isEmpty)
    }

    func testEmailNotEligible() {
        XCTAssertFalse(PageURLCorrection.isEligibleForCorrection(trimmedInput: "user@example.com"))
    }

    func testRespectsMaximumCandidates() {
        let candidates = PageURLCorrection.correctionCandidates(
            trimmedInput: "google",
            strategy: .aggressive,
            maximumCandidates: 2
        )
        XCTAssertEqual(candidates.count, 2)
    }

    func testBBCcoNotRewrittenAsSuspiciousTLD() {
        let candidates = PageURLCorrection.correctionCandidates(
            trimmedInput: "bbc.co",
            strategy: .aggressive,
            maximumCandidates: 8
        )
        XCTAssertFalse(candidates.contains(where: { $0.hasPrefix("bbc.com") && !$0.contains("www.") }))
    }

    func testDeduplicatesCandidates() {
        let candidates = PageURLCorrection.correctionCandidates(
            trimmedInput: "google",
            strategy: .aggressive,
            maximumCandidates: 20
        )
        let lowered = candidates.map { $0.lowercased() }
        XCTAssertEqual(lowered.count, Set(lowered).count)
    }

    func testDisplayStringIncludesPath() {
        let url = URL(string: "https://example.com/path?q=1")!
        XCTAssertEqual(PageURLCorrection.displayString(for: url), "example.com/path?q=1")
    }
}
