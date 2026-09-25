import HarnessDomain
import SwiftUI

struct WorkflowOverview: View {
    var store: AppStore
    let run: Run
    @State private var selectedStep: String?
    private var selected: RunbookStep? {
        run.plan.first { $0.id == selectedStep }
            ?? (!run.contextApproved ? run.plan.first { $0.kind == "context" } : run.currentStep) ?? run.plan.last
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(run.plan) { step in
                        Button {
                            selectedStep = step.id
                        } label: {
                            HStack(spacing: 6) {
                                Image(
                                    systemName: step.status == .pass
                                        ? "checkmark.circle.fill" : step.status == .blocked ? "pause.circle" : "circle")
                                Text(step.title)
                            }.font(.caption).padding(10)
                                .background(
                                    selected?.id == step.id ? HarnessTheme.accent.opacity(0.12) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                            .accessibilityLabel("\(step.title), \(step.status.rawValue)")
                    }
                }.padding(16)
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(run.stageLabel).font(.headline)
                    Text(run.reason).font(.callout).foregroundStyle(.secondary).fixedSize(
                        horizontal: false, vertical: true)
                }
                Spacer()
                if let selected { StatusBadge(text: selected.status.rawValue) }
            }.padding(20)
            Divider()
            Group {
                switch selected?.kind {
                case "context": ContextView(store: store, run: run)
                case "investigation": InvestigationSummary(run: run)
                case "plan": RunPlanView(store: store, run: run)
                case "reproduction", "verification": ScenarioEvidenceView(store: store, run: run)
                case "validation": ValidationView(store: store, run: run)
                case "review": ReviewView(store: store, run: run)
                case "evidence": EvidenceView(store: store, run: run)
                default: DiffView(store: store, run: run)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct InvestigationSummary: View {
    let run: Run
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeading(title: "Diagnóstico do projeto", detail: "SOMENTE LEITURA")
                if let investigation = run.workflow?.investigation, !investigation.isEmpty {
                    Surface {
                        MarkdownView(investigation)
                    }
                } else {
                    EmptyPanel(
                        symbol: "doc.text.magnifyingglass",
                        title: run.state.active ? "Investigando o código" : "Diagnóstico ainda não produzido",
                        detail:
                            "O executor examina o fluxo real, identifica os arquivos envolvidos e preserva o resultado para fundamentar a proposta."
                    )
                }
            }.padding(24)
        }
    }
}
