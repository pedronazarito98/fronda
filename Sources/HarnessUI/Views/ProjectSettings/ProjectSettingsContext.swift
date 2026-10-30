import HarnessInfrastructure
import SwiftUI

struct ProjectSettingsContext: View {
    @Binding var draft: ProjectSettingsDraft

    private let weights: [(key: String, title: String, detail: String)] = [
        ("criteria", "Critérios de aceite", "Arquivos relacionados ao resultado esperado."),
        ("symbols", "Símbolos do código", "Nomes de funções, tipos e outros símbolos."),
        ("diff", "Alterações da tarefa", "Arquivos já modificados nesta tarefa."),
        ("tests", "Testes relacionados", "Arquivos com testes associados."),
        ("path", "Caminhos de arquivos", "Nomes e pastas relacionados ao objetivo."),
        ("history", "Histórico do Git", "Arquivos presentes em alterações recentes."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Surface {
                ProjectSettingsPathsField(
                    title: "Exclusões do índice",
                    hint: "Um caminho ou padrão por linha. Reindexe o projeto para atualizar o índice.",
                    placeholder: "dist/**", text: $draft.exclusions)
            }
            Surface {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Prioridade no contexto").font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Button("Restaurar padrões") { draft.contextWeights = nil }.buttonStyle(.link)
                            .disabled(draft.contextWeights == nil)
                    }
                    Text("Pesos maiores dão mais relevância ao selecionar arquivos. Use de 0 a 10.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(weights, id: \.key) { item in
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.system(size: 12, weight: .medium))
                                Text(item.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Stepper(value: weight(item.key), in: 0...10) {
                                Text(
                                    "\(draft.contextWeights?[item.key] ?? ContextRelations.defaultWeights[item.key] ?? 1)"
                                )
                                .monospacedDigit().frame(width: 22)
                            }.fixedSize().accessibilityLabel("Peso de \(item.title)")
                        }
                        if item.key != weights.last?.key { Divider() }
                    }
                }
            }
            Surface {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Critérios do Jira").font(.system(size: 14, weight: .semibold))
                    TextField("customfield_10042", text: $draft.jiraAcceptanceField)
                        .textFieldStyle(.roundedBorder).font(.system(size: 12, design: .monospaced))
                        .accessibilityLabel("ID do campo de critérios do Jira")
                    Text(
                        "Informe o ID do campo de aceite. O conteúdo original é preservado e você pode editar os critérios antes de criar a tarefa."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func weight(_ key: String) -> Binding<Int> {
        Binding(
            get: { draft.contextWeights?[key] ?? ContextRelations.defaultWeights[key] ?? 1 },
            set: { value in
                var updated = draft
                var weights = updated.contextWeights ?? ContextRelations.defaultWeights
                weights[key] = value
                updated.contextWeights = weights
                draft = updated
            })
    }
}
