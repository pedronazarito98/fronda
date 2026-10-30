import HarnessDomain
import SwiftUI

struct DeliveryStatusView: View {
    var store: AppStore
    let run: Run
    @State private var closing = false
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 14) {
                Label("Entrega e encerramento", systemImage: "shippingbox").font(.headline)
                Text(run.nextAction).foregroundStyle(.secondary)
                if let delivery = run.workflow?.delivery {
                    if let sha = delivery.commitSHA {
                        LabeledContent("Commit", value: String(sha.prefix(12))).font(.caption.monospaced())
                    }
                    if let url = delivery.pullRequestURL, let destination = URL(string: url) {
                        Link("Abrir pull request", destination: destination)
                    }
                    if let merged = delivery.mergedAt {
                        Text("Merge confirmado em \(merged.formatted())").font(.caption)
                    }
                    if delivery.pullRequestPath != nil && delivery.closedAt == nil {
                        HStack {
                            Button("Consultar merge") { store.perform("delivery.refresh", id: run.id) }
                            if delivery.mergedAt != nil { Button("Encerrar e liberar worktree…") { closing = true } }
                        }.disabled(run.state.active || store.busy.contains(run.id))
                    }
                    if !run.mode.writes && run.state == .ready {
                        Button("Consolidar investigação") {
                            store.perform("delivery.close", id: run.id) { $0.expectedSequence = run.sequence }
                        }
                    }
                    if delivery.closedAt != nil {
                        Label("Diário consolidado · evidências preservadas", systemImage: "checkmark.seal")
                            .foregroundStyle(.green)
                    }
                }
                Text(
                    "Cada operação tem sua própria prévia e autorização. A limpeza exige merge confirmado e ausência de arquivos ou commits adicionais."
                ).font(.caption).foregroundStyle(.secondary)
            }
        }.confirmationDialog("Encerrar esta tarefa?", isPresented: $closing) {
            Button("Consolidar diário e remover worktree limpa") {
                store.perform("delivery.close", id: run.id) { $0.expectedSequence = run.sequence }
            }
        } message: {
            Text(
                "O Fronda consultará o merge e conferirá o HEAD novamente. Arquivos adicionais impedem a remoção. O diário e as mídias serão preservados."
            )
        }
    }
}
