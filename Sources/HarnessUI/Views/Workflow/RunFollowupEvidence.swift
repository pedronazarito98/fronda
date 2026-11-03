import Foundation
import HarnessDomain

enum RunFollowupEvidence {
    static func latestValidations(in run: Run) -> [ValidationResult] {
        Dictionary(grouping: run.validations, by: { $0.validator.id })
            .compactMap { $0.value.max { $0.createdAt < $1.createdAt } }
            .sorted { $0.validator.name.localizedStandardCompare($1.validator.name) == .orderedAscending }
    }

    static func status(of result: ValidationResult, in run: Run) -> GateStatus {
        if ![.running, .notRun].contains(result.status), result.revision != run.revision {
            return .stale
        }
        return result.status
    }

    static func criterionIsConfirmed(_ criterion: Criterion) -> Bool {
        criterion.state == "SATISFIED" && !criterion.evidence.isEmpty
    }

    static func validationIsConfirmed(_ result: ValidationResult, in run: Run) -> Bool {
        !run.revision.isEmpty && status(of: result, in: run) == .pass
            && result.exitCode == 0 && !result.artifactHash.isEmpty
    }
}
