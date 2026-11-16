import HarnessDomain

extension AppStore {
    var archivedChats: [Conversation] {
        (snapshot.conversations ?? []).filter { $0.archivedAt != nil }
    }

    func archiveChat(_ id: String) {
        Task {
            do {
                var request = RPCRequest("conversation.archive")
                request.id = id
                _ = try await send(request)
                if chatID == id { newChat() }
                await refresh(silent: true)
            } catch { self.error = error.localizedDescription }
        }
    }

    func restoreChat(_ id: String) {
        Task {
            do {
                var request = RPCRequest("conversation.restore")
                request.id = id
                _ = try await send(request)
                await refresh(silent: true)
                selectChat(id)
            } catch { self.error = error.localizedDescription }
        }
    }
}
