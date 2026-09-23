import HarnessDomain
import HarnessInfrastructure
import XCTest

@testable import HarnessCore

@MainActor
final class CoordinatorTests: XCTestCase {
    func testReadyRequiresAllMandatoryStepsToPass() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var run = try await fixture.run(complete: true)
        for status in [GateStatus.notRun, .running, .fail, .blocked, .stale, .skipped, .cancelled] {
            run.plan[2].status = status
            try await fixture.coordinator.record(run, kind: "test.step", message: status.rawValue)
            try await fixture.coordinator.finalize(run.id)
            let observed = try await fixture.coordinator.run(run.id)
            XCTAssertEqual(observed.state, .partial, "Mandatory implementation was \(status)")
        }
        run.plan[2].status = .pass
        try await fixture.coordinator.record(run, kind: "test.step", message: "complete")
        try await fixture.coordinator.finalize(run.id)
        let observed = try await fixture.coordinator.run(run.id)
        XCTAssertEqual(observed.state, .ready)
    }

    func testEmptyRevisionAndMissingCriteriaCannotBeReady() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var run = try await fixture.run(complete: true)
        run.revision = ""
        run.reviewRevision = ""
        run.humanReviewRevision = ""
        run.validations[0].revision = ""
        run.criteria = []
        try await fixture.coordinator.record(run, kind: "test.empty", message: "Unverified snapshot")
        try await fixture.coordinator.finalize(run.id)
        let observed = try await fixture.coordinator.run(run.id)
        XCTAssertEqual(observed.state, .partial)
    }

    func testUnknownCriterionLinkCannotSatisfyTraceability() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var run = try await fixture.run(complete: true)
        var file = ChangedFile(path: "Greeting.swift", status: "M")
        file.linkedCriteria = ["nonexistent-criterion"]
        run.changedFiles = [file]
        try await fixture.coordinator.record(run, kind: "test.trace", message: "Invalid criterion link")
        try await fixture.coordinator.finalize(run.id)
        let observed = try await fixture.coordinator.run(run.id)
        XCTAssertEqual(observed.state, .partial)
    }

    func testCatalogGateResultsComeFromRealProcesses() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var project = fixture.project
        project.validators = [
            Fixture.validator(), Fixture.validator("/usr/bin/false"), Fixture.validator(approved: false),
        ]
        try await fixture.coordinator.saveProject(project)
        let run = try await fixture.run()
        let pass = await fixture.coordinator.validate(run.id, validator: project.validators[0])
        let fail = await fixture.coordinator.validate(run.id, validator: project.validators[1])
        let blocked = await fixture.coordinator.validate(run.id, validator: project.validators[2])
        XCTAssertEqual(pass.status, .pass)
        XCTAssertEqual(pass.exitCode, 0)
        XCTAssertEqual(fail.status, .fail)
        XCTAssertEqual(fail.exitCode, 1)
        XCTAssertEqual(blocked.status, .blocked)
        XCTAssertNil(blocked.exitCode)
    }

    func testPartialValidatorRunCannotMarkWholeStagePass() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var project = fixture.project
        project.validators.append(Fixture.validator())
        try await fixture.coordinator.saveProject(project)
        let run = try await fixture.run()
        await fixture.coordinator.validateRun(run.id, validatorID: project.validators[0].id)
        let observed = try await fixture.coordinator.run(run.id)
        XCTAssertNotEqual(observed.plan.first { $0.kind == "validation" }?.status, .pass)
        XCTAssertEqual(observed.state, .partial)
    }

    func testFileEditInvalidatesGatesReviewsAndCriteria() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        let run = try await fixture.run(complete: true)
        try await fixture.coordinator.finalize(run.id)
        try "changed\n".write(
            to: fixture.repository.appendingPathComponent("Greeting.swift"), atomically: true, encoding: .utf8)
        try await fixture.coordinator.reconcile(run.id)
        let observed = try await fixture.coordinator.run(run.id)
        XCTAssertEqual(observed.state, .partial)
        XCTAssertEqual(observed.validations[0].status, .stale)
        XCTAssertTrue(observed.reviewRevision.isEmpty)
        XCTAssertTrue(observed.humanReviewRevision.isEmpty)
        XCTAssertEqual(observed.criteria[0].state, "UNVERIFIED")
        XCTAssertNotEqual(observed.revision, run.revision)
    }

    func testRetryInvalidatesOnlyStepAndDescendants() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        let run = try await fixture.run(complete: true)
        var request = RPCRequest("step.retry")
        request.id = run.id
        request.relatedID = run.plan[3].id
        let response = await fixture.coordinator.handle(request)
        XCTAssertNil(response.error)
        let observed = try await fixture.coordinator.run(run.id)
        XCTAssertEqual(observed.plan[2].status, .pass)
        XCTAssertEqual(observed.plan[3].status, .notRun)
        XCTAssertEqual(observed.plan[4].status, .notRun)
        XCTAssertEqual(observed.validations[0].status, .stale)
        XCTAssertTrue(observed.humanReviewRevision.isEmpty)
    }

    func testRequestIDIsIdempotentAndOldSequenceIsRejected() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        let run = try await fixture.run()
        var request = RPCRequest("run.budget")
        request.id = run.id
        request.number = 64000
        request.expectedSequence = run.sequence
        let first = await fixture.coordinator.handle(request)
        let second = await fixture.coordinator.handle(request)
        XCTAssertNil(first.error)
        XCTAssertNil(second.error)
        let updated = try await fixture.coordinator.run(run.id)
        XCTAssertEqual(updated.sequence, run.sequence + 1)
        request.requestID = makeID()
        let stale = await fixture.coordinator.handle(request)
        XCTAssertTrue(stale.error?.contains("REVISION_CONFLICT") == true)
    }

    func testRestartRecoversInterruptedWorkWithoutInventingExitCode() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        var run = try await fixture.run()
        run.state = .running
        run.attempts = [Attempt()]
        var gate = ValidationResult()
        gate.status = .running
        run.validations = [gate]
        var action = Approval()
        action.state = "SENDING"
        run.approvals = [action]
        try await fixture.coordinator.record(run, kind: "test.running", message: "Interrupted fixture")
        let recovered = try RunCoordinator(paths: fixture.paths)
        let observed = try await recovered.run(run.id)
        XCTAssertEqual(observed.state, .recovering)
        XCTAssertEqual(observed.attempts[0].status, "INTERRUPTED_UNKNOWN")
        XCTAssertEqual(observed.validations[0].status, .blocked)
        XCTAssertNil(observed.validations[0].exitCode)
        XCTAssertEqual(observed.approvals[0].state, "UNKNOWN")
    }

    func testReplayReturnsEarlierStateWithoutExecutingIt() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        let run = try await fixture.run()
        var change = RPCRequest("run.budget")
        change.id = run.id
        change.number = 60000
        _ = await fixture.coordinator.handle(change)
        var replay = RPCRequest("replay")
        replay.id = run.id
        replay.number = run.sequence
        let old = await fixture.coordinator.handle(replay)
        let current = try await fixture.coordinator.run(run.id)
        XCTAssertEqual(old.run?.budget, run.budget)
        XCTAssertEqual(current.budget, 60000)
        XCTAssertEqual(current.attempts.count, 0)
    }

    func testShutdownRejectsFurtherCommands() async throws {
        let fixture = try await Fixture.make()
        defer { fixture.remove() }
        try await fixture.coordinator.prepareShutdown(force: false)
        let response = await fixture.coordinator.handle(RPCRequest("queue.toggle"))
        XCTAssertTrue(response.error?.contains("SERVICE_STOPPING") == true)
    }
}
