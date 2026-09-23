import HarnessDomain
import SwiftUI

struct ContentView: View {
    @Bindable var store: AppStore
    @SceneStorage("sidebar.route") private var selection = "center"
    @State private var inspector = false
    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, selection: $selection)
                .navigationSplitViewColumnWidth(min: 205, ideal: 228, max: 310)
        } detail: {
            Group {
                if selection.hasPrefix("run:") {
                    RunWorkspace(store: store, runID: String(selection.dropFirst(4))).id(selection)
                } else if selection.hasPrefix("project:") {
                    ProjectDetailView(store: store, projectID: String(selection.dropFirst(8)))
                } else {
                    switch selection {
                    case "runs": RunsView(store: store)
                    case "projects": ProjectsView(store: store)
                    case "runbooks": RunbooksView(store: store)
                    case "decisions": DecisionsView(store: store)
                    default: CommandCenterView(store: store)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Text("HARNESS").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2)
                        .foregroundStyle(.secondary)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        store.showPalette = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }.help("Buscar e executar comando (⌘K)")
                    Button {
                        store.showComposer = true
                    } label: {
                        Label("Nova run", systemImage: "plus")
                    }.help("Nova run (⌘N)").accessibilityIdentifier("toolbar.new-run")
                }
            }
        }
        .tint(HarnessTheme.accent)
        .frame(minWidth: 1080, minHeight: 700)
        .navigationTitle("")
        .onChange(of: store.route) { _, route in selection = route }
        .sheet(isPresented: $store.showComposer) { NewRunView(store: store) }
        .sheet(isPresented: $store.showPalette) { CommandPaletteView(store: store) }
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
            }
        }
    }
}
