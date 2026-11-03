import Foundation
import HarnessDomain

struct RunFileDocument: Sendable {
    enum Preview: Sendable {
        case markdown, literal
        case json(String)
        case table(RunDelimitedTable)
        case sourceOnly(String)
    }

    let source: String
    let isRedacted: Bool
    let preview: Preview

    init(format: RunFileFormat, source: String, isRedacted: Bool) {
        self.source = source
        self.isRedacted = isRedacted
        do {
            switch format {
            case .markdown:
                // Keep large reports readable without constructing thousands of SwiftUI cells at once.
                let newlines = source.utf8.lazy.filter { $0 == 10 }.prefix(2_001).count
                let pipes = source.utf8.lazy.filter { $0 == 124 }.prefix(4_001).count
                preview =
                    newlines <= 2_000 && pipes <= 4_000 && source.utf8.count <= 256_000
                    ? .markdown : .sourceOnly("Este Markdown é extenso. A fonte completa está disponível abaixo.")
            case .json: preview = .json(try Self.indentJSON(source))
            case .csv, .tsv: preview = .table(try RunDelimitedTable(source, tsv: format == .tsv))
            case .text, .code: preview = .literal
            }
        } catch {
            preview = .sourceOnly(error.localizedDescription)
        }
    }

    var hasFormattedView: Bool {
        switch preview {
        case .markdown, .json, .table: true
        case .literal, .sourceOnly: false
        }
    }

    /// Foundation checks syntax. Indent the original tokens to preserve numeric precision and key order.
    private static func indentJSON(_ source: String) throws -> String {
        let bytes = Array(source.utf8)
        guard (try? JSONSerialization.jsonObject(with: Data(bytes), options: [.fragmentsAllowed])) != nil else {
            throw HarnessError("O conteúdo não pôde ser interpretado como JSON. Confira a fonte.")
        }
        var output = [UInt8]()
        var depth = 0
        var inString = false
        var escaped = false
        var previous: UInt8?
        func newline() {
            output.append(10)
            output.append(contentsOf: repeatElement(32, count: depth * 2))
        }
        for byte in bytes {
            if inString {
                output.append(byte)
                if escaped {
                    escaped = false
                } else if byte == 92 {
                    escaped = true
                } else if byte == 34 {
                    inString = false
                }
                continue
            }
            if [9, 10, 13, 32].contains(byte) { continue }
            let closer = byte == 93 || byte == 125
            let openerBefore = previous == 91 || previous == 123
            if closer { depth = max(0, depth - 1) }
            if (closer && !openerBefore) || (!closer && (openerBefore || previous == 44)) { newline() }
            output.append(byte)
            if byte == 58 { output.append(32) }
            if byte == 34 { inString = true }
            if byte == 91 || byte == 123 { depth += 1 }
            guard output.count <= 2_097_152 else {
                throw HarnessError("A versão indentada excede 2 MiB. A fonte completa está disponível abaixo.")
            }
            previous = byte
        }
        return String(decoding: output, as: UTF8.self)
    }
}
