import Foundation
import HarnessDomain

public enum GitWorkspace {
    public static func git(_ args: [String], at path: String, timeout: Int = 60) async throws -> String {
        // Explicit publication retains repository validation hooks. Inspection and preparation
        // never execute checkout hooks from untrusted projects.
        let hookOptions = ["commit", "push"].contains(args.first ?? "") ? [] : ["-c", "core.hooksPath=/dev/null"]
        let result = try await ProcessRunner.run("git", hookOptions + args, cwd: path, timeout: timeout)
        guard result.exitCode == 0 else {
            throw HarnessError(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return result.stdout
    }
    public static func inspect(path: String, bookmark: Data? = nil) async throws -> Project {
        let root = try await git(["rev-parse", "--show-toplevel"], at: path).trimmingCharacters(
            in: .whitespacesAndNewlines)
        var project = Project()
        project.path = root
        project.name = URL(fileURLWithPath: root).lastPathComponent
        project.bookmark = bookmark
        project.head =
            (try? await git(["rev-parse", "HEAD"], at: root).trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
        project.branch =
            (try? await git(["branch", "--show-current"], at: root).trimmingCharacters(in: .whitespacesAndNewlines))
            ?? ""
        project.dirty = !(try await git(["status", "--porcelain=v1"], at: root)).isEmpty
        project.remote =
            (try? await git(["remote", "get-url", "origin"], at: root).trimmingCharacters(in: .whitespacesAndNewlines))
            ?? ""
        project.validators = suggestedValidators(root)
        return project
    }
    private static func suggestedValidators(_ root: String) -> [Validator] {
        var result = [Validator]()
        func add(_ name: String, _ executable: String, _ arguments: [String], readOnly: Bool = false) {
            var item = Validator()
            item.name = name
            item.executable = executable
            item.arguments = arguments
            item.readOnly = readOnly
            result.append(item)
        }
        add("Integridade do diff", "git", ["diff", "--check"], readOnly: true)
        if FileManager.default.fileExists(atPath: root + "/Package.swift") { add("Build Swift", "swift", ["build"]) }
        if let data = try? Data(contentsOf: URL(fileURLWithPath: root + "/package.json")), data.count < 500_000,
            let json = try? JSONDecoder().decode(JSONValue.self, from: data)
        {
            let manager = FileManager.default.fileExists(atPath: root + "/pnpm-lock.yaml") ? "pnpm" : "npm"
            for key in ["lint", "typecheck", "test", "build"] where json["scripts"][key].string != "" {
                add(key, manager, ["run", key])
            }
        }
        if FileManager.default.fileExists(atPath: root + "/go.mod") { add("Build Go", "go", ["build", "./..."]) }
        return result
    }
    public static func acquire(project: Project, run: Run, paths: StoragePaths) async throws -> (String, String) {
        guard !run.baseSHA.isEmpty else {
            throw HarnessError("O projeto precisa de um commit base antes de criar uma worktree.")
        }
        if !run.mode.writes { return (project.path, project.branch) }
        let path = paths.worktrees.appendingPathComponent(run.id).path
        let branch = "harness/\(run.id.prefix(12))"
        if FileManager.default.fileExists(atPath: path) {
            let observedBranch = try await git(["branch", "--show-current"], at: path).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let common = try await git(["rev-parse", "--path-format=absolute", "--git-common-dir"], at: path)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let expected = try await git(["rev-parse", "--path-format=absolute", "--git-common-dir"], at: project.path)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard observedBranch == branch, common == expected else {
                throw HarnessError("WORKSPACE_DIVERGED: o diretório existente não pertence à worktree esperada.")
            }
            _ = try await git(["merge-base", "--is-ancestor", run.baseSHA, "HEAD"], at: path)
            return (path, branch)
        }
        _ = try await git(["worktree", "add", "-b", branch, path, run.baseSHA], at: project.path)
        _ = try await git(["worktree", "lock", "--reason", "Fronda run \(run.id)", path], at: project.path)
        return (path, branch)
    }
    public static func snapshot(path: String, base: String) async throws -> (
        revision: String, diff: String, files: [ChangedFile]
    ) {
        let head = try await git(["rev-parse", "HEAD"], at: path).trimmingCharacters(in: .whitespacesAndNewlines)
        let reference = base.isEmpty ? head : base
        // Bind approvals and gates to staged object IDs/modes without reading private file contents.
        let staged = try await git(["ls-files", "--stage", "-z"], at: path)
        var diff = ""
        let names = try await git(["diff", "--name-status", "--no-renames", "-z", reference], at: path).split(
            separator: "\0", omittingEmptySubsequences: true
        ).map(String.init)
        var files = [ChangedFile]()
        var hashes = [String]()
        var index = 0
        while index + 1 < names.count {
            files.append(ChangedFile(path: names[index + 1], status: names[index]))
            index += 2
        }
        let untracked = try await git(["ls-files", "--others", "--exclude-standard", "-z"], at: path).split(
            separator: "\0"
        ).map(String.init)
        for file in untracked { files.append(ChangedFile(path: file, status: "?")) }
        let readable = files.filter { (try? ContextFirewall.containedPath($0.path, root: path)) != nil }.map(\.path)
        if !readable.isEmpty {
            diff = try await git(
                ["diff", "--no-ext-diff", "--no-textconv", "--no-renames", reference, "--"] + readable, at: path)
        }
        for file in files {
            if let url = try? ContextFirewall.containedPath(file.path, root: path),
                let values = try? url.resourceValues(forKeys: [.fileSizeKey]), (values.fileSize ?? 0) < 4_000_000,
                let data = try? Data(contentsOf: url)
            {
                hashes.append(file.path + ":" + Coding.hash(data))
                if file.status == "?", let content = String(data: data, encoding: .utf8), !content.contains("\0") {
                    diff +=
                        "\ndiff --git a/\(file.path) b/\(file.path)\nnew file mode 100644\n--- /dev/null\n+++ b/\(file.path)\n@@ -0,0 +1,\(content.components(separatedBy: "\n").count) @@\n"
                        + content.components(separatedBy: "\n").map { "+" + $0 }.joined(separator: "\n")
                }
            } else {
                let attributes = try? FileManager.default.attributesOfItem(
                    atPath: URL(fileURLWithPath: path).appendingPathComponent(file.path).path)
                hashes.append(
                    file.path + ":metadata:" + String(describing: attributes?[.modificationDate]) + ":"
                        + String(describing: attributes?[.size]))
            }
        }
        let stats =
            readable.isEmpty
            ? ""
            : try await git(
                ["diff", "--numstat", "--no-ext-diff", "--no-textconv", reference, "--"] + readable, at: path)
        for line in stats.split(separator: "\n") {
            let parts = line.split(separator: "\t").map(String.init)
            if parts.count == 3, let offset = files.firstIndex(where: { $0.path == parts[2] }) {
                files[offset].additions = Int(parts[0]) ?? 0
                files[offset].deletions = Int(parts[1]) ?? 0
            }
        }
        return (
            Coding.hash(reference + head + staged + diff + hashes.sorted().joined(separator: "\n")),
            ContextFirewall.redact(diff), files
        )
    }
}
