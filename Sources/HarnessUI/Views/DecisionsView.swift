import HarnessDomain
import SwiftUI

struct DecisionsView: View {
    var store: AppStore
    @SceneStorage("fronda.decisions.history") private var history = false
    @Environment(\.workspaceNavigation) private var navigation
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
                        subtitle: "Confira o que está pendente e abra a revisão da tarefa ou da operação.")
                    Toggle("Histórico", isOn: $history).toggleStyle(.switch)
                }
                if store.decisionRunID != nil {
                    HStack {
                        Text(runs.first?.title ?? "Esta tarefa não está mais disponível").font(.callout)
                        Spacer()
                        Button("Ver todas as decisões") { store.decisionRunID = nil }
                    }.padding(12).background(FrondaTheme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                if !history && !runs.contains(where: { pendingAction($0) != nil || !visibleApprovals($0).isEmpty }) {
                    EmptyPanel(
                        symbol: "checkmark.bubble", title: "Nenhuma decisão pendente",
                        detail: "Quando uma tarefa precisar de você, a ação aparece aqui.")
                }
                ForEach(runs) { run in
                    if let action = pendingAction(run) {
                        taskDecision(run, action: action)
                    }
                    ForEach(visibleApprovals(run)) { approval in
                        ApprovalCard(store: store, run: run, approval: approval)
                    }
                }
            }.padding(32)
        }
        .rememberScrollPosition("decisions")
        .onDisappear { store.decisionRunID = nil }
    }

    private func pendingAction(_ run: Run) -> RunUserAction? {
        let project = store.snapshot.projects.first { $0.id == run.projectID }
        guard run.state == .waitingUser, let action = RunUserAction.next(for: run, project: project),
            action != .reviewOperations
        else { return nil }
        return action
    }

    private func visibleApprovals(_ run: Run) -> [Approval] {
        run.approvals.filter { approval in
            history || ["PREPARED", "UNKNOWN"].contains(approval.state)
                || (run.state == .waitingUser && ["APPROVED", "SENDING"].contains(approval.state))
        }
    }

    private func taskDecision(_ run: Run, action: RunUserAction) -> some View {
        let destination = action.destination
        return Surface {
            VStack(alignment: .leading, spacing: 10) {
                Text(run.title).font(.headline)
                Text(action.detail).font(.callout).foregroundStyle(.secondary)
                if destination == nil {
                    Text("No início da tarefa, escolha “\(action.title)”.")
                        .font(.callout.weight(.medium))
                }
                Button(destination == nil ? "Abrir tarefa" : action.title) {
                    (navigation ?? store.navigation).visit(
                        WorkspaceLocation(route: "run:" + run.id, section: destination ?? .conversation))
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("decisions.open-task." + run.id)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
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
