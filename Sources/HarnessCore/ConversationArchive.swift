import Foundation
import HarnessDomain

extension RunCoordinator {
    func setConversationArchived(_ id: String, archived: Bool) throws {
        var conversation: Conversation
        if let stored = conversations[id] {
            conversation = stored
        } else if id.hasPrefix("run-"), let run = runs.first(where: { "run-" + $0.id == id }),
            !conversations.values.contains(where: { $0.turns.contains(where: { $0.runID == run.id }) })
        {
            conversation = legacyConversation(run)
        } else {
            throw HarnessError("Conversa não encontrada.")
        }
        if archived {
            let runIDs = Set(conversation.turns.compactMap(\.runID))
            guard !preparingConversations.contains(id), conversationJobs[id] == nil,
                !conversation.turns.contains(where: { $0.status == .pending }),
                (conversation.queuedTurns ?? []).isEmpty,
                !runs.contains(where: {
                    runIDs.contains($0.id)
                        && ($0.state.active || $0.state == .queued || jobs[$0.id] != nil
                            || exclusiveOperations.contains($0.id) || extensionBusy.contains($0.id))
                })
            else {
                throw HarnessError("Pause ou aguarde a execução antes de arquivar a conversa.")
            }
            if conversation.archivedAt == nil { conversation.archivedAt = Date() }
        } else {
            conversation.archivedAt = nil
        }
        conversation.updatedAt = Date()
        try store.save(conversation, id: id, table: "conversations")
        conversations[id] = conversation
    }
}
