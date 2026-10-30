import AppKit
import HarnessDomain
import SwiftUI

struct ExtensionsView: View {
    var store: AppStore
    @State private var editing: HarnessExtension?
    @State private var busy: String?
    @State private var importing: ProviderKind?
    var body: some View {
        Section("Skills, MCPs e comandos") {
            Text("Conecte capacidades e escolha onde podem atuar. Cada tarefa mostra a seleção antes de executar.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                ForEach(ProviderKind.allCases) { kind in
                    Button("Importar do \(kind.rawValue)…") { importing = kind }
                }
            }
            ForEach(store.snapshot.preferences.extensions ?? []) { item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(item.name, systemImage: item.kind == .skill ? "book.closed" : "puzzlepiece.extension")
                            .font(.headline)
                        Spacer()
                        StatusBadge(text: item.enabled ? item.status : "DISABLED")
                    }
                    Text(item.summary.isEmpty ? item.kind.label : item.summary).font(.callout)
                    Text(
                        "\(item.kind.label) · v\(item.version) · \(item.tools.filter(\.enabled).count) ferramentas autorizadas"
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    if !item.detail.isEmpty { Text(item.detail).font(.caption).foregroundStyle(.secondary) }
                    HStack {
                        Button("Configurar") { editing = item }
                        if item.kind == .mcp {
                            Button(busy == item.id ? "Consultando…" : "Descobrir ferramentas") {
                                busy = item.id
                                Task {
                                    do {
                                        var request = RPCRequest("extension.discover")
                                        request.id = item.id
                                        _ = try await store.send(request)
                                        await store.refresh()
                                        editing = store.snapshot.preferences.extensions?.first { $0.id == item.id }
                                    } catch { store.error = error.localizedDescription }
                                    busy = nil
                                }
                            }.disabled(busy != nil)
                        }
                    }
                }.padding(.vertical, 8)
            }
            Button("Adicionar extensão…") { editing = HarnessExtension() }
                .accessibilityIdentifier("extensions.add")
        }.sheet(item: $editing) { item in ExtensionEditor(store: store, initial: item) }
            .sheet(item: $importing) { ProviderImportView(store: store, provider: $0) }
    }
}

private struct ExtensionEditor: View {
    var store: AppStore
    let initial: HarnessExtension
    @Environment(\.dismiss) private var dismiss
    @State private var item = HarnessExtension()
    @State private var arguments = ""
    @State private var keywords = ""
    @State private var error: String?
    @State private var saving = false
    @State private var authorization = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Configurar extensão").font(.title2.weight(.semibold))
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Salvar") { save() }.buttonStyle(.borderedProminent).disabled(saving)
            }.padding(20)
            Form {
                Section("Identificação") {
                    TextField("Nome", text: $item.name)
                    TextField("Quando usar", text: $item.summary, axis: .vertical)
                    Picker("Tipo", selection: $item.kind) {
                        ForEach(ExtensionKind.allCases.filter { $0 != .instructions || item.kind == .instructions }) {
                            Text($0.label).tag($0)
                        }
                    }
                    .disabled(store.snapshot.preferences.extensions?.contains(where: { $0.id == item.id }) == true)
                    Toggle("Habilitar nas tarefas elegíveis", isOn: $item.enabled)
                }
                if item.kind == .instructions {
                    Section("Texto importado") {
                        Text(item.skillPath).font(.caption.monospaced()).textSelection(.enabled)
                        Text(String(item.skillContent.prefix(6000))).font(.caption).textSelection(.enabled)
                        Text("Para atualizar o conteúdo, refaça a importação do provider.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else if item.kind == .skill {
                    Section("Instruções") {
                        TextField("Caminho do SKILL.md", text: $item.skillPath)
                        Button("Selecionar SKILL.md…") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = false
                            if panel.runModal() == .OK { item.skillPath = panel.url?.path ?? "" }
                        }
                        Text(
                            "O conteúdo é carregado quando necessário. Referências textuais dentro da pasta ficam disponíveis; scripts precisam ser cadastrados como comandos."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Section("Conexão") {
                        if item.kind == .mcp {
                            TextField("Endpoint HTTP (deixe vazio para stdio)", text: $item.endpoint)
                        }
                        if item.endpoint.isEmpty || item.kind == .command {
                            TextField("Executável", text: $item.executable)
                            TextField("Argumentos: um por linha", text: $arguments, axis: .vertical).lineLimit(3...8)
                        }
                        if item.kind == .mcp && !item.endpoint.isEmpty {
                            SecureField("Token Bearer (opcional; salvo no Keychain)", text: $authorization)
                            if item.authorizationReference != nil {
                                Text("Autorização armazenada. Deixe vazio para manter.").font(.caption)
                            }
                        }
                        Stepper(
                            "Tempo limite: \(item.timeoutSeconds)s", value: $item.timeoutSeconds, in: 5...600, step: 5)
                        Text(
                            "Use uma instalação local de confiança. Processos executam com o acesso do seu usuário; a declaração de leitura não é um sandbox. MCP remoto com OAuth próprio ainda não é suportado."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Ferramentas autorizadas") {
                        if item.tools.isEmpty {
                            Text("Salve o MCP e use Descobrir ferramentas para escolher as permissões.").font(.caption)
                        }
                        ForEach($item.tools) { $tool in
                            VStack(alignment: .leading) {
                                Toggle(tool.name, isOn: $tool.enabled)
                                Text(tool.description).font(.caption).foregroundStyle(.secondary)
                                Toggle("Permitir também em etapas de leitura", isOn: $tool.readOnly).disabled(
                                    !tool.enabled)
                            }
                        }
                    }
                }
                Section("Seleção adaptativa") {
                    TextField("Palavras do objetivo, separadas por vírgula", text: $keywords)
                    Text(
                        "Sem palavras: elegível em todas as tarefas dos projetos selecionados. A seleção pode ser ajustada por tarefa."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    ForEach(StepKind.allCases, id: \.rawValue) { stage in
                        Toggle(
                            stage.rawValue,
                            isOn: Binding(
                                get: { item.stages.contains(stage.rawValue) },
                                set: { checked in
                                    item.stages.removeAll { $0 == stage.rawValue }
                                    if checked { item.stages.append(stage.rawValue) }
                                }))
                    }
                }
                Section("Projetos · nenhum selecionado permite todos") {
                    ForEach(store.snapshot.projects) { project in
                        Toggle(
                            project.name,
                            isOn: Binding(
                                get: { item.projectIDs.contains(project.id) },
                                set: { checked in
                                    item.projectIDs.removeAll { $0 == project.id }
                                    if checked { item.projectIDs.append(project.id) }
                                }))
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.formStyle(.grouped)
        }.frame(width: 720, height: 740)
            .onAppear {
                item = initial
                arguments = item.arguments.joined(separator: "\n")
                keywords = item.keywords.joined(separator: ", ")
            }
            .onChange(of: item.kind) {
                if item.kind == .command && item.tools.isEmpty {
                    var tool = ExtensionTool()
                    tool.name = "run"
                    item.tools = [tool]
                }
            }
    }
    private func save() {
        saving = true
        item.arguments = arguments.split(separator: "\n").map(String.init)
        item.keywords = keywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter {
            !$0.isEmpty
        }
        Task {
            do {
                var request = RPCRequest("extension.save")
                request.extensionConfiguration = item
                request.text = authorization
                _ = try await store.send(request)
                await store.refresh()
                dismiss()
            } catch { self.error = error.localizedDescription }
            saving = false
        }
    }
}
