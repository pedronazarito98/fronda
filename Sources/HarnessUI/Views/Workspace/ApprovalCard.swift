import HarnessDomain
import SwiftUI

struct ApprovalCard: View {
    var store: AppStore
    let run: Run
    let approval: Approval
    @State private var confirming = false
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "hand.raised").foregroundStyle(FrondaTheme.accent)
                    Text(approval.title).font(.headline)
                    Spacer()
                    StatusBadge(text: approval.state)
                }
                Text(run.title).font(.callout).foregroundStyle(.secondary)
                LabeledContent("Destino", value: approval.destination).font(.caption).textSelection(.enabled)
                if let endpoint = approval.endpoint {
                    LabeledContent("Conexão", value: endpoint).font(.caption).textSelection(.enabled)
                }
                MonospaceBlock(text: approval.payload).frame(minHeight: 100, maxHeight: 250)
                Text("Digest \(approval.payloadHash.prefix(20)) · snapshot \(approval.revision.prefix(12))").font(
                    .system(size: 9, design: .monospaced)
                ).foregroundStyle(.secondary)
                if approval.state == "PREPARED" {
                    HStack {
                        Text("Válida até \(approval.expiresAt.formatted(date: .abbreviated, time: .shortened))").font(
                            .caption
                        ).foregroundStyle(.secondary)
                        Spacer()
                        Button("Recusar") { decide(false) }.disabled(!run.pauseAllowsContinuation)
                        Button("Aprovar esta operação…") { confirming = true }.buttonStyle(.borderedProminent).disabled(
                            run.state.active || !run.pauseAllowsContinuation)
                    }
                } else if !approval.result.isEmpty {
                    DisclosureGroup("Resultado observado") {
                        Text(approval.result).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
                if approval.state == "UNKNOWN" {
                    Button("Consultar destino sem repetir operação") {
                        store.perform("approval.reconcile", id: run.id) { $0.relatedID = approval.id }
                    }
                    .disabled(!run.pauseAllowsContinuation)
                }
            }
        }
        .confirmationDialog("Executar esta operação exata?", isPresented: $confirming) {
            Button("Aprovar e executar") { decide(true) }.disabled(!run.pauseAllowsContinuation)
        } message: {
            Text("\(approval.kind)\n\(approval.destination)\nA aprovação vale apenas para este payload e snapshot.")
        }
    }
    private func decide(_ granted: Bool) {
        store.perform("approval.decide", id: run.id) {
            $0.relatedID = approval.id
            $0.flag = granted
            $0.expectedSequence = run.sequence
        }
    }
}
