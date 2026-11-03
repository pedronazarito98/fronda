import Foundation
import HarnessDomain

struct RunFollowupLoopProjection {
    let run: Run

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
                RunFollowupHistoryItem(
                    id: execution.id + ":" + iteration.id,
                    title: "Ciclo \(iteration.number) · \(iteration.state.label)",
                    detail: iteration.decisionReason.isEmpty
                        ? iteration.finishedAt == nil
                            ? "Ainda sem resultado registrado." : "Resultado detalhado não registrado."
                        : iteration.decisionReason,
                    appearance: RunFlowAppearance(loopState: iteration.state),
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
