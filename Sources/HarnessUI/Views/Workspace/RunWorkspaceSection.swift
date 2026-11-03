import HarnessDomain
import SwiftUI

enum RunWorkspaceSection: String, Codable, CaseIterable, Identifiable {
    case conversation = "Conversa"
    case overview = "Visão geral"
    case context = "Contexto"
    case plan = "Plano"
    case proposal = "Proposta"
    case changes = "Alterações"
    case files = "Arquivos"
    case validation = "Validação"
    case checkup = "Conferência e entrega"
    case review = "Revisão"
    case evidence = "Evidências"
    case activity = "Atividade"
    case tokens = "Tokens"
    case scenarios = "Cenários"

    var id: String { rawValue }
    var isTaskHome: Bool { self == .conversation || self == .overview }

    var symbol: String {
        switch self {
        case .conversation: "list.bullet.rectangle"
        case .overview: "rectangle.grid.1x2"
        case .context: "doc.text.magnifyingglass"
        case .plan: "list.bullet.clipboard"
        case .proposal: "doc.text"
        case .changes: "chevron.left.forwardslash.chevron.right"
        case .files: "folder"
        case .validation: "checkmark.shield"
        case .checkup: "checkmark.seal"
        case .review: "text.magnifyingglass"
        case .evidence: "doc.richtext"
        case .activity: "waveform.path"
        case .tokens: "chart.bar"
        case .scenarios: "checkmark.viewfinder"
        }
    }

    static func destination(for step: RunbookStep) -> Self {
        switch step.kind {
        case "context": .context
        case "plan", "investigation": .proposal
        case "validation": .validation
        case "review": .review
        case "evidence": .evidence
        case "reproduction", "verification": .scenarios
        default: .changes
        }
    }
}
