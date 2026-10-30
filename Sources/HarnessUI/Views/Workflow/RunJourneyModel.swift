import HarnessDomain
import SwiftUI

struct RunJourneyModel {
    let steps: [RunJourneyStep]
    let currentStepID: String?

    init(run: Run) {
        let contextPending = Self.contextApprovalPending(in: run)
        let planPending = Self.planApprovalPending(in: run)
        let currentID = Self.currentStepID(in: run, contextPending: contextPending, planPending: planPending)
        currentStepID = currentID
        steps = run.plan.enumerated().map { index, step in
            let isCurrent = step.id == currentID
            let state = Self.phase(
                for: step, run: run, isCurrent: isCurrent, contextPending: contextPending, planPending: planPending)
            return RunJourneyStep(
                step: step, number: index + 1, isCurrent: isCurrent, state: state,
                detail: Self.detail(for: step, writes: run.mode.writes),
                expectedOutcome: Self.expectedOutcome(for: step, writes: run.mode.writes),
                dependencySummary: Self.dependencies(
                    of: step, in: run, currentID: currentID,
                    contextPending: contextPending, planPending: planPending),
                blocker: isCurrent && [.blocked, .failed, .recovering].contains(run.state) && !run.reason.isEmpty
                    ? run.reason : nil)
        }
    }

    var completedCount: Int { steps.filter { $0.step.status == .pass }.count }
    var skippedCount: Int { steps.filter { $0.step.status == .skipped }.count }
    var totalCount: Int { steps.count }
    var progressSummary: String {
        guard totalCount > 0 else { return "Plano ainda não disponível" }
        let completed = "\(completedCount) de \(totalCount) concluídas"
        let skipped = "\(skippedCount) " + (skippedCount == 1 ? "pulada" : "puladas")
        return skippedCount == 0 ? completed : completed + " · " + skipped
    }

    func step(id: String?) -> RunJourneyStep? {
        steps.first { $0.id == id } ?? steps.first { $0.id == currentStepID } ?? steps.last
    }

    private static func contextApprovalPending(in run: Run) -> Bool {
        guard run.pack != nil, !run.contextApproved, !run.state.active,
            ![.archived, .cancelled].contains(run.state)
        else {
            return false
        }
        return run.state == .waitingUser
            || run.plan.contains { $0.kind == "context" && $0.status == .pass }
    }

    private static func planApprovalPending(in run: Run) -> Bool {
        guard run.pack != nil, !run.planApproved, !run.state.active,
            ![.archived, .cancelled].contains(run.state)
        else {
            return false
        }
        if run.workflow != nil {
            return run.contextApproved && !(run.workflow?.proposal.isEmpty ?? true)
        }
        return contextApprovalPending(in: run) && run.plan.contains { $0.kind == "plan" && $0.status == .pass }
    }

    private static func currentStepID(in run: Run, contextPending: Bool, planPending: Bool) -> String? {
        guard ![.archived, .cancelled].contains(run.state) else { return nil }
        if let running = run.plan.first(where: { $0.status == .running }) { return running.id }
        if contextPending || (run.state == .preparing && !run.contextApproved),
            let context = run.plan.first(where: { $0.kind == "context" })
        {
            return context.id
        }
        if planPending, let plan = run.plan.first(where: { $0.kind == "plan" }) { return plan.id }
        return run.currentStep?.id
    }

    private static func phase(
        for step: RunbookStep, run: Run, isCurrent: Bool, contextPending: Bool, planPending: Bool
    ) -> RunJourneyPhaseState {
        if step.status == .running {
            switch run.state {
            case .paused: return .paused
            case .blocked: return .blocked
            case .failed: return .failed
            case .recovering: return .recovering
            case .archived, .cancelled: return .interrupted
            case .waitingUser: return .awaitingAction
            default: return run.state.active ? .running : .interrupted
            }
        }
        if step.kind == "context" && contextPending { return .awaitingApproval }
        if step.kind == "plan" && planPending { return .awaitingApproval }
        if isCurrent {
            if run.state == .preparing && step.kind == "context" { return .preparing }
            if run.state == .waitingUser && ["reproduction", "verification"].contains(step.kind) {
                return .awaitingEvidence
            }
            if ![.pass, .skipped].contains(step.status) {
                switch run.state {
                case .blocked: return .blocked
                case .failed: return .failed
                case .paused: return .paused
                case .recovering: return .recovering
                default: break
                }
            }
        }
        switch step.status {
        case .notRun: return .notStarted
        case .running: return .running
        case .pass: return .passed
        case .fail: return .failed
        case .blocked: return .blocked
        case .stale: return .stale
        case .skipped: return .skipped
        case .cancelled: return .interrupted
        }
    }

    private static func dependencies(
        of step: RunbookStep, in run: Run, currentID: String?, contextPending: Bool, planPending: Bool
    ) -> String? {
        guard ![.pass, .skipped].contains(step.status) else { return nil }
        var pending = [String]()
        var outcomes = [RunbookStep]()
        for dependencyID in step.dependencies {
            guard let dependency = run.plan.first(where: { $0.id == dependencyID }) else {
                pending.append("dependência não encontrada (\(dependencyID))")
                continue
            }
            if dependency.kind == "context" && contextPending {
                pending.append("\(dependency.title) (autorização)")
            } else if dependency.kind == "plan" && planPending {
                pending.append("\(dependency.title) (aprovação)")
            } else {
                switch dependency.status {
                case .notRun, .running, .stale: pending.append(dependency.title)
                case .fail, .blocked, .cancelled: outcomes.append(dependency)
                case .skipped where step.condition == "on_pass": outcomes.append(dependency)
                case .pass, .skipped: break
                }
            }
        }
        var messages = [String]()
        if !pending.isEmpty { messages.append("Aguarda: " + pending.joined(separator: ", ") + ".") }
        if !outcomes.isEmpty {
            let names = outcomes.map { dependency in
                let state = phase(
                    for: dependency, run: run, isCurrent: false,
                    contextPending: contextPending, planPending: planPending)
                return "\(dependency.title) (\(state.label.lowercased()))"
            }
            messages.append("Dependências a conferir: " + names.joined(separator: ", ") + ".")
            if step.condition == "on_pass" {
                messages.append("A condição exige que todas as dependências terminem com sucesso.")
            } else if step.condition == "on_failure" {
                messages.append(
                    outcomes.contains { [.fail, .blocked].contains($0.status) }
                        ? "A condição de executar após falha está atendida."
                        : "A condição exige uma dependência com falha ou bloqueio.")
            }
            if let current = outcomes.first(where: { $0.id == currentID }),
                [.blocked, .failed, .paused, .recovering, .waitingUser, .partial].contains(run.state)
            {
                messages.append("A execução está parada em \(current.title).")
            }
        }
        return messages.isEmpty ? nil : messages.joined(separator: " ")
    }

    private static func detail(for step: RunbookStep, writes: Bool) -> String {
        switch step.kind {
        case "context": "Confira os arquivos, o escopo e o executor antes de autorizar o envio."
        case "investigation": "Entenda o fluxo atual e examine o diagnóstico produzido pelo executor."
        case "reproduction": "Registre o cenário, o resultado esperado e a falha observada."
        case "plan": "Revise a proposta, os arquivos envolvidos e os critérios antes de aprovar."
        case "implementation":
            writes
                ? "Acompanhe as alterações feitas pelo executor e compare o resultado com o plano."
                : "Acompanhe a análise do executor e confira o resultado em modo de leitura."
        case "validation": "Confira os comandos executados, suas saídas e o resultado de cada validação."
        case "verification": "Observe o comportamento e registre a evidência do cenário atual."
        case "review": "Examine o parecer independente, os achados e a revisão humana."
        case "evidence": "Confira critérios, arquivos e evidências antes de preparar a entrega."
        default: "Confira o resultado e as evidências desta etapa do plano."
        }
    }

    private static func expectedOutcome(for step: RunbookStep, writes: Bool) -> String {
        switch step.kind {
        case "context": "Contexto conferido e envio autorizado"
        case "investigation": "Diagnóstico do fluxo e dos arquivos envolvidos"
        case "reproduction": "Problema reproduzido com evidência registrada"
        case "plan": "Proposta revisada e aprovada"
        case "implementation":
            writes ? "Alterações disponíveis para conferência" : "Resultado da investigação disponível"
        case "validation": "Comandos e resultados vinculados ao snapshot"
        case "verification": "Cenário observado e evidência registrada"
        case "review": "Parecer e achados disponíveis para decisão humana"
        case "evidence": "Critérios ligados às evidências da entrega"
        default: "Resultado documentado para conferência"
        }
    }
}

struct RunJourneyStep: Identifiable {
    let step: RunbookStep
    let number: Int
    let isCurrent: Bool
    let state: RunJourneyPhaseState
    let detail: String
    let expectedOutcome: String
    let dependencySummary: String?
    let blocker: String?

    var id: String { step.id }
    var title: String { step.title }
    var isFinished: Bool { state == .passed || state == .skipped }
}

enum RunJourneyPhaseState: Equatable {
    case notStarted, preparing, running, passed, failed, blocked, stale, skipped
    case awaitingApproval, awaitingEvidence, awaitingAction, paused, recovering, interrupted

    var label: String {
        switch self {
        case .notStarted: "Não iniciada"
        case .preparing: "Preparando"
        case .running: "Em execução"
        case .passed: "Concluída"
        case .failed: "Falhou"
        case .blocked: "Bloqueada"
        case .stale: "Precisa revalidar"
        case .skipped: "Pulada"
        case .awaitingApproval: "Aguarda sua aprovação"
        case .awaitingEvidence: "Aguarda evidência"
        case .awaitingAction: "Aguarda sua decisão"
        case .paused: "Pausada"
        case .recovering: "Requer recuperação"
        case .interrupted: "Interrompida"
        }
    }

    var symbol: String {
        switch self {
        case .notStarted: "circle"
        case .preparing, .running: "circle.dotted"
        case .passed: "checkmark"
        case .failed: "xmark"
        case .blocked, .stale, .recovering: "exclamationmark"
        case .skipped: "arrow.right"
        case .awaitingApproval, .awaitingAction: "hand.raised"
        case .awaitingEvidence: "camera"
        case .paused: "pause"
        case .interrupted: "stop"
        }
    }

    var color: Color {
        switch self {
        case .passed: FrondaTheme.success
        case .failed: FrondaTheme.danger
        case .awaitingApproval, .awaitingEvidence, .awaitingAction, .blocked, .stale, .recovering: FrondaTheme.warning
        case .preparing, .running: FrondaTheme.accent
        case .notStarted, .skipped, .paused, .interrupted: FrondaTheme.textMuted
        }
    }
}
