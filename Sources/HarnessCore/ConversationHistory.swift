import Foundation
import HarnessDomain
import HarnessInfrastructure

extension RunCoordinator {
    func conversationHistory() -> [Conversation] {
        let byID = Dictionary(uniqueKeysWithValues: runs.map { ($0.id, $0) })
        let linked = Set(conversations.values.flatMap { $0.turns.compactMap(\.runID) })
        var history = conversations.values.map { value in
            var projected = value
            for index in projected.turns.indices {
                if projected.turns[index].status == .pending {
                    if let partial = partialReplies[value.id], partial.turnID == projected.turns[index].id {
                        projected.turns[index].reply = partial.text
                    }
                    continue
                }
                guard projected.turns[index].runSnapshotSequence == nil else { continue }
                guard let runID = projected.turns[index].runID, let run = byID[runID] else { continue }
                projected.turns[index].reply = conversationResult(run)
                projected.updatedAt = max(projected.updatedAt, run.updatedAt)
            }
            return projected
        }
        // A run created by the CLI or an older version becomes a conversation on first follow-up.
        history += runs.filter { !linked.contains($0.id) }.map(legacyConversation)
        return history.sorted { $0.updatedAt == $1.updatedAt ? $0.id < $1.id : $0.updatedAt > $1.updatedAt }
    }

    func legacyConversation(_ run: Run) -> Conversation {
        var conversation = Conversation(id: "run-" + run.id, title: run.title)
        var turn = ConversationTurn(
            id: run.id, prompt: run.source.text.isEmpty ? run.title : run.source.text, provider: run.provider,
            execution: run.execution ?? ExecutionConfiguration())
        turn.createdAt = run.createdAt
        turn.status = .completed
        turn.runID = run.id
        turn.reply = conversationResult(run)
        conversation.turns = [turn]
        conversation.updatedAt = run.updatedAt
        return conversation
    }

    func conversationResult(_ run: Run) -> String {
        if !run.report.isEmpty { return run.report }
        if [.failed, .cancelled, .blocked, .partial].contains(run.state), !run.reason.isEmpty { return run.reason }
        if let proposal = run.workflow?.proposal, !proposal.isEmpty { return proposal }
        if let investigation = run.workflow?.investigation, !investigation.isEmpty { return investigation }
        return run.state.terminal ? run.reason : ""
    }

    /// Build the provider input from immutable attachment snapshots and observed project results.
    /// Retain newest complete exchanges first when the configured context budget is reached.
    func conversationPrompt(_ conversation: Conversation, through turnID: String) throws -> String {
        guard let last = conversation.turns.firstIndex(where: { $0.id == turnID }) else {
            throw HarnessError("Mensagem não encontrada.")
        }
        let current = conversation.turns[last]
        let projectIDs = Set(
            conversation.turns[...last].compactMap { turn in
                turn.runID.flatMap { id in runs.first(where: { $0.id == id })?.projectID }
            } + [current.projectID].compactMap { $0 })
        for id in projectIDs {
            let project = try project(id)
            guard project.disabledProviders?.contains(current.provider) != true else {
                throw HarnessError(
                    "O projeto \(project.name) não permite enviar contexto a \(current.provider.rawValue). Escolha um executor permitido."
                )
            }
            guard !project.requireStrongIsolation else {
                throw HarnessError("O projeto \(project.name) exige isolamento forte para enviar seu contexto.")
            }
        }
        let budget = max(1000, preferences.contextBudget) * 4
        var history = [String]()
        var bytes = 0
        for turn in conversation.turns[...last].reversed() {
            let files = try turn.attachments.map { attachment -> JSONValue in
                let content = try String(
                    contentsOf: paths.artifacts.appendingPathComponent(attachment.contentHash), encoding: .utf8)
                return .object(["name": .string(attachment.name), "text": .string(content)])
            }
            var exchange: [String: JSONValue] = [
                "user": .string(turn.prompt), "provider": .string(turn.provider.rawValue),
                "configuration": .string(turn.execution.summary),
            ]
            if !files.isEmpty { exchange["attachments"] = .array(files) }
            if turn.id != turnID {
                exchange["status"] = .string(turn.status.rawValue)
                if turn.runID == nil, !turn.reply.isEmpty { exchange["assistant"] = .string(turn.reply) }
                let execution = try turn.runID.flatMap { id in
                    if let sequence = turn.runSnapshotSequence { return try store.replay(id, sequence: sequence) }
                    return runs.first(where: { $0.id == id })
                }
                if let run = execution {
                    var observed: [String: JSONValue] = [
                        "state": .string(run.state.label), "reason": .string(run.reason),
                        "result": .string(conversationResult(run)),
                        "steps": .array(
                            run.plan.map {
                                .string($0.title + " · " + $0.status.rawValue)
                            }), "files": .array(run.changedFiles.map { .string($0.path) }),
                        "checks": .array(
                            run.validations.map { .string($0.validator.name + " · " + $0.status.rawValue) }),
                    ]
                    if run.contextApproved, !run.diff.isEmpty {
                        observed["diffExcerpt"] = .string(String(run.diff.prefix(min(preferences.contextBudget, 4000))))
                    }
                    if run.source.text != turn.prompt { observed["objective"] = .string(run.source.text) }
                    let guidance = (run.guidance ?? []).filter { $0.conversationTurnID == turn.id }
                    if !guidance.isEmpty {
                        observed["guidance"] = .array(
                            guidance.map { item in
                                var entry: [String: JSONValue] = ["delivery": .string(item.status.rawValue)]
                                if item.status == .delivered {
                                    do { entry["text"] = .string(try guidancePayload(item)) } catch {
                                        entry["text"] = .string(item.text)
                                        entry["attachmentStatus"] = .string(
                                            "Conteúdo salvo indisponível; peça o reenvio se necessário.")
                                        if turn.runSnapshotSequence == nil,
                                            runs.contains(where: { $0.id == run.id && $0.conversationTurnID == turn.id }
                                            )
                                        {
                                            try? recordGuidanceAttachmentError(run.id, guidanceID: item.id)
                                        }
                                    }
                                }
                                return .object(entry)
                            })
                        observed["guidanceNote"] = .string(
                            "Entrega confirmada não comprova cumprimento. Orientações pendentes, incertas ou dispensadas não são instruções ativas."
                        )
                    }
                    exchange["execution"] = .object(observed)
                }
            }
            let encoded = try Coding.string(JSONValue.object(exchange))
            if bytes + encoded.utf8.count + 1 > budget {
                guard turn.id != turnID else {
                    throw HarnessError(
                        "A mensagem e os anexos excedem o orçamento de contexto. Reduza o conteúdo ou ajuste o limite.")
                }
                // A large earlier attachment should not displace the user's question and observed answer.
                let available = budget - bytes - 1
                if available >= 800 {
                    let excerptBytes = min(available / 5, 3000)
                    let result = exchange["execution"]?["result"].string ?? turn.reply
                    let excerpt = try Coding.string(
                        JSONValue.object([
                            "userExcerpt": .string(
                                String(decoding: turn.prompt.utf8.prefix(excerptBytes), as: UTF8.self)),
                            "replyExcerpt": .string(String(decoding: result.utf8.prefix(excerptBytes), as: UTF8.self)),
                            "status": .string(turn.status.rawValue),
                            "attachmentNames": .array(turn.attachments.map { .string($0.name) }),
                            "truncated": .bool(true),
                        ]))
                    if excerpt.utf8.count <= available { history.append(excerpt) }
                }
                break
            }
            history.append(encoded)
            bytes += encoded.utf8.count + 1
        }
        let omitted = last + 1 - history.count
        let notice = omitted > 0 ? "Turnos anteriores omitidos pelo limite de contexto: \(omitted).\n" : ""
        return notice + history.reversed().joined(separator: "\n")
    }
}
