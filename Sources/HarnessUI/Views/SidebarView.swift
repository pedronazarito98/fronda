import HarnessDomain
import SwiftUI

struct SidebarView: View {
    var store: AppStore
    @Binding var selection: String
    @Environment(\.openWindow) private var openWindow

    private var recentRuns: [Run] {
        Array(store.snapshot.runs.filter { $0.state != .archived }.sorted { $0.updatedAt > $1.updatedAt }.prefix(5))
    }

    var body: some View {
        VStack(spacing: 0) {
            brand
            Button {
                store.showPalette = true
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                    Text("Buscar no workspace")
                    Spacer(minLength: 0)
                    Text("⌘K").font(.system(size: 10, design: .monospaced))
                }
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.horizontal, 11).padding(.vertical, 10)
                .background(FrondaTheme.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain).help("Buscar tarefas, projetos e comandos (⌘K)")
            .disabled(store.showComposer || store.showPalette)
            .padding(.horizontal, 16).padding(.bottom, 10)

            List(selection: $selection) {
                Section("Workspace") {
                    ForEach(WorkspaceDestination.workspace) { destination in
                        navigationLabel(destination).badge(badge(for: destination)).tag(destination.rawValue)
                    }
                }
                Section("Biblioteca") {
                    ForEach(WorkspaceDestination.library) { destination in
                        navigationLabel(destination).tag(destination.rawValue)
                    }
                }
                if !store.snapshot.projects.isEmpty {
                    Section("Seus projetos") {
                        ForEach(store.snapshot.projects) { project in
                            Label(project.name, systemImage: "folder")
                                .tag("project:" + project.id)
                                .contextMenu {
                                    Button("Nova tarefa neste projeto") {
                                        store.composerProjectID = project.id
                                        store.showComposer = true
                                    }
                                    Button("Mostrar no Finder") { store.reveal(project.path) }
                                }
                        }
                    }
                }
                if !recentRuns.isEmpty {
                    Section("Retomar") {
                        ForEach(recentRuns) { run in
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(run.title).font(.system(size: 12)).lineLimit(1)
                                    Text(run.state.label).font(.system(size: 10)).foregroundStyle(.secondary)
                                }.padding(.vertical, 3)
                            } icon: {
                                Image(systemName: run.state.active ? "circle.dotted" : "circle")
                                    .foregroundStyle(
                                        run.state == .waitingUser ? FrondaTheme.warning : FrondaTheme.accent)
                            }
                            .tag("run:" + run.id)
                            .contextMenu {
                                Button("Abrir em outra janela") { openWindow(id: "run", value: run.id) }
                                Button("Mostrar worktree no Finder") { store.reveal(run.workspace) }
                                    .disabled(run.workspace.isEmpty)
                            }
                        }
                    }
                }
            }.listStyle(.sidebar)

            footer
        }
    }

    private var brand: some View {
        HStack(alignment: .center, spacing: 0) {
            FrondaWordmark(width: 148)
            Spacer(minLength: 0)
            Text("V2").font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(FrondaTheme.accent)
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(FrondaTheme.accent.opacity(0.08), in: Capsule())
                .accessibilityLabel("Versão 2")
        }.padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 8)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            HStack {
                SettingsLink { Label("Ajustes", systemImage: "gearshape") }
                    .help("Abrir ajustes (⌘,)")
                    .buttonStyle(.plain).font(.system(size: 12))
                Spacer()
                Button {
                    store.addProject()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }.buttonStyle(.plain).help("Adicionar projeto")
                    .accessibilityLabel("Adicionar projeto")
            }
            HStack(spacing: 7) {
                Circle().fill(store.connected ? FrondaTheme.success : FrondaTheme.warning).frame(width: 6, height: 6)
                Text(
                    store.connected
                        ? "Coordenador local conectado" : store.loading ? "Conectando…" : "Sem conexão local"
                )
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .accessibilityIdentifier("coordinator.status")
            }
        }.padding(.horizontal, 20).padding(.bottom, 17)
    }

    private func navigationLabel(_ destination: WorkspaceDestination) -> some View {
        Label(destination.title, systemImage: destination.symbol)
            .foregroundStyle(selection == destination.rawValue ? .primary : .secondary)
            .padding(.vertical, 2)
    }

    private func badge(for destination: WorkspaceDestination) -> Int {
        switch destination {
        case .runs: store.activeRuns.count
        case .decisions: store.pendingDecisions
        default: 0
        }
    }
}
