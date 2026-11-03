import Foundation
import HarnessDomain

struct RunDelimitedTable: Sendable {
    let rows: [[String]]
    let columnCount: Int
    let columnWidths: [CGFloat]

    init(_ source: String, tsv: Bool) throws {
        let bytes = Array(source.utf8)
        let delimiter: UInt8 = tsv ? 9 : Self.csvDelimiter(in: bytes)
        var rows = [[String]]()
        var row = [String]()
        var field = [UInt8]()
        var quoted = false
        var quoteClosed = false
        var index = 0
        var cells = 0
        var widths = [Int]()
        func finishField() throws {
            guard row.count < 100, cells < 50_000 else {
                throw HarnessError(
                    "A tabela excede 100 colunas ou 50.000 células. O conteúdo está disponível na fonte.")
            }
            let value = String(decoding: field, as: UTF8.self)
            let column = row.count
            if column == widths.count { widths.append(0) }
            widths[column] = max(widths[column], value.prefix(42).count)
            row.append(value)
            field.removeAll(keepingCapacity: true)
            quoteClosed = false
            cells += 1
        }
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            if quoted {
                if byte != 34 {
                    field.append(byte)
                } else if index < bytes.count && bytes[index] == 34 {
                    field.append(34)
                    index += 1
                } else {
                    quoted = false
                    quoteClosed = true
                }
                continue
            }
            switch byte {
            case delimiter: try finishField()
            case 10, 13:
                if byte == 13 && index < bytes.count && bytes[index] == 10 { index += 1 }
                try finishField()
                rows.append(row)
                row.removeAll(keepingCapacity: true)
            case 34 where field.isEmpty && !quoteClosed: quoted = true
            case 34: throw Self.malformed
            case 32 where quoteClosed: continue
            default:
                guard !quoteClosed else { throw Self.malformed }
                field.append(byte)
            }
        }
        guard !quoted else { throw Self.malformed }
        if !row.isEmpty || !field.isEmpty || quoteClosed {
            try finishField()
            rows.append(row)
        }
        self.rows = rows
        columnCount = widths.count
        columnWidths = widths.map { CGFloat(max(105, min(290, 24 + $0 * 7))) }
    }

    private static var malformed: HarnessError {
        HarnessError("As aspas ou os separadores da tabela não puderam ser interpretados. Confira a fonte.")
    }

    private static func csvDelimiter(in bytes: [UInt8]) -> UInt8 {
        var quoted = false
        var commas = 0
        var semicolons = 0
        for byte in bytes {
            if byte == 34 { quoted.toggle() }
            if !quoted {
                if byte == 10 || byte == 13 { break }
                if byte == 44 { commas += 1 }
                if byte == 59 { semicolons += 1 }
            }
        }
        return semicolons > commas ? 59 : 44
    }
}
