import HarnessDomain
import SwiftUI

struct RunBoardInspector: View {
    let store: AppStore
    let run: Run
    let open: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label(
                            store.snapshot.projects.first(where: { $0.id == run.projectID })?.name ?? "Projeto",
                            systemImage: "folder"
                        ).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Fechar resumo", systemImage: "xmark", action: close)
                            .labelStyle(.iconOnly).help("Fechar o resumo desta tarefa")
                    }
                    Text(run.title).font(.title3.weight(.semibold))
                    FrondaBadge(
                        run.state.label, symbol: RunDisplay.symbol(for: run.state),
                        color: RunDisplay.color(for: run.state))
                    Text(run.source.text).font(.callout).foregroundStyle(.secondary).lineLimit(4)
                    Divider()
                    Text("Etapas da tarefa").font(.headline)
                    ForEach(RunJourneyModel(run: run).steps) { step in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: step.state.symbol).foregroundStyle(step.state.color).frame(width: 20)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.title).font(.callout.weight(.medium))
                                Text(step.state.label).font(.caption).foregroundStyle(step.state.color)
                            }
                        }
                    }
                    if let loop = RunFollowupModel(run: run, isConnected: store.connected).loopSummary {
                        FrondaBadge(loop, symbol: "arrow.triangle.2.circlepath", color: FrondaTheme.reference)
                    }
                    Divider()
                    Text("Próximo passo").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(RunDisplay.nextAction(for: run, in: store.snapshot)).font(.callout)
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            Button(action: open) {
                HStack {
                    Text("Abrir tarefa")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .help("Abrir o fluxo e as ações desta tarefa")
            .padding(16)
        }.background(FrondaTheme.surface)
    }
}
