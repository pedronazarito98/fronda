import AppKit
import HarnessDomain
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct ScenarioEvidenceView: View {
    var store: AppStore
    let run: Run
    @State private var adding = false
    @State private var preview: URL?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    SectionHeading(title: "Cenários e evidências", detail: "ANTES / DEPOIS")
                    Button("Registrar cenário") { adding = true }.buttonStyle(.borderedProminent)
                        .disabled(run.state.active || run.state == .archived || run.workspace.isEmpty)
                }
                Text(
                    "Registre o comportamento observado, o ambiente e os critérios conferidos. PASS na reprodução significa que o problema foi reproduzido; na conferência, que o resultado esperado foi observado."
                )
                .font(.callout).foregroundStyle(.secondary)
                if run.workflow?.observations.isEmpty != false {
                    EmptyPanel(
                        symbol: "viewfinder", title: "A evidência começa no cenário",
                        detail:
                            "Imagens e vídeos ficam disponíveis no diário imediatamente e são preservados ao encerrar a tarefa."
                    )
                }
                ForEach(run.workflow?.observations ?? []) { item in
                    Surface {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label(
                                    item.phase.label,
                                    systemImage: item.phase == .before ? "backward.end" : "checkmark.viewfinder")
                                Spacer()
                                StatusBadge(
                                    text: item.phase != .before && item.revision != run.revision
                                        ? "STALE" : item.status.rawValue)
                            }.font(.caption)
                            Text(item.scenario).font(.headline)
                            Text("Esperado").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            MarkdownView(item.expected)
                            Text("Observado").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            MarkdownView(item.observed)
                            Text(item.environment).font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Text(
                                    "\(item.source ?? "Observação humana") · \(item.createdAt.formatted(date: .abbreviated, time: .shortened))"
                                ).font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                if item.mediaHash != nil {
                                    Button("Abrir imagem ou vídeo") {
                                        Task {
                                            var request = RPCRequest("evidence.media")
                                            request.id = run.id
                                            request.relatedID = item.id
                                            do {
                                                preview = URL(fileURLWithPath: try await store.send(request).path)
                                            } catch { store.error = error.localizedDescription }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }.padding(24)
        }.sheet(isPresented: $adding) { ScenarioEditor(store: store, run: run) }
            .quickLookPreview($preview)
    }
}

private struct ScenarioEditor: View {
    var store: AppStore
    let run: Run
    @Environment(\.dismiss) private var dismiss
    @State private var evidence = ScenarioEvidence()
    @State private var mediaPath = ""
    @State private var shareMedia = false
    @State private var saving = false
    @State private var error: String?
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Registrar observação").font(.title2.weight(.semibold))
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Salvar evidência") { save() }.buttonStyle(.borderedProminent).disabled(saving)
            }.padding(20)
            Form {
                Section("Cenário") {
                    Picker("Momento", selection: $evidence.phase) {
                        ForEach(ObservationPhase.allCases) { Text($0.label).tag($0) }
                    }
                    TextField("Nome do cenário", text: $evidence.scenario)
                    if evidence.phase == .after {
                        ForEach(run.workflow?.observations.filter { $0.phase == .before && $0.status == .pass } ?? []) {
                            baseline in
                            Button("Repetir: " + baseline.scenario) {
                                evidence.scenario = baseline.scenario
                                evidence.environment = baseline.environment
                                evidence.criterionIDs = baseline.criterionIDs
                            }
                        }
                    }
                    TextField("Comportamento esperado", text: $evidence.expected, axis: .vertical)
                    TextField("O que foi observado", text: $evidence.observed, axis: .vertical)
                    TextField("Ambiente, viewport ou dispositivo", text: $evidence.environment)
                    Picker("Resultado observado", selection: $evidence.status) {
                        ForEach([GateStatus.notRun, .pass, .fail, .blocked], id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Critérios conferidos") {
                    ForEach(run.criteria) { criterion in
                        Toggle(
                            criterion.text,
                            isOn: Binding(
                                get: { evidence.criterionIDs.contains(criterion.id) },
                                set: { included in
                                    evidence.criterionIDs.removeAll { $0 == criterion.id }
                                    if included { evidence.criterionIDs.append(criterion.id) }
                                }))
                    }
                }
                Section("Artefato já recebido") {
                    Picker(
                        "Vincular artefato",
                        selection: Binding(
                            get: { evidence.artifactID ?? "" }, set: { evidence.artifactID = $0.isEmpty ? nil : $0 })
                    ) {
                        Text("Nenhum").tag("")
                        ForEach((run.evidenceArtifacts ?? []).filter { $0.revision == run.revision }) {
                            Text($0.title).tag($0.id)
                        }
                    }
                }
                Section("Imagem ou vídeo") {
                    Button(
                        mediaPath.isEmpty ? "Selecionar arquivo…" : URL(fileURLWithPath: mediaPath).lastPathComponent
                    ) {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.png, .jpeg, .heic, .mpeg4Movie, .quickTimeMovie]
                        panel.canChooseDirectories = false
                        if panel.runModal() == .OK { mediaPath = panel.url?.path ?? "" }
                    }
                    Toggle("Disponibilizar a mídia para o revisor", isOn: $shareMedia)
                    Text(
                        "Até 100 MB. Ao compartilhar, imagens ou frames de vídeo podem ser enviados ao provider durante a revisão."
                    ).font(.caption).foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.formStyle(.grouped)
        }.frame(width: 680, height: 690)
            .onAppear {
                evidence.phase = !run.planApproved ? .before : run.workflow?.kind == .interface ? .visual : .after
                evidence.criterionIDs = run.criteria.map(\.id)
            }
    }
    private func save() {
        saving = true
        Task {
            var request = RPCRequest("scenario.record")
            request.id = run.id
            request.expectedSequence = run.sequence
            request.observation = evidence
            request.path = mediaPath
            do {
                if !mediaPath.isEmpty, evidence.artifactID == nil {
                    var intake = RPCRequest("evidence.register")
                    intake.id = run.id
                    intake.expectedSequence = run.sequence
                    intake.payload = .object([
                        "path": .string(mediaPath), "title": .string(evidence.scenario),
                        "revision": .string(run.revision),
                        "criterionIDs": .array(evidence.criterionIDs.map(JSONValue.string)),
                        "providerReadable": .bool(shareMedia),
                    ])
                    request.observation?.artifactID = try await store.send(intake).id
                    request.path = ""
                    request.expectedSequence = nil
                }
                _ = try await store.send(request)
                await store.refresh()
                dismiss()
            } catch { self.error = error.localizedDescription }
            saving = false
        }
    }
}
