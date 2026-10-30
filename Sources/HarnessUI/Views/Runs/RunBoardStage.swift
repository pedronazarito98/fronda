import HarnessDomain
import SwiftUI

enum RunBoardStage: String, CaseIterable, Identifiable {
    case prepare = "Preparar"
    case investigate = "Investigar"
    case implement = "Implementar"
    case review = "Revisar"
    case completed = "Concluído"

    var id: String { rawValue }
    var color: Color {
        switch self {
        case .prepare: FrondaTheme.textMuted
        case .investigate: FrondaTheme.clay
        case .implement: FrondaTheme.accent
        case .review: FrondaTheme.warning
        case .completed: FrondaTheme.success
        }
    }

    static func stage(for run: Run) -> Self {
        if run.workflow?.delivery.closedAt != nil { return .completed }
        if run.state == .ready || run.workflow?.delivery.pullRequestURL != nil { return .review }
        if run.state == .preparing || (!run.contextApproved && !run.state.active) { return .prepare }
        guard let step = run.currentStep else {
            return run.plan.isEmpty ? .prepare : .review
        }
        switch step.kind {
        case "context": return .prepare
        case "investigation", "reproduction", "plan": return .investigate
        case "implementation": return .implement
        case "validation", "verification", "review", "evidence": return .review
        default: return .prepare
        }
    }
}
