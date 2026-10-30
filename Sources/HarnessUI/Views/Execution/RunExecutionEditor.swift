import HarnessDomain
import SwiftUI

struct RunExecutionEditor: View {
    let store: AppStore
    @State var run: Run
    @Environment(\.dismiss) private var dismiss
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Quem faz cada parte").font(.title2.weight(.semibold))
                    Text("Modelo, esforço e agentes por etapa").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction).disabled(saving)
                Button("Salvar e revisar contexto", action: save).buttonStyle(.borderedProminent)
                    .disabled(saving).accessibilityIdentifier("execution.save")
            }.padding(22)
            Form {
                Section("Padrão da tarefa") {
                    Picker("Executor", selection: $run.provider) {
                        ForEach(ProviderKind.allCases) { Text($0.rawValue).tag($0) }
                    }.onChange(of: run.provider) { run.execution = ExecutionConfiguration() }
                    ExecutionControls(
                        configuration: Binding(
                            get: { run.execution ?? ExecutionConfiguration() }, set: { run.execution = $0 }),
                        provider: run.provider,
                        models: store.snapshot.providers.first { $0.kind == run.provider }?.models ?? [])
                    Button("Consultar modelos desta instalação") {
                        store.perform("provider.models") { $0.text = run.provider.rawValue }
                    }.disabled(store.busy.contains("provider.models"))
                    Stepper(
                        "Teto da tarefa: \(run.budget.formatted()) tokens", value: $run.budget, in: 1000...500000,
                        step: 1000)
                }
                Section("Agentes por etapa") {
                    Text(
                        "Cada etapa de IA abre uma tentativa própria. Personalize a investigação, a implementação e a revisão conforme a dificuldade."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    ForEach($run.plan) { $step in
                        if step.usesAgent {
                            DisclosureGroup {
                                StepExecutionControls(
                                    step: $step, defaultProvider: run.provider, models: store.snapshot.providers,
                                    inheritedExecution: run.execution
                                )
                                .padding(.vertical, 10)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.title).font(.headline)
                                    Text(
                                        "\((step.provider ?? run.provider).rawValue) · \(step.execution(in: run).summary)"
                                    )
                                    .font(.caption).foregroundStyle(.secondary)
                                }.padding(.vertical, 5)
                            }
                        }
                    }
                }
                Section {
                    Text(
                        "Salvar cria uma revisão do plano e pede uma nova aprovação. Tentativas anteriores preservam o modelo e o esforço solicitados. O custo real depende do uso reportado pelo provider."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    if let error {
                        Text(error).foregroundStyle(FrondaTheme.danger)
                        Button("Recarregar tarefa e descartar esta edição") {
                            Task {
                                await store.refresh()
                                if let latest = store.snapshot.runs.first(where: { $0.id == run.id }) {
                                    run = latest
                                    self.error = nil
                                }
                            }
                        }
                    }
                }
            }.formStyle(.grouped).disabled(saving)
        }.frame(width: 760, height: 720).interactiveDismissDisabled(saving)
    }

    private func save() {
        saving = true
        Task {
            do {
                var request = RPCRequest("plan.save")
                request.id = run.id
                request.expectedSequence = run.sequence
                request.run = run
                _ = try await store.send(request)
                await store.refresh()
                dismiss()
            } catch { self.error = error.localizedDescription }
            saving = false
        }
    }
}
