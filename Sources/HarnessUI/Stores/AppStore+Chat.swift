import Foundation
import HarnessDomain

extension AppStore {
    var chats: [Conversation] { (snapshot.conversations ?? []).filter { $0.archivedAt == nil } }
    var selectedChat: Conversation? { chats.first { $0.id == chatID } }

    func newChat() { selectChat(makeID()) }

    func selectChat(_ id: String) {
        hasSelectedChat = true
        pendingRunID = nil
        if chatID != id {
            graph = nil
            runDetail = nil
            chatID = id
        }
    }

    func openChat(forRun id: String) {
        pendingRunID = id
        resolvePendingChat()
    }

    func resolvePendingChat() {
        guard let id = pendingRunID,
            let chat = chats.first(where: { $0.turns.contains(where: { $0.runID == id }) })
        else { return }
        selectChat(chat.id)
        graph = ChatRunReference(runID: id, sequence: nil)
    }

    func submitChat(
        conversationID: String, prompt: String, attachments: [String], provider: ProviderKind,
        execution: ExecutionConfiguration,
        projectID: String?, autonomy: AutonomyMode, requestID: String
    ) async throws {
        var request = RPCRequest("conversation.send")
        request.id = conversationID
        request.requestID = requestID
        request.text = prompt
        request.arguments = attachments
        request.chatProvider = provider
        request.chatExecution = execution
        request.chatAutonomy = projectID == nil ? nil : autonomy
        request.relatedID = projectID ?? ""
        _ = try await send(request)
        await refresh(silent: true)
    }

    func retryChat(conversationID: String, turnID: String, requestID: String) async throws {
        var request = RPCRequest("conversation.retry")
        request.id = conversationID
        request.relatedID = turnID
        request.requestID = requestID
        _ = try await send(request)
        await refresh(silent: true)
    }

    func guideRun(id: String, text: String, attachments: [String], requestID: String) async throws {
        var request = RPCRequest("run.guide")
        request.id = id
        request.text = text
        request.arguments = attachments
        request.requestID = requestID
        _ = try await send(request)
        await refresh(silent: true)
    }

    func cancelReply() {
        guard let turn = selectedChat?.turns.last, turn.status == .pending, turn.runID == nil else { return }
        var request = RPCRequest("conversation.cancel")
        request.id = chatID
        request.relatedID = turn.id
        Task {
            do {
                _ = try await send(request)
                await refresh(silent: true)
            } catch { self.error = error.localizedDescription }
        }
    }
}
