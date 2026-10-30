import SwiftUI

struct HomeCardSpan: LayoutValueKey {
    static let defaultValue = 1
}

struct HomeCardOrder: LayoutValueKey {
    static let defaultValue = 0
}

struct HomeGridMetrics {
    static let gap: CGFloat = 16
    let columns: Int
    let unit: CGFloat

    init(width: CGFloat) {
        columns = min(3, max(1, Int((width + Self.gap) / (300 + Self.gap))))
        unit = max(1, (width - CGFloat(columns - 1) * Self.gap) / CGFloat(columns))
    }
}

struct HomeCardGrid: Layout {
    private let gap = HomeGridMetrics.gap

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let proposedWidth = proposal.width ?? 960
        let width = proposedWidth.isFinite ? max(1, proposedWidth) : 960
        let frames = frames(width: width, subviews: subviews)
        return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = frames(width: bounds.width, subviews: subviews)
        for (index, frame) in frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size))
        }
    }

    private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        let metrics = HomeGridMetrics(width: width)
        let columns = metrics.columns
        let unit = metrics.unit
        let order = subviews.indices.sorted { subviews[$0][HomeCardOrder.self] < subviews[$1][HomeCardOrder.self] }
        var result = Array(repeating: CGRect.zero, count: subviews.count)
        var rowIndices: [Int] = []
        var column = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        func finishRow() {
            y += rowHeight + gap
            rowIndices.removeAll(keepingCapacity: true)
            rowHeight = 0
            column = 0
        }
        for index in order {
            let view = subviews[index]
            let span = min(columns, max(1, view[HomeCardSpan.self]))
            if column + span > columns { finishRow() }
            let cardWidth = CGFloat(span) * unit + CGFloat(span - 1) * gap
            let size = view.sizeThatFits(ProposedViewSize(width: cardWidth, height: nil))
            result[index] = CGRect(x: CGFloat(column) * (unit + gap), y: y, width: cardWidth, height: size.height)
            rowIndices.append(index)
            rowHeight = max(rowHeight, size.height)
            column += span
        }
        if !rowIndices.isEmpty { finishRow() }
        return result
    }
}
