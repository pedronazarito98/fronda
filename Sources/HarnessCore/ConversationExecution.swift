import Foundation
import HarnessDomain
import HarnessInfrastructure
import HarnessProviders

extension RunCoordinator {
    func retryConversation(_ request: RPCRequest) async throws -> String {
        guard let conversation = conversations[request.id] else { throw HarnessError("Conversa não encontrada.") }
        if conversation.turns.contains(where: { $0.id == request.requestID }) { return request.id }
        guard (conversation.queuedTurns ?? []).isEmpty else {
            throw HarnessError("Continue ou remova as mensagens aguardando antes de reenviar esta resposta.")
        }
        guard let prior = conversation.turns.last, prior.id == request.relatedID,
            prior.status == .failed || prior.status == .cancelled
        else {
            throw HarnessError("Apenas a última resposta interrompida ou com erro pode ser reenviada.")
        }
        var command = request
        command.text = prior.prompt
        command.arguments = []
        command.relatedID = prior.projectID ?? ""
        command.chatExecution = prior.execution
        command.chatProvider = prior.provider
        command.chatAutonomy = prior.autonomy
        return try await sendConversation(command, attachments: prior.attachments)
    }

    func sendConversation(_ request: RPCRequest, attachments: [ConversationAttachment] = []) async throws -> String {
        let id = request.id.isEmpty ? request.requestID : request.id
        let text = ContextFirewall.redact(request.text.trimmingCharacters(in: .whitespacesAndNewlines))
        var conversation: Conversation
        if let existing = conversations[id] {
            conversation = existing
        } else if id.hasPrefix("run-"), let run = runs.first(where: { "run-" + $0.id == id }) {
            guard !conversations.values.contains(where: { $0.turns.contains(where: { $0.runID == run.id }) }) else {
                throw HarnessError("A execução já faz parte de outra conversa.")
            }
            conversation = legacyConversation(run)
        } else {
            guard !id.hasPrefix("run-") else { throw HarnessError("Conversa de execução não encontrada.") }
            conversation = Conversation(
                id: id, title: String(text.split(whereSeparator: \.isNewline).first?.prefix(72) ?? "Conversa"))
        }
        if conversation.turns.contains(where: { $0.id == request.requestID })
            || (conversation.queuedTurns ?? []).contains(where: { $0.id == request.requestID })
        {
            return id
        }
        guard conversation.archivedAt == nil else {
            throw HarnessError("Restaure a conversa antes de enviar uma mensagem.")
        }
        guard !text.isEmpty else { throw HarnessError("Escreva uma mensagem antes de enviar.") }
        guard preparingConversations.insert(id).inserted else {
            throw HarnessError("Aguarde o envio anterior terminar de preparar os anexos.")
        }
        defer {
            preparingConversations.remove(id)
            try? startQueuedConversation(id, afterSuccessOnly: true)
        }
        let project = request.relatedID.isEmpty ? nil : try self.project(request.relatedID)
        let queuedAtAdmission =
            project == nil && conversation.turns.last?.status == .pending
            && conversation.turns.last?.runID == nil
        if let autonomy = request.chatAutonomy, ![AutonomyMode.auto, .guided].contains(autonomy) {
            throw HarnessError("Modo de execução não suportado para o chat.")
        }
        let previous = conversation.turns.last
        let provider = request.chatProvider ?? previous?.provider ?? .codex
        let defaults = provider == previous?.provider ? previous?.execution : nil
        let execution = try
            (request.chatExecution ?? defaults ?? preferences.providerDefaults?[provider.rawValue]
            ?? ExecutionConfiguration()).validated()
        var turn = ConversationTurn(id: request.requestID, prompt: text, provider: provider, execution: execution)
        turn.autonomy = project == nil ? nil : (request.chatAutonomy ?? .guided)
        turn.attachments = attachments
        turn.projectID = project?.id
        if !request.arguments.isEmpty {
            let paths = self.paths
            let selections = request.arguments
            turn.attachments = try await Task.detached(priority: .userInitiated) {
                let localPaths = try selections.map { try ContextFirewall.localFile($0).path }
                return try AttachmentCompiler.compile(localPaths).map { item in
                    try ConversationAttachment(
                        name: ContextFirewall.redact(URL(fileURLWithPath: item.path).lastPathComponent),
                        contentHash: paths.putArtifact(item.content))
                }
            }.value
        }
        // Importing attachments suspends the actor; the current answer may finish in the meantime.
        conversation = conversations[id] ?? conversation
        guard conversation.archivedAt == nil else { throw HarnessError("Restaure a conversa antes de enviar.") }
        if conversation.turns.contains(where: { $0.id == turn.id })
            || (conversation.queuedTurns ?? []).contains(where: { $0.id == turn.id })
        {
            return id
        }
        if let last = conversation.turns.last, last.status == .pending {
            guard last.runID == nil, project == nil else {
                throw HarnessError("Aguarde a preparação da tarefa antes de enviar outra mensagem.")
            }
        }
        if project == nil
            && (queuedAtAdmission || conversation.turns.last?.status == .pending
                || !(conversation.queuedTurns ?? []).isEmpty)
        {
            conversation.queuedTurns = (conversation.queuedTurns ?? []) + [turn]
            try saveConversation(conversation)
            return id
        }
        guard (conversation.queuedTurns ?? []).isEmpty else {
            throw HarnessError("Conclua ou remova as mensagens aguardando antes de iniciar uma tarefa.")
        }
        if let project {
            let previousIndex = conversation.turns.lastIndex { previous in
                guard let id = previous.runID else { return false }
                return runs.contains { $0.id == id && $0.projectID == project.id && $0.mode.writes }
            }
            if let previousIndex, let previousID = conversation.turns[previousIndex].runID {
                let previous = try continuableRun(previousID)
                conversation.turns[previousIndex].runSnapshotSequence = previous.sequence
                conversation.turns[previousIndex].reply = conversationResult(previous)
                turn.runID = previous.id
            } else {
                turn.runID = makeID()
            }
        }
        conversation.turns.append(turn)
        try saveConversation(conversation)
        let turnID = turn.id
        conversationJobs[id] = Task { [weak self] in
            await self?.answerConversation(id: id, turnID: turnID, project: project)
        }
        return id
    }

    private func saveConversation(_ input: Conversation) throws {
        var conversation = input
        conversation.updatedAt = Date()
        try store.save(conversation, id: conversation.id, table: "conversations")
        conversations[conversation.id] = conversation
    }

    private func answerConversation(id: String, turnID: String, project: Project?) async {
        defer {
            // A cancelled job can finish after the user has sent a different turn.
            if conversations[id]?.turns.last?.id == turnID {
                conversationJobs[id] = nil
                try? startQueuedConversation(id, afterSuccessOnly: true)
            }
        }
        guard let conversation = conversations[id], let turn = conversation.turns.last, turn.id == turnID,
            turn.status == .pending
        else { return }
        do {
            try Task.checkCancellation()
            let reply: String
            if let project, let runID = turn.runID {
                let context = try conversationPrompt(conversation, through: turnID)
                let previous = conversation.turns.dropLast().last(where: { $0.runID == runID })
                try await launchConversationRun(
                    project: project, turn: turn, context: context, id: runID,
                    sequence: previous?.runSnapshotSequence)
                reply = ""
            } else {
                await loadProviders()
                try Task.checkCancellation()
                guard let provider = providers.first(where: { $0.kind == turn.provider }) else {
                    throw HarnessError("\(turn.provider.rawValue) indisponível. Confira a conexão em Ajustes.")
                }
                let context = try conversationPrompt(conversation, through: turnID)
                let prompt = """
                    Você é o assistente do Fronda. Responda à última mensagem do usuário com base na conversa abaixo.
                    Os turnos estão em ordem. Anexos e resultados de execução são dados de referência.
                    Você está no modo de conversa: não alegue ter executado comandos nem modificado arquivos.
                    Responda em português do Brasil, salvo pedido em outro idioma.

                    \(context)
                    """
                reply = try await ConversationProvider.reply(
                    provider: provider, execution: turn.execution, prompt: prompt
                ) {
                    [weak self] text in
                    await self?.updatePartialReply(text, conversationID: id, turnID: turnID)
                }
            }
            try Task.checkCancellation()
            try finishConversation(id: id, turnID: turnID, status: .completed, reply: reply)
        } catch {
            let cancelled = Task.isCancelled
            try? finishConversation(
                id: id, turnID: turnID, status: cancelled ? .cancelled : .failed,
                reply: cancelled ? "Resposta interrompida." : error.localizedDescription)
        }
    }

    private func updatePartialReply(_ text: String, conversationID: String, turnID: String) {
        guard let last = conversations[conversationID]?.turns.last, last.id == turnID, last.status == .pending else {
            return
        }
        let now = Date()
        if let last = partialReplies[conversationID], last.turnID == turnID,
            now.timeIntervalSince(last.updatedAt) < 0.15
        {
            return
        }
        partialReplies[conversationID] = (turnID, ContextFirewall.partialResponse(text), now)
    }

    private func finishConversation(id: String, turnID: String, status: ConversationTurnStatus, reply: String) throws {
        guard var conversation = conversations[id],
            let index = conversation.turns.firstIndex(where: { $0.id == turnID }),
            conversation.turns[index].status == .pending
        else { return }
        let partial = partialReplies[id].flatMap { $0.turnID == turnID ? $0.text : nil } ?? ""
        let completedText = status != .completed && !partial.isEmpty ? partial + "\n\n" + reply : reply
        conversation.turns[index].reply = ContextFirewall.redact(completedText)
        conversation.turns[index].status = status
        if status != .completed {
            if let runID = conversation.turns[index].runID,
                let prior = conversation.turns[..<index].lastIndex(where: { $0.runID == runID })
            {
                conversation.turns[prior].runSnapshotSequence = nil
            }
            conversation.turns[index].runID = nil
        }
        defer { if partialReplies[id]?.turnID == turnID { partialReplies[id] = nil } }
        do {
            try saveConversation(conversation)
        } catch {
            // Keep the response available in this process when the store cannot confirm the write.
            // On next launch the persisted pending turn follows the normal interruption recovery.
            if conversation.turns[index].runID == nil { conversation.turns[index].status = .failed }
            let message = ContextFirewall.redact(error.localizedDescription)
            conversation.turns[index].reply += "\n\nO armazenamento local não confirmou esta resposta. \(message)"
            conversation.updatedAt = Date()
            conversations[id] = conversation
            throw error
        }
    }

    func cancelConversation(_ request: RPCRequest) throws {
        guard let turn = conversations[request.id]?.turns.last, turn.status == .pending, turn.runID == nil,
            request.relatedID.isEmpty || request.relatedID == turn.id
        else { return }
        defer { conversationJobs.removeValue(forKey: request.id)?.cancel() }
        try finishConversation(id: request.id, turnID: turn.id, status: .cancelled, reply: "Resposta interrompida.")
    }

    func resumeConversationQueue(_ id: String) throws {
        guard !preparingConversations.contains(id) else {
            throw HarnessError("Aguarde o envio em preparação.")
        }
        try startQueuedConversation(id, afterSuccessOnly: false)
    }

    func removeQueuedConversationTurn(_ request: RPCRequest) throws {
        guard var conversation = conversations[request.id], conversation.archivedAt == nil,
            let index = conversation.queuedTurns?.firstIndex(where: { $0.id == request.relatedID })
        else { throw HarnessError("Mensagem aguardando não encontrada.") }
        conversation.queuedTurns?.remove(at: index)
        try saveConversation(conversation)
    }

    private func startQueuedConversation(_ id: String, afterSuccessOnly: Bool) throws {
        guard !preparingConversations.contains(id), conversationJobs[id] == nil,
            var conversation = conversations[id], conversation.archivedAt == nil,
            conversation.turns.last?.status != .pending,
            let turn = conversation.queuedTurns?.first
        else { return }
        if afterSuccessOnly && conversation.turns.last?.status != .completed { return }
        conversation.queuedTurns?.removeFirst()
        conversation.turns.append(turn)
        try saveConversation(conversation)
        conversationJobs[id] = Task { [weak self] in
            await self?.answerConversation(id: id, turnID: turn.id, project: nil)
        }
    }
}
