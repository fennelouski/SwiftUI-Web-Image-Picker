import CoreGraphics

/// Maps discovered-image count to masonry column count and tile dimensions relative to the pre-1.2.2 layout.
enum MasonryThumbnailScale {
    /// At this count and above, thumbnails use the raised dense-grid scale (still below sparse maximum).
    static let referenceCountForDenseGrid = 40

    /// Linear scale vs today's tile width/height at 1 image.
    static let maximumLinearScaleVsToday: CGFloat = 3

    /// Linear scale vs today at ``referenceCountForDenseGrid`` and above (~4→3 columns on regular width).
    static let denseGridLinearScaleVsToday: CGFloat = 4.0 / 3.0

    static let todayLoadingMinHeight: CGFloat = 120
    static let todayFailureMinHeight: CGFloat = 100

    /// Linear width/height multiplier relative to the legacy picker layout.
    static func linearScaleVsToday(imageCount: Int) -> CGFloat {
        guard imageCount > 0 else { return 1 }
        if imageCount >= referenceCountForDenseGrid {
            return denseGridLinearScaleVsToday
        }
        if imageCount <= 1 {
            return maximumLinearScaleVsToday
        }
        let referenceSpan = CGFloat(referenceCountForDenseGrid - 1)
        let t = CGFloat(referenceCountForDenseGrid - imageCount) / referenceSpan
        let scale = denseGridLinearScaleVsToday
            + (maximumLinearScaleVsToday - denseGridLinearScaleVsToday) * t
        return max(1, min(maximumLinearScaleVsToday, scale))
    }

    static func effectiveColumnCount(baseColumns: Int, imageCount: Int) -> Int {
        let base = max(1, baseColumns)
        let scale = linearScaleVsToday(imageCount: imageCount)
        return max(1, Int((CGFloat(base) / scale).rounded()))
    }

    /// When masonry collapses to one column, caps tile width so linear scale does not exceed ``maximumLinearScaleVsToday``.
    static func maxTileWidth(containerWidth: CGFloat, baseColumns: Int, imageCount: Int) -> CGFloat? {
        guard containerWidth > 0 else { return nil }
        let base = max(1, baseColumns)
        let columns = effectiveColumnCount(baseColumns: base, imageCount: imageCount)
        guard columns == 1 else { return nil }
        let scale = linearScaleVsToday(imageCount: imageCount)
        guard scale < CGFloat(base) else { return nil }
        return containerWidth * scale / CGFloat(base)
    }

    static func tileMinHeightsVsToday(imageCount: Int) -> (loading: CGFloat, failure: CGFloat) {
        let scale = linearScaleVsToday(imageCount: imageCount)
        return (
            loading: (todayLoadingMinHeight * scale).rounded(),
            failure: (todayFailureMinHeight * scale).rounded()
        )
    }
}
