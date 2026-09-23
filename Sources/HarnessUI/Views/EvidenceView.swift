import HarnessDomain
import SwiftUI

struct EvidenceView: View {
    var store: AppStore
    let run: Run
    @State private var publishing = false
    @State private var exporting = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Surface {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Resultado da run").font(.title2.weight(.semibold))
                            Spacer()
                            StatusBadge(text: run.state.rawValue)
                        }
                        Text(run.reason).font(.callout).foregroundStyle(.secondary)
                        HStack {
                            Button("Exportar pacote de evidências…") { exporting = true }.buttonStyle(
                                .borderedProminent)
                            Button("Preparar publicação…") { publishing = true }.disabled(
                                run.state.active || run.workspace.isEmpty)
                        }
                    }
                }
                SectionHeading(
                    title: "Critério → evidência",
                    detail: "\(run.criteria.filter { $0.state == "SATISFIED" }.count)/\(run.criteria.count) CONFIRMADOS"
                )
                ForEach(run.criteria) { criterion in
                    Surface(padding: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(criterion.text).font(.callout.weight(.medium))
                                Spacer()
                                StatusBadge(text: criterion.state)
                            }
                            Text(
                                criterion.evidence.isEmpty
                                    ? "Sem vínculo de evidência. Requer revisão."
                                    : criterion.evidence.joined(separator: "\n")
                            ).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        }
                    }
                }
                SectionHeading(title: "Rastreabilidade de arquivos")
                ForEach(run.changedFiles) { file in
                    HStack {
                        Text(file.path).font(.caption.monospaced())
                        Spacer()
                        Text(file.linkedCriteria.isEmpty ? "Sem vínculo" : "\(file.linkedCriteria.count) critérios")
                            .font(.caption).foregroundStyle(file.linkedCriteria.isEmpty ? .orange : .secondary)
                    }.padding(.vertical, 7)
                }
                SectionHeading(title: "Operações propostas e confirmadas")
                if run.approvals.isEmpty {
                    Text("Nenhuma operação externa foi proposta.").font(.callout).foregroundStyle(.secondary)
                }
                ForEach(run.approvals) { approval in ApprovalCard(store: store, run: run, approval: approval) }
                Text(
                    "O pacote local inclui manifesto SHA-256, relatório, diff redigido e eventos. Credenciais, sessões e logs brutos ficam fora da exportação."
                ).font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.sheet(isPresented: $publishing) { PublicationView(store: store, run: run) }
            .sheet(isPresented: $exporting) { EvidenceExportView(store: store, run: run) }
    }
}

struct PublicationView: View {
    var store: AppStore
    let run: Run
    @Environment(\.dismiss) private var dismiss
    @State private var kind = "git.commit"
    @State private var destination = ""
    @State private var payload = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Preparar operação").font(.title2.weight(.semibold))
            Text(
                "A operação ficará em Decisões, com payload, destino e hash deste snapshot. A preparação não executa a escrita."
            ).font(.callout).foregroundStyle(.secondary)
            Picker("Ação", selection: $kind) {
                Text("Commit local").tag("git.commit")
                Text("Push da branch").tag("git.push")
                Text("Criar PR GitHub").tag("github.pr")
                Text("Comentário GitHub").tag("github.comment")
                Text("Comentário Jira").tag("jira.comment")
                Text("Transição Jira").tag("jira.transition")
            }
            if !kind.hasPrefix("git.") {
                TextField("Path REST na conexão (ex.: repos/owner/repo/pulls)", text: $destination).textFieldStyle(
                    .roundedBorder)
            }
            Text(kind.hasPrefix("git.") ? "Mensagem / descrição da operação" : "Corpo JSON exato").font(.headline)
            TextEditor(text: $payload).font(.system(size: 12, design: .monospaced)).frame(height: 220).border(
                .quaternary)
            HStack {
                Text("Snapshot \(run.revision.prefix(16))").font(.caption.monospaced()).foregroundStyle(.secondary)
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Preparar proposta") { prepare() }.disabled(payload.isEmpty).buttonStyle(.borderedProminent)
            }
        }.padding(28).frame(width: 720).onAppear { payload = run.title }
            .onChange(of: kind) { _, next in
                if next == "github.pr" {
                    payload =
                        "{\n  \"title\": \"\(run.title)\",\n  \"head\": \"\(run.branch)\",\n  \"base\": \"main\",\n  \"body\": \"\"\n}"
                } else if !next.hasPrefix("git.") {
                    payload = "{\n  \"body\": \"\"\n}"
                } else {
                    payload = run.title
                }
            }
    }
    private func prepare() {
        var approval = Approval()
        approval.kind = kind
        approval.title = kind
        approval.payload = payload
        approval.destination = destination
        store.perform("approval.prepare", id: run.id) {
            $0.approval = approval
            $0.expectedSequence = run.sequence
        }
        dismiss()
    }
}
