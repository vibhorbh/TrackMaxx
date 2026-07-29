//
//  MasonryLayout.swift
//  CalorieAI
//
//  A small, custom `Layout` conformance: N balanced columns, each new item
//  placed into whichever column is currently shortest. This is what gives
//  the timeline its "magazine catalog" rhythm instead of a rigid grid —
//  paired with `TimelineMealCard`'s per-entry aspect ratio variation.
//

import SwiftUI

struct MasonryLayout: Layout {
    var columns: Int = 2
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 0
        guard width > 0, columns > 0 else { return .zero }
        let columnWidth = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        var columnHeights = [CGFloat](repeating: 0, count: columns)

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            let shortest = shortestColumn(columnHeights)
            columnHeights[shortest] += size.height + spacing
        }

        let maxHeight = max((columnHeights.max() ?? 0) - spacing, 0)
        return CGSize(width: width, height: maxHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        guard bounds.width > 0, columns > 0 else { return }
        let columnWidth = (bounds.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        var columnHeights = [CGFloat](repeating: 0, count: columns)

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            let columnIndex = shortestColumn(columnHeights)
            let x = bounds.minX + CGFloat(columnIndex) * (columnWidth + spacing)
            let y = bounds.minY + columnHeights[columnIndex]
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: columnWidth, height: size.height)
            )
            columnHeights[columnIndex] += size.height + spacing
        }
    }

    private func shortestColumn(_ heights: [CGFloat]) -> Int {
        heights.indices.min { heights[$0] < heights[$1] } ?? 0
    }
}
