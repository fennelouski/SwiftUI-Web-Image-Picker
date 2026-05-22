import XCTest
@testable import WebImagePicker

final class MasonryThumbnailScaleTests: XCTestCase {
    func testDenseGridUsesRaisedBaseline() {
        XCTAssertEqual(
            MasonryThumbnailScale.linearScaleVsToday(imageCount: 40),
            MasonryThumbnailScale.denseGridLinearScaleVsToday
        )
        XCTAssertEqual(
            MasonryThumbnailScale.linearScaleVsToday(imageCount: 100),
            MasonryThumbnailScale.denseGridLinearScaleVsToday
        )
        XCTAssertGreaterThan(
            MasonryThumbnailScale.denseGridLinearScaleVsToday,
            1
        )
    }

    func testSingleImageUsesMaximumScale() {
        XCTAssertEqual(MasonryThumbnailScale.linearScaleVsToday(imageCount: 1), 3)
        XCTAssertEqual(MasonryThumbnailScale.linearScaleVsToday(imageCount: 0), 1)
    }

    func testMidCountInterpolatesBetweenDenseAndSparse() {
        let scale = MasonryThumbnailScale.linearScaleVsToday(imageCount: 20)
        XCTAssertGreaterThan(scale, MasonryThumbnailScale.denseGridLinearScaleVsToday)
        XCTAssertLessThan(scale, MasonryThumbnailScale.maximumLinearScaleVsToday)
    }

    func testScaleNeverBelowToday() {
        for count in 1...50 {
            XCTAssertGreaterThanOrEqual(
                MasonryThumbnailScale.linearScaleVsToday(imageCount: count),
                1
            )
        }
    }

    func testEffectiveColumnCountDecreasesAsImageCountDecreases() {
        let base = 4
        var previous = MasonryThumbnailScale.effectiveColumnCount(baseColumns: base, imageCount: 1)
        for count in 2...45 {
            let current = MasonryThumbnailScale.effectiveColumnCount(baseColumns: base, imageCount: count)
            XCTAssertGreaterThanOrEqual(current, previous)
            previous = current
        }
    }

    func testEffectiveColumnCountAtDenseGridMatchesRaisedBaseline() {
        XCTAssertEqual(
            MasonryThumbnailScale.effectiveColumnCount(baseColumns: 4, imageCount: 40),
            3
        )
    }

    func testMaxTileWidthCapsSingleColumnSparseLayout() {
        let width: CGFloat = 400
        let maxWidth = MasonryThumbnailScale.maxTileWidth(
            containerWidth: width,
            baseColumns: 4,
            imageCount: 1
        )
        XCTAssertNotNil(maxWidth)
        XCTAssertEqual(maxWidth!, 300, accuracy: 0.5)
    }

    func testMaxTileWidthNilForMultiColumn() {
        XCTAssertNil(
            MasonryThumbnailScale.maxTileWidth(
                containerWidth: 400,
                baseColumns: 4,
                imageCount: 40
            )
        )
    }

    func testTileMinHeightsScaleWithImageCount() {
        let sparse = MasonryThumbnailScale.tileMinHeightsVsToday(imageCount: 1)
        XCTAssertEqual(sparse.loading, 360)
        XCTAssertEqual(sparse.failure, 300)

        let dense = MasonryThumbnailScale.tileMinHeightsVsToday(imageCount: 40)
        XCTAssertEqual(dense.loading, 160)
        XCTAssertEqual(dense.failure, 133)
    }
}
