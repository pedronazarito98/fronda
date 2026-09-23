import HarnessDomain
import HarnessInfrastructure
import XCTest

final class ContextTests: XCTestCase {
    func testPrivatePathsAreExcludedButSourceFilesRemainUsable() {
        for path in [
            ".env", "AUTH/config.json", ".codex/config.json", "folder/state.sqlite", "logs/output.txt",
            "sessions/data.json",
        ] {
            XCTAssertNotNil(ContextFirewall.exclusion(path), path)
        }
        XCTAssertNil(ContextFirewall.exclusion("Sources/SessionController.swift"))
        XCTAssertNil(ContextFirewall.exclusion("Sources/TokenRecord.ts"))
    }

    func testTraversalAndSymlinkAreRejectedBeforeReading() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(makeID())
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createSymbolicLink(
            atPath: root.appendingPathComponent("alias").path, withDestinationPath: "/does-not-exist")
        for path in ["../outside", "/outside", "alias/child", ".env", ""] {
            XCTAssertThrowsError(try ContextFirewall.containedPath(path, root: root.path), path)
        }
        XCTAssertEqual(
            try ContextFirewall.containedPath("Sources/New.swift", root: root.path).lastPathComponent, "New.swift")
    }

    func testPathScopeUsesDirectoryBoundaries() {
        XCTAssertTrue(ContextFirewall.matches("Sources/App.swift", patterns: ["Sources/**"]))
        XCTAssertFalse(ContextFirewall.matches("SourcesExtra/App.swift", patterns: ["Sources/**"]))
        XCTAssertFalse(ContextFirewall.matches("Sources.swift", patterns: ["Sources/**"]))
    }

    func testPackSelectionHonorsExclusionEvenForPreviouslyIncludedItem() throws {
        var run = Run()
        run.title = "Greeting"
        run.exclusions = ["Greeting.swift"]
        var item = ContextItem()
        item.path = "Greeting.swift"
        item.content = "hello"
        item.estimatedTokens = 2
        item.included = true
        let pack = try ContextCompiler.compile(run: run, candidates: [item], budget: 4000)
        XCTAssertFalse(pack.items[0].included)
        XCTAssertTrue(pack.items[0].content.isEmpty)
        XCTAssertFalse(pack.payload.contains("<file "))
    }

    func testMandatoryPinCannotSilentlyDisappearWhenBudgetIsExceeded() {
        var run = Run()
        run.pins = ["Huge.swift"]
        var item = ContextItem()
        item.path = "Huge.swift"
        item.content = String(repeating: "x", count: 20000)
        item.estimatedTokens = 5000
        XCTAssertThrowsError(try ContextCompiler.compile(run: run, candidates: [item], budget: 1000))
    }

    func testPackRedactsAllUserAuthoredFieldsAndVerifiesItsHash() throws {
        var run = Run()
        // Deliberately synthetic pattern, never a real credential.
        let synthetic = "password=\"synthetic-qa-value\""
        run.criteria = [Criterion(text: synthetic)]
        run.plan = [RunbookStep(title: synthetic)]
        let pack = try ContextCompiler.compile(run: run, candidates: [], budget: 4000)
        XCTAssertFalse(pack.payload.contains("synthetic-qa-value"))
        XCTAssertTrue(pack.payload.contains("[REDACTED]"))
        XCTAssertEqual(pack.hash, Coding.hash(pack.payload))
        XCTAssertEqual(pack.estimatedTokens, (pack.payload.utf8.count + 3) / 4)
    }
}
