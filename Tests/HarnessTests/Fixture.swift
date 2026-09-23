import Foundation
import HarnessDomain
import HarnessInfrastructure

@testable import HarnessCore

struct Fixture {
    let root: URL
    let repository: URL
    let paths: StoragePaths
    let project: Project
    let coordinator: RunCoordinator

    static func make() async throws -> Fixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("HarnessTests-" + makeID())
        let repository = root.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        do {
            try "func greeting() -> String { \"hello\" }\n".write(
                to: repository.appendingPathComponent("Greeting.swift"), atomically: true, encoding: .utf8)
            _ = try await GitWorkspace.git(["init", "--initial-branch=main"], at: repository.path)
            _ = try await GitWorkspace.git(["add", "Greeting.swift"], at: repository.path)
            _ = try await GitWorkspace.git(
                [
                    "-c", "user.name=Harness QA", "-c", "user.email=qa@example.invalid", "-c", "commit.gpgsign=false",
                    "commit", "-m", "Local test fixture",
                ], at: repository.path)
            let paths = try StoragePaths(root: root.appendingPathComponent("runtime"))
            var project = try await GitWorkspace.inspect(path: repository.path)
            project.validators = [validator()]
            let coordinator = try RunCoordinator(paths: paths)
            try await coordinator.saveProject(project)
            return Fixture(root: root, repository: repository, paths: paths, project: project, coordinator: coordinator)
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }

    static func validator(_ executable: String = "/usr/bin/true", arguments: [String] = [], approved: Bool = true)
        -> Validator
    {
        var value = Validator()
        value.name = "Local process"
        value.executable = executable
        value.arguments = arguments
        value.approved = approved
        value.readOnly = true
        return value
    }

    func run(complete: Bool = false) async throws -> Run {
        var value = Run()
        value.projectID = project.id
        value.title = "Validate greeting"
        value.source.text = value.title
        value.runbook = Runbook.builtins[0]
        value.plan = value.runbook.steps
        value.baseSHA = project.head
        value.workspace = repository.path
        value.revision = try await GitWorkspace.snapshot(path: repository.path, base: project.head).revision
        value.state = .paused
        value.criteria = [Criterion(text: "Greeting remains readable")]
        if complete {
            value.planApproved = true
            value.contextApproved = true
            for index in value.plan.indices { value.plan[index].status = .pass }
            value.plan[value.plan.count - 1].status = .notRun
            var result = ValidationResult()
            result.validator = project.validators[0]
            result.status = .pass
            result.exitCode = 0
            result.revision = value.revision
            value.validations = [result]
            value.criteria[0].state = "SATISFIED"
            value.criteria[0].evidence = ["human-review:" + value.revision]
            value.reviewRevision = value.revision
            value.humanReviewRevision = value.revision
        }
        try await coordinator.record(value, kind: "test.created", message: "Isolated acceptance fixture")
        return try await coordinator.run(value.id)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}
