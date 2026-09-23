import Foundation

public enum RunState: String, Codable, CaseIterable, Sendable {
    case draft = "DRAFT"
    case queued = "QUEUED"
    case preparing = "PREPARING"
    case running = "RUNNING"
    case waitingUser = "WAITING_USER"
    case paused = "PAUSED"
    case recovering = "RECOVERING"
    case ready = "READY"
    case partial = "PARTIAL"
    case failed = "FAILED"
    case cancelled = "CANCELLED"
    case blocked = "BLOCKED"
    case archived = "ARCHIVED"
    public var active: Bool { [.preparing, .running].contains(self) }
    public var terminal: Bool { [.ready, .partial, .failed, .cancelled, .blocked, .archived].contains(self) }
    public var label: String {
        switch self {
        case .draft: "Rascunho"
        case .queued: "Na fila"
        case .preparing: "Preparando"
        case .running: "Em execução"
        case .waitingUser: "Aguardando você"
        case .paused: "Pausada"
        case .recovering: "Recuperação necessária"
        case .ready: "Pronta para revisão"
        case .partial: "Parcial"
        case .failed: "Falhou"
        case .cancelled: "Cancelada"
        case .blocked: "Bloqueada"
        case .archived: "Arquivada"
        }
    }
}

public enum GateStatus: String, Codable, CaseIterable, Sendable {
    case notRun = "NOT_RUN"
    case running = "RUNNING"
    case pass = "PASS"
    case fail = "FAIL"
    case blocked = "BLOCKED"
    case stale = "STALE"
    case skipped = "SKIPPED"
    case cancelled = "CANCELLED"
}

public enum AutonomyMode: String, Codable, CaseIterable, Sendable {
    case explore = "Explorar"
    case plan = "Planejar"
    case guided = "Guiado"
    case auto = "Auto"
    case trusted = "Confiável"
    public var writes: Bool { [.guided, .auto, .trusted].contains(self) }
}

public enum ProviderKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case codex = "Codex"
    case claude = "Claude Code"
    public var id: String { rawValue }
}

public enum SourceKind: String, Codable, CaseIterable, Sendable {
    case text = "Texto"
    case jira = "Jira"
    case github = "GitHub"
    case file = "Arquivo"
    case screenshot = "Screenshot"
    case validation = "Validação"
    case diff = "Diff"
    public static func detect(_ text: String) -> Self {
        if text.contains("/pull/") { return .github }
        if text.range(of: #"\b[A-Z][A-Z0-9]+-\d+\b"#, options: .regularExpression) != nil { return .jira }
        return .text
    }
}

public struct HarnessError: LocalizedError, Codable, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public func makeID() -> String { UUID().uuidString.lowercased() }
