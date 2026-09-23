import HarnessDomain
import SwiftUI

struct ProjectsView: View {
    var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    PageHeading(
                        eyebrow: "Contexto começa aqui", title: "Projetos",
                        subtitle: "Repositórios, regras e comandos que suas runs compartilham.")
                    Button("Adicionar projeto…") { store.addProject() }.buttonStyle(.borderedProminent)
                }
                if store.snapshot.projects.isEmpty {
                    EmptyPanel(
                        symbol: "folder.badge.plus", title: "Seu código, neste Mac",
                        detail:
                            "Adicione um repositório existente. O Harness detecta Git e sugere validadores sem instalar dependências."
                    )
                }
                ForEach(store.snapshot.projects) { project in
                    Button {
                        store.route = "project:" + project.id
                    } label: {
                        Surface {
                            HStack(spacing: 18) {
                                Image(systemName: "folder").font(.title).foregroundStyle(HarnessTheme.accent)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(project.name).font(.headline)
                                    Text(project.path).font(.system(size: 11, design: .monospaced)).foregroundStyle(
                                        .secondary)
                                    Text("\(project.branch) · \(project.indexedFiles) arquivos indexados").font(
                                        .caption
                                    ).foregroundStyle(.secondary)
                                }
                                Spacer()
                                StatusBadge(text: project.indexState)
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }.padding(32)
        }
    }
}

struct ProjectDetailView: View {
    var store: AppStore
    let projectID: String
    @State private var query = ""
    @State private var matches = [ContextItem]()
    @State private var editing = false
    private var project: Project? { store.snapshot.projects.first { $0.id == projectID } }
    var body: some View {
        if let project {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        PageHeading(eyebrow: "Projeto", title: project.name, subtitle: project.path)
                        Button("Configurar…") { editing = true }
                        Button {
                            store.reveal(project.path)
                        } label: {
                            Image(systemName: "folder")
                        }
                    }
                    HStack(spacing: 14) {
                        Metric(
                            title: "Arquivos indexados", value: project.indexedFiles.formatted(),
                            symbol: "doc.text.magnifyingglass")
                        Metric(
                            title: "Validadores aprovados", value: "\(project.validators.filter(\.approved).count)",
                            symbol: "checkmark.diamond", color: .green)
                        Metric(
                            title: "Runs neste projeto",
                            value: "\(store.snapshot.runs.filter { $0.projectID == projectID }.count)",
                            symbol: "play.rectangle")
                    }
                    Surface {
                        VStack(alignment: .leading, spacing: 13) {
                            HStack {
                                Text("Índice local").font(.headline)
                                StatusBadge(text: project.indexState)
                                Spacer()
                                Button("Reindexar") { store.perform("project.index", id: projectID) }
                            }
                            Text(project.indexMessage).font(.caption).foregroundStyle(.secondary)
                            HStack {
                                TextField("Buscar arquivo, símbolo ou conteúdo…", text: $query).textFieldStyle(
                                    .roundedBorder
                                ).onSubmit { search() }
                                Button("Buscar") { search() }
                            }
                            ForEach(matches) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(item.path).font(.system(size: 12, weight: .medium, design: .monospaced))
                                        Text(item.symbols.prefix(8).joined(separator: " · ")).font(.caption)
                                            .foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Spacer()
                                    Button {
                                        store.openFile(project.path + "/" + item.path)
                                    } label: {
                                        Image(systemName: "arrow.up.right.square")
                                    }.buttonStyle(.plain)
                                }.padding(.vertical, 7)
                            }
                        }
                    }
                    SectionHeading(title: "Comandos de validação", detail: "EXECUÇÃO SEPARADA DO CADASTRO")
                    ForEach(project.validators) { validator in
                        Surface(padding: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(validator.name).font(.headline)
                                    Text(validator.displayCommand).font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(validator.approved ? "Aprovado" : "Revisão necessária").font(.caption)
                                    .foregroundStyle(validator.approved ? .green : .orange)
                            }
                        }
                    }
                    SectionHeading(title: "Worktrees e runs")
                    ForEach(store.snapshot.runs.filter { $0.projectID == projectID }) { run in
                        RunRow(store: store, run: run)
                    }
                }.padding(32)
            }.sheet(isPresented: $editing) { ProjectSettingsView(store: store, project: project) }
        } else {
            EmptyPanel(
                symbol: "folder", title: "Projeto não encontrado", detail: "Escolha um projeto na barra lateral.")
        }
    }
    private func search() {
        var request = RPCRequest("search")
        request.id = projectID
        request.text = query
        Task {
            do { matches = try await store.send(request).items ?? [] } catch {
                store.error = error.localizedDescription
            }
        }
    }
}
