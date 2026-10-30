import HarnessDomain
import SwiftUI

struct StepExecutionControls: View {
    @Binding var step: RunbookStep
    let defaultProvider: ProviderKind
    var models: [ProviderInfo] = []
    var inheritedExecution: ExecutionConfiguration?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(
                "Executor da etapa",
                selection: Binding(
                    get: { step.provider?.rawValue ?? "" },
                    set: {
                        step.provider = ProviderKind(rawValue: $0)
                        step.model = nil
                        step.effort = nil
                    })
            ) {
                Text("Herdar da tarefa · \(defaultProvider.rawValue)").tag("")
                ForEach(ProviderKind.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            ExecutionControls(
                configuration: Binding(
                    get: { ExecutionConfiguration(model: step.model, effort: step.effort) },
                    set: {
                        step.model = $0.model
                        step.effort = $0.effort
                    }),
                provider: step.provider ?? defaultProvider,
                models: models.first { $0.kind == (step.provider ?? defaultProvider) }?.models ?? [],
                defaultLabel: step.provider == nil || step.provider == defaultProvider
                    ? "Herdar da tarefa" : "Padrão do provider",
                inheritedModel: step.provider == nil || step.provider == defaultProvider
                    ? inheritedExecution?.model : nil)
        }
    }
}
