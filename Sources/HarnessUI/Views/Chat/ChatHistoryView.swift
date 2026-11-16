import HarnessDomain
import SwiftUI

struct ChatHistoryView: View {
    let store: AppStore
    @Environment(\.openSettings) private var openSettings
    @State private var removingChat: Conversation?
    @State private var showingTrash = false
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.horizontal, 18).padding(.top, 17).padding(.bottom, 18)

            Button {
                store.newChat()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 20)
                    Text("Nova conversa").font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 0)
                    Text("⌘N").font(.system(size: 10, weight: .medium))
                        .foregroundStyle(FrondaTheme.textMuted)
                }
                .foregroundStyle(FrondaTheme.accent)
                .padding(.horizontal, 11).padding(.vertical, 10)
                .background(FrondaTheme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10).stroke(FrondaTheme.border.opacity(0.8), lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .help("Iniciar uma conversa (⌘N)")
            .accessibilityIdentifier("chat.new")
            .padding(.horizontal, 13).padding(.bottom, 10)

            searchField
                .padding(.horizontal, 13).padding(.bottom, 12)

            List(selection: Binding<String?>(get: { store.chatID }, set: { if let id = $0 { store.selectChat(id) } })) {
                if !visibleDraftIDs.isEmpty {
                    Section("Rascunhos") {
                        ForEach(visibleDraftIDs, id: \.self) { id in
                            let prompt = store.chatDrafts[id]?.prompt ?? ""
                            conversationRow(prompt.isEmpty ? "Mensagem com anexo" : prompt, isDraft: true)
                                .tag(id)
                        }
                    }
                }
                ForEach(visibleGroups) { group in
                    Section(group.name) {
                        ForEach(group.chats) { chat in
                            savedConversationRow(chat)
                        }
                    }
                }
                if !visibleArchivedChats.isEmpty {
                    DisclosureGroup(
                        "Lixeira",
                        isExpanded: Binding(
                            get: { showingTrash || !searchQuery.isEmpty },
                            set: { showingTrash = $0 }
                        )
                    ) {
                        ForEach(visibleArchivedChats) { chat in
                            HStack {
                                Text(chat.title).font(.callout).lineLimit(1)
                                Spacer(minLength: 4)
                                Button("Restaurar") { store.restoreChat(chat.id) }
                                    .buttonStyle(.borderless).font(.caption)
                            }
                        }
                    }
                }
                if !searchQuery.isEmpty && visibleDraftIDs.isEmpty && visibleGroups.isEmpty
                    && visibleArchivedChats.isEmpty
                {
                    Text("Nenhuma conversa encontrada")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .tint(FrondaTheme.accent)

            Rectangle().fill(FrondaTheme.border.opacity(0.65)).frame(height: 1)
                .padding(.horizontal, 14)
            Button {
                openSettings()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape").font(.system(size: 13))
                        .frame(width: 20)
                    Text("Ajustes").font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(FrondaTheme.textMuted)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).padding(.horizontal, 17).padding(.vertical, 16)
        }
        .background(FrondaTheme.sidebar.ignoresSafeArea())
        .navigationTitle("Fronda")
        .confirmationDialog(
            "Mover esta conversa para a lixeira?",
            isPresented: Binding(get: { removingChat != nil }, set: { if !$0 { removingChat = nil } }),
            presenting: removingChat
        ) { chat in
            Button("Mover para a lixeira", role: .destructive) {
                store.archiveChat(chat.id)
                removingChat = nil
            }
        } message: { _ in
            Text("Você poderá restaurar a conversa pela barra lateral.")
        }
    }

    private var brand: some View {
        HStack {
            Text("fronda").font(.system(size: 25, weight: .semibold, design: .serif))
                .italic().tracking(-0.7)
            Spacer()
        }
        .foregroundStyle(FrondaTheme.accent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fronda")
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FrondaTheme.textMuted)
                .accessibilityHidden(true)
            TextField("Buscar conversas", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .accessibilityLabel("Buscar conversas")
                .accessibilityIdentifier("chat.history.search")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(FrondaTheme.textMuted)
                }
                .buttonStyle(.plain)
                .help("Limpar busca")
                .accessibilityLabel("Limpar busca")
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .background(FrondaTheme.surface.opacity(0.36), in: RoundedRectangle(cornerRadius: 9))
    }

    private func savedConversationRow(_ chat: Conversation) -> some View {
        HStack(spacing: 4) {
            conversationRow(chat.title)
            if store.chatID == chat.id {
                Menu {
                    Button("Mover para a lixeira", role: .destructive) { removingChat = chat }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 22, height: 24)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden)
                .help("Opções da conversa")
                .accessibilityLabel("Opções de " + chat.title)
            }
        }
        .tag(chat.id)
        .accessibilityIdentifier("chat.history." + chat.id)
        .contextMenu {
            Button("Mover para a lixeira", role: .destructive) { removingChat = chat }
        }
    }

    private func conversationRow(_ title: String, isDraft: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isDraft ? "pencil" : "bubble.left")
                .font(.system(size: 12))
                .foregroundStyle(FrondaTheme.accent)
                .frame(width: 16)
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(title).font(.system(size: 12.5)).lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private struct HistoryGroup: Identifiable {
        let id: String
        let name: String
        var chats: [Conversation]
    }

    private var draftIDs: [String] {
        let saved = Set(store.chats.map(\.id))
        return store.chatDrafts.keys.filter { id in
            guard !saved.contains(id), let draft = store.chatDrafts[id] else { return false }
            return !draft.prompt.isEmpty || !draft.attachments.isEmpty
        }.sorted()
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var visibleDraftIDs: [String] {
        guard !searchQuery.isEmpty else { return draftIDs }
        return draftIDs.filter { id in
            let prompt = store.chatDrafts[id]?.prompt ?? ""
            return (prompt.isEmpty ? "Mensagem com anexo" : prompt).localizedStandardContains(searchQuery)
        }
    }

    private var visibleGroups: [HistoryGroup] {
        guard !searchQuery.isEmpty else { return groups }
        return groups.compactMap { group in
            if group.name.localizedStandardContains(searchQuery) { return group }
            let matches = group.chats.filter { $0.title.localizedStandardContains(searchQuery) }
            return matches.isEmpty ? nil : HistoryGroup(id: group.id, name: group.name, chats: matches)
        }
    }

    private var visibleArchivedChats: [Conversation] {
        guard !searchQuery.isEmpty else { return store.archivedChats }
        return store.archivedChats.filter { $0.title.localizedStandardContains(searchQuery) }
    }

    private var groups: [HistoryGroup] {
        let projects = Dictionary(uniqueKeysWithValues: store.snapshot.projects.map { ($0.id, $0.name) })
        let runs = Dictionary(uniqueKeysWithValues: store.snapshot.runs.map { ($0.id, $0.projectID) })
        var groups: [HistoryGroup] = []
        for chat in store.chats {
            let id = chat.turns.reversed().compactMap { $0.runID.flatMap { runs[$0] } }.first ?? ""
            if let index = groups.firstIndex(where: { $0.id == id }) {
                groups[index].chats.append(chat)
            } else {
                groups.append(HistoryGroup(id: id, name: projects[id] ?? "Conversas", chats: [chat]))
            }
        }
        return groups
    }
}
