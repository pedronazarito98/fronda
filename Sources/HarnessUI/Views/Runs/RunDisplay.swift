import HarnessDomain
import SwiftUI

enum RunDisplay {
    static func needsAttention(_ run: Run) -> Bool {
        guard ![.archived, .cancelled].contains(run.state), run.workflow?.delivery.closedAt == nil else { return false }
        return [.waitingUser, .blocked, .failed, .recovering, .partial, .ready].contains(run.state)
            || run.approvals.contains { $0.state == "PREPARED" }
    }

    static func attentionOrder(_ lhs: Run, _ rhs: Run) -> Bool {
        let left = attentionPriority(lhs)
        let right = attentionPriority(rhs)
        if left != right { return left < right }
        return lhs.updatedAt == rhs.updatedAt ? lhs.id < rhs.id : lhs.updatedAt > rhs.updatedAt
    }

    static func attentionPriority(_ run: Run) -> Int {
        if run.state == .waitingUser || run.approvals.contains(where: { $0.state == "PREPARED" }) { return 0 }
        if [.blocked, .failed, .recovering].contains(run.state) { return 1 }
        if [.ready, .partial].contains(run.state) { return 2 }
        if run.state.active { return 3 }
        return 4
    }

    static func color(for state: RunState) -> Color {
        switch state {
        case .failed: FrondaTheme.danger
        case .waitingUser, .blocked, .partial, .recovering: FrondaTheme.clay
        case .ready: FrondaTheme.success
        case .running, .preparing: FrondaTheme.accent
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

    static func nextAction(for run: Run) -> String {
        if run.workflow?.delivery.closedAt != nil { return "Consultar diário" }
        if run.state == .archived || run.state == .cancelled { return "Consultar histórico" }
        if run.state == .failed || run.state == .blocked { return "Conferir impedimento" }
        if run.state == .recovering { return "Conferir recuperação" }
        if run.state == .queued { return "Acompanhar fila" }
        return run.nextAction
    }
}

enum RunListFilter: String, CaseIterable, Identifiable {
    case all = "Todas"
    case attention = "Pedem atenção"
    case active = "Em andamento"
    case ready = "Prontas"
    case archived = "Arquivadas"

    var id: String { rawValue }

    func includes(_ run: Run) -> Bool {
        switch self {
        case .all: run.state != .archived
        case .attention: RunDisplay.needsAttention(run)
        case .active: !run.state.terminal
        case .ready: run.state == .ready
        case .archived: run.state == .archived
        }
    }
}

enum RunListSort: String, CaseIterable, Identifiable {
    case updated = "Atualizadas recentemente"
    case created = "Criadas recentemente"
    case attention = "Atenção primeiro"
    case title = "Título A–Z"

    var id: String { rawValue }

    func precedes(_ lhs: Run, _ rhs: Run) -> Bool {
        switch self {
        case .updated: lhs.updatedAt == rhs.updatedAt ? lhs.id < rhs.id : lhs.updatedAt > rhs.updatedAt
        case .created: lhs.createdAt == rhs.createdAt ? lhs.id < rhs.id : lhs.createdAt > rhs.createdAt
        case .attention: RunDisplay.attentionOrder(lhs, rhs)
        case .title:
            lhs.title == rhs.title
                ? lhs.id < rhs.id : lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }
}
