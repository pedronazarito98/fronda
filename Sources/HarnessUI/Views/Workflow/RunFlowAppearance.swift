import HarnessDomain
import SwiftUI

enum RunFlowAppearance: CaseIterable, Hashable {
    case running, confirmed, attention, waiting, failed

    init(phase: RunJourneyPhaseState) {
        switch phase {
        case .preparing, .running: self = .running
        case .passed: self = .confirmed
        case .failed: self = .failed
        case .awaitingApproval, .awaitingEvidence, .awaitingAction, .blocked, .stale, .recovering:
            self = .attention
        case .notStarted, .skipped, .paused, .interrupted: self = .waiting
        }
    }

    init(step: RunJourneyStep, run: Run) {
        if step.state == .failed, let loop = run.loopExecution,
            loop.policy.stepIDs.contains(step.id), [.running, .evaluating, .repeating].contains(loop.state)
        {
            self = .attention
            return
        }
        guard step.state == .passed else {
            self.init(phase: step.state)
            return
        }
        switch step.step.kind {
        case "validation":
            let results = RunFollowupEvidence.latestValidations(in: run)
            self =
                !results.isEmpty
                    && results.allSatisfy { result in
                        RunFollowupEvidence.validationIsConfirmed(result, in: run)
                    } ? .confirmed : .waiting
        case "reproduction":
            self =
                run.workflow?.observations.contains { $0.phase == .before && $0.status == .pass } == true
                ? .confirmed : .waiting
        case "verification":
            self =
                !run.revision.isEmpty && run.workflowEvidenceComplete
                    && run.workflow?.observations.contains {
                        $0.phase != .before && $0.status == .pass && $0.revision == run.revision
                    } == true ? .confirmed : .waiting
        default: self = .waiting
        }
    }

    init(loopState: LoopState) {
        switch loopState {
        case .running, .evaluating: self = .running
        case .passed: self = .confirmed
        case .repeating, .awaitingUser, .limitReached, .stalled: self = .attention
        case .paused, .cancelled: self = .waiting
        case .failed: self = .failed
        }
    }

    var label: String {
        switch self {
        case .running: "Em execução"
        case .confirmed: "Comprovado"
        case .attention: "Atenção"
        case .waiting: "Aguardando"
        case .failed: "Falhou"
        }
    }

    var symbol: String {
        switch self {
        case .running: "circle.dotted"
        case .confirmed: "checkmark.circle.fill"
        case .attention: "exclamationmark.circle"
        case .waiting: "clock"
        case .failed: "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .running: FrondaTheme.running
        case .confirmed: FrondaTheme.success
        case .attention: FrondaTheme.warning
        case .waiting: FrondaTheme.textMuted
        case .failed: FrondaTheme.danger
        }
    }
}
