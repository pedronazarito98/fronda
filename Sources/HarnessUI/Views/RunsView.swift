import HarnessDomain
import SwiftUI

struct RunsView: View {
    var store: AppStore
    let navigation: WorkspaceNavigation
    @Environment(\.workspaceShowsSummary) private var showsSummary
    @State private var comparing = false
    @State private var showingFilters = false
    @FocusState private var searchFocused: Bool

    init(store: AppStore, navigation: WorkspaceNavigation? = nil) {
        self.store = store
        self.navigation = navigation ?? store.navigation
    }

    private var search: String { navigation.viewState["runs.search"] ?? "" }
    private var filter: RunListFilter { RunListFilter(rawValue: navigation.viewState["runs.filter"] ?? "") ?? .all }
    private var order: RunListSort { RunListSort(rawValue: navigation.viewState["runs.order"] ?? "") ?? .updated }
    private var project: String { navigation.viewState["runs.project"] ?? "" }
    private var isBoard: Bool { navigation.viewState["runs.presentation"] != "list" }
    private var hasFilters: Bool { !search.isEmpty || filter != .all || !project.isEmpty }
    private func state(_ key: String, default value: String = "") -> Binding<String> {
        Binding(get: { navigation.viewState[key] ?? value }, set: { navigation.viewState[key] = $0 })
    }

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var filtered: [Run] {
        let projects = Dictionary(
            store.snapshot.projects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return store.snapshot.runs.filter { run in
            filter.includes(run) && (project.isEmpty || run.projectID == project)
                && (query.isEmpty
                    || [run.title, projects[run.projectID] ?? "", run.provider.rawValue, run.runbook.name]
                        .contains { $0.localizedCaseInsensitiveContains(query) })
        }.sorted(by: order.precedes)
    }
    private var emptyTitle: String {
        if !query.isEmpty { return "Nenhum resultado para “\(query)”" }
        switch filter {
        case .all: return "Sua próxima tarefa começa aqui"
        case .attention: return "Nenhuma tarefa pede atenção"
        case .active: return "Nenhuma tarefa em andamento"
        case .ready: return "As entregas prontas aparecerão aqui"
        case .archived: return "Nenhuma tarefa arquivada"
        }
    }
    private var emptyDetail: String {
        if !query.isEmpty { return "Tente outro título, projeto, executor ou fluxo de trabalho." }
        switch filter {
        case .all:
            return
                "Descreva um objetivo e prepare o contexto. Cada execução terá seu próprio histórico e suas evidências."
        case .attention: return "Aprovações, impedimentos e entregas para revisar aparecem juntos neste filtro."
        case .active: return "Tarefas em execução, na fila, pausadas ou em preparação aparecem aqui."
        case .ready: return "Quando uma execução terminar pronta para revisão, você poderá conferir a entrega aqui."
        case .archived: return "As tarefas arquivadas continuam disponíveis com seu histórico."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            heading
            if showsSummary { summary }
            if filtered.isEmpty {
                emptyState.padding(24).frame(maxHeight: .infinity, alignment: .top)
            } else if isBoard {
                RunBoard(store: store, runs: filtered, navigation: navigation)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { run in RunRow(store: store, run: run) }
                    }.padding(24).frame(maxWidth: 1100).frame(maxWidth: .infinity)
                }.rememberScrollPosition("runs.list")
            }
        }
        .background(FrondaTheme.surface)
        .sheet(isPresented: $comparing) { CompareRunsView(store: store) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("runs.list")
    }

    private var heading: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                projectPicker
                presentationPicker
                Spacer(minLength: 0)
                actions
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    projectPicker
                    Spacer()
                    actions
                }
                presentationPicker
            }
        }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 12)
    }

    private var projectPicker: some View {
        Menu {
            Button("Todos os projetos") { navigation.viewState["runs.project"] = "" }
            ForEach(store.snapshot.projects) { project in
                Button(project.name) { navigation.viewState["runs.project"] = project.id }
            }
        } label: {
            Text(store.snapshot.projects.first { $0.id == project }?.name ?? "Todos os projetos")
                .font(.system(size: 15, weight: .semibold)).lineLimit(1)
        }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Filtrar por projeto")
    }

    private var presentationPicker: some View {
        HStack(spacing: 16) {
            presentationButton("Quadro", board: true)
            presentationButton("Lista", board: false)
        }
    }

    private func presentationButton(_ label: String, board: Bool) -> some View {
        Button {
            navigation.viewState["runs.presentation"] = board ? "board" : "list"
        } label: {
            Text(label).font(.system(size: 12, weight: isBoard == board ? .medium : .regular))
                .foregroundStyle(isBoard == board ? .primary : .secondary)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    if isBoard == board { Rectangle().fill(FrondaTheme.accent).frame(height: 2) }
                }
        }.buttonStyle(.plain).accessibilityAddTraits(isBoard == board ? .isSelected : [])
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                showingFilters.toggle()
            } label: {
                Image(systemName: hasFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                    .foregroundStyle(hasFilters ? FrondaTheme.accent : .secondary)
            }
            .buttonStyle(.plain).help("Buscar, filtrar e ordenar tarefas")
            .accessibilityLabel("Filtros de tarefas").accessibilityIdentifier("runs.filters")
            .popover(isPresented: $showingFilters, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Encontre uma tarefa").font(.headline)
                    controls
                    Divider()
                    Button("Comparar abordagens") {
                        showingFilters = false
                        comparing = true
                    }
                    .disabled(store.snapshot.runs.count < 2)
                    if hasFilters { Button("Limpar filtros", action: clearFilters) }
                }.padding(20).frame(width: 390)
            }
            Button(action: prepare) { Label("Nova tarefa", systemImage: "plus") }
                .buttonStyle(.borderedProminent).controlSize(.regular)
        }
    }

    private var summary: some View {
        HStack(spacing: 8) {
            Image(systemName: "pin").accessibilityHidden(true)
            Text(
                "\(filtered.filter(RunDisplay.needsAttention).count) precisam de você · \(filtered.filter { $0.state.active }.count) em andamento"
            )
            .lineLimit(2)
            Spacer(minLength: 0)
            Text("\(filtered.count) tarefas").accessibilityIdentifier("runs.result-count")
            if store.snapshot.preferences.queuePaused { Image(systemName: "pause.circle").help("Fila pausada") }
        }.font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.horizontal, 24).padding(.bottom, 12)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 16) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Buscar por tarefa, projeto ou executor…", text: state("runs.search"))
                        .textFieldStyle(.plain).focused($searchFocused)
                        .accessibilityLabel("Buscar tarefas").accessibilityIdentifier("runs.search")
                    if !search.isEmpty {
                        Button {
                            navigation.viewState["runs.search"] = ""
                            searchFocused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }.buttonStyle(.plain).accessibilityLabel("Limpar busca")
                    }
                }
                .font(.callout).padding(12)
                .background(FrondaTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(FrondaTheme.border, lineWidth: 1))
                Picker(
                    "Ordenar",
                    selection: Binding(get: { order }, set: { navigation.viewState["runs.order"] = $0.rawValue })
                ) {
                    ForEach(RunListSort.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu).fixedSize()
                .accessibilityIdentifier("runs.sort")
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(RunListFilter.allCases) { option in
                        filterButton(option)
                    }
                }
                .padding(2)
            }.scrollIndicators(.hidden)
        }
    }

    private func filterButton(_ option: RunListFilter) -> some View {
        let selected = filter == option
        let count = store.snapshot.runs.filter(option.includes).count
        return Button {
            navigation.viewState["runs.filter"] = option.rawValue
        } label: {
            HStack(spacing: 7) {
                Text(option.rawValue).font(.system(size: 12, weight: selected ? .semibold : .medium))
                Text(count.formatted()).font(.system(size: 10, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(FrondaTheme.accent.opacity(selected ? 0.13 : 0.05), in: Capsule())
            }
            .foregroundStyle(selected ? FrondaTheme.accent : .secondary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(selected ? FrondaTheme.accent.opacity(0.10) : .clear, in: Capsule())
            .overlay(
                Capsule().strokeBorder(selected ? FrondaTheme.accent.opacity(0.24) : FrondaTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.rawValue), \(count) tarefas")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("runs.filter.\(option.id)")
    }

    private var emptyState: some View {
        Surface(padding: 0) {
            VStack(spacing: 0) {
                EmptyPanel(
                    symbol: query.isEmpty ? "square.stack.3d.up" : "magnifyingglass",
                    title: emptyTitle, detail: emptyDetail)
                if hasFilters {
                    Button("Mostrar todas as tarefas") {
                        clearFilters()
                    }
                    .padding(.bottom, 30)
                } else {
                    Button("Preparar primeira tarefa", action: prepare)
                        .buttonStyle(.borderedProminent).padding(.bottom, 30)
                }
            }
        }
    }

    private func clearFilters() {
        navigation.viewState["runs.search"] = ""
        navigation.viewState["runs.filter"] = RunListFilter.all.rawValue
        navigation.viewState["runs.project"] = ""
    }

    private func prepare() {
        store.composerText = ""
        store.composerSource = nil
        store.composerProjectID = project
        store.composerRunbookID = ""
        store.showComposer = true
    }
}
