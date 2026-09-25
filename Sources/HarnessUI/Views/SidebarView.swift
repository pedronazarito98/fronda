import HarnessDomain
import SwiftUI

struct SidebarView: View {
    var store: AppStore
    @Binding var selection: String
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up.fill").font(.system(size: 22)).foregroundStyle(
                    HarnessTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Harness").font(.system(size: 18, weight: .semibold))
                    Text("SEU WORKSPACE DE AGENTES").font(.system(size: 7, weight: .medium)).tracking(1.1)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(.horizontal, 19).padding(.vertical, 25)
            List(selection: $selection) {
                Section("Workspace") {
                    Label("Caixa de entrada", systemImage: "square.grid.2x2").tag("center")
                    Label("Tarefas", systemImage: "play.rectangle").badge(store.activeRuns.count).tag("runs")
                    Label("Decisões", systemImage: "checkmark.bubble").badge(store.pendingDecisions).tag("decisions")
                }
                Section("Biblioteca") {
                    Label("Diário", systemImage: "book.closed").tag("diary")
                    Label("Projetos", systemImage: "folder").tag("projects")
                    Label("Fluxos", systemImage: "books.vertical").tag("runbooks")
                }
                if !store.snapshot.projects.isEmpty {
                    Section("Projetos") {
                        ForEach(store.snapshot.projects) { project in
                            Label(project.name, systemImage: "folder").tag("project:" + project.id)
                        }
                    }
                }
                if !store.snapshot.runs.isEmpty {
                    Section("Recentes") {
                        ForEach(store.snapshot.runs.filter { $0.state != .archived }.prefix(6)) { run in
                            Label {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(run.title).lineLimit(1)
                                    Text(run.stageLabel).font(.caption2).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: run.state.active ? "circle.dotted" : "circle")
                            }
                            .tag("run:" + run.id)
                        }
                    }
                }
            }.listStyle(.sidebar)
            Spacer(minLength: 0)
            Divider().padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 13) {
                SettingsLink { Label("Ajustes", systemImage: "gearshape").font(.system(size: 12)) }.buttonStyle(.plain)
                HStack(spacing: 6) {
                    Circle().fill(store.connected ? .green : .orange).frame(width: 6, height: 6)
                    Text(store.connected ? "Coordenador local conectado" : "Conectando…").font(.system(size: 10))
                        .foregroundStyle(.secondary).accessibilityIdentifier("coordinator.status")
                }
                Text("LOCAL-FIRST  ·  SEM TELEMETRIA").font(.system(size: 8, design: .monospaced)).tracking(0.8)
                    .foregroundStyle(.tertiary)
            }.padding(20)
        }
    }
}
