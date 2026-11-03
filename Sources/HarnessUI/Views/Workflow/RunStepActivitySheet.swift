import HarnessDomain
import SwiftUI

struct RunStepActivitySheet: View {
    let store: AppStore
    let runID: String
    let stepID: String
    let onOpen: (RunWorkspaceSection) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var inspectedDependency: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Dentro da etapa", systemImage: "list.bullet.indent").font(.headline)
                Spacer()
                Button("Concluído") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(.horizontal, 24).padding(.vertical, 16)
            Divider()
            if let run = store.snapshot.runs.first(where: { $0.id == runID }),
                let selected = RunJourneyModel(run: run).steps.first(where: { $0.id == (inspectedDependency ?? stepID) }
                )
            {
                RunJourneyDetail(
                    store: store, run: run, selected: selected,
                    onOpen: { destination in
                        dismiss()
                        onOpen(destination)
                    },
                    onSelectStep: { inspectedDependency = $0 })
            } else {
                ContentUnavailableView(
                    "Etapa indisponível", systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("O plano desta tarefa mudou. Confira as etapas na tarefa."))
            }
        }
        .frame(minWidth: 420, idealWidth: 620, minHeight: 360, idealHeight: 620)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("step.activity-sheet")
    }
}
