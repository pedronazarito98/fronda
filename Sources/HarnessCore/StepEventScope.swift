import HarnessDomain

/// Task-local because independent runs, manual actions and late provider callbacks can interleave on the coordinator.
struct StepEventScope: Sendable {
    @TaskLocal static var current: StepEventScope?
    let runID: String
    let stepID: String
    var attemptID: String?
}

extension Run {
    func uniqueStepID(ofKind kind: String) -> String? {
        let matching = plan.filter { $0.kind == kind }
        return matching.count == 1 ? matching[0].id : nil
    }
}
