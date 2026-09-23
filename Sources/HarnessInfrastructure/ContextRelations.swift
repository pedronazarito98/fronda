import Foundation
import HarnessDomain

public enum ContextRelations {
    public static let defaultWeights = ["criteria": 5, "symbols": 4, "diff": 4, "tests": 3, "path": 3, "history": 1]
    public static func history(_ items: [ContextItem], projectPath: String) async throws -> [ContextItem] {
        let output = try await GitWorkspace.git(
            ["log", "-8", "--format=COMMIT:%h %s", "--name-only", "--no-renames"], at: projectPath)
        var commit = ""
        var history = [String: [String]]()
        for line in output.split(separator: "\n").map(String.init) {
            if line.hasPrefix("COMMIT:") {
                commit = String(line.dropFirst(7))
            } else if ContextFirewall.exclusion(line) == nil, !commit.isEmpty {
                history[line, default: []].append(commit)
            }
        }
        return items.map { item in
            var item = item
            item.gitHistory = history[item.path] ?? []
            return item
        }
    }
}
