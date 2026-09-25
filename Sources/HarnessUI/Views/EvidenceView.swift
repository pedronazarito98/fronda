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
                                run.state != .ready || run.workspace.isEmpty)
                        }
                    }
                }
                ArtifactGallery(store: store, run: run)
                if run.workflow != nil {
                    DeliveryStatusView(store: store, run: run)
                    DisclosureGroup("Cenários e mídias (\(run.workflow?.observations.count ?? 0))") {
                        ScenarioEvidenceView(store: store, run: run).frame(minHeight: 320)
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
                                MarkdownView(criterion.text)
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
