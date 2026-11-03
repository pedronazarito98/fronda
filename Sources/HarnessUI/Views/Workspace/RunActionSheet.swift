import HarnessDomain
import SwiftUI

enum RunActionSheet: Hashable, Identifiable {
    case loopPolicy, reproduction, verification, operations
    case step(String)
    var id: Self { self }

    @MainActor @ViewBuilder func content(
        store: AppStore, run: Run, onOpen: @escaping (RunWorkspaceSection) -> Void
    ) -> some View {
        switch self {
        case .loopPolicy: PlanEditorView(store: store, run: run)
        case .reproduction: ScenarioEditor(store: store, run: run, initialPhase: .before)
        case .verification:
            ScenarioEditor(store: store, run: run, initialPhase: run.workflow?.kind == .interface ? .visual : .after)
        case .operations: RunOperationsSheet(store: store, run: run)
        case .step(let id):
            RunStepActivitySheet(store: store, runID: run.id, stepID: id, onOpen: onOpen)
        }
    }
}

private struct RunOperationsSheet: View {
    let store: AppStore
    let run: Run
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let pending = run.approvals.filter { ["PREPARED", "UNKNOWN", "APPROVED", "SENDING"].contains($0.state) }
        VStack(spacing: 0) {
            HStack {
                Text("Operações desta tarefa").font(.headline)
                Spacer()
                Button("Concluído") { dismiss() }
            }.padding(20)
            Divider()
            if pending.isEmpty {
                EmptyPanel(
                    symbol: "checkmark.circle", title: "Nenhuma operação pendente",
                    detail: "O resultado fica disponível em Evidências.")
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(pending) { approval in
                            ApprovalCard(store: store, run: run, approval: approval)
                                .disabled(!store.connected || store.busy.contains(run.id))
                        }
                    }.padding(20)
                }
            }
        }.frame(minWidth: 480, idealWidth: 560, minHeight: 360, idealHeight: 510)
    }
}
