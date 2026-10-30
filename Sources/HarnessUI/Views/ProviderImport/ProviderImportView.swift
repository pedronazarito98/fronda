import HarnessDomain
import HarnessInfrastructure
import SwiftUI

struct ProviderImportView: View {
    let store: AppStore
    let provider: ProviderKind
    @Environment(\.dismiss) private var dismiss
    @State private var preview: ProviderImportPreview?
    @State private var selected = Set<String>()
    @State private var focused: String?
    @State private var query = ""
    @State private var projectID = ""
    @State private var loading = true
    @State private var saving = false
    @State private var error: String?
    @State private var result: String?
    @State private var scanID = UUID()

    private var items: [ProviderImportItem] {
        (preview?.items ?? []).filter {
            query.isEmpty || "\($0.name) \($0.kind.label) \($0.scope)".localizedStandardContains(query)
        }
    }
    private var inspected: ProviderImportItem? { preview?.items.first { $0.id == focused } }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let result {
                ContentUnavailableView {
                    Label("Contexto no lugar", systemImage: "checkmark.seal.fill")
                } description: {
                    Text(
                        result
                            + " Skills e instruções estão disponíveis. MCPs aguardam revisão das ferramentas em Ajustes → Extensões."
                    )
                } actions: {
                    Button("Concluir") { dismiss() }.buttonStyle(.borderedProminent)
                }.frame(maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    catalog.frame(width: 430)
                    Divider()
                    detail.id(focused).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                Divider()
                footer
            }
        }.frame(width: 940, height: 730).background(FrondaTheme.canvas).tint(FrondaTheme.accent)
            .interactiveDismissDisabled(saving)
            .task { await scan() }
            .task(id: projectID) { if preview != nil { await scan() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "tray.and.arrow.down.fill").font(.title).foregroundStyle(FrondaTheme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Traga seu jeito de trabalhar").font(.title2.weight(.semibold))
                    Text("\(provider.rawValue) → Fronda · escolha o que vem com você")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Fechar") { dismiss() }.keyboardShortcut(.cancelAction).disabled(saving)
            }
            HStack {
                Picker("Buscar em", selection: $projectID) {
                    Text("Configuração deste usuário").tag("")
                    ForEach(store.snapshot.projects) { Text("Usuário + \($0.name)").tag($0.id) }
                }.frame(maxWidth: 480).disabled(loading || saving)
                Spacer()
                Button("Buscar novamente") { Task { await scan() } }.disabled(loading || saving)
            }
        }.padding(22)
    }

    private var catalog: some View {
        VStack(spacing: 0) {
            TextField("Filtrar skills, regras, MCPs…", text: $query).textFieldStyle(.roundedBorder).padding(16)
            if loading {
                ProgressView("Buscando configurações portáveis…").frame(maxHeight: .infinity)
            } else if items.isEmpty {
                ContentUnavailableView(
                    "Nenhum item encontrado", systemImage: "tray",
                    description:
                        Text(
                            query.isEmpty
                                ? "Confira o provider instalado ou selecione um projeto cadastrado."
                                : "Tente outro termo."))
            } else {
                List(selection: $focused) {
                    ForEach(ProviderImportKind.allCases) { kind in
                        let group = items.filter { $0.kind == kind }
                        if !group.isEmpty {
                            Section("\(kind.label) · \(group.count)") {
                                ForEach(group) { item in
                                    HStack(spacing: 10) {
                                        Toggle(item.name, isOn: selection(item)).labelsHidden().toggleStyle(.checkbox)
                                            .disabled(!item.selectable || saving)
                                            .accessibilityLabel("Importar \(item.name)")
                                        Image(systemName: kind.symbol).foregroundStyle(FrondaTheme.accent).frame(
                                            width: 20)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name).font(.callout.weight(.medium)).lineLimit(1)
                                            Text(item.alreadyImported ? "Já importado · \(item.scope)" : item.scope)
                                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                        if !item.selectable {
                                            Image(systemName: "exclamationmark.circle").foregroundStyle(
                                                FrondaTheme.warning)
                                        }
                                    }.padding(.vertical, 5).tag(item.id)
                                }
                            }
                        }
                    }
                }.listStyle(.inset).scrollContentBackground(.hidden)
            }
        }
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let item = inspected {
                    Label(item.kind.label, systemImage: item.kind.symbol).font(.caption.weight(.semibold))
                        .foregroundStyle(FrondaTheme.accent)
                    Text(item.name).font(.title2.weight(.semibold))
                    Text(item.detail).font(.callout).foregroundStyle(.secondary)
                    Text(item.source).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                    Divider()
                    Text(item.preview.isEmpty ? "Sem prévia disponível." : item.preview)
                        .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Image(systemName: "checklist").font(.system(size: 42, weight: .light)).foregroundStyle(
                        FrondaTheme.accent)
                    Text("Só o que faz sentido para você.").font(.title2.weight(.semibold))
                    Text(
                        "Clique em um item para conferir a origem e o conteúdo. Marque as caixas para importar; desmarcar mantém o item fora desta importação."
                    )
                    .foregroundStyle(.secondary)
                }
                if let warnings = preview?.warnings, !warnings.isEmpty {
                    Divider()
                    DisclosureGroup("Como a importação funciona") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                        }.padding(.top, 10)
                    }.font(.callout)
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error { Text(error).font(.caption).foregroundStyle(FrondaTheme.danger).textSelection(.enabled) }
            HStack {
                Button("Marcar visíveis") {
                    selected.formUnion(
                        items.filter { $0.selectable && $0.kind != .settings && !$0.alreadyImported }.map(\.id))
                }.disabled(loading || saving)
                Button("Desmarcar todos") { selected.removeAll() }.disabled(saving)
                Spacer()
                Text(selected.count == 1 ? "1 selecionado" : "\(selected.count) selecionados")
                    .font(.caption).foregroundStyle(.secondary)
                Button(saving ? "Importando…" : "Importar seleção", action: apply)
                    .buttonStyle(.borderedProminent).disabled(loading || saving || selected.isEmpty)
                    .accessibilityIdentifier("provider-import.apply")
            }
        }.padding(20)
    }

    private func selection(_ item: ProviderImportItem) -> Binding<Bool> {
        Binding(
            get: { selected.contains(item.id) },
            set: { enabled in
                if enabled {
                    if item.kind == .settings {
                        selected.subtract((preview?.items ?? []).filter { $0.kind == .settings }.map(\.id))
                    }
                    selected.insert(item.id)
                } else {
                    selected.remove(item.id)
                }
            })
    }

    private func scan() async {
        let generation = UUID()
        scanID = generation
        loading = true
        error = nil
        selected.removeAll()
        focused = nil
        do {
            var request = RPCRequest("provider.import.preview")
            request.text = provider.rawValue
            request.id = projectID
            let response = try await store.send(request)
            guard scanID == generation else { return }
            guard let payload = response.payload else { throw HarnessError("Prévia não retornada pelo coordenador.") }
            preview = try Coding.decode(ProviderImportPreview.self, from: Coding.encode(payload))
            focused = preview?.items.first?.id
        } catch {
            if scanID == generation {
                self.error = error.localizedDescription
                preview = nil
            }
        }
        if scanID == generation { loading = false }
    }

    private func apply() {
        guard let preview else { return }
        saving = true
        error = nil
        Task {
            do {
                var request = RPCRequest("provider.import.apply")
                request.id = preview.id
                request.arguments = selected.sorted()
                result = try await store.send(request).text
                await store.refresh()
            } catch { self.error = error.localizedDescription }
            saving = false
        }
    }
}
