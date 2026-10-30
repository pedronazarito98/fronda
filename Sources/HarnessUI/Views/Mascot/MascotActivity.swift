import Foundation
import HarnessDomain

struct MascotActivity: Identifiable {
    enum Destination {
        case run(String, RunWorkspaceSection)
        case decision(String)
        case external(String)
        case sessions
    }

    let id: String
    let title: String
    let detail: String
    let state: MascotState
    let priority: Int
    let updatedAt: Date
    let action: String
    let destination: Destination

    static func task(_ run: Run, connected: Bool, now: Date) -> Self {
        let prepared = run.approvals.contains { $0.state == "PREPARED" && $0.expiresAt > now }
        let state: MascotState
        let priority: Int
        let action: String
        let destination: Destination
        if prepared || run.state == .waitingUser {
            state = .attention
            priority = 0
            action = "Abrir decisão"
            if prepared {
                destination = .decision(run.id)
            } else {
                let section: RunWorkspaceSection =
                    !run.contextApproved ? .context : !run.planApproved ? .plan : .conversation
                destination = .run(run.id, section)
            }
        } else if [.failed, .blocked, .recovering].contains(run.state) {
            state = .error
            priority = 1
            action = "Conferir impedimento"
            destination = .run(run.id, .conversation)
        } else if run.state == .partial {
            state = .attention
            priority = 2
            action = "Conferir resultado parcial"
            destination = .run(run.id, run.report.isEmpty ? .validation : .conversation)
        } else if run.state == .ready {
            state = .success
            priority = 3
            action = "Revisar resultado"
            destination = .run(run.id, run.report.isEmpty ? .changes : .conversation)
        } else {
            state = run.state.active ? .working : .idle
            priority = run.state.active ? 4 : 5
            action = "Acompanhar tarefa"
            destination = .run(run.id, .overview)
        }
        return Self(
            id: "run:" + run.id, title: run.title,
            detail: connected ? run.nextAction : "Último estado recebido · " + run.state.label,
            state: connected ? state : .idle, priority: connected ? priority : 6,
            updatedAt: run.updatedAt, action: action, destination: destination)
    }

    static func session(_ session: ExternalSession, current: Bool, now: Date) -> Self {
        let fresh = current && !session.isStale(at: now)
        let recent = now.timeIntervalSince(session.updatedAt) < 3600
        let state: MascotState
        let priority: Int
        switch session.state {
        case .waiting where fresh: (state, priority) = (.attention, 0)
        case .interrupted where fresh && recent: (state, priority) = (.error, 1)
        case .completed where fresh && recent: (state, priority) = (.success, 3)
        case .running where fresh: (state, priority) = (.working, 4)
        default: (state, priority) = (.idle, 5)
        }
        let verb = state == .attention ? "Abrir decisão" : state == .success ? "Ver resultado" : "Abrir sessão"
        return Self(
            id: session.id, title: session.project,
            detail: session.provider.rawValue + " · " + (fresh ? session.state.label : "Sem atualização recente"),
            state: state, priority: priority, updatedAt: session.updatedAt,
            action: session.provider == .codex ? verb + " no Codex" : "Ver na central de sessões",
            destination: session.provider == .codex ? .external(session.sessionID) : .sessions)
    }
}

extension AppStore {
    var mascotActivities: [MascotActivity] {
        let now = Date.now
        let runs = snapshot.runs.filter {
            ![.draft, .archived, .cancelled].contains($0.state) && $0.workflow?.delivery.closedAt == nil
        }.map { MascotActivity.task($0, connected: connected, now: now) }
        let sessions = visibleExternalSessions.map {
            MascotActivity.session($0, current: externalSessionError == nil, now: now)
        }
        return (runs + sessions).sorted {
            if $0.priority != $1.priority { return $0.priority < $1.priority }
            return $0.updatedAt == $1.updatedAt ? $0.id < $1.id : $0.updatedAt > $1.updatedAt
        }
    }
}
