import SwiftUI

/// A staggered-column layout that places each subview in the currently shortest column.
public struct MasonryLayout: Layout {
    public var columns: Int
    public var spacing: CGFloat

    public init(columns: Int = 2, spacing: CGFloat = 8) {
        self.columns = max(1, columns)
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .zero
        guard width.isFinite, width > 0, !subviews.isEmpty else {
            return CGSize(width: width, height: proposal.height ?? 0)
        }

        let columnCount = min(columns, subviews.count)
        let columnWidth = (width - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
        var columnHeights = Array(repeating: CGFloat(0), count: columnCount)

        for subview in subviews {
            let proposed = ProposedViewSize(width: columnWidth, height: nil)
            let height = subview.sizeThatFits(proposed).height
            if let index = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset {
                columnHeights[index] += height + spacing
            }
        }

        let maxHeight = (columnHeights.max() ?? 0) - spacing
        return CGSize(width: width, height: max(0, maxHeight))
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }

        let width = bounds.width
        let columnCount = min(columns, subviews.count)
        let columnWidth = (width - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
        var columnHeights = Array(repeating: CGFloat(0), count: columnCount)

        for subview in subviews {
            let proposed = ProposedViewSize(width: columnWidth, height: nil)
            let size = subview.sizeThatFits(proposed)
            guard let column = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset else {
                continue
            }

            let x = bounds.minX + CGFloat(column) * (columnWidth + spacing)
            let y = bounds.minY + columnHeights[column]
            let point = CGPoint(x: x, y: y)
            subview.place(at: point, proposal: ProposedViewSize(width: columnWidth, height: size.height))
            columnHeights[column] += size.height + spacing
        }
    }
}
