import HarnessDomain
import SwiftUI

struct ReviewView: View {
    var store: AppStore
    let run: Run
    @State private var selected: ReviewFinding?
    @State private var justification = ""
    @State private var confirming = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    SectionHeading(
                        title: "Revisão e Scope Guard",
                        detail: "\(run.findings.filter { $0.state == "OPEN" }.count) EM ABERTO")
                    Button("Confirmar revisão humana…") { confirming = true }.disabled(run.state.active)
                }
                if run.findings.isEmpty {
                    EmptyPanel(
                        symbol: "checkmark.shield", title: "Nenhum achado registrado",
                        detail: run.reviewRevision.isEmpty
                            ? "A revisão independente ainda não foi concluída. A ausência de achados não indica aprovação."
                            : "Confira os critérios e a validação antes de confirmar a revisão humana.")
                }
                ForEach(run.findings) { finding in
                    Surface {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(finding.severity).font(.caption.monospaced()).foregroundStyle(.orange)
                                Text(finding.title).font(.headline)
                                Spacer()
                                StatusBadge(text: finding.state)
                            }
                            if !finding.path.isEmpty { Text(finding.path).font(.caption.monospaced()) }
                            MarkdownView(finding.evidence)
                            Text("\(finding.author) · snapshot \(finding.revision.prefix(12))").font(.caption)
                                .foregroundStyle(.secondary)
                            if finding.state == "OPEN" {
                                Button("Resolver achado…") {
                                    justification = ""
                                    selected = finding
                                }
                            } else {
                                MarkdownView(finding.resolution)
                            }
                        }
                    }
                }
            }.padding(24)
        }
        .sheet(item: $selected) { finding in
            VStack(alignment: .leading, spacing: 20) {
                Text("Resolver achado").font(.title2)
                Text(finding.title).font(.headline)
                TextField("Justificativa e evidência", text: $justification, axis: .vertical).lineLimit(4...8)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancelar") { selected = nil }
                    Spacer()
                    Button("Aceitar risco") { resolve(finding, risk: true) }.disabled(justification.isEmpty)
                    Button("Confirmar resolução") { resolve(finding, risk: false) }.disabled(justification.isEmpty)
                        .buttonStyle(.borderedProminent)
                }
            }.padding(28).frame(width: 580)
        }
        .confirmationDialog("Confirmar os critérios neste snapshot?", isPresented: $confirming) {
            Button("Revisei o diff e confirmo os critérios") {
                store.perform("review.accept", id: run.id) {
                    $0.flag = true
                    $0.expectedSequence = run.sequence
                }
            }
            Button("Registrar revisão com critérios pendentes") {
                store.perform("review.accept", id: run.id) {
                    $0.flag = false
                    $0.expectedSequence = run.sequence
                }
            }
        } message: {
            Text(
                "Sua confirmação ficará registrada como evidência humana. Gates pendentes ou achados abertos continuam impedindo READY."
            )
        }
    }
    private func resolve(_ finding: ReviewFinding, risk: Bool) {
        store.perform("review.resolve", id: run.id) {
            $0.relatedID = finding.id
            $0.text = justification
            $0.flag = risk
        }
        selected = nil
    }
}
