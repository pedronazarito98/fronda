import Foundation
import HarnessDomain

struct RunFollowupLoopProjection {
    let run: Run

    enum CurrentVerification {
        case approved, pending, failed, unavailable
    }

    /// The cycle result is historical; a later validation may replace it on the same revision.
    func currentVerification(project: Project?) -> CurrentVerification {
        guard let project, project.id == run.projectID else { return .unavailable }
        let required = run.runbook.validators(for: project).filter(\.required)
        guard !required.isEmpty, !run.revision.isEmpty else { return .pending }
        let latest = RunFollowupEvidence.latestValidations(in: run)
        let current = required.compactMap { validator in
            latest.first { $0.validator == validator && $0.revision == run.revision }
        }
        if current.contains(where: { $0.status == .fail && $0.exitCode.map { $0 != 0 } == true }) {
            return .failed
        }
        guard current.count == required.count,
            current.allSatisfy({ RunFollowupEvidence.validationIsConfirmed($0, in: run) }),
            run.loopExecution?.validatedRevision == run.revision
        else { return .pending }
        return .approved
    }

    var policy: LoopPolicy? { run.loopExecution?.policy ?? run.runbook.loopPolicy }

    var summary: String? {
        guard let policy else { return nil }
        guard let iteration = run.currentLoopIteration else {
            return "Até \(policy.maxIterations) ciclos · ainda não iniciado"
        }
        return "Ciclo \(iteration.number) de \(policy.maxIterations)"
    }

    var repetitionReason: String {
        guard let execution = run.loopExecution else {
            return policy == nil
                ? "Esta tarefa não tem um ciclo de correção ativado."
                : "O ciclo ainda não começou. Uma nova rodada depende do resultado das checagens."
        }
        let currentNumber = execution.currentIteration?.number ?? 0
        let previous = execution.iterations
            .filter { $0.number < currentNumber && $0.finishedAt != nil }
            .max { $0.number < $1.number }
        guard let previous else {
            if execution.state == .repeating, let iteration = execution.currentIteration,
                !iteration.decisionReason.isEmpty
            {
                return iteration.decisionReason
            }
            return "Ainda não houve repetição neste ciclo."
        }
        if previous.state == .repeating, !previous.decisionReason.isEmpty {
            return previous.decisionReason
        }
        let failedNames = previous.validations.filter { $0.status == .fail }.map { $0.validator.name }
        if !failedNames.isEmpty {
            return "A rodada anterior registrou falha em: \(failedNames.joined(separator: ", "))."
        }
        return "A execução foi retomada, mas o motivo desta repetição não está registrado."
    }

    var didRepeat: Bool {
        (run.currentLoopIteration?.number ?? 0) > 1 || run.loopExecution?.state == .repeating
    }

    var history: [RunFollowupHistoryItem] {
        var executions = run.loopHistory ?? []
        if let current = run.loopExecution {
            executions.removeAll { $0.id == current.id }
            executions.append(current)
        }
        return executions.flatMap { execution in
            execution.iterations.map { iteration in
                let currentPause =
                    execution.id == run.loopExecution?.id
                    && iteration.id == execution.currentIterationID && iteration.finishedAt == nil
                    && [.paused, .recovering].contains(run.state) && run.pauseStatus != nil
                let status =
                    currentPause && run.isPauseRequested
                    ? "Solicitando pausa"
                    : currentPause && run.needsPauseReview
                        ? "Parada não confirmada"
                        : currentPause && run.pauseStatus == .acknowledged
                            ? "Interrupção conferida por você"
                            : iteration.state == .passed
                                ? "Verificações aprovadas naquela rodada" : iteration.state.label
                let appearance: RunFlowAppearance =
                    currentPause && run.isPauseRequested
                    ? .running
                    : currentPause && run.needsPauseReview ? .attention : RunFlowAppearance(loopState: iteration.state)
                return RunFollowupHistoryItem(
                    id: execution.id + ":" + iteration.id,
                    title: "Ciclo \(iteration.number) · \(status)",
                    detail: iteration.decisionReason.isEmpty
                        ? iteration.finishedAt == nil
                            ? "Ainda sem resultado registrado." : "Resultado detalhado não registrado."
                        : iteration.state == .passed
                            ? "Na rodada registrada: " + iteration.decisionReason : iteration.decisionReason,
                    appearance: appearance,
                    date: iteration.finishedAt ?? iteration.startedAt,
                    checks: iteration.validations.map { result in
                        "\(result.validator.name): \(RunFollowupModel.validationLabel(result.status))"
                    })
            }
        }
        .sorted { $0.date > $1.date }
    }

    var limits: [String] {
        var values = [String]()
        if let policy {
            values.append("Até \(policy.maxIterations) ciclos de correção e checagem.")
            values.append("Parar após \(policy.maxStagnantIterations) ciclos sem progresso.")
            values.append(
                "Tempo ativo: \(policy.maxDurationSeconds / 60) min, conferido entre etapas; uma chamada em andamento pode terminar depois."
            )
        } else {
            values.append("Sem repetição automática configurada.")
        }
        values.append("Teto da tarefa: \(run.budget.formatted()) tokens.")
        if run.tokens.contains(where: { $0.input != nil || $0.output != nil }) {
            values.append("Uso informado pelo executor: \(run.reportedTokens.formatted()) tokens.")
        } else {
            values.append("O executor ainda não informou o consumo de tokens.")
        }
        return values
    }
}

struct RunFollowupHistoryItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let appearance: RunFlowAppearance
    let date: Date
    let checks: [String]
}
