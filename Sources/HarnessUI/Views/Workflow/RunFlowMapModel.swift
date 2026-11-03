import Foundation
import HarnessDomain

/// Presentation data only. The coordinator owns loop membership, policy and progress.
struct RunFlowMapLoop: Identifiable, Hashable {
    let id: String
    let title: String
    let stepIDs: [String]
    let summary: String
    let returnLabel: String
    let didRepeat: Bool
}

struct RunFlowMapNodeModel: Identifiable {
    let journey: RunJourneyStep
    let appearance: RunFlowAppearance
    let role: String
    let roleSymbol: String
    let status: String
    let dependencyDescription: String

    var id: String { journey.id }
    var title: String { journey.title }
    var condition: String? { Self.conditionLabel(journey.step.condition) }
    var finished: Bool { journey.state == .passed || journey.state == .skipped }
    var statusSymbol: String {
        if journey.state == .passed, appearance == .waiting { return "checkmark" }
        return appearance.symbol
    }

    init(journey: RunJourneyStep, run: Run, connected: Bool = true) {
        self.journey = journey
        let reportedAppearance = RunFlowAppearance(step: journey, run: run)
        appearance = !connected && reportedAppearance == .running ? .waiting : reportedAppearance
        let step = journey.step
        let humanDecision =
            ["context", "reproduction", "verification"].contains(step.kind)
            && [.awaitingApproval, .awaitingEvidence, .awaitingAction].contains(journey.state)
            || (step.kind == "context" && journey.state == .passed && run.contextApproved)
        if humanDecision || (step.kind == "plan" && journey.state == .awaitingApproval) {
            role = "Pessoa"
            roleSymbol = "person"
        } else if step.usesAgent {
            role = "Modelo"
            roleSymbol = "sparkles"
        } else {
            role = "Código"
            roleSymbol = "chevron.left.forwardslash.chevron.right"
        }
        if !connected && reportedAppearance == .running {
            status = "Último estado recebido"
        } else if journey.state == .passed {
            switch step.kind {
            case "implementation":
                status = run.mode.writes ? "Etapa concluída · confira as alterações" : "Análise concluída"
            case "validation", "verification":
                status = appearance == .confirmed ? "Verificação aprovada" : "Etapa concluída"
            case "reproduction" where appearance == .confirmed: status = "Reprodução comprovada"
            case "context" where run.contextApproved: status = "Contexto aprovado"
            case "plan" where run.planApproved: status = "Plano aprovado"
            default: status = "Etapa concluída"
            }
        } else if journey.state == .skipped {
            status = "Não executada"
        } else if journey.state == .failed && appearance == .attention {
            status = "Pendência encontrada"
        } else {
            status = journey.state.label
        }
        let names = step.dependencies.map { dependencyID in
            run.plan.first(where: { $0.id == dependencyID })?.title ?? "Etapa indisponível"
        }
        dependencyDescription = names.isEmpty ? "Sem dependências" : "Depende de " + names.joined(separator: ", ")
    }

    static func conditionLabel(_ condition: String) -> String? {
        switch condition {
        case "on_pass": "Se as dependências passarem"
        case "on_failure": "Se uma dependência falhar"
        case "has_changes": "Se houver alterações"
        default: nil
        }
    }
}
