import HarnessDomain
import SwiftUI

struct RunPlanDetailsView: View {
    var store: AppStore
    let run: Run
    @Environment(\.workspaceIsSidePane) private var isSidePane
    @State private var editing = false
    @State private var editingExecution = false
    @State private var skipping: RunbookStep?
    @State private var reason = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                (isSidePane ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout())) {
                    SectionHeading(title: "Plano de execução", detail: "REVISÃO \(run.planRevision)")
                    Button("Editar plano") { editing = true }.disabled(run.state.active)
                    Button("Modelos e agentes") { editingExecution = true }.disabled(run.state.active)
                }
                if let workflow = run.workflow {
                    if !workflow.proposal.isEmpty {
                        Surface {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Proposta de implementação", systemImage: "doc.text.magnifyingglass").font(
                                    .headline)
                                MarkdownView(workflow.proposal)
                            }
                        }
                    }
                    if !workflow.investigation.isEmpty {
                        DisclosureGroup("Diagnóstico do projeto") {
                            MarkdownView(workflow.investigation)
                        }
                    }
                }
                Text(
                    "Cada revisão permanece no histórico. Alterar critérios ou escopo exige nova aprovação e invalida as evidências dependentes."
                ).font(.callout).foregroundStyle(.secondary)
                if run.workflow != nil {
                    DisclosureGroup("Etapas e configuração do plano") { stepList }
                } else {
                    stepList
                }
            }.padding(24)
        }.rememberScrollPosition(
            "run.\(run.id).plan", startAtTop: !run.planApproved && run.workflow?.proposal.isEmpty == false
        )
        .sheet(isPresented: $editing) { PlanEditorView(store: store, run: run) }
        .sheet(isPresented: $editingExecution) { RunExecutionEditor(store: store, run: run) }
        .sheet(item: $skipping) { step in
            VStack(alignment: .leading, spacing: 18) {
                Text("Pular \(step.title)").font(.title2)
                Text("Uma exceção em etapa obrigatória mantém o resultado PARTIAL.").foregroundStyle(.secondary)
                TextField("Justificativa", text: $reason, axis: .vertical)
                HStack {
                    Button("Cancelar") { skipping = nil }
                    Spacer()
                    Button("Registrar exceção") {
                        store.perform("step.skip", id: run.id) {
                            $0.relatedID = step.id
                            $0.text = reason
                        }
                        skipping = nil
                    }.disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(24).frame(width: 540)
        }
    }
    private var stepList: some View {
        ForEach(Array(run.plan.enumerated()), id: \.element.id) { index, step in
            Surface {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(index + 1)").font(.title3.monospaced()).foregroundStyle(FrondaTheme.accent)
                        Text(step.title).font(.headline)
                        Spacer()
                        StatusBadge(text: step.status.rawValue)
                    }
                    Text(
                        "\(step.kind) · depende de \(step.dependencies.isEmpty ? "nenhuma etapa" : step.dependencies.joined(separator: ", "))"
                    ).font(.caption).foregroundStyle(.secondary)
                    if step.usesAgent {
                        Label(
                            "\((step.provider ?? run.provider).rawValue) · \(step.execution(in: run).summary)",
                            systemImage: "cpu"
                        )
                        .font(.caption).foregroundStyle(FrondaTheme.accent)
                    }
                    if !step.paths.isEmpty {
                        Text(step.paths.joined(separator: ", ")).font(.caption.monospaced())
                    }
                    HStack {
                        Button("Tentar novamente a partir daqui") {
                            store.perform("step.retry", id: run.id) {
                                $0.relatedID = step.id
                                $0.expectedSequence = run.sequence
                            }
                        }.disabled(run.state.active)
                        Button("Pular com justificativa…") {
                            reason = ""
                            skipping = step
                        }.disabled(run.state.active || step.status == .pass)
                    }.font(.caption)
                }
            }
        }
    }

}
