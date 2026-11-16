import HarnessDomain
import SwiftUI

enum RunDisplay {
    static func needsAttention(_ run: Run) -> Bool {
        guard ![.archived, .cancelled].contains(run.state), run.workflow?.delivery.closedAt == nil else { return false }
        return run.needsPauseReview
            || [.waitingUser, .blocked, .failed, .recovering, .partial, .ready].contains(run.state)
            || run.approvals.contains { $0.state == "PREPARED" }
    }

    static func attentionOrder(_ lhs: Run, _ rhs: Run) -> Bool {
        let left = attentionPriority(lhs)
        let right = attentionPriority(rhs)
        if left != right { return left < right }
        return lhs.updatedAt == rhs.updatedAt ? lhs.id < rhs.id : lhs.updatedAt > rhs.updatedAt
    }

    static func attentionPriority(_ run: Run) -> Int {
        if run.needsPauseReview || run.state == .waitingUser
            || run.approvals.contains(where: { $0.state == "PREPARED" })
        {
            return 0
        }
        if [.blocked, .failed, .recovering].contains(run.state) { return 1 }
        if [.ready, .partial].contains(run.state) { return 2 }
        if run.state.active { return 3 }
        return 4
    }

    static func color(for state: RunState) -> Color {
        switch state {
        case .failed: FrondaTheme.danger
        case .waitingUser, .blocked, .partial, .recovering: FrondaTheme.warning
        case .ready: FrondaTheme.success
        case .running, .preparing: FrondaTheme.running
        default: .secondary
        }
    }

    static func symbol(for state: RunState) -> String {
        switch state {
        case .running, .preparing: "circle.dotted"
        case .waitingUser: "hand.raised.fill"
        case .ready: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .blocked, .partial, .recovering: "exclamationmark.circle.fill"
        case .paused: "pause.circle"
        case .queued: "clock"
        case .archived: "archivebox"
        case .cancelled: "stop.circle"
        case .draft: "pencil.circle"
        }
    }

    static func nextAction(for run: Run, in snapshot: Snapshot) -> String {
        if run.workflow?.delivery.closedAt != nil { return "Consultar conversa" }
        if run.state == .archived || run.state == .cancelled { return "Consultar histórico" }
        if run.isPauseRequested { return "Aguardando interrupção" }
        let project = snapshot.projects.first { $0.id == run.projectID }
        if let action = RunUserAction.next(for: run, project: project) { return action.title }
        if run.state == .queued { return "Acompanhar fila" }
        return run.nextAction
    }
}
