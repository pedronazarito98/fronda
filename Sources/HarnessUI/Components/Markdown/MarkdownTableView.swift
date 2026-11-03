import SwiftUI

struct MarkdownTableView: View {
    let block: MarkdownBlock

    var body: some View {
        let widths = columnWidths
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(block.rows) { row in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(row.cells) { cell in
                            MarkdownInlineText(cell.text)
                                .font(.system(size: 13, weight: row.isHeader ? .semibold : .regular))
                                .frame(width: widths[cell.column], alignment: alignment(cell.column))
                                .padding(.horizontal, 14).padding(.vertical, 11)
                        }
                    }
                    .background(row.isHeader ? Color.secondary.opacity(0.10) : Color.clear, in: Rectangle())
                    .overlay(alignment: .bottom) { Divider() }
                }
            }
            .background(.background.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            .clipShape(.rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary, lineWidth: 1))
        }
    }

    private var columnWidths: [CGFloat] {
        var widths = Array(repeating: CGFloat(110), count: block.columns.count)
        for row in block.rows {
            for cell in row.cells where widths.indices.contains(cell.column) {
                let length = cell.text.characters.prefix(46).count
                widths[cell.column] = max(widths[cell.column], min(320, CGFloat(length) * 7))
            }
        }
        return widths
    }

    private func alignment(_ column: Int) -> Alignment {
        guard block.columns.indices.contains(column) else { return .leading }
        switch block.columns[column].alignment {
        case .center: return .center
        case .right: return .trailing
        default: return .leading
        }
    }
}
