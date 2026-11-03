import SwiftUI

struct RunFileTableView: View {
    let table: RunDelimitedTable
    @State private var usesHeader = true
    @State private var page = 0
    private let pageSize = 50
    private var offset: Int { usesHeader && !table.rows.isEmpty ? 1 : 0 }
    private var count: Int { table.rows.count - offset }
    private var pages: Int { max(1, (count + pageSize - 1) / pageSize) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(
                    "\(count) \(count == 1 ? "linha" : "linhas") · \(table.columnCount) \(table.columnCount == 1 ? "coluna" : "colunas")"
                )
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                Toggle("Primeira linha como cabeçalho", isOn: $usesHeader).controlSize(.small)
            }.padding(.horizontal, 18).padding(.vertical, 10)
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    row(index: usesHeader && !table.rows.isEmpty ? 0 : nil, header: true)
                    let start = min(offset + page * pageSize, table.rows.count)
                    ForEach(start..<min(start + pageSize, table.rows.count), id: \.self) { index in
                        row(index: index, header: false)
                    }
                }.padding(14)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if pages > 1 {
                Divider()
                HStack {
                    Spacer()
                    Button("Anterior", systemImage: "chevron.left") { page -= 1 }.disabled(page == 0)
                    Text("\(page + 1) de \(pages)").font(.caption.monospacedDigit())
                    Button("Próxima", systemImage: "chevron.right") { page += 1 }.disabled(page + 1 >= pages)
                }.controlSize(.small).padding(12)
            }
        }
        .onChange(of: usesHeader) { page = 0 }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("file-reader.table")
    }

    private func row(index: Int?, header: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<table.columnCount, id: \.self) { column in
                let cell = index.flatMap { table.rows[$0].indices.contains(column) ? table.rows[$0][column] : nil }
                let value = cell ?? (header ? "Coluna \(column + 1)" : "")
                let heading =
                    usesHeader && table.rows.first?.indices.contains(column) == true
                    ? table.rows[0][column] : "Coluna \(column + 1)"
                Text(verbatim: value)
                    .font(.system(size: 12, weight: header ? .semibold : .regular))
                    .frame(width: table.columnWidths[column], alignment: .leading)
                    .padding(.horizontal, 8).padding(.vertical, 7)
                    .accessibilityLabel(header ? value : heading + ", " + value)
                    .accessibilityAddTraits(header ? .isHeader : [])
            }
        }
        .background(header ? FrondaTheme.accent.opacity(0.1) : .clear)
        .overlay(alignment: .bottom) { Divider() }
    }
}
