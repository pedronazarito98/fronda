import HarnessDomain
import HarnessInfrastructure
import XCTest

@testable import HarnessCore

@MainActor
final class ExecutionTests: XCTestCase {
    func testTwoProjectsKeepTheirSearchIndexAcrossCoordinatorRestart() async throws {
        let first = try await Fixture.make()
        let second = try await Fixture.make()
        defer {
            first.remove()
            second.remove()
        }
        try await first.coordinator.saveProject(second.project)
        await first.coordinator.indexProject(first.project.id)
        await first.coordinator.indexProject(second.project.id)
        let restarted = try RunCoordinator(paths: first.paths)
        let snapshot = await restarted.snapshot()
        XCTAssertEqual(snapshot.projects.count, 2)
        XCTAssertTrue(snapshot.projects.allSatisfy { $0.indexState == "READY" && $0.indexedFiles > 0 })
        for project in snapshot.projects {
            var search = RPCRequest("search")
            search.id = project.id
            search.text = "greeting"
            let response = await restarted.handle(search)
            XCTAssertNil(response.error)
            XCTAssertTrue(response.items?.contains { $0.path == "Greeting.swift" && !$0.symbols.isEmpty } == true)
        }
    }

    func testInvalidBookmarkDoesNotReportIndexSuccess() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var project = fixture.project
        project.bookmark = Data([0, 1, 2, 3])
        try await fixture.coordinator.saveProject(project)
        await fixture.coordinator.indexProject(project.id)
        let observed = try await fixture.coordinator.project(project.id)
        XCTAssertEqual(observed.indexState, "ERROR")
        XCTAssertEqual(observed.indexedFiles, 0)
    }

    func testStrongIsolationRequirementStopsBeforeProviderAttempt() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var run = try await fixture.run(complete: true)
        run.state = .running
        try await fixture.coordinator.record(run, kind: "test.scheduled", message: "Execution entered by scheduler")
        var project = fixture.project
        project.requireStrongIsolation = true
        try await fixture.coordinator.saveProject(project)
        await fixture.coordinator.execute(run.id)
        let observed = try await fixture.coordinator.run(run.id)
        XCTAssertEqual(observed.state, .blocked)
        XCTAssertTrue(observed.attempts.isEmpty)
    }

    func testProviderSwitchInvalidatesDependentEvidenceWithoutCallingProvider() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        let run = try await fixture.run(complete: true)
        var request = RPCRequest("run.provider")
        request.id = run.id
        request.text = ProviderKind.claude.rawValue
        let response = await fixture.coordinator.handle(request)
        XCTAssertNil(response.error)
        let observed = try await fixture.coordinator.run(run.id)
        XCTAssertEqual(observed.provider, .claude)
        XCTAssertFalse(observed.contextApproved)
        XCTAssertEqual(observed.plan[2].status, .notRun)
        XCTAssertEqual(observed.validations[0].status, .stale)
        XCTAssertTrue(observed.reviewRevision.isEmpty)
        XCTAssertTrue(observed.attempts.isEmpty)
    }

    func testConcurrentRetriesOfSameCreateRequestCreateExactlyOneRun() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var run = Run()
        run.projectID = fixture.project.id
        run.title = "Idempotent creation"
        run.runbook = Runbook.builtins[0]
        var request = RPCRequest("run.create")
        request.run = run
        let repeatedRequest = request
        async let first = fixture.coordinator.handle(repeatedRequest)
        async let retry = fixture.coordinator.handle(repeatedRequest)
        let (a, b) = await (first, retry)
        XCTAssertNil(a.error)
        XCTAssertNil(b.error)
        XCTAssertEqual(a.id, b.id)
        let snapshot = await fixture.coordinator.snapshot()
        XCTAssertEqual(snapshot.runs.count, 1)
    }

    func testConditionalSkipIsAllowedOnlyWhenConditionIsFalse() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var run = try await fixture.run(complete: true)
        run.plan[2].condition = "on_failure"
        run.plan[2].status = .skipped
        try await fixture.coordinator.record(run, kind: "test.conditional", message: "Failure branch not needed")
        try await fixture.coordinator.finalize(run.id)
        let skipped = try await fixture.coordinator.run(run.id)
        XCTAssertEqual(skipped.state, .ready)
        run.plan[2].condition = "on_pass"
        try await fixture.coordinator.record(
            run, kind: "test.conditional", message: "Required success branch was skipped")
        try await fixture.coordinator.finalize(run.id)
        let required = try await fixture.coordinator.run(run.id)
        XCTAssertEqual(required.state, .partial)
    }

    func testPassWithoutObservedExitCodeCannotBeReady() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var run = try await fixture.run(complete: true)
        run.validations[0].exitCode = nil
        try await fixture.coordinator.record(run, kind: "test.unobserved", message: "Missing process evidence")
        try await fixture.coordinator.finalize(run.id)
        let observed = try await fixture.coordinator.run(run.id)
        XCTAssertEqual(observed.state, .partial)
    }

    func testCancellationInterruptsARealProcess() async throws {
        let process = Task {
            try await ProcessRunner.run("/bin/sleep", ["20"], cwd: NSTemporaryDirectory())
        }
        try await Task.sleep(for: .milliseconds(100))
        process.cancel()
        let result = try await process.value
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertFalse(result.timedOut)
        XCTAssertLessThan(result.duration, 10)
    }

    func testCatalogEditInvalidatesPreviouslyReadyRun() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        let run = try await fixture.run(complete: true)
        try await fixture.coordinator.finalize(run.id)
        var project = fixture.project
        project.validators[0].arguments = ["changed"]
        var request = RPCRequest("project.update")
        request.project = project
        let response = await fixture.coordinator.handle(request)
        XCTAssertNil(response.error)
        let observed = try await fixture.coordinator.run(run.id)
        XCTAssertEqual(observed.state, .partial)
        XCTAssertEqual(observed.validations[0].status, .stale)
        XCTAssertTrue(observed.reviewRevision.isEmpty)
    }
}
