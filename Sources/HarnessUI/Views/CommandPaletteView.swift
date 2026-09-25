import HarnessDomain
import SwiftUI

struct CommandPaletteView: View {
    var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var focused: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                Image(systemName: "magnifyingglass").foregroundStyle(HarnessTheme.accent)
                TextField("Buscar projeto, run ou comando…", text: $query).textFieldStyle(.plain).font(.title3).focused(
                    $focused
                ).accessibilityIdentifier("palette.search")
                Text("ESC").font(.caption.monospaced()).foregroundStyle(.tertiary)
            }.padding(24)
            Divider()
            List {
                Section("Ações") {
                    row("Nova run", "plus") {
                        dismiss()
                        store.showComposer = true
                    }
                    row("Adicionar projeto", "folder.badge.plus") {
                        dismiss()
                        store.addProject()
                    }
                    row("Command Center", "square.grid.2x2") { navigate("center") }
                    row("Decisões pendentes", "checkmark.bubble") { navigate("decisions") }
                    row(store.snapshot.preferences.queuePaused ? "Retomar fila" : "Pausar fila", "pause") {
                        store.perform("queue.toggle")
                        dismiss()
                    }
                }
                Section("Projetos") {
                    ForEach(
                        store.snapshot.projects.filter {
                            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
                        }
                    ) { project in row(project.name, "folder") { navigate("project:" + project.id) } }
                }
                Section("Runs") {
                    ForEach(
                        store.snapshot.runs.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
                            .prefix(12)
                    ) { run in row(run.title, "play.rectangle") { navigate("run:" + run.id) } }
                }
                Section("Runbooks") {
                    ForEach(
                        store.snapshot.runbooks.filter {
                            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
                        }
                    ) { book in row(book.name, book.symbol) { navigate("runbooks") } }
                }
            }.listStyle(.inset)
        }.frame(width: 660, height: 500).onAppear { focused = true }.onExitCommand { dismiss() }
    }
    private func row(_ name: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(name, systemImage: symbol).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
        }.buttonStyle(.plain)
    }
    private func navigate(_ route: String) {
        store.route = route
        dismiss()
    }
}

struct MenuBarView: View {
    var store: AppStore
    var island: SessionIslandController
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Harness", systemImage: "square.stack.3d.up.fill").font(.headline)
                Spacer()
                Text("\(store.activeRuns.count) ativas").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            if store.snapshot.runs.filter({ !$0.state.terminal }).isEmpty {
                Text("Nenhuma execução em andamento.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(store.snapshot.runs.filter { !$0.state.terminal }.prefix(5)) { run in
                Button {
                    open(run.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(run.title.prefix(28))).font(.callout)
                        Text(run.state.label).font(.caption2).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
            }
            Divider()
            Button("Abrir Harness") {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            Button("Central de sessões (⌥⌘I)") { island.toggle() }
            Button(store.snapshot.preferences.queuePaused ? "Retomar fila" : "Pausar fila") {
                store.perform("queue.toggle")
            }
            Button("Nova run…") {
                openWindow(id: "main")
                store.showComposer = true
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }.padding(20).frame(width: 310)
    }
    private func open(_ id: String) {
        openWindow(id: "main")
        store.route = "run:" + id
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
