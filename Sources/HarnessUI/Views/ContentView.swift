import HarnessDomain
import SwiftUI

struct ContentView: View {
    @Bindable var store: AppStore
    @SceneStorage("fronda.chat.selected") private var savedChatID = ""
    @State private var visibility = NavigationSplitViewVisibility.all
    @State private var restored = false

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {
            ChatHistoryView(store: store)
                .navigationSplitViewColumnWidth(min: 180, ideal: 235, max: 320)
        } detail: {
            GeometryReader { geometry in
                let wide = geometry.size.width >= 850
                let showsTrail = wide && store.graph == nil && (store.runDetail == nil || isAction)
                let layout =
                    wide
                    ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
                layout {
                    conversation(showsTaskRail: showsTrail)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(1)
                    if hasPanel || showsTrail {
                        Divider()
                        panel
                            .frame(
                                width: wide ? panelWidth(geometry.size.width, showsTrail: showsTrail) : nil,
                                height: wide ? nil : min(max(geometry.size.height * 0.42, 200), 420)
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(store.selectedChat?.title ?? "Nova conversa")
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(item: actionDetail) { detail in
            ChatRunDetailView(store: store, detail: detail)
        }
        .onChange(of: store.connected, initial: true) {
            if store.connected && !restored {
                restored = true
                if store.pendingRunID == nil && !store.hasSelectedChat,
                    store.chats.contains(where: { $0.id == savedChatID })
                {
                    store.selectChat(savedChatID)
                }
                savedChatID = store.chatID
            }
        }
        .onChange(of: store.chatID) { if restored { savedChatID = store.chatID } }
        .alert(
            "Não foi possível concluir",
            isPresented: Binding(
                get: { store.error != nil }, set: { if !$0 { store.error = nil } })
        ) {
            Button("OK") { store.error = nil }
        } message: {
            Text(store.error ?? "")
        }
        .frame(minWidth: 760, minHeight: 520)
        .tint(FrondaTheme.accent)
    }

    private var hasPanel: Bool {
        store.graph != nil || (store.runDetail != nil && !isAction)
    }

    private func panelWidth(_ available: CGFloat, showsTrail: Bool) -> CGFloat {
        if showsTrail { return min(max(available * 0.31, 285), 370) }
        return min(max(available * 0.48, 400), 680)
    }

    private var isAction: Bool {
        if case .action = store.runDetail?.page { return true }
        return false
    }

    private var actionDetail: Binding<ChatRunDetail?> {
        Binding(
            get: { isAction ? store.runDetail : nil },
            set: { if $0 == nil && isAction { store.runDetail = nil } }
        )
    }

    private func conversation(showsTaskRail: Bool) -> some View {
        VStack(spacing: 0) {
            if !store.connected {
                HStack {
                    if store.loading {
                        ProgressView().controlSize(.small)
                        Text("Conectando ao Fronda…")
                    } else {
                        Label("Coordenador desconectado", systemImage: "wifi.slash")
                        Spacer()
                        Button("Reconectar") { Task { await store.refresh() } }
                    }
                }.font(.caption).padding(10)
                Divider()
            }
            ChatConversationView(store: store, conversation: store.selectedChat, showsTaskRail: showsTaskRail) {
                id, sequence in
                store.runDetail = nil
                store.graph = ChatRunReference(runID: id, sequence: sequence)
            }.id(store.chatID)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var panel: some View {
        if let detail = store.runDetail, !isAction {
            ChatRunDetailView(store: store, detail: detail).id(detail.runID)
        } else if let graph = store.graph, let run = store.snapshot.runs.first(where: { $0.id == graph.runID }) {
            ChatRunRevision(store: store, current: run, sequence: graph.sequence) { displayed in
                ChatGraphInspector(store: store, run: displayed, snapshotSequence: graph.sequence)
            }.id(graph)
        } else {
            ChatTaskRail(store: store)
        }
    }

}
