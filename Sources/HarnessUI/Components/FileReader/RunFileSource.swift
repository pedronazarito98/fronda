import AppKit
import Foundation
import UniformTypeIdentifiers

enum RunFileSource: Hashable, Identifiable, Sendable {
    case external(URL)
    case workspace(root: String, path: String)
    case snapshot(name: String, content: String)
    case artifact(url: URL, name: String)

    var id: Self { self }

    var name: String {
        switch self {
        case .external(let url): url.lastPathComponent
        case .workspace(_, let path), .snapshot(let path, _): (path as NSString).lastPathComponent
        case .artifact(let url, let name): name.isEmpty ? url.lastPathComponent : name
        }
    }

    var origin: String {
        switch self {
        case .external: "Arquivo local"
        case .workspace: "Arquivo de trabalho"
        case .snapshot: "Cópia do contexto"
        case .artifact: "Evidência preservada"
        }
    }

    var format: RunFileFormat {
        if case .artifact(let url, _) = self { return RunFileFormat(fileExtension: url.pathExtension) }
        return RunFileFormat(fileExtension: (name as NSString).pathExtension)
    }

    @MainActor static func chooseExternal() -> Self? {
        let panel = NSOpenPanel()
        panel.title = "Ler arquivo no Fronda"
        panel.prompt = "Ler arquivo"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return .external(url)
    }

    static func prefersQuickLook(for filename: String) -> Bool {
        guard let type = UTType(filenameExtension: (filename as NSString).pathExtension) else { return false }
        return [.pdf, .image, .movie, .audio].contains { type.conforms(to: $0) }
    }
}

enum RunFileFormat: String, Sendable {
    case markdown = "Markdown"
    case json = "JSON"
    case csv = "CSV"
    case tsv = "TSV"
    case code = "Código"
    case text = "Texto"

    init(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "md", "markdown", "mdown", "mkd": self = .markdown
        case "json", "geojson": self = .json
        case "csv": self = .csv
        case "tsv", "tab": self = .tsv
        default:
            if let type = UTType(filenameExtension: fileExtension), type.conforms(to: .sourceCode) {
                self = .code
            } else {
                self = .text
            }
        }
    }

    var symbol: String {
        switch self {
        case .markdown: "text.richtext"
        case .json: "curlybraces"
        case .csv, .tsv: "tablecells"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .text: "doc.plaintext"
        }
    }
}
