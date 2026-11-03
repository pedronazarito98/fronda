import Foundation
import HarnessDomain

struct RunFollowupModel {
    let run: Run
    let isConnected: Bool
    let journey: RunJourneyModel
    let loop: RunFollowupLoopProjection

    init(run: Run, isConnected: Bool = true) {
        self.run = run
        self.isConnected = isConnected
        journey = RunJourneyModel(run: run)
        loop = RunFollowupLoopProjection(run: run)
    }

    func currentSummary(for action: RunUserAction?) -> String {
        guard isConnected, run.state == .waitingUser else { return currentTitle }
        switch action {
        case .reviewContext: return "Aguardando autorização do contexto"
        case .reviewProposal: return "Aguardando aprovação da proposta"
        case .recordReproduction: return "Falta registrar a reprodução"
        case .recordVerification: return "Falta registrar o resultado do cenário"
        case .reviewChecks: return "Uma verificação precisa de atenção"
        case .reviewOperations: return "Há uma operação para conferir"
        case .resume: return "O trabalho pode continuar"
        default: return currentTitle
        }
    }
    var loopSummary: String? { loop.summary }

    var currentStep: RunJourneyStep? {
        journey.steps.first { $0.id == journey.currentStepID }
    }

    var currentTitle: String {
        guard isConnected else { return "Último estado conhecido" }
        if [.paused, .blocked, .partial].contains(run.state) {
            if run.loopExecution?.state == .limitReached { return "O ciclo atingiu o limite" }
            if run.loopExecution?.state == .stalled { return "O ciclo parou sem progresso" }
        }
        switch run.state {
        case .draft: return "Plano aguardando preparação"
        case .queued: return "Aguardando sua vez"
        case .paused: return "Execução pausada"
        case .recovering: return "É preciso recuperar a execução"
        case .ready: return "Pronta para sua revisão"
        case .partial: return "A execução deixou pendências"
        case .failed: return "A execução encontrou uma falha"
        case .cancelled: return "Execução cancelada"
        case .archived: return "Tarefa arquivada"
        case .blocked: return "A execução está bloqueada"
        case .waitingUser:
            switch currentStep?.state {
            case .awaitingApproval:
                return currentStep?.step.kind == "context"
                    ? "Aguardando autorização do contexto" : "Aguardando aprovação do plano"
            case .awaitingEvidence: return "Aguardando a evidência do cenário"
            default: return "Aguardando sua decisão"
            }
        case .preparing: return "Preparando contexto"
        case .running: return currentStep?.title ?? "Executando a tarefa"
        }
    }

    var currentDetail: String {
        guard isConnected else {
            let previous = currentStep.map { "\(run.state.label) · \($0.title)" } ?? run.state.label
            return "\(previous). A conexão foi interrompida; não é possível confirmar a atividade atual."
        }
        if run.state != .draft && !run.state.active,
            !run.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return run.reason
        }
        switch run.state {
        case .draft:
            return "Prepare o contexto desta revisão para conferir o que será enviado antes de autorizar a execução."
        case .queued: return "Nenhuma etapa está executando enquanto a tarefa aguarda sua vez."
        case .paused:
            return run.loopExecution?.reason.isEmpty == false
                ? run.loopExecution?.reason ?? "A execução está pausada."
                : "Nenhuma etapa está em execução. O trabalho aguarda uma retomada."
        case .ready: return "Confira as alterações e as evidências antes de preparar a entrega."
        case .partial: return "Confira os resultados e as pendências antes de retomar o trabalho."
        case .blocked: return "O avanço depende de resolver o bloqueio registrado nesta tarefa."
        case .failed: return "O trabalho parou com falha. Confira os resultados disponíveis."
        case .recovering: return "Confira a última etapa registrada antes de recuperar o trabalho."
        case .cancelled: return "A execução foi encerrada por cancelamento."
        case .archived: return "Esta tarefa está arquivada; seus resultados permanecem disponíveis."
        case .waitingUser:
            if currentStep?.state == .awaitingEvidence {
                return "A próxima etapa depende de registrar o resultado observado no cenário."
            }
            return "A próxima etapa depende de uma decisão sua."
        case .preparing:
            return "O Fronda prepara os arquivos e as instruções para você revisar antes de autorizar o envio."
        case .running: break
        }
        guard let currentStep else { return "Não há uma etapa atual informada." }
        switch currentStep.step.kind {
        case "validation":
            if let result = run.validations.last(where: { $0.status == .running && $0.revision == run.revision }) {
                return "A checagem “\(result.validator.name)” está em execução."
            }
            return "A etapa de validação está em andamento; ainda não há uma checagem ativa informada."
        case "implementation":
            return "O executor trabalha nesta etapa. O resultado ainda precisa passar pelas checagens."
        case "investigation": return "O executor está investigando o projeto para preparar o diagnóstico."
        case "context": return "O Fronda prepara os arquivos e as instruções que serão enviados ao executor."
        case "plan": return "O executor está preparando a proposta para sua revisão."
        case "review": return "A revisão independente está em andamento."
        case "reproduction", "verification": return "A conclusão depende de evidência registrada para este cenário."
        default: return "O executor não informou uma descrição mais detalhada desta etapa."
        }
    }

    var currentAppearance: RunFlowAppearance {
        guard isConnected else { return .waiting }
        if run.state == .blocked && run.loopExecution?.state == .failed { return .failed }
        return switch run.state {
        case .preparing, .running: .running
        case .waitingUser, .recovering, .partial, .blocked: .attention
        case .failed: .failed
        case .draft, .queued, .paused, .ready, .cancelled, .archived: .waiting
        }
    }

    var remaining: [String] {
        if [.cancelled, .archived].contains(run.state) {
            return ["O trabalho foi encerrado. As checagens e pendências registradas continuam disponíveis."]
        }
        var items = [String]()
        if run.state == .draft {
            items.append("Preparar e revisar o contexto do plano atual.")
        } else if run.pack != nil && !run.contextApproved {
            items.append("Autorizar o contexto que será enviado ao executor.")
        } else if run.contextApproved && !run.planApproved && !(run.workflow?.proposal.isEmpty ?? true) {
            items.append("Revisar e aprovar a proposta de implementação.")
        }
        let pendingValidations = RunFollowupEvidence.latestValidations(in: run).filter {
            $0.validator.required && !RunFollowupEvidence.validationIsConfirmed($0, in: run)
        }
        if run.validations.isEmpty,
            run.plan.contains(where: { $0.kind == "validation" && $0.status != .skipped })
        {
            items.append("Ainda não há resultado de checagem registrado.")
        }
        for result in pendingValidations.prefix(2) {
            let status = RunFollowupEvidence.status(of: result, in: run)
            let detail = status == .pass ? "comprovação incompleta" : Self.validationLabel(status).lowercased()
            items.append("\(result.validator.name): \(detail).")
        }
        if pendingValidations.count > 2 {
            items.append("Mais \(pendingValidations.count - 2) checagens obrigatórias pendentes.")
        }
        if !run.workflowEvidenceComplete {
            items.append("Registrar a evidência do cenário na versão atual da alteração.")
        }
        let pendingCriteria = run.criteria.filter { !RunFollowupEvidence.criterionIsConfirmed($0) }
        if let criterion = pendingCriteria.first {
            items.append("Confirmar: \(criterion.text)")
            if pendingCriteria.count > 1 {
                items.append("Mais \(pendingCriteria.count - 1) critérios aguardam evidência.")
            }
        } else if run.criteria.isEmpty {
            items.append("Registrar os critérios que definem a conclusão desta tarefa.")
        }
        let findings = run.findings.filter { ["OPEN", "ACCEPTED_RISK"].contains($0.state) }
        if !findings.isEmpty {
            items.append(
                "Resolver \(findings.count) \(findings.count == 1 ? "achado da revisão" : "achados da revisão").")
        }
        if items.isEmpty {
            if run.state == .ready {
                items.append("Revisar as alterações e as evidências para decidir sobre a entrega.")
            } else if let currentStep {
                items.append(currentStep.expectedOutcome + ".")
            } else {
                items.append("Conferir os resultados e a revisão da entrega.")
            }
        }
        return items
    }

    static func validationLabel(_ status: GateStatus) -> String {
        switch status {
        case .pass: "Passou"
        case .fail: "Falhou"
        case .running: "Em execução"
        case .notRun: "Ainda não executada"
        case .blocked: "Bloqueada"
        case .stale: "Precisa revalidar"
        case .skipped: "Não executada neste caminho"
        case .cancelled: "Cancelada"
        }
    }
}
