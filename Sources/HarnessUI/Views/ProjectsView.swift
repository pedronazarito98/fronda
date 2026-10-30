import HarnessDomain
import SwiftUI

struct ProjectsView: View {
    var store: AppStore
    @SceneStorage("fronda.projects.query") private var query = ""
    @SceneStorage("fronda.projects.filter") private var filter = ProjectLibraryFilter.all

    private var matchingProjects: [Project] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.snapshot.projects.filter { project in
            let matchesQuery =
                term.isEmpty
                || [project.name, project.path, project.branch].contains { $0.localizedStandardContains(term) }
            return matchesQuery && filter.includes(project, runs: store.snapshot.runs)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if store.snapshot.projects.isEmpty {
                    welcome
                } else {
                    libraryControls
                    if matchingProjects.isEmpty {
                        ProjectEmptyState(
                            symbol: "line.3.horizontal.decrease.circle", title: "Nenhum projeto nesta busca",
                            detail: "Tente outro nome, caminho ou branch, ou remova o filtro."
                        ) {
                            Button("Limpar busca e filtro") {
                                query = ""
                                filter = .all
                            }
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(matchingProjects) { project in
                                ProjectLibraryRow(
                                    project: project, runs: store.snapshot.runs.filter { $0.projectID == project.id }
                                ) { store.route = "project:" + project.id }
                            }
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .rememberScrollPosition("projects")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Projetos").font(.system(size: 27, weight: .semibold)).tracking(-0.6)
                Text("Contexto, comandos e tarefas de cada repositório.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button {
                store.addProject()
            } label: {
                Label("Adicionar projeto…", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.connected || store.busy.contains("project.add"))
            .accessibilityIdentifier("projects.add")
        }
    }

    private var libraryControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    searchField
                    filterPicker.fixedSize()
                }
                VStack(alignment: .leading, spacing: 10) {
                    searchField
                    filterPicker
                }
            }
            HStack {
                Text(
                    "\(matchingProjects.count) de \(store.snapshot.projects.count) \(store.snapshot.projects.count == 1 ? "projeto" : "projetos")"
                )
                Spacer()
                if !store.connected { Text("Coordenador desconectado").foregroundStyle(FrondaTheme.warning) }
            }.font(.caption).foregroundStyle(.secondary)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
            TextField("Buscar projeto, caminho ou branch", text: $query)
                .textFieldStyle(.plain).accessibilityLabel("Buscar projetos")
                .accessibilityIdentifier("projects.search")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Limpar busca de projetos")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(FrondaTheme.border) }
    }

    private var filterPicker: some View {
        Picker("Filtrar projetos", selection: $filter) {
            ForEach(ProjectLibraryFilter.allCases) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented).labelsHidden().accessibilityIdentifier("projects.filter")
    }

    private var welcome: some View {
        ProjectEmptyState(
            symbol: "folder.badge.plus", title: "Comece pelo seu repositório",
            detail:
                "Escolha uma pasta Git neste Mac. O Fronda reúne o contexto do código e sugere comandos para você revisar."
        ) {
            Text("Depois, prepare a primeira tarefa com esse projeto.")
                .font(.caption).foregroundStyle(.secondary)
            if !store.connected {
                Text(store.loading ? "Conectando ao coordenador…" : "Aguarde a conexão para adicionar um projeto.")
                    .font(.caption).foregroundStyle(FrondaTheme.warning)
            }
        }
    }
}
