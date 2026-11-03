import Foundation
import HarnessDomain
import HarnessInfrastructure
import HarnessProviders

extension RunCoordinator {
    func executeLoop(_ policy: LoopPolicy, runID id: String) async throws {
        var value = try run(id)
        try policy.validate(steps: value.plan, mode: value.mode)
        let project = try project(value.projectID)
        let mandatory = value.runbook.validators(for: project).filter(\.required)
        if value.loopExecution == nil { value.loopExecution = LoopExecution(policy: policy) }
        guard value.loopExecution?.policy.hasSameGroup(as: policy) == true else {
            throw HarnessError("O grupo do ciclo mudou. Revise e aprove o plano antes de continuar.")
        }
        value.loopExecution?.policy = policy
        if mandatory.isEmpty || mandatory.contains(where: { !$0.approved }) {
            let reason =
                mandatory.isEmpty
                ? "Cadastre e aprove uma verificação obrigatória em Validação para continuar o ciclo."
                : "Confira os comandos obrigatórios em Validação e aprove os que ainda estão pendentes."
            value.state = .waitingUser
            value.reason = reason
            value.loopExecution?.state = .awaitingUser
            value.loopExecution?.reason = reason
            value.loopExecution?.validationWait = .catalog
            updateUnfinishedIteration(&value, state: .awaitingUser, reason: reason)
            try record(value, kind: "loop.awaitingUser", message: reason)
            return
        }
        value.loopExecution?.validationWait = nil
        for validator in mandatory { try PolicyEngine.approveValidator(validator, run: value) }
        if value.plan.contains(where: { policy.stepIDs.contains($0.id) && $0.status == .skipped }) {
            value.loopExecution?.state = .awaitingUser
            value.loopExecution?.reason =
                "Uma etapa obrigatória do ciclo foi pulada. Revise essa exceção antes de executar o grupo."
            value.state = .partial
            value.reason = value.loopExecution?.reason ?? ""
            try record(value, kind: "loop.awaitingUser", message: value.reason)
            return
        }
        if value.loopExecution?.state == .passed,
            value.loopExecution?.validatedRevision == value.revision,
            value.plan.filter({ policy.stepIDs.contains($0.id) }).allSatisfy({ $0.status == .pass })
        {
            return
        }
        value.loopExecution?.activeSince = Date()
        try record(value, kind: "loop.resumed", message: "Acompanhando o ciclo de correção e suas verificações.")
        defer { finishLoopClock(id) }

        do {
            while true {
                try Task.checkCancellation()
                value = try run(id)
                guard value.state.active else { return }
                guard
                    try loopMayProceed(
                        id,
                        startingIteration: value.currentLoopIteration?.finishedAt != nil
                            || value.currentLoopIteration == nil)
                else { return }
                value = try run(id)
                if value.currentLoopIteration == nil || value.currentLoopIteration?.finishedAt != nil {
                    try beginLoopIteration(id)
                }
                guard try await executeLoopStep(policy.implementationStepID, runID: id) else { return }
                guard try loopMayProceed(id, startingIteration: false) else { return }
                guard try await executeLoopStep(policy.validationStepID, runID: id) else { return }
                try Task.checkCancellation()
                guard try run(id).state.active else { return }
                guard try evaluateLoop(id, validators: mandatory) else { return }
            }
        } catch {
            if var current = try? run(id), current.state.active {
                let reason = ContextFirewall.redact(error.localizedDescription)
                current.loopExecution?.state = .failed
                current.loopExecution?.reason = reason
                if let offset = current.loopExecution?.iterations.firstIndex(where: {
                    $0.id == current.loopExecution?.currentIterationID
                }) {
                    current.loopExecution?.iterations[offset].state = .failed
                    current.loopExecution?.iterations[offset].decisionReason = reason
                }
                try? record(current, kind: "loop.failed", message: reason)
            }
            throw error
        }
    }

    private func executeLoopStep(_ stepID: String, runID id: String) async throws -> Bool {
        var value = try run(id)
        guard value.state.active, let step = value.plan.first(where: { $0.id == stepID }) else { return false }
        if step.status == .pass { return true }
        guard try shouldExecute(step, run: value) else { return false }
        let providerKind = step.provider ?? value.provider
        guard !((try project(value.projectID)).disabledProviders ?? []).contains(providerKind) else {
            throw HarnessError("Provider desta etapa desativado no projeto.")
        }
        value.loopExecution?.state = .running
        let iterationNumber = value.currentLoopIteration?.number ?? 1
        value.loopExecution?.reason = "\(step.title) · ciclo \(iterationNumber)."
        if let index = value.loopExecution?.iterations.firstIndex(where: {
            $0.id == value.loopExecution?.currentIterationID
        }) {
            value.loopExecution?.iterations[index].state = .running
        }
        try record(value, kind: "loop.step_started", message: value.loopExecution?.reason ?? "", stepID: step.id)
        let provider = providers.first { $0.kind == providerKind } ?? ProviderInfo(kind: providerKind)
        try await executeStep(step, runID: id, provider: provider)
        try Task.checkCancellation()
        value = try run(id)
        guard value.state.active else { return false }
        return true
    }

    private func beginLoopIteration(_ id: String) throws {
        var value = try run(id)
        guard var execution = value.loopExecution else { throw HarnessError("Ciclo indisponível.") }
        let iteration = LoopIteration(
            number: execution.iterations.count + 1, inputRevision: value.revision, planRevision: value.planRevision)
        execution.iterations.append(iteration)
        execution.currentIterationID = iteration.id
        execution.validatedRevision = nil
        execution.state = .running
        execution.reason = "Ciclo \(iteration.number) de até \(execution.policy.maxIterations)."
        value.loopExecution = execution
        let affected = dependentSteps(in: value, roots: [execution.policy.implementationStepID])
        for i in value.plan.indices where affected.contains(value.plan[i].id) { value.plan[i].status = .notRun }
        for i in value.validations.indices { value.validations[i].status = .stale }
        value.reviewRevision = ""
        value.humanReviewRevision = ""
        try record(value, kind: "loop.iteration_started", message: execution.reason)
    }

    /// Checked before each stage and iteration; an in-flight provider may finish after the time allowance.
    func loopMayProceed(_ id: String, startingIteration: Bool) throws -> Bool {
        var value = try run(id)
        guard value.state.active, let execution = value.loopExecution else { return false }
        let state: LoopState
        let reason: String
        if value.approvals.contains(where: { ["PREPARED", "APPROVED", "SENDING", "UNKNOWN"].contains($0.state) }) {
            state = .awaitingUser
            reason = "Há uma operação pendente de decisão ou conferência. O ciclo não inicia outra etapa."
        } else if (value.extensionInvocations ?? []).contains(where: { ["RUNNING", "UNKNOWN"].contains($0.state) }) {
            state = .awaitingUser
            reason =
                "Uma ferramenta ainda não tem resultado confirmado. Confira seus efeitos antes de continuar o ciclo."
        } else if !value.planApproved || !value.contextApproved {
            state = .awaitingUser
            reason = "O plano e o contexto precisam de aprovação antes de continuar o ciclo."
        } else if value.findings.contains(where: {
            $0.author == "Scope Guard" && ["OPEN", "ACCEPTED_RISK"].contains($0.state)
        }) {
            state = .awaitingUser
            reason = "Uma alteração saiu do escopo permitido. Confira os achados antes de continuar."
        } else if value.reportedTokens >= value.budget {
            state = .limitReached
            reason = "O orçamento da tarefa foi atingido. Revise o teto antes de iniciar outra etapa."
        } else if execution.consumedSeconds >= Double(execution.policy.maxDurationSeconds) {
            state = .limitReached
            reason = "O limite de tempo ativo do ciclo foi atingido. Revise a política para continuar."
        } else if startingIteration && execution.iterations.count >= execution.policy.maxIterations {
            state = .limitReached
            reason =
                "Limite absoluto de \(execution.policy.maxIterations) ciclos atingido. Revise o plano para ampliar o total."
        } else if startingIteration
            && stagnantIterations(execution, planRevision: value.planRevision) >= execution.policy.maxStagnantIterations
        {
            state = .stalled
            reason = "As verificações repetem a falha sem progresso observado. Revise a abordagem antes de continuar."
        } else {
            return true
        }
        value.loopExecution?.state = state
        value.loopExecution?.reason = reason
        updateUnfinishedIteration(&value, state: state, reason: reason)
        value.state = state == .awaitingUser ? .waitingUser : .blocked
        value.reason = reason
        try record(value, kind: "loop.\(state.rawValue)", message: reason)
        return false
    }

    func finishLoopClock(_ id: String) {
        guard var value = try? run(id), let since = value.loopExecution?.activeSince else { return }
        value.loopExecution?.elapsedSeconds += max(0, Date().timeIntervalSince(since))
        value.loopExecution?.activeSince = nil
        if value.loopExecution?.state == .running || value.loopExecution?.state == .evaluating {
            let state: LoopState?
            switch value.state {
            case .paused, .recovering: state = .paused
            case .waitingUser: state = .awaitingUser
            case .cancelled: state = .cancelled
            case .blocked: state = value.reportedTokens >= value.budget ? .limitReached : .failed
            case .failed: state = .failed
            default: state = nil
            }
            if let state {
                value.loopExecution?.state = state
                value.loopExecution?.reason = value.reason
                let reason = value.reason
                updateUnfinishedIteration(&value, state: state, reason: reason)
            }
        }
        try? record(value, kind: "loop.checkpoint", message: "Estado e tempo ativo do ciclo preservados.")
    }

    func suspendLoop(_ value: inout Run, state: LoopState, reason: String) {
        guard let execution = value.loopExecution, execution.state != .passed else { return }
        if let since = execution.activeSince {
            value.loopExecution?.elapsedSeconds += max(0, Date().timeIntervalSince(since))
        }
        value.loopExecution?.activeSince = nil
        value.loopExecution?.state = state
        value.loopExecution?.reason = reason
        updateUnfinishedIteration(&value, state: state, reason: reason)
    }

    private func updateUnfinishedIteration(_ value: inout Run, state: LoopState, reason: String) {
        guard let execution = value.loopExecution else { return }
        if let index = execution.iterations.firstIndex(where: { $0.id == execution.currentIterationID }),
            execution.iterations[index].finishedAt == nil
        {
            value.loopExecution?.iterations[index].state = state
            value.loopExecution?.iterations[index].decisionReason = reason
        }
    }
}
