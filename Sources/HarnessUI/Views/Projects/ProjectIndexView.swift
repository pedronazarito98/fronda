import HarnessDomain
import SwiftUI

struct ProjectIndexView: View {
    var store: AppStore
    let project: Project
    @State private var query = ""
    @State private var matches = [ContextItem]()
    @State private var submittedQuery: String?
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var requestID: UUID?
    @State private var searching = false

    private var status: ProjectIndexStatus { ProjectIndexStatus(rawValue: project.indexState) }
    private var indexing: Bool { project.indexState == "INDEXING" }
    private var canSearch: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.connected && !indexing && !searching
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Surface(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        if indexing { ProgressView().controlSize(.small).accessibilityLabel("Atualizando índice") }
                        VStack(alignment: .leading, spacing: 5) {
                            ProjectIndexBadge(state: project.indexState)
                            Text(status.explanation).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 10)
                        Button(project.indexState == "NOT_INDEXED" ? "Criar índice" : "Atualizar índice") {
                            invalidateSearch()
                            store.perform("project.index", id: project.id)
                        }
                        .disabled(!store.connected || indexing || store.busy.contains(project.id))
                        .accessibilityIdentifier("project.index.refresh")
                    }
                    if let indexedAt = project.indexedAt {
                        Text(
                            "\(project.indexedFiles.formatted()) \(project.indexedFiles == 1 ? "arquivo" : "arquivos") · Última indexação: \(indexedAt.formatted(date: .abbreviated, time: .shortened))"
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    if !project.indexMessage.isEmpty {
                        DisclosureGroup("Detalhes da indexação") {
                            Text(project.indexMessage).font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                        }.font(.caption)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 11) {
                Text("Encontre contexto no código").font(.system(size: 16, weight: .semibold))
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
                        TextField("Arquivo, símbolo ou conteúdo…", text: $query)
                            .textFieldStyle(.plain).onSubmit(search)
                            .accessibilityLabel("Buscar no índice do projeto").accessibilityIdentifier(
                                "project.index.query")
                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel(
                                "Limpar busca no índice")
                        }
                    }
                    .padding(11).background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 10))
                    .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(FrondaTheme.border) }
                    Button("Buscar", action: search).disabled(!canSearch).accessibilityIdentifier(
                        "project.index.search")
                }
                searchContent
            }
        }
        .onChange(of: query) { _, _ in invalidateSearch() }
        .onChange(of: project.id) { _, _ in
            query = ""
            invalidateSearch()
        }
        .onChange(of: project.indexedAt) { _, _ in invalidateSearch() }
        .onChange(of: project.indexState) { _, newValue in if newValue == "INDEXING" { invalidateSearch() } }
        .onDisappear { invalidateSearch() }
    }

    @ViewBuilder private var searchContent: some View {
        if searching {
            HStack(spacing: 9) {
                ProgressView().controlSize(.small)
                Text("Buscando no índice local…").font(.callout).foregroundStyle(.secondary)
            }.padding(.vertical, 16).accessibilityElement(children: .combine)
        } else if let searchError {
            VStack(alignment: .leading, spacing: 8) {
                Text("Não foi possível buscar").font(.callout.weight(.semibold)).foregroundStyle(FrondaTheme.danger)
                Text(searchError).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Button("Tentar novamente", action: search).disabled(!canSearch)
            }.padding(.vertical, 12)
        } else if let submittedQuery {
            if matches.isEmpty {
                ProjectEmptyState(
                    symbol: "doc.text.magnifyingglass", title: "Nenhum resultado para “\(submittedQuery)”",
                    detail: "Tente outro termo ou atualize o índice se o arquivo foi alterado recentemente."
                ) { EmptyView() }
            } else {
                Text("\(matches.count) \(matches.count == 1 ? "resultado" : "resultados") para “\(submittedQuery)”")
                    .font(.caption).foregroundStyle(.secondary)
                Surface(padding: 0) {
                    LazyVStack(spacing: 0) {
                        ForEach(matches) { item in
                            resultRow(item)
                            if item.id != matches.last?.id { Divider().padding(.horizontal, 16) }
                        }
                    }
                }
            }
        } else {
            Text(
                indexing
                    ? "A busca fica disponível quando a indexação terminar."
                    : "Busque por um termo para explorar os arquivos indexados."
            )
            .font(.caption).foregroundStyle(.secondary).padding(.vertical, 5)
        }
    }

    private func resultRow(_ item: ContextItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text").foregroundStyle(FrondaTheme.accent).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.path).font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(2).textSelection(.enabled)
                if !item.symbols.isEmpty {
                    Text(item.symbols.prefix(8).joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 12)
            Button {
                store.openFile(project.path + "/" + item.path)
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .buttonStyle(.plain).help("Abrir \(item.path)").accessibilityLabel("Abrir \(item.path)")
            .accessibilityIdentifier("project.index.open." + item.id)
        }.padding(16)
    }

    private func invalidateSearch() {
        requestID = nil
        searchTask?.cancel()
        searchTask = nil
        searching = false
        matches = []
        submittedQuery = nil
        searchError = nil
    }

    private func search() {
        guard canSearch else { return }
        invalidateSearch()
        let token = UUID()
        let projectID = project.id
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var request = RPCRequest("search")
        request.id = projectID
        request.text = term
        requestID = token
        searching = true
        searchTask = Task { @MainActor in
            do {
                let response = try await store.send(request)
                guard !Task.isCancelled, requestID == token, project.id == projectID,
                    query.trimmingCharacters(in: .whitespacesAndNewlines) == term
                else { return }
                matches = response.items ?? []
                submittedQuery = term
                searching = false
                searchTask = nil
            } catch {
                guard !Task.isCancelled, requestID == token else { return }
                searchError = error.localizedDescription
                searching = false
                searchTask = nil
            }
        }
    }
}
