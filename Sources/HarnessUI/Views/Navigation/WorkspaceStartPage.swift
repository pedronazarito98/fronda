import SwiftUI

struct WorkspaceStartPage: View {
    let store: AppStore
    let navigation: WorkspaceNavigation
    @State private var query = ""

    private var destinations: [WorkspaceDestination] {
        WorkspaceDestination.allCases.filter { matches($0.title) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("O que você quer abrir?").font(.system(size: 24, weight: .semibold))
                    Text("Um novo espaço para o seu trabalho.").foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Buscar páginas, projetos e tarefas", text: $query)
                        .textFieldStyle(.plain).accessibilityIdentifier("workspace.start-search")
                    if !query.isEmpty {
                        Button("Limpar busca", systemImage: "xmark.circle.fill") { query = "" }
                            .labelStyle(.iconOnly).foregroundStyle(.secondary).help("Limpar busca")
                    }
                }
                .padding(13).background(FrondaTheme.canvas, in: RoundedRectangle(cornerRadius: 12))
                pages
                projects
                recentTasks
            }
            .frame(maxWidth: 700, alignment: .leading)
            .padding(.horizontal, 28).padding(.top, 40).padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workspace.start")
        .onAppear { query = navigation.viewState["start.query"] ?? "" }
        .onChange(of: query) { _, value in navigation.viewState["start.query"] = value }
    }

    private var pages: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("No seu workspace")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                if matches("Nova tarefa") {
                    Button {
                        store.showComposer = true
                    } label: {
                        destinationLabel("Nova tarefa", symbol: "square.and.pencil")
                    }
                    .buttonStyle(WorkspaceStartButtonStyle()).help("Preparar uma nova tarefa (⌘N)")
                }
                ForEach(destinations) { destination in
                    Button {
                        open(destination.rawValue)
                    } label: {
                        destinationLabel(destination.title, symbol: destination.symbol)
                    }
                    .buttonStyle(WorkspaceStartButtonStyle())
                    .help("Abrir \(destination.title) neste painel")
                    .contextMenu { destinationActions(destination.rawValue) }
                }
            }
        }
    }

    @ViewBuilder private var projects: some View {
        let projects = store.snapshot.projects.filter { matches($0.name) }
        if !projects.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Seus projetos")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 14)], alignment: .leading, spacing: 14) {
                    ForEach(projects.prefix(8)) { project in
                        Button {
                            open("project:" + project.id)
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: "folder")
                                    .font(.system(size: 23)).foregroundStyle(FrondaTheme.accent)
                                    .frame(width: 52, height: 52)
                                    .background(FrondaTheme.canvas, in: RoundedRectangle(cornerRadius: 14))
                                Text(project.name).font(.callout).lineLimit(1)
                            }.frame(maxWidth: .infinity).padding(.vertical, 8).contentShape(Rectangle())
                        }
                        .help("Abrir projeto \(project.name) neste painel")
                        .contextMenu { destinationActions("project:" + project.id) }
                    }
                }
            }
        }
    }

    private var recentTasks: some View {
        let runs = store.snapshot.runs.filter { matches($0.title) }.sorted { $0.updatedAt > $1.updatedAt }
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Recentes")
            if runs.isEmpty {
                Text(query.isEmpty ? "Suas tarefas recentes aparecerão aqui." : "Nenhuma tarefa encontrada.")
                    .font(.callout).foregroundStyle(.secondary).padding(.vertical, 10)
            }
            ForEach(runs.prefix(8)) { run in
                Button {
                    open("run:" + run.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text").font(.title3).foregroundStyle(FrondaTheme.accent)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(run.title).lineLimit(2)
                            Text(store.snapshot.projects.first { $0.id == run.projectID }?.name ?? "Tarefa")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Text(run.updatedAt, format: .dateTime.day().month(.abbreviated))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12).padding(.horizontal, 10).contentShape(Rectangle())
                }
                .help("Abrir \(run.title) neste painel")
                .contextMenu { destinationActions("run:" + run.id) }
                Divider()
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.callout.weight(.semibold)).foregroundStyle(.secondary)
    }

    private func destinationLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(FrondaTheme.accent).frame(width: 20)
            Text(title).font(.callout).lineLimit(1)
            Spacer(minLength: 0)
        }.padding(14).frame(maxWidth: .infinity).contentShape(Rectangle())
    }

    private func matches(_ value: String) -> Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || value.localizedCaseInsensitiveContains(query.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func open(_ route: String) {
        store.workspace.focus(navigation)
        navigation.visit(route)
    }

    @ViewBuilder private func destinationActions(_ route: String) -> some View {
        Button("Abrir em nova aba") { store.workspace.openTab(WorkspaceLocation(route: route)) }
        Button("Abrir ao lado") { store.workspace.openBeside(WorkspaceLocation(route: route), from: navigation) }
    }
}

private struct WorkspaceStartButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? FrondaTheme.accent.opacity(0.12) : FrondaTheme.surfaceRaised,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(FrondaTheme.border.opacity(0.45)))
    }
}
