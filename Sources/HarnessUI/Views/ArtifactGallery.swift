import AppKit
import HarnessDomain
import QuickLook
import SwiftUI

struct ArtifactGallery: View {
    var store: AppStore
    let run: Run
    @State private var importing = false
    @State private var preview: URL?
    @State private var markdownPreview: MarkdownPreviewContent?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeading(title: "Artefatos da tarefa", detail: "FERRAMENTAS / CLI / IMPORTAÇÃO")
                Spacer()
                Button("Importar artefato…") { importing = true }
                    .disabled(run.state.active || run.workspace.isEmpty || run.state == .archived)
                    .accessibilityIdentifier("evidence.import")
            }
            if (run.evidenceArtifacts ?? []).isEmpty {
                Text(
                    "Capturas, vídeos e relatórios recebidos de extensões aparecem aqui. O recebimento não aprova um cenário automaticamente."
                )
                .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(run.evidenceArtifacts ?? []) { artifact in
                Surface(padding: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(
                                artifact.title,
                                systemImage: artifact.mimeType.hasPrefix("video/") ? "film" : "doc.richtext"
                            )
                            .font(.headline)
                            Spacer()
                            StatusBadge(text: artifact.revision == run.revision ? "RECEIVED" : "STALE")
                        }
                        Text(
                            "\(artifact.source) · \(artifact.mimeType) · \(ByteCountFormatter.string(fromByteCount: Int64(artifact.byteCount), countStyle: .file))"
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        Text("\(artifact.criterionIDs.count) critérios · snapshot \(artifact.revision.prefix(12))")
                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                        HStack {
                            Button("Visualizar") { open(artifact) }
                            Spacer()
                            Toggle(
                                "Disponível para o revisor",
                                isOn: Binding(
                                    get: { artifact.providerReadable },
                                    set: { shared in
                                        store.perform("evidence.share", id: run.id) {
                                            $0.relatedID = artifact.id
                                            $0.flag = shared
                                        }
                                    })
                            ).toggleStyle(.switch).disabled(run.state.active || run.state == .archived)
                        }
                    }
                }
            }
            if !(run.extensionInvocations ?? []).isEmpty {
                DisclosureGroup("Chamadas de extensões") {
                    ForEach(run.extensionInvocations ?? []) { invocation in
                        HStack {
                            Text(invocation.tool).font(.caption.monospaced())
                            Spacer()
                            StatusBadge(text: invocation.state)
                            if ["UNKNOWN", "RUNNING"].contains(invocation.state), !run.state.active {
                                Button("Conferi o destino") {
                                    store.perform("extension.resolve", id: run.id) {
                                        $0.relatedID = invocation.id
                                        $0.text =
                                            "Usuário conferiu o destino e liberou novas chamadas para \(invocation.tool)."
                                    }
                                }
                            }
                        }.padding(.vertical, 5)
                    }
                }
            }
        }.sheet(isPresented: $importing) { ArtifactImporter(store: store, run: run) }
            .sheet(item: $markdownPreview) { MarkdownPreview(content: $0) }
            .quickLookPreview($preview)
    }
    private func open(_ artifact: EvidenceArtifact) {
        Task {
            var request = RPCRequest("evidence.file")
            request.id = run.id
            request.relatedID = artifact.id
            do {
                let url = URL(fileURLWithPath: try await store.send(request).path)
                if artifact.fileExtension == "md", artifact.byteCount <= 1_000_000 {
                    let source = try await Task.detached(priority: .userInitiated) {
                        try String(contentsOf: url, encoding: .utf8)
                    }.value
                    markdownPreview = MarkdownPreviewContent(id: artifact.id, title: artifact.title, source: source)
                } else {
                    preview = url
                }
            } catch {
                store.error = error.localizedDescription
            }
        }
    }
}

private struct ArtifactImporter: View {
    var store: AppStore
    let run: Run
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var path = ""
    @State private var shared = false
    @State private var criteria = Set<String>()
    @State private var error: String?
    @State private var saving = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Importar evidência").font(.title2.weight(.semibold))
            TextField("Título", text: $title)
            Button(
                path.isEmpty ? "Selecionar imagem, vídeo ou relatório…" : URL(fileURLWithPath: path).lastPathComponent
            ) {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = false
                if panel.runModal() == .OK {
                    path = panel.url?.path ?? ""
                    if title.isEmpty { title = panel.url?.lastPathComponent ?? "" }
                }
            }
            ForEach(run.criteria) { criterion in
                Toggle(
                    criterion.text,
                    isOn: Binding(
                        get: { criteria.contains(criterion.id) },
                        set: { selected in
                            if selected { criteria.insert(criterion.id) } else { criteria.remove(criterion.id) }
                        }))
            }
            Toggle("Permitir que o provider leia este conteúdo na revisão", isOn: $shared)
            Text(
                "Imagens podem ser enviadas ao provider. Vídeos fornecem frames solicitados, com timestamp; áudio e sequência completa não são analisados automaticamente."
            )
            .font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Importar") { save() }.buttonStyle(.borderedProminent)
                    .disabled(saving || path.isEmpty || title.isEmpty || criteria.isEmpty)
            }
        }.padding(24).frame(width: 600).onAppear { criteria = Set(run.criteria.map(\.id)) }
    }
    private func save() {
        saving = true
        Task {
            var request = RPCRequest("evidence.register")
            request.id = run.id
            request.expectedSequence = run.sequence
            request.payload = .object([
                "path": .string(path), "title": .string(title), "revision": .string(run.revision),
                "criterionIDs": .array(criteria.sorted().map(JSONValue.string)), "providerReadable": .bool(shared),
            ])
            do {
                _ = try await store.send(request)
                await store.refresh()
                dismiss()
            } catch { self.error = error.localizedDescription }
            saving = false
        }
    }
}
