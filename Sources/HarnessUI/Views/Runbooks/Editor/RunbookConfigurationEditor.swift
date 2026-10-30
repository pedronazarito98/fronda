import HarnessDomain
import SwiftUI

struct RunbookConfigurationEditor: View {
    @Binding var book: Runbook
    @State private var advanced = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dê um nome ao caminho").font(.headline)
                    TextField("Nome do fluxo", text: $book.name)
                        .textFieldStyle(.roundedBorder).accessibilityIdentifier("runbook-editor.name")
                    TextField("O que este fluxo ajuda a resolver?", text: $book.subtitle, axis: .vertical)
                        .lineLimit(2...3).textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Descrição do fluxo")
                }
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    Text("Como o trabalho acontece").font(.headline)
                    LabeledContent("Autonomia padrão") {
                        Picker("Autonomia padrão", selection: $book.mode) {
                            ForEach(AutonomyMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.labelsHidden().frame(width: 200)
                    }
                    Text(
                        book.mode.writes
                            ? "O trabalho pode gerar alterações em um espaço isolado da tarefa."
                            : "O trabalho fica em leitura e planejamento."
                    ).font(.caption).foregroundStyle(.secondary)
                    LabeledContent("Executor padrão") {
                        Picker("Executor padrão", selection: $book.provider) {
                            ForEach(ProviderKind.allCases) { Text($0.rawValue).tag($0) }
                        }.labelsHidden().frame(width: 200)
                    }
                    LabeledContent("Tipo de trabalho") {
                        Picker("Tipo de trabalho", selection: $book.workKind) {
                            Text("Personalizado").tag(Optional<WorkKind>.none)
                            ForEach(WorkKind.allCases) {
                                Text(RunbookEditorStepLabels.workKind($0)).tag(Optional($0))
                            }
                        }.labelsHidden().frame(width: 200)
                    }
                    Text(
                        book.workKind == nil
                            ? "Você define as etapas e as conexões deste fluxo."
                            : "Este tipo mantém etapas obrigatórias em sequência. A estrutura é conferida antes de salvar."
                    ).font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Limites da tarefa").font(.headline)
                    Stepper(
                        "Orçamento: \(book.budget.formatted()) tokens",
                        value: $book.budget, in: 1000...500000, step: 1000
                    )
                    .accessibilityIdentifier("runbook-editor.budget")
                    DisclosureGroup("Opções avançadas", isExpanded: $advanced) {
                        Stepper("Novas tentativas por etapa: \(book.retries)", value: $book.retries, in: 0...10)
                            .padding(.top, 10)
                    }.font(.callout)
                }
            }
            .padding(24).frame(maxWidth: 670, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
