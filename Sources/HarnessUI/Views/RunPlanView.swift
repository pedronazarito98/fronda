import HarnessDomain
import SwiftUI

struct RunPlanView: View {
    var store: AppStore
    let run: Run
    @State private var editing = false
    @State private var skipping: RunbookStep?
    @State private var reason = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    SectionHeading(title: "Plano de execução", detail: "REVISÃO \(run.planRevision)")
                    Button("Editar plano") { editing = true }.disabled(run.state.active)
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
        }.sheet(isPresented: $editing) { PlanEditorView(store: store, run: run) }
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
                        Text("\(index + 1)").font(.title3.monospaced()).foregroundStyle(HarnessTheme.accent)
                        Text(step.title).font(.headline)
                        Spacer()
                        StatusBadge(text: step.status.rawValue)
                    }
                    Text(
                        "\(step.kind) · depende de \(step.dependencies.isEmpty ? "nenhuma etapa" : step.dependencies.joined(separator: ", "))"
                    ).font(.caption).foregroundStyle(.secondary)
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

struct PlanEditorView: View {
    var store: AppStore
    @State var run: Run
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack {
            HStack {
                Text("Editar plano").font(.title2.weight(.semibold))
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Salvar revisão") {
                    store.perform("plan.save", id: run.id) {
                        $0.run = run
                        $0.expectedSequence = run.sequence
                    }
                    dismiss()
                }.buttonStyle(.borderedProminent)
            }.padding(20)
            Form {
                Section("Etapas") {
                    ForEach($run.plan) { $step in
                        VStack(alignment: .leading) {
                            TextField(step.kind, text: $step.title)
                            TextField(
                                "Paths da etapa, separados por vírgula",
                                text: Binding(
                                    get: { step.paths.joined(separator: ",") },
                                    set: {
                                        step.paths = $0.split(separator: ",").map {
                                            $0.trimmingCharacters(in: .whitespaces)
                                        }
                                    }))
                            TextField(
                                "IDs dos critérios",
                                text: Binding(
                                    get: { step.criteria.joined(separator: ",") },
                                    set: {
                                        step.criteria = $0.split(separator: ",").map {
                                            $0.trimmingCharacters(in: .whitespaces)
                                        }
                                    }))
                        }
                    }
                }
                Section("Critérios") {
                    ForEach($run.criteria) { $criterion in
                        VStack(alignment: .leading) {
                            TextField("Critério", text: $criterion.text, axis: .vertical)
                            Text(criterion.id).font(.caption.monospaced()).textSelection(.enabled)
                        }
                    }
                    Button("Adicionar critério") { run.criteria.append(Criterion()) }
                }
                Section("Escopo e orçamento") {
                    TextField(
                        "Paths",
                        text: Binding(
                            get: { run.scope.joined(separator: "\n") },
                            set: { run.scope = $0.split(separator: "\n").map(String.init) }), axis: .vertical)
                    Stepper("\(run.budget) tokens", value: $run.budget, in: 1000...500000, step: 1000)
                }
            }.formStyle(.grouped)
        }.frame(width: 680, height: 680)
    }
}
