import HarnessDomain
import HarnessInfrastructure
import XCTest

@testable import HarnessCore

@MainActor
final class PolicyEvidenceTests: XCTestCase {
    func testReadOnlyAndIndependentReviewCannotWrite() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var run = try await fixture.run()
        run.state = .running
        run.planApproved = true
        run.mode = .explore
        try await fixture.coordinator.record(run, kind: "test.readonly", message: "Read-only run")
        let args = JSONValue.object([
            "path": .string("New.swift"), "content": .string("new"), "expectedHash": .string(""),
        ])
        let denied = await fixture.coordinator.handleTool(runID: run.id, name: "harness_write_file", arguments: args)
        XCTAssertTrue(denied.contains("POLICY_DENIED"))
        var attempt = Attempt()
        attempt.stepID = run.plan.first { $0.kind == "review" }!.id
        run.attempts = [attempt]
        run.mode = .guided
        try await fixture.coordinator.record(run, kind: "test.review", message: "Independent review")
        let review = await fixture.coordinator.handleTool(runID: run.id, name: "harness_write_file", arguments: args)
        XCTAssertTrue(review.contains("POLICY_DENIED"))
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: fixture.repository.appendingPathComponent("New.swift").path))
    }

    func testBrokerRejectsOutOfScopeAndStaleFileHash() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var run = try await fixture.run()
        let workspace = try await GitWorkspace.acquire(project: fixture.project, run: run, paths: fixture.paths)
        run.workspace = workspace.0
        run.branch = workspace.1
        run.state = .running
        run.planApproved = true
        run.scope = ["Greeting.swift"]
        try await fixture.coordinator.record(run, kind: "test.scope", message: "Scoped worktree")
        for path in ["../outside", "Outside.swift", ".env"] {
            let response = await fixture.coordinator.handleTool(
                runID: run.id, name: "harness_write_file",
                arguments: .object(["path": .string(path), "content": .string("test"), "expectedHash": .string("")]))
            XCTAssertTrue(response.contains("POLICY_DENIED"), path)
        }
        let conflict = await fixture.coordinator.handleTool(
            runID: run.id, name: "harness_write_file",
            arguments: .object([
                "path": .string("Greeting.swift"), "content": .string("test"), "expectedHash": .string("wrong-hash"),
            ]))
        XCTAssertTrue(conflict.contains("REVISION_CONFLICT"))
        XCTAssertTrue(
            try String(contentsOfFile: run.workspace + "/Greeting.swift", encoding: .utf8).contains("func greeting"))
    }

    func testChangedSnapshotRejectsPreparedCommitWithoutWriting() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var run = try await fixture.run()
        let workspace = try await GitWorkspace.acquire(project: fixture.project, run: run, paths: fixture.paths)
        run.workspace = workspace.0
        run.branch = workspace.1
        run.planApproved = true
        try "first\n".write(toFile: run.workspace + "/Greeting.swift", atomically: true, encoding: .utf8)
        try await fixture.coordinator.record(run, kind: "test.prepare", message: "Isolated commit proposal")
        var action = Approval()
        action.kind = "git.commit"
        action.payload = "Test proposal; must not commit"
        var prepare = RPCRequest("approval.prepare")
        prepare.id = run.id
        prepare.approval = action
        let id = try await fixture.coordinator.prepareAction(prepare)
        try "second\n".write(toFile: run.workspace + "/Greeting.swift", atomically: true, encoding: .utf8)
        var decide = RPCRequest("approval.decide")
        decide.id = run.id
        decide.relatedID = id
        decide.flag = true
        do {
            try await fixture.coordinator.decideAction(decide)
            XCTFail("Stale approval must be rejected")
        } catch { XCTAssertTrue(error.localizedDescription.contains("SNAPSHOT_STALE")) }
        let observed = try await fixture.coordinator.run(run.id)
        XCTAssertEqual(observed.approvals.last?.state, "STALE")
        let head = try await GitWorkspace.git(["rev-parse", "HEAD"], at: run.workspace).trimmingCharacters(
            in: .whitespacesAndNewlines)
        XCTAssertEqual(head, run.baseSHA)
    }

    func testBudgetUsesCumulativeReportedUsageAndEmitsWarningOnce() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var run = try await fixture.run()
        run.budget = 1000
        run.state = .running
        let attempt = Attempt()
        run.attempts = [attempt]
        var token = TokenRecord()
        token.attemptID = attempt.id
        token.estimatedPackInput = 2000
        run.tokens = [token]
        try await fixture.coordinator.record(run, kind: "test.usage", message: "Synthetic cumulative metrics")
        for total in [800, 800, 1000] {
            let payload = JSONValue.object([
                "tokenUsage": .object([
                    "total": .object([
                        "inputTokens": .number(Double(total)), "outputTokens": .number(0),
                        "cachedInputTokens": .number(300),
                    ])
                ])
            ])
            await fixture.coordinator.providerEvent(
                run.id, attemptID: attempt.id, kind: "thread/tokenUsage/updated", payload: payload)
        }
        let observed = try await fixture.coordinator.run(run.id)
        XCTAssertEqual(observed.reportedTokens, 1000)
        XCTAssertEqual(observed.state, .blocked)
        var query = RPCRequest("events")
        query.id = run.id
        let events = await fixture.coordinator.handle(query).events ?? []
        XCTAssertEqual(events.filter { $0.kind == "budget.warning" }.count, 1)
        XCTAssertEqual(events.filter { $0.kind == "budget.exhausted" }.count, 1)
    }

    func testExportHashesAndMetadataOnlyPrivacy() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var run = try await fixture.run(complete: true)
        run.title = "Private fixture objective"
        run.report = "Private fixture report"
        run.changedFiles = [ChangedFile(path: "PrivateFixture.swift", status: "M")]
        run.diff = "Private fixture diff"
        try await fixture.coordinator.record(run, kind: "test.export", message: run.title)
        for includeText in [true, false] {
            var options = EvidenceExportOptions()
            options.includeText = includeText
            let path = try await fixture.coordinator.exportEvidence(run.id, options: options)
            let folder = URL(fileURLWithPath: path)
            let manifest = try Coding.decode(
                JSONValue.self, from: Data(contentsOf: folder.appendingPathComponent("manifest.json")))
            XCTAssertEqual(manifest["includesFreeText"].bool, includeText)
            for (name, expected) in manifest["files"].object {
                let bytes = try Data(contentsOf: folder.appendingPathComponent(name))
                XCTAssertEqual(Coding.hash(bytes), expected.string)
                if !includeText {
                    let text = String(decoding: bytes, as: UTF8.self)
                    XCTAssertFalse(text.contains("Private fixture"))
                    XCTAssertFalse(text.contains("PrivateFixture.swift"))
                    XCTAssertFalse(text.contains(fixture.root.path))
                }
            }
            XCTAssertEqual(
                FileManager.default.fileExists(atPath: folder.appendingPathComponent("diff.patch").path), includeText)
        }
    }
}
