import Foundation
import HarnessDomain
import HarnessInfrastructure

extension RunCoordinator {
    func launchConversationRun(
        project: Project, turn: ConversationTurn, context: String, id: String, sequence: Int?
    ) async throws {
        let contextHash = try paths.putArtifact(context)
        if let sequence {
            try await continueConversationRun(id: id, turn: turn, contextHash: contextHash, sequence: sequence)
            return
        }
        guard let book = runbooks.first(where: { $0.id == "builtin-0" }) else {
            throw HarnessError("O fluxo de implementação do projeto está indisponível.")
        }
        var run = Run()
        run.projectID = project.id
        run.title = String(turn.prompt.prefix(160))
        run.source.text = turn.prompt
        run.conversationContextHash = contextHash
        run.conversationTurnID = turn.id
        run.provider = turn.provider
        run.execution = turn.execution
        run.runbook = book
        run.mode = turn.autonomy ?? book.mode
        run.chatLoopAutoEligible = book.loopPolicy == nil
        configureConversationLoop(&run, project: project)
        run.scope = project.allowedPaths
        run.lockedPaths = project.lockedPaths
        run.budget = preferences.tokenBudget
        var command = RPCRequest("run.create")
        command.run = run
        _ = try await createRun(command, reservedID: id)
    }

    /// The chat may use the existing bounded cycle only when its checks are already authorized.
    /// A policy explicitly present in the selected runbook is preserved as configured.
    @discardableResult
    func configureConversationLoop(_ run: inout Run, project: Project) -> Bool {
        guard run.chatLoopAutoEligible == true, run.runbook.loopPolicy == nil, run.mode.writes else { return false }
        let required = run.runbook.validators(for: project).filter(\.required)
        guard !required.isEmpty,
            required.allSatisfy({ $0.approved && (try? PolicyEngine.approveValidator($0, run: run)) != nil })
        else { return false }
        let steps = run.plan.isEmpty ? run.runbook.steps : run.plan
        let implementations = steps.filter { $0.kind == "implementation" }
        let validations = steps.filter { $0.kind == "validation" }
        guard implementations.count == 1, validations.count == 1,
            let implementation = implementations.first, let validation = validations.first
        else { return false }
        let policy = LoopPolicy(implementationStepID: implementation.id, validationStepID: validation.id)
        guard (try? policy.validate(steps: steps, mode: run.mode)) != nil else { return false }
        run.runbook.loopPolicy = policy
        return true
    }

    func continuableRun(_ id: String) throws -> Run {
        let run = try self.run(id)
        guard !run.state.active, run.state != .queued, !run.pauseNeedsConfirmation, jobs[id] == nil,
            !exclusiveOperations.contains(id), !extensionBusy.contains(id)
        else {
            throw HarnessError(
                "A execução ainda está em andamento. Aguarde ou pause para pedir outra alteração. Perguntas continuam disponíveis no chat."
            )
        }
        guard run.workflow?.delivery.closedAt == nil, run.workflow?.delivery.mergedAt == nil else {
            throw HarnessError(
                "Esta entrega foi encerrada. Comece uma nova conversa para trabalhar a partir da base atual do projeto."
            )
        }
        guard !run.approvals.contains(where: { ["SENDING", "APPROVED", "UNKNOWN"].contains($0.state) }),
            run.extensionInvocations?.contains(where: { ["RUNNING", "UNKNOWN"].contains($0.state) }) != true
        else {
            throw HarnessError("Reconcilie a ação externa pendente da execução antes de continuar nesta worktree.")
        }
        guard
            run.guidance?.contains(where: {
                $0.conversationTurnID == run.conversationTurnID
                    && ([.queued, .uncertain].contains($0.status)
                        || ($0.status == .delivered && $0.attachmentError != nil
                            && $0.continueWithoutAttachments != true))
            }) != true
        else {
            throw HarnessError("Resolva as orientações pendentes desta tarefa antes de continuar na mesma worktree.")
        }
        for item in run.guidance ?? []
        where item.conversationTurnID == run.conversationTurnID && item.status == .delivered
            && item.continueWithoutAttachments != true && !(item.attachments ?? []).isEmpty
        {
            do { _ = try guidancePayload(item) } catch {
                try recordGuidanceAttachmentError(id, guidanceID: item.id)
                throw HarnessError(
                    "Os anexos de uma orientação anterior estão indisponíveis. Confira a mensagem antes de continuar.")
            }
        }
        return run
    }

    /// A new request replaces the active plan, while its predecessor remains replayable at its exact sequence.
    private func continueConversationRun(id: String, turn: ConversationTurn, contextHash: String, sequence: Int)
        async throws
    {
        let previous = try continuableRun(id)
        if !previous.workspace.isEmpty {
            guard previous.workspace == paths.worktrees.appendingPathComponent(id).path,
                FileManager.default.fileExists(atPath: previous.workspace)
            else {
                throw HarnessError("A worktree anterior não está disponível. Confira o projeto para continuar.")
            }
            let workspace = try await GitWorkspace.acquire(
                project: project(previous.projectID), run: previous, paths: paths)
            guard workspace.0 == previous.workspace else { throw HarnessError("A worktree da execução mudou.") }
        }
        try Task.checkCancellation()
        var value = try continuableRun(id)
        guard value.sequence == sequence else {
            throw HarnessError(
                "A execução mudou durante o envio. Confira o estado atualizado e envie a mensagem novamente.")
        }
        value.conversationTurnID = turn.id
        value.pauseStatus = nil
        value.budgetAtLastBlock = nil
        value.conversationContextHash = contextHash
        value.title = String(turn.prompt.prefix(160))
        value.source.text = turn.prompt
        value.source.attachments = []
        value.provider = turn.provider
        value.execution = turn.execution
        value.mode = turn.autonomy ?? value.mode
        value.planRevision += 1
        value.contextApproved = false
        value.planApproved = false
        value.pack = nil
        value.report = ""
        value.reviewRevision = ""
        value.humanReviewRevision = ""
        value.findings = []
        value.extensionBindings = nil
        value.evidenceArtifacts = nil
        value.workflow?.investigation = ""
        value.workflow?.proposal = ""
        value.workflow?.observations = []
        for i in value.plan.indices {
            value.plan[i].status = .notRun
            value.plan[i].model = nil
            value.plan[i].effort = nil
            value.plan[i].provider = nil
        }
        if let loop = value.loopExecution {
            value.loopHistory = (value.loopHistory ?? []) + [loop]
            value.loopExecution = nil
        }
        value.criteria = [Criterion(text: "A alteração solicitada neste turno foi revisada e validada na worktree.")]
        for i in value.validations.indices { value.validations[i].status = .stale }
        for i in value.approvals.indices where value.approvals[i].state == "PREPARED" {
            value.approvals[i].state = "STALE"
        }
        value.state = .queued
        value.reason = "Preparando o novo pedido na mesma worktree."
        try record(value, kind: "conversation.work_continued", message: value.reason)
        schedule()
    }
}
