import Foundation
import HarnessDomain

public enum IndexEngine {
    private static let cache = IndexCache()
    /// Index content is delivered in bounded batches; only metadata for the file
    /// list is retained across the scan. SQLite owns the persistent full text.
    public static func stream(project: Project, onBatch: @escaping @Sendable ([ContextItem]) async throws -> Void)
        async throws -> [String]
    {
        let output = try await GitWorkspace.git(
            ["ls-files", "--cached", "--others", "--exclude-standard", "-z"], at: project.path)
        let eligible = Array(Set(output.split(separator: "\0").map(String.init))).sorted().prefix(50000)
        var tests = [String: [String]]()
        for path in eligible where path.lowercased().contains("test") || path.lowercased().contains("spec") {
            tests[stem(path), default: []].append(path)
        }
        var indexed = [String]()
        for start in stride(from: 0, to: eligible.count, by: 64) {
            try Task.checkCancellation()
            let paths = Array(eligible[start..<min(start + 64, eligible.count)])
            var items = await parse(paths: paths, project: project)
            for i in items.indices {
                items[i].associatedTests = tests[stem(items[i].path)]?.filter { $0 != items[i].path } ?? []
            }
            indexed += items.map(\.path)
            try await onBatch(items)
        }
        return indexed
    }
    /// Context candidates are bounded before compilation; pins and cited paths
    /// rank ahead of optional files. Excluded content never stays in the pack.
    public static func scan(project: Project, query: String = "", pins: [String] = []) async throws -> [ContextItem] {
        let collector = CandidateCollector(query: query, pins: pins)
        _ = try await stream(project: project) { items in await collector.add(items) }
        return await collector.items
    }
    private static func parse(paths: [String], project: Project) async -> [ContextItem] {
        await Task.detached(priority: .utility) {
            var items = [ContextItem]()
            for path in paths {
                guard ContextFirewall.exclusion(path) == nil,
                    !ContextFirewall.matches(path, patterns: project.exclusions),
                    let url = try? ContextFirewall.containedPath(path, root: project.path),
                    let values = try? url.resourceValues(forKeys: [
                        .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey,
                    ]),
                    values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 0) <= 256_000
                else { continue }
                let signature = "\(values.fileSize ?? 0):\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)"
                if let cached = await cache.item(path: url.path, signature: signature) {
                    items.append(cached)
                    continue
                }
                guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8),
                    !text.contains("\0")
                else { continue }
                var item = ContextItem()
                item.path = path
                item.hash = Coding.hash(data)
                item.content = ContextFirewall.redact(text)
                item.estimatedTokens = (item.content.utf8.count + 3) / 4
                let structure = StructuralParser.parse(text, extension: url.pathExtension)
                item.symbols = structure.symbols
                item.imports = structure.imports
                item.references = structure.references
                item.parserRevision = "syntax-2"
                item.reason =
                    structure.supported
                    ? (structure.hasErrors
                        ? "Tree-sitter: árvore parcial com erros de sintaxe"
                        : "Tree-sitter: definições e imports sintáticos")
                    : "Busca lexical; linguagem sem parser estrutural"
                if item.content != text { item.classification = "redacted" }
                await cache.put(path: url.path, signature: signature, item: item)
                items.append(item)
            }
            return items
        }.value
    }
    private static func stem(_ path: String) -> String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent.lowercased().replacingOccurrences(
            of: "tests", with: ""
        ).replacingOccurrences(of: "test", with: "").replacingOccurrences(of: "spec", with: "").trimmingCharacters(
            in: CharacterSet(charactersIn: "._-"))
    }
}

private actor CandidateCollector {
    private let words: Set<String>
    private let pins: Set<String>
    var items = [ContextItem]()
    init(query: String, pins: [String]) {
        words = Set(query.lowercased().split { !$0.isLetter && !$0.isNumber }.filter { $0.count > 2 }.map(String.init))
        self.pins = Set(pins)
    }
    func add(_ batch: [ContextItem]) {
        items += batch.map { input in
            var item = input
            item.score = words.reduce(0) {
                $0 + (item.path.lowercased().contains($1) ? 5 : 0)
                    + (item.symbols.joined(separator: " ").lowercased().contains($1) ? 4 : 0)
            }
            if pins.contains(item.path) { item.score += 10000 }
            if ["AGENTS.md", "README.md", "CLAUDE.md"].contains(item.path) { item.score += 5000 }
            return item
        }
        items.sort { $0.score == $1.score ? $0.path < $1.path : $0.score > $1.score }
        items = Array(items.prefix(max(256, pins.count + 3)))
    }
}

private actor IndexCache {
    struct Entry {
        let signature: String
        let item: ContextItem
    }
    private var entries = [String: Entry]()
    private var bytes = 0
    func item(path: String, signature: String) -> ContextItem? {
        entries[path]?.signature == signature ? entries[path]?.item : nil
    }
    func put(path: String, signature: String, item: ContextItem) {
        if bytes > 16_000_000 {
            entries.removeAll(keepingCapacity: true)
            bytes = 0
        }
        bytes -= entries[path]?.item.content.utf8.count ?? 0
        entries[path] = Entry(signature: signature, item: item)
        bytes += item.content.utf8.count
    }
}
