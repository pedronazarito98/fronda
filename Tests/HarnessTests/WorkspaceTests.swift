import HarnessDomain
import HarnessInfrastructure
import XCTest

@MainActor
final class WorkspaceTests: XCTestCase {
    func testExplicitCommitHonorsRepositoryValidationHook() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        for (key, value) in [
            ("user.name", "Harness QA"), ("user.email", "qa@example.invalid"), ("commit.gpgsign", "false"),
        ] {
            _ = try await GitWorkspace.git(["config", key, value], at: fixture.repository.path)
        }
        let hook = fixture.repository.appendingPathComponent(".git/hooks/pre-commit")
        try "#!/bin/sh\nexit 1\n".write(to: hook, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hook.path)
        try "changed\n".write(
            to: fixture.repository.appendingPathComponent("Greeting.swift"), atomically: true, encoding: .utf8)
        _ = try await GitWorkspace.git(["add", "Greeting.swift"], at: fixture.repository.path)
        do {
            _ = try await GitWorkspace.git(
                ["commit", "-m", "Must be rejected by the fixture hook"], at: fixture.repository.path)
            XCTFail("Explicit commits must honor the repository's own gate")
        } catch {}
        let head = try await GitWorkspace.git(["rev-parse", "HEAD"], at: fixture.repository.path).trimmingCharacters(
            in: .whitespacesAndNewlines)
        XCTAssertEqual(head, fixture.project.head)
    }

    func testConcurrentWorktreesHaveIndependentFilesAndPreserveCheckout() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var first = Run()
        first.baseSHA = fixture.project.head
        var second = Run()
        second.baseSHA = fixture.project.head
        async let left = GitWorkspace.acquire(project: fixture.project, run: first, paths: fixture.paths)
        async let right = GitWorkspace.acquire(project: fixture.project, run: second, paths: fixture.paths)
        let (a, b) = try await (left, right)
        XCTAssertNotEqual(a.0, b.0)
        XCTAssertNotEqual(a.1, b.1)
        try "changed\n".write(toFile: a.0 + "/Greeting.swift", atomically: true, encoding: .utf8)
        XCTAssertEqual(
            try String(contentsOfFile: b.0 + "/Greeting.swift", encoding: .utf8),
            "func greeting() -> String { \"hello\" }\n")
        let status = try await GitWorkspace.git(["status", "--porcelain"], at: fixture.repository.path)
        XCTAssertTrue(status.isEmpty)
    }

    func testExistingUnrelatedWorktreeIsRejected() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var run = Run()
        run.baseSHA = fixture.project.head
        let destination = fixture.paths.worktrees.appendingPathComponent(run.id)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        do {
            _ = try await GitWorkspace.acquire(project: fixture.project, run: run, paths: fixture.paths)
            XCTFail("Unrelated directory must not be reused")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }

    func testSnapshotChangesWhenIndexChangesButWorkingFileDoesNot() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        let file = fixture.repository.appendingPathComponent("Greeting.swift")
        let original = try String(contentsOf: file, encoding: .utf8)
        let before = try await GitWorkspace.snapshot(path: fixture.repository.path, base: fixture.project.head)
        try "staged-content\n".write(to: file, atomically: true, encoding: .utf8)
        _ = try await GitWorkspace.git(["add", "Greeting.swift"], at: fixture.repository.path)
        try original.write(to: file, atomically: true, encoding: .utf8)
        let after = try await GitWorkspace.snapshot(path: fixture.repository.path, base: fixture.project.head)
        XCTAssertNotEqual(before.revision, after.revision, "Approval must bind the index as well as working files")
    }

    func testIndexDiscoversSwiftSymbolsAndExcludesPrivatePathNames() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        let items = try await IndexEngine.scan(project: fixture.project)
        let greeting = try XCTUnwrap(items.first { $0.path == "Greeting.swift" })
        XCTAssertTrue(greeting.symbols.contains { $0.contains("greeting") })
        XCTAssertTrue(items.allSatisfy { ContextFirewall.exclusion($0.path) == nil })
    }

    func testProcessExitAndTimeoutAreObserved() async throws {
        let success = try await ProcessRunner.run("/usr/bin/true", [], cwd: NSTemporaryDirectory())
        let failure = try await ProcessRunner.run("/usr/bin/false", [], cwd: NSTemporaryDirectory())
        let timeout = try await ProcessRunner.run("/bin/sleep", ["20"], cwd: NSTemporaryDirectory(), timeout: 1)
        XCTAssertEqual(success.exitCode, 0)
        XCTAssertEqual(failure.exitCode, 1)
        XCTAssertTrue(timeout.timedOut)
        XCTAssertNotEqual(timeout.exitCode, 0)
        XCTAssertLessThan(timeout.duration, 10)
    }
}
