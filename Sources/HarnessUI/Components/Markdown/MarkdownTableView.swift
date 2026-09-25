import SwiftUI

struct MarkdownTableView: View {
    let block: MarkdownBlock

    var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(block.rows) { row in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(row.cells) { cell in
                            MarkdownInlineText(cell.text)
                                .font(.system(size: 13, weight: row.isHeader ? .semibold : .regular))
                                .frame(width: columnWidth(cell.column), alignment: alignment(cell.column))
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

    private func columnWidth(_ column: Int) -> CGFloat {
        let longest =
            block.rows.compactMap { row in
                row.cells.first { $0.column == column }?.text.characters.count
            }.max() ?? 0
        return min(320, max(110, CGFloat(longest) * 7))
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
