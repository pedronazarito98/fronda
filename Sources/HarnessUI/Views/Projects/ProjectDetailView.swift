import HarnessDomain
import SwiftUI

struct ProjectDetailView: View {
    var store: AppStore
    let projectID: String

    var body: some View {
        if let project = store.snapshot.projects.first(where: { $0.id == projectID }) {
            ProjectWorkspaceView(store: store, project: project).id(projectID)
        } else {
            ProjectEmptyState(
                symbol: "folder", title: "Projeto não encontrado",
                detail: "Este projeto não está disponível no workspace."
            ) {
                Button("Ver projetos") { store.route = "projects" }
            }.padding(28)
        }
    }
}

private enum ProjectDetailSection: String, CaseIterable, Identifiable {
    case index = "Índice"
    case validations = "Validações"
    case tasks = "Tarefas"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .index: "doc.text.magnifyingglass"
        case .validations: "checkmark.shield"
        case .tasks: "play.rectangle"
        }
    }
}

private struct ProjectWorkspaceView: View {
    var store: AppStore
    let project: Project
    @SceneStorage private var section: ProjectDetailSection
    @State private var settingsSection: ProjectSettingsSection?

    init(store: AppStore, project: Project) {
        self.store = store
        self.project = project
        _section = SceneStorage(wrappedValue: .index, "fronda.project.\(project.id).section")
    }

    private var runs: [Run] { store.snapshot.runs.filter { $0.projectID == project.id } }
    private var pendingCommands: Int { project.validators.filter { !$0.approved }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                sectionNavigation
                Group {
                    switch section {
                    case .index: ProjectIndexView(store: store, project: project)
                    case .validations:
                        ProjectValidationList(project: project) { openSettings(.validation) }
                    case .tasks:
                        ProjectTaskList(store: store, runs: runs, createTask: createTask)
                    }
                }
            }
            .padding(28).frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
        }
        .rememberScrollPosition("project." + project.id)
        .sheet(item: $settingsSection) { destination in
            ProjectSettingsView(store: store, project: project, initialSection: destination)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Button("Projetos") { store.route = "projects" }
                    .buttonStyle(.plain).foregroundStyle(FrondaTheme.accent)
                Image(systemName: "chevron.right").font(.system(size: 8)).accessibilityHidden(true)
                Text(project.name).lineLimit(1)
            }.font(.caption).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    title
                    Spacer(minLength: 12)
                    actions
                }
                VStack(alignment: .leading, spacing: 14) {
                    title
                    actions
                }
            }
            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.branch").accessibilityHidden(true)
                    Text(project.branch.isEmpty ? "Branch não informada" : project.branch)
                }
                if project.dirty { Text("Alterações locais").foregroundStyle(FrondaTheme.warning) }
                Spacer()
                if !store.connected { Text("Coordenador desconectado").foregroundStyle(FrondaTheme.warning) }
            }.font(.caption).foregroundStyle(.secondary)
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.name).font(.system(size: 27, weight: .semibold)).tracking(-0.5).lineLimit(2)
            Text(project.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                .textSelection(.enabled).help(project.path)
        }
    }

    private var actions: some View {
        HStack(spacing: 9) {
            Button {
                store.reveal(project.path)
            } label: {
                Image(systemName: "folder")
            }
            .help("Mostrar no Finder").accessibilityLabel("Mostrar projeto no Finder")
            .accessibilityIdentifier("project.reveal")
            Button("Configurar…") { openSettings(.access) }
                .accessibilityIdentifier("project.settings")
            Button(action: createTask) { Label("Nova tarefa", systemImage: "plus") }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("project.new-task")
        }.fixedSize()
    }

    private var sectionNavigation: some View {
        HStack(spacing: 10) {
            ForEach(ProjectDetailSection.allCases) { item in
                Button {
                    section = item
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 8) {
                            Image(systemName: item.symbol).accessibilityHidden(true)
                            Text(item.rawValue).fontWeight(.semibold)
                            Spacer(minLength: 0)
                            Text(count(for: item)).monospacedDigit().foregroundStyle(.secondary)
                        }.font(.system(size: 12))
                        Text(summary(for: item)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        section == item ? FrondaTheme.accent.opacity(0.08) : FrondaTheme.surface,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(section == item ? FrondaTheme.accent.opacity(0.6) : FrondaTheme.border)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain).foregroundStyle(section == item ? FrondaTheme.accent : .primary)
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("\(item.rawValue), \(count(for: item)), \(summary(for: item))")
                .accessibilityAddTraits(section == item ? [.isSelected] : [])
                .accessibilityRemoveTraits(section == item ? [] : [.isSelected])
                .accessibilityIdentifier("project.section." + sectionID(item))
            }
        }
    }

    private func count(for item: ProjectDetailSection) -> String {
        switch item {
        case .index: project.indexedFiles.formatted()
        case .validations: project.validators.count.formatted()
        case .tasks: runs.count.formatted()
        }
    }

    private func summary(for item: ProjectDetailSection) -> String {
        switch item {
        case .index: return ProjectIndexStatus(rawValue: project.indexState).label
        case .validations:
            if project.validators.isEmpty {
                return "Configurar comandos"
            } else if pendingCommands > 0 {
                return "\(pendingCommands) para revisar"
            } else {
                return project.validators.count == 1 ? "Comando aprovado" : "Comandos aprovados"
            }
        case .tasks:
            if runs.isEmpty {
                return "Preparar a primeira"
            } else {
                let attention = runs.filter(RunDisplay.needsAttention).count
                if attention == 1 { return "1 pede atenção" }
                return attention > 1 ? "\(attention) pedem atenção" : "Acompanhar trabalho"
            }
        }
    }

    private func sectionID(_ item: ProjectDetailSection) -> String {
        switch item {
        case .index: "index"
        case .validations: "validations"
        case .tasks: "tasks"
        }
    }

    private func openSettings(_ destination: ProjectSettingsSection) {
        settingsSection = destination
    }

    private func createTask() {
        guard store.snapshot.projects.contains(where: { $0.id == project.id }) else { return }
        store.composerText = ""
        store.composerSource = nil
        store.composerProjectID = project.id
        store.composerRunbookID = ""
        store.showComposer = true
    }
}
