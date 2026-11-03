import HarnessDomain
import SwiftUI

struct LoopPolicyEditor: View {
    @Binding var policy: LoopPolicy?
    let steps: [RunbookStep]
    let mode: AutonomyMode
    var completedIterations = 0
    @State private var advanced = false

    private var availablePolicy: LoopPolicy? {
        guard mode.writes, steps.filter({ $0.kind == "validation" }).count == 1,
            let validation = steps.first(where: { $0.kind == "validation" && $0.condition == "always" }),
            validation.dependencies.count == 1,
            let implementation = steps.first(where: {
                $0.id == validation.dependencies.first && $0.kind == "implementation" && $0.condition == "always"
            })
        else { return nil }
        return LoopPolicy(implementationStepID: implementation.id, validationStepID: validation.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(
                "Corrigir e verificar em ciclos",
                isOn: Binding(
                    get: { policy != nil },
                    set: { policy = $0 ? availablePolicy : nil })
            )
            .disabled(policy == nil && availablePolicy == nil)
            .accessibilityIdentifier("loop-policy.enabled")
            Text(
                "Se a validação automática falhar, o executor recebe as pendências e tenta uma nova correção dentro dos limites aprovados."
            )
            .font(.caption).foregroundStyle(.secondary)
            if policy != nil {
                Stepper("Até \(policy?.maxIterations ?? 3) ciclos no total", value: value(\.maxIterations), in: 1...10)
                    .accessibilityIdentifier("loop-policy.iterations")
                if completedIterations > 0 {
                    Text(
                        "\(completedIterations) ciclos já registrados. Alterar o limite mantém a contagem e o histórico."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
                DisclosureGroup("Tempo e progresso", isExpanded: $advanced) {
                    VStack(alignment: .leading, spacing: 10) {
                        Stepper(
                            "Tempo ativo: \((policy?.maxDurationSeconds ?? 1800) / 60) minutos",
                            value: Binding(
                                get: { (policy?.maxDurationSeconds ?? 1800) / 60 },
                                set: { policy?.maxDurationSeconds = $0 * 60 }), in: 1...1440, step: 5)
                        Stepper(
                            "Parar após \(policy?.maxStagnantIterations ?? 2) ciclos sem progresso",
                            value: value(\.maxStagnantIterations), in: 1...10)
                        Text(
                            "O tempo é conferido entre etapas, sem interromper a chamada em andamento. O orçamento de tokens é o da tarefa. Revisão, evidências e entrega continuam fora do ciclo."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 8)
                }
            }
            if availablePolicy == nil {
                Label(
                    "Use um modo com escrita e uma única etapa Validar, obrigatória e ligada diretamente a Implementar.",
                    systemImage: "info.circle"
                )
                .font(.caption).foregroundStyle(FrondaTheme.warning)
            }
        }
    }

    private func value(_ path: WritableKeyPath<LoopPolicy, Int>) -> Binding<Int> {
        Binding(get: { policy?[keyPath: path] ?? 1 }, set: { policy?[keyPath: path] = $0 })
    }
}
