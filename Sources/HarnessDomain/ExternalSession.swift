import Foundation

public struct ExternalSession: Codable, Identifiable, Sendable {
    public let id: String
    public let sessionID: String
    public let provider: ProviderKind
    public let project: String
    public let state: State
    public let updatedAt: Date

    public enum State: String, Codable, Sendable {
        case idle, running, waiting, completed, interrupted, ended
        public var label: String {
            switch self {
            case .idle: "Sessão aberta"
            case .running: "Em execução"
            case .waiting: "Aguardando aprovação"
            case .completed: "Turno concluído"
            case .interrupted: "Interrompida"
            case .ended: "Encerrada"
            }
        }
    }

    public init(sessionID: String, provider: ProviderKind, project: String, state: State, updatedAt: Date = .now) {
        self.id = provider.rawValue + ":" + sessionID
        self.sessionID = sessionID
        self.provider = provider
        self.project = project
        self.state = state
        self.updatedAt = updatedAt
    }

    public func isStale(at date: Date) -> Bool {
        [.running, .waiting, .idle].contains(state) && date.timeIntervalSince(updatedAt) > 300
    }
}
