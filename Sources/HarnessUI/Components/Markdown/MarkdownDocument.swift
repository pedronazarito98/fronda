import Foundation

struct MarkdownDocument: Sendable {
    var blocks = [MarkdownBlock]()

    init(_ source: String) {
        guard let parsed = try? AttributedString(markdown: source) else {
            blocks = [MarkdownBlock(id: 0, text: AttributedString(source))]
            return
        }
        var markedItems = Set<Int>()
        for (intent, range) in parsed.runs[\.presentationIntent] {
            let components = intent?.components ?? []
            var text = AttributedString(parsed[range])
            text.presentationIntent = nil
            let identity = components.first?.identity ?? 0
            if let table = components.first(where: {
                if case .table = $0.kind { return true }
                return false
            }),
                case .table(let columns) = table.kind
            {
                if blocks.last?.id != table.identity {
                    blocks.append(MarkdownBlock(id: table.identity, kind: .table, columns: columns))
                }
                let row = components.first {
                    if case .tableHeaderRow = $0.kind { return true }
                    if case .tableRow = $0.kind { return true }
                    return false
                }
                let cell = components.first {
                    if case .tableCell = $0.kind { return true }
                    return false
                }
                if let row, let cell, case .tableCell(let column) = cell.kind {
                    let tableIndex = blocks.count - 1
                    if blocks[tableIndex].rows.last?.id != row.identity {
                        blocks[tableIndex].rows.append(
                            MarkdownRow(id: row.identity, isHeader: row.kind == .tableHeaderRow))
                    }
                    let rowIndex = blocks[tableIndex].rows.count - 1
                    blocks[tableIndex].rows[rowIndex].cells.append(
                        MarkdownCell(id: "\(row.identity):\(column)", column: column, text: text))
                }
                continue
            }
            var block = MarkdownBlock(id: identity, text: text)
            for component in components {
                switch component.kind {
                case .header(let level): block.kind = .heading(level)
                case .codeBlock(let language): block.kind = .code(language)
                case .thematicBreak: block.kind = .divider
                case .blockQuote: block.quoted = true
                case .orderedList, .unorderedList: block.listDepth += 1
                default: break
                }
            }
            if let item = components.first(where: {
                if case .listItem = $0.kind { return true }
                return false
            }),
                case .listItem(let ordinal) = item.kind, markedItems.insert(item.identity).inserted
            {
                let list = components.first { $0.kind == .orderedList || $0.kind == .unorderedList }
                block.marker = list?.kind == .orderedList ? "\(ordinal)." : "•"
                let plain = String(text.characters)
                if plain.hasPrefix("[ ] ") || plain.hasPrefix("[x] ") || plain.hasPrefix("[X] ") {
                    block.checked = !plain.hasPrefix("[ ] ")
                    text.removeSubrange(text.startIndex..<text.characters.index(text.startIndex, offsetBy: 4))
                    block.text = text
                }
            }
            blocks.append(block)
        }
        // Empty cells have no attributed run; keep their columns in the rendered table.
        for index in blocks.indices where !blocks[index].columns.isEmpty {
            for rowIndex in blocks[index].rows.indices {
                let row = blocks[index].rows[rowIndex]
                blocks[index].rows[rowIndex].cells = blocks[index].columns.indices.map { column in
                    row.cells.first { $0.column == column }
                        ?? MarkdownCell(id: "\(row.id):\(column)", column: column, text: AttributedString())
                }
            }
        }
        if blocks.isEmpty && !source.isEmpty {
            blocks = [MarkdownBlock(id: 0, text: AttributedString(source))]
        }
    }
}

struct MarkdownBlock: Identifiable, Sendable {
    enum Kind: Sendable {
        case paragraph
        case heading(Int)
        case code(String?)
        case divider, table
    }
    let id: Int
    var text = AttributedString()
    var kind = Kind.paragraph
    var quoted = false
    var listDepth = 0
    var marker: String?
    var checked: Bool?
    var columns = [PresentationIntent.TableColumn]()
    var rows = [MarkdownRow]()
}

struct MarkdownRow: Identifiable, Sendable {
    let id: Int
    let isHeader: Bool
    var cells = [MarkdownCell]()
}

struct MarkdownCell: Identifiable, Sendable {
    let id: String
    let column: Int
    let text: AttributedString
}
