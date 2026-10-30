import HarnessDomain
import SwiftUI

struct DecisionsView: View {
    var store: AppStore
    @SceneStorage("fronda.decisions.history") private var history = false
    private var runs: [Run] {
        guard let id = store.decisionRunID else { return store.snapshot.runs }
        return store.snapshot.runs.filter { $0.id == id }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    PageHeading(
                        eyebrow: "Você mantém o controle", title: "Decisões",
                        subtitle: "Revise o conteúdo, o destino e o impacto de cada operação.")
                    Toggle("Histórico", isOn: $history).toggleStyle(.switch)
                }
                if store.decisionRunID != nil {
                    HStack {
                        Text(runs.first?.title ?? "Esta tarefa não está mais disponível").font(.callout)
                        Spacer()
                        Button("Ver todas as decisões") { store.decisionRunID = nil }
                    }.padding(12).background(FrondaTheme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                if store.pendingDecisions == 0 && !history {
                    EmptyPanel(
                        symbol: "checkmark.bubble", title: "Nenhuma decisão pendente",
                        detail: "Quando uma run precisar de você, o pedido aparece aqui com a proposta exata.")
                }
                ForEach(runs) { run in
                    if run.state == .waitingUser {
                        Surface {
                            HStack {
                                VStack(alignment: .leading, spacing: 9) {
                                    Text(run.title).font(.headline)
                                    Text(run.nextAction).font(.callout).foregroundStyle(
                                        .secondary)
                                    Text("Destino: \(run.provider.rawValue) · pack \(run.pack?.hash.prefix(12) ?? "")")
                                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Inspecionar run") { store.route = "run:" + run.id }.buttonStyle(
                                    .borderedProminent)
                            }
                        }
                    }
                    ForEach(run.approvals.filter { history || $0.state == "PREPARED" }) { approval in
                        ApprovalCard(store: store, run: run, approval: approval)
                    }
                }
            }.padding(32)
        }
        .rememberScrollPosition("decisions")
        .onDisappear { store.decisionRunID = nil }
    }
}

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
                        Button("Recusar") { decide(false) }
                        Button("Aprovar esta operação…") { confirming = true }.buttonStyle(.borderedProminent).disabled(
                            run.state.active)
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
                }
            }
        }
        .confirmationDialog("Executar esta operação exata?", isPresented: $confirming) {
            Button("Aprovar e executar") { decide(true) }
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
