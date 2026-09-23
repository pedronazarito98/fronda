import HarnessDomain
import XCTest

final class RunbookTests: XCTestCase {
    func testBuiltinsHaveUniqueIdentitiesAndValidGraphs() throws {
        let books = Runbook.builtins
        XCTAssertEqual(books.count, 12)
        XCTAssertEqual(Set(books.map(\.id)).count, books.count)
        for book in books {
            var completed = Set<String>()
            for step in try book.orderedSteps() {
                XCTAssertTrue(Set(step.dependencies).isSubset(of: completed))
                completed.insert(step.id)
            }
        }
    }

    func testCycleAndMissingDependencyAreRejected() {
        var book = Runbook.builtins[0]
        book.steps[0].dependencies = [book.steps.last!.id]
        XCTAssertThrowsError(try book.orderedSteps())
        book.steps[0].dependencies = ["missing"]
        XCTAssertThrowsError(try book.orderedSteps())
    }

    func testDuplicateStepsAndUnknownConditionsAreRejected() {
        var book = Runbook.builtins[0]
        book.steps.append(book.steps[0])
        XCTAssertThrowsError(try book.orderedSteps())
        book = Runbook.builtins[0]
        book.steps[0].condition = "maybe"
        XCTAssertThrowsError(try book.orderedSteps())
    }

    func testProjectValidatorCannotBeReplacedByRunbookWithSameID() {
        var project = Project()
        let command = Fixture.validator(approved: false)
        project.validators = [command]
        var book = Runbook.builtins[0]
        var replacement = command
        replacement.approved = true
        book.validationCommands = [replacement]
        XCTAssertEqual(book.validators(for: project), [command])
    }

    func testReportedUsageDoesNotIncludeEstimateOrCountCacheTwice() {
        var run = Run()
        var record = TokenRecord()
        record.input = 100
        record.output = 20
        record.cachedInput = 80
        record.estimatedPackInput = 900
        var estimate = TokenRecord()
        estimate.estimatedPackInput = 700
        run.tokens = [record, estimate]
        XCTAssertEqual(run.reportedTokens, 120)
    }
}
