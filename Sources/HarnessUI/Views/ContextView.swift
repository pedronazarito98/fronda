import HarnessDomain
import SwiftUI

struct ContextView: View {
    var store: AppStore
    let run: Run
    @State private var mode = "Selecionados"
    @State private var query = ""
    @State private var attemptID = ""
    @State private var attemptPayload = ""
    private var items: [ContextItem] {
        (run.pack?.items ?? []).filter {
            (query.isEmpty || $0.path.localizedCaseInsensitiveContains(query)
                || $0.symbols.contains { $0.localizedCaseInsensitiveContains(query) })
                && (mode == "Excluídos" ? !$0.included : mode == "Selecionados" ? $0.included : true)
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Inspector", selection: $mode) {
                    ForEach(
                        ["Selecionados", "Candidatos", "Excluídos", "Grafo", "Payload exato", "Tentativas"], id: \.self
                    ) { Text($0) }
                }.pickerStyle(.segmented)
            }.padding(18)
            if let pack = run.pack {
                HStack {
                    Text("v\(pack.version)").font(.caption.monospaced())
                    Label(run.provider.rawValue, systemImage: "arrow.up.right.square")
                    Text("\(pack.estimatedTokens.formatted()) tokens estimados")
                    Spacer()
                    Text("SHA \(pack.hash.prefix(12))").font(.caption.monospaced())
                }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.bottom, 14)
                Divider()
                if mode == "Payload exato" {
                    MonospaceBlock(text: pack.payload).padding(14)
                } else if mode == "Tentativas" {
                    Picker("Payload enviado", selection: $attemptID) {
                        Text("Selecione uma tentativa").tag("")
                        ForEach(run.attempts) { attempt in
                            Text("\(attempt.provider.rawValue) · \(attempt.stepID) · \(attempt.startedAt.formatted())")
                                .tag(attempt.id)
                        }
                    }.padding(16)
                    MonospaceBlock(text: attemptPayload).padding(14)
                } else if mode == "Grafo" {
                    ContextGraphView(store: store, run: run)
                } else {
                    TextField("Filtrar paths e símbolos…", text: $query).textFieldStyle(.roundedBorder).padding(16)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(items) { item in
                                Surface(padding: 15) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(alignment: .top) {
                                            Image(systemName: item.included ? "doc.text" : "doc.badge.ellipsis")
                                                .foregroundStyle(item.included ? HarnessTheme.accent : .secondary)
                                            Text(item.path).font(
                                                .system(size: 12, weight: .medium, design: .monospaced)
                                            ).textSelection(.enabled)
                                            Spacer()
                                            Text("~\(item.estimatedTokens)").font(.caption.monospaced())
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(item.reason).font(.caption).foregroundStyle(.secondary)
                                        if !item.symbols.isEmpty {
                                            Text(item.symbols.prefix(8).joined(separator: " · ")).font(
                                                .system(size: 10, design: .monospaced)
                                            ).foregroundStyle(.secondary).lineLimit(2)
                                        }
                                        HStack {
                                            Text("\(item.classification) · \(item.hash.prefix(10))").font(
                                                .system(size: 9, design: .monospaced)
                                            ).foregroundStyle(.tertiary)
                                            Spacer()
                                            Button("Abrir") { store.openFile(run.workspace + "/" + item.path) }
                                                .disabled(item.path.hasPrefix("attachments/"))
                                            action(
                                                run.pins.contains(item.path) ? "Desafixar" : "Fixar", "pin",
                                                path: item.path)
                                            action(
                                                run.exclusions.contains(item.path) ? "Reincluir" : "Excluir", "exclude",
                                                path: item.path)
                                            action(
                                                run.lockedPaths.contains(item.path) ? "Destravar" : "Travar", "lock",
                                                path: item.path)
                                        }.font(.caption)
                                    }
                                }
                            }
                        }.padding(.horizontal, 18).padding(.bottom, 20)
                    }
                }
                Text(pack.estimateMethod).font(.system(size: 9)).foregroundStyle(.tertiary).padding(10)
            } else {
                Spacer()
                EmptyPanel(
                    symbol: "point.3.connected.trianglepath.dotted", title: "Contexto ainda não compilado",
                    detail:
                        "Prepare a run para examinar os arquivos, critérios e o payload antes de enviar ao provider.")
                Spacer()
            }
        }
        .task(id: attemptID) {
            guard !attemptID.isEmpty else { return }
            var request = RPCRequest("attempt.payload")
            request.id = run.id
            request.relatedID = attemptID
            do { attemptPayload = try await store.send(request).text } catch {
                attemptPayload = error.localizedDescription
            }
        }
    }
    private func action(_ label: String, _ action: String, path: String) -> some View {
        Button(label) {
            store.perform("context.update", id: run.id) {
                $0.text = action
                $0.path = path
            }
        }.disabled(run.state.active).buttonStyle(.borderless)
    }
}

struct ContextGraphView: View {
    var store: AppStore
    let run: Run
    @State private var query = ""
    @State private var relation = "Todas"
    var nodes: [ContextItem] {
        (run.pack?.items ?? []).filter {
            $0.included
                && (query.isEmpty || $0.path.localizedCaseInsensitiveContains(query)
                    || $0.symbols.contains(where: { $0.localizedCaseInsensitiveContains(query) }))
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                TextField("Buscar arquivo ou símbolo no grafo", text: $query).textFieldStyle(.roundedBorder)
                Picker("Relações", selection: $relation) {
                    ForEach(["Todas", "Imports", "Referências", "Testes", "Histórico"], id: \.self) { Text($0) }
                }.pickerStyle(.segmented)
                Surface {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("Objetivo e critérios", systemImage: "scope").font(.headline).foregroundStyle(
                            HarnessTheme.accent)
                        Text(run.title).font(.callout)
                        Text("Expandindo um salto: objetivo → arquivos selecionados → símbolos detectados.").font(
                            .caption
                        ).foregroundStyle(.secondary)
                    }
                }
                ForEach(nodes) { node in
                    HStack(alignment: .top, spacing: 20) {
                        Image(systemName: "arrow.turn.down.right").foregroundStyle(.tertiary).padding(.top, 12)
                        Surface(padding: 15) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(node.path).font(.system(size: 12, weight: .semibold, design: .monospaced))
                                Text(node.reason).font(.caption).foregroundStyle(.secondary)
                                if !node.symbols.isEmpty {
                                    DisclosureGroup("\(node.symbols.count) símbolos · Tree-sitter") {
                                        VStack(alignment: .leading, spacing: 7) {
                                            ForEach(Array(node.symbols.enumerated()), id: \.offset) { _, symbol in
                                                Label(symbol, systemImage: "curlybraces").font(.caption.monospaced())
                                            }
                                        }.padding(.top, 10)
                                    }
                                }
                                if ["Todas", "Imports"].contains(relation), !node.imports.isEmpty {
                                    DisclosureGroup("Imports detectados") {
                                        Text(node.imports.joined(separator: "\n")).font(.caption.monospaced())
                                            .textSelection(.enabled)
                                    }
                                }
                                if ["Todas", "Referências"].contains(relation), let references = node.references,
                                    !references.isEmpty
                                {
                                    DisclosureGroup("Chamadas sintáticas · \(references.count)") {
                                        Text(references.joined(separator: "\n")).font(.caption.monospaced())
                                            .textSelection(.enabled)
                                    }
                                }
                                if ["Todas", "Testes"].contains(relation), let tests = node.associatedTests,
                                    !tests.isEmpty
                                {
                                    DisclosureGroup("Testes relacionados pelo nome do arquivo") {
                                        ForEach(tests, id: \.self) { path in
                                            Button(path) { store.openFile(run.workspace + "/" + path) }.font(
                                                .caption.monospaced())
                                        }
                                    }
                                }
                                if ["Todas", "Histórico"].contains(relation), let history = node.gitHistory,
                                    !history.isEmpty
                                {
                                    DisclosureGroup("Histórico Git recente") {
                                        Text(history.joined(separator: "\n")).font(.caption.monospaced()).textSelection(
                                            .enabled)
                                    }
                                }
                                HStack {
                                    Button("Abrir arquivo") { store.openFile(run.workspace + "/" + node.path) }
                                    Button(run.pins.contains(node.path) ? "Desafixar" : "Fixar") {
                                        store.perform("context.update", id: run.id) {
                                            $0.path = node.path
                                            $0.text = "pin"
                                        }
                                    }
                                    Button(run.lockedPaths.contains(node.path) ? "Destravar" : "Travar") {
                                        store.perform("context.update", id: run.id) {
                                            $0.path = node.path
                                            $0.text = "lock"
                                        }
                                    }
                                }.font(.caption).disabled(run.state.active || node.path.hasPrefix("attachments/"))
                            }
                        }
                    }
                }
                Text(
                    "Lista acessível por teclado e VoiceOver. Definições e imports extraídos de árvores sintáticas; a relevância por objetivo é calculada separadamente."
                ).font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }
    }
}
