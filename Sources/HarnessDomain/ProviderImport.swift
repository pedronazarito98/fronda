import Foundation

public enum ProviderImportKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case skill, rule, prompt, agent, mcp, settings, unsupported
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .skill: "Skills"
        case .rule: "Regras"
        case .prompt: "Comandos de texto"
        case .agent: "Instruções de agentes"
        case .mcp: "MCPs"
        case .settings: "Modelo e esforço"
        case .unsupported: "Revisão manual"
        }
    }
    public var symbol: String {
        switch self {
        case .skill: "sparkles"
        case .rule: "text.book.closed"
        case .prompt: "text.bubble"
        case .agent: "person.crop.circle.badge.gearshape"
        case .mcp: "puzzlepiece.extension"
        case .settings: "slider.horizontal.3"
        case .unsupported: "hand.raised"
        }
    }
}

public struct ProviderImportItem: Codable, Sendable, Identifiable {
    public var id = ""
    public var name = ""
    public var kind = ProviderImportKind.skill
    public var source = ""
    public var scope = "Este usuário"
    public var preview = ""
    public var detail = ""
    public var fingerprint = ""
    public var configuration: HarnessExtension?
    public var execution: ExecutionConfiguration?
    public var selectable = true
    public var alreadyImported = false
    public init() {}
}

public struct ProviderImportPreview: Codable, Sendable {
    public var id = makeID()
    public var provider: ProviderKind
    public var projectID: String?
    public var items = [ProviderImportItem]()
    public var warnings = [String]()
    public init(provider: ProviderKind) { self.provider = provider }
}
