import HarnessDomain
import SwiftUI

struct ContentView: View {
    @Bindable var store: AppStore
    @SceneStorage("sidebar.route") private var savedRoute = "center"
    @AppStorage(WorkspaceSession.storageKey) private var savedWorkspace = ""
    @AppStorage("fronda.sidebar.expanded") private var sidebarExpanded = false
    @State private var paletteAction: PaletteEntry.Action?
    @State private var restoredNavigation = false
    @State private var windowWidth: CGFloat = 860

    private var navigation: WorkspaceNavigation { store.navigation }
    private var selection: String { navigation.location.route }
    private var selectionBinding: Binding<String> {
        Binding(get: { navigation.location.route }, set: { navigation.visit($0) })
    }
    private var runID: String? { selection.hasPrefix("run:") ? String(selection.dropFirst(4)) : nil }
    private var pageTitle: String {
        WorkspaceTabBar.title(for: selection, store: store)
    }
    var body: some View {
        HStack(spacing: 0) {
            if sidebarExpanded {
                SidebarView(store: store, selection: selectionBinding).frame(width: 230)
            } else {
                WorkspaceRail(store: store, expanded: $sidebarExpanded)
            }
            Divider()
            workspaceContent
                .id(store.workspace.selected.id)
                .environment(\.workspaceShowsSummary, store.workspace.selected.showsSummary)
        }
        .background(FrondaTheme.surface)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            windowWidth = $0
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("Alternar navegação", systemImage: "sidebar.left") { sidebarExpanded.toggle() }
                    .help("Expandir ou recolher navegação")
            }
            WorkspaceToolbar(store: store, navigation: navigation, windowWidth: windowWidth)
        }
        .toolbar(removing: .title)
        .safeAreaInset(edge: .top, spacing: 0) {
            if store.firstTaskJourney.isActive && !store.showComposer
                && (store.firstTaskJourney.runID == nil || store.firstTaskJourney.runID != runID)
            {
                FirstTaskJourneyReminder(store: store)
            }
            if !store.connected && !store.loading {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                    Text("O coordenador local está desconectado.")
                    Spacer()
                    Button("Tentar novamente") { Task { await store.refresh() } }
                }
                .font(.callout).padding(12).background(FrondaTheme.warning.opacity(0.12))
            }
        }
        .tint(FrondaTheme.accent)
        .frame(minWidth: 860, minHeight: 620)
        .navigationTitle("Fronda")
        .navigationSubtitle(pageTitle)
        .focusedSceneValue(\.frondaRunID, runID)
        .focusedSceneValue(\.workspaceNavigation, navigation)
        .focusedSceneValue(\.workspaceSession, store.workspace)
        .environment(\.workspaceNavigation, navigation)
        .onAppear {
            guard !restoredNavigation else { return }
            let requestedRoute = store.route
            if !store.workspace.restore(savedWorkspace) { navigation.restore(savedRoute) }
            if requestedRoute != "center" { navigation.visit(requestedRoute) }
            restoredNavigation = true
        }
        .onChange(of: store.workspace.encoded) { _, value in
            if restoredNavigation { savedWorkspace = value }
        }
        .onChange(of: navigation.location) { _, location in
            savedRoute = location.route
        }
        .onChange(of: store.showComposer || store.showPalette || store.showStopConfirmation) { _, presented in
            for tab in store.workspace.tabs {
                tab.primary.isPresenting = presented
                tab.secondary?.isPresenting = presented
            }
        }
        .onChange(of: store.loading) { _, loading in
            if !loading && store.connected && store.snapshot.preferences.onboardingCompleted != true
                && store.snapshot.projects.isEmpty && store.snapshot.runs.isEmpty && selection == "center"
            {
                store.route = "guide"
            }
        }
        .sheet(isPresented: $store.showComposer) { NewRunView(store: store) }
        .sheet(isPresented: $store.showPalette, onDismiss: completePaletteAction) {
            CommandPaletteView(store: store) { paletteAction = $0 }
        }
        .alert(
            "Não foi possível concluir",
            isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
        ) {
            Button("OK") { store.error = nil }
        } message: {
            Text(store.error ?? "")
        }
        .confirmationDialog("Parar as runs e sair?", isPresented: $store.showStopConfirmation) {
            Button("Parar runs e sair", role: .destructive) {
                Task {
                    for run in store.activeRuns {
                        var request = RPCRequest("run.pause")
                        request.id = run.id
                        _ = try? await store.send(request)
                    }
                    NSApplication.shared.terminate(nil)
                }
            }
        } message: {
            Text("O histórico e as worktrees serão preservados para retomar depois.")
        }
        .overlay(alignment: .bottom) {
            if store.loading {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Conectando ao coordenador local…").font(.caption)
                }.padding(12).background(.regularMaterial, in: Capsule()).padding()
            } else if let notice = store.notice {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(FrondaTheme.success)
                    Text(notice).font(.callout)
                    Button {
                        store.notice = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain).accessibilityLabel("Fechar aviso").help("Fechar aviso")
                }
                .padding(12).background(.regularMaterial, in: Capsule()).padding()
                .task(id: notice) {
                    try? await Task.sleep(for: .seconds(5))
                    if !Task.isCancelled && store.notice == notice { store.notice = nil }
                }
            }
        }
    }

    private var workspaceContent: some View {
        let tab = store.workspace.selected
        return GeometryReader { geometry in
            if let secondary = tab.secondary {
                if geometry.size.width >= 840 {
                    HSplitView {
                        WorkspacePane(store: store, navigation: tab.primary)
                            .id(tab.primary.id)
                            .frame(minWidth: 420, maxWidth: .infinity)
                            .background(
                                WorkspaceSplitPosition(
                                    fraction: Binding(get: { tab.splitFraction }, set: { tab.splitFraction = $0 })))
                        WorkspacePane(store: store, navigation: secondary, isSecondary: true)
                            .id(secondary.id)
                            .frame(minWidth: 360, maxWidth: .infinity)
                    }
                    .overlay {
                        WorkspaceSplitHandle(
                            fraction: Binding(get: { tab.splitFraction }, set: { tab.splitFraction = $0 }),
                            width: geometry.size.width, coordinateSpace: tab.id.uuidString,
                            swap: store.workspace.swapPanes
                        )
                        .position(x: geometry.size.width * tab.splitFraction, y: geometry.size.height / 2)
                    }
                    .coordinateSpace(name: tab.id.uuidString)
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Button("Quadro principal", systemImage: "rectangle.leadinghalf.inset.filled") {
                                tab.secondaryFocused = false
                            }.help("Mostrar o painel esquerdo")
                            Button("Painel ao lado", systemImage: "rectangle.trailinghalf.inset.filled") {
                                tab.secondaryFocused = true
                            }.help("Mostrar o painel direito")
                            Spacer()
                            Button("Trocar painéis", systemImage: "arrow.left.arrow.right") {
                                store.workspace.swapPanes()
                            }.labelStyle(.iconOnly).help("Trocar os painéis esquerdo e direito")
                            Button("Fechar painel", systemImage: "xmark") { store.workspace.closeSide() }
                                .labelStyle(.iconOnly).help("Fechar o painel direito sem interromper a execução")
                        }.controlSize(.small).padding(10)
                        WorkspacePane(store: store, navigation: tab.navigation, isSecondary: tab.secondaryFocused)
                            .id(tab.navigation.id)
                    }
                }
            } else {
                WorkspacePane(store: store, navigation: tab.primary)
            }
        }
    }

    private func completePaletteAction() {
        guard let action = paletteAction else { return }
        paletteAction = nil
        switch action {
        case .navigate(let route): store.route = route
        case .guide(let topic):
            store.guideTopic = topic
            store.route = WorkspaceDestination.guide.rawValue
        case .compose(let bookID):
            store.composerRunbookID = bookID ?? ""
            store.showComposer = true
        case .addProject: store.addProject()
        case .toggleQueue: store.perform("queue.toggle")
        }
    }
}
