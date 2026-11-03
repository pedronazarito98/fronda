import HarnessDomain
import SwiftUI

struct PlanEditorView: View {
    var store: AppStore
    @State var run: Run
    @Environment(\.dismiss) private var dismiss
    @State private var saving = false
    @State private var saveError: String?
    private var policyIssue: String? {
        do {
            try run.runbook.loopPolicy?.validate(steps: run.plan, mode: run.mode)
            return nil
        } catch { return error.localizedDescription }
    }
    var body: some View {
        VStack {
            HStack {
                Text("Editar plano").font(.title2.weight(.semibold))
                Spacer()
                Button("Cancelar") { dismiss() }.disabled(saving)
                Button(saving ? "Salvando…" : "Salvar revisão", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(saving || policyIssue != nil || !store.connected)
            }.padding(20)
            if let issue = saveError ?? policyIssue {
                Label(issue, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(FrondaTheme.warning).padding(.horizontal, 20)
            }
            Form {
                Section("Ciclos de correção") {
                    LoopPolicyEditor(
                        policy: $run.runbook.loopPolicy, steps: run.plan, mode: run.mode,
                        completedIterations: run.loopExecution?.iterations.count ?? 0)
                }
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
            .interactiveDismissDisabled(saving)
    }

    private func save() {
        saving = true
        saveError = nil
        var request = RPCRequest("plan.save")
        request.id = run.id
        request.run = run
        request.expectedSequence = run.sequence
        Task {
            defer { saving = false }
            do {
                _ = try await store.send(request)
                await store.refresh()
                dismiss()
            } catch { saveError = error.localizedDescription }
        }
    }
}
