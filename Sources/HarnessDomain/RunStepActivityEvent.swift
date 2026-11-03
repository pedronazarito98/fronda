import Foundation

public struct RunStepActivityEvent: Identifiable, Sendable {
    public let event: RunEvent
    public let title: String
    public let detail: String?
    public let category: Category
    public var id: String { event.id }

    public enum Category: Sendable {
        case stage, provider, file, tool, validation, attention, success, failure

    }

    public init?(_ event: RunEvent) {
        self.event = event
        let item: (String, String?, Category)
        switch event.kind {
        case "run.preparing": item = ("Preparação iniciada", nil, .stage)
        case "workspace.leased": item = ("Espaço de trabalho preparado", nil, .stage)
        case "context.pack_compiled": item = ("Contexto preparado", event.message, .success)
        case "step.running": item = ("Etapa iniciada", event.message, .stage)
        case "step.pass": item = ("Etapa concluída", event.message, .success)
        case "step.fail": item = ("A etapa falhou", event.message, .failure)
        case "step.blocked", "step.stale": item = ("Etapa precisa de atenção", event.message, .attention)
        case "step.skipped": item = ("Etapa pulada", event.message, .attention)
        case "step.retry_requested": item = ("Nova tentativa solicitada", nil, .stage)
        case "loop.step_started": item = ("Etapa iniciada no ciclo", nil, .stage)
        case "provider.attempt_started": item = ("Executor iniciou a tentativa", nil, .provider)
        case "provider.result": item = ("Resultado do executor recebido", nil, .provider)
        case "provider.error": item = ("Executor comunicou um erro", nil, .failure)
        case "provider.permission.denied": item = ("Permissão recusada", nil, .attention)
        case "provider.item/started", "provider.item/completed":
            let finished = event.kind == "provider.item/completed"
            switch event.activitySubject {
            case "commandExecution": item = (finished ? "Comando terminou" : "Executando comando", nil, .tool)
            case "fileChange": item = (finished ? "Alteração de arquivo recebida" : "Editando arquivo", nil, .file)
            case "mcpToolCall", "dynamicToolCall":
                item = (finished ? "Chamada de ferramenta terminou" : "Chamando ferramenta", nil, .tool)
            case "webSearch": item = (finished ? "Busca na web terminou" : "Buscando na web", nil, .tool)
            case "agentMessage" where finished: item = ("Resposta do executor recebida", nil, .provider)
            default: return nil
            }
        case "tool.file_read": item = ("Arquivo lido", event.message, .file)
        case "tool.file_written": item = ("Arquivo alterado", event.activitySubject, .file)
        case "tool.search": item = ("Busca no projeto", event.message, .tool)
        case "tool.failed": item = ("A ferramenta não concluiu a operação", event.activitySubject, .failure)
        case "instructions.loaded", "skill.loaded": item = ("Instruções carregadas", nil, .tool)
        case "extension.call_started": item = ("Ferramenta acionada", event.activitySubject, .tool)
        case "extension.call_completed": item = ("Ferramenta respondeu", event.activitySubject, .tool)
        case "extension.call_uncertain": item = ("Resultado da ferramenta incerto", event.activitySubject, .attention)
        case "permission.requested": item = ("Uma operação precisa de aprovação", nil, .attention)
        case "permission.investigation_approved": item = ("Investigação autorizada", nil, .success)
        case "permission.plan_and_egress_approved": item = ("Plano autorizado", nil, .success)
        case "validation.suite_started": item = ("Conferência solicitada", nil, .validation)
        case "validation.started": item = ("Verificação iniciada", event.activitySubject, .validation)
        case "validation.finished":
            let status = event.activitySubject.flatMap { GateStatus(rawValue: $0) }
            switch status {
            case .pass: item = ("Verificação passou", event.message, .success)
            case .fail: item = ("Verificação falhou", event.message, .failure)
            case .blocked: item = ("Verificação bloqueada", event.message, .attention)
            case .stale: item = ("Verificação desatualizada", event.message, .attention)
            case .cancelled: item = ("Verificação interrompida", event.message, .attention)
            case .skipped: item = ("Verificação pulada", event.message, .attention)
            case .running, .notRun, nil: item = ("Verificação sem término confirmado", event.message, .attention)
            }
        case "validation.blocked": item = ("Verificação bloqueada", nil, .attention)
        case "investigation.completed", "plan.proposed": item = ("Documento disponível para revisão", nil, .success)
        case "plan.awaiting_approval", "scenario.awaiting_evidence": item = ("Sua vez", event.message, .attention)
        case "scenario.observed": item = ("Observação registrada", event.activitySubject, .stage)
        case "review.human_confirmed": item = ("Revisão humana registrada", nil, .success)
        case "evidence.received", "evidence.provided_to_reviewer": item = ("Evidência disponível", nil, .file)
        case "review.completed": item = ("Parecer disponível", nil, .stage)
        default: return nil
        }
        (title, detail, category) = item
    }
}
