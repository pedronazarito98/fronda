import HarnessDomain
import SwiftUI

enum RunWorkspaceSection: String, Codable, CaseIterable, Identifiable {
    case conversation = "Conversa"
    case overview = "Visão geral"
    case context = "Contexto"
    case plan = "Plano"
    case changes = "Alterações"
    case validation = "Validação"
    case review = "Revisão"
    case evidence = "Evidências"
    case activity = "Atividade"
    case tokens = "Tokens"
    case scenarios = "Cenários"

    var id: String { rawValue }
    static let primary: [Self] = [.conversation, .plan, .changes, .context, .validation]
    static let additional: [Self] = [.overview, .review, .scenarios, .evidence, .activity, .tokens]

    var symbol: String {
        switch self {
        case .conversation: "bubble.left.and.bubble.right"
        case .overview: "rectangle.grid.1x2"
        case .context: "doc.text.magnifyingglass"
        case .plan: "list.bullet.clipboard"
        case .changes: "chevron.left.forwardslash.chevron.right"
        case .validation: "checkmark.shield"
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
        case "plan", "investigation": .plan
        case "validation": .validation
        case "review": .review
        case "evidence": .evidence
        case "reproduction", "verification": .scenarios
        default: .changes
        }
    }
}
