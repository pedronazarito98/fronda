import HarnessDomain
import SwiftUI

struct RunbookStepEditor: View {
    @Binding var step: RunbookStep
    let book: Runbook
    let steps: [RunbookStep]
    let remove: () -> Void
    @State private var advanced = false

    private var missingDependencies: [String] {
        step.dependencies.filter { id in id == step.id || !steps.contains { $0.id == id } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text("Esta etapa").font(.headline)
                        Spacer()
                        Button(role: .destructive, action: remove) {
                            Image(systemName: "trash")
                        }.buttonStyle(.plain).accessibilityLabel("Excluir etapa \(step.title)")
                            .accessibilityIdentifier("runbook-editor.delete-step")
                    }
                    TextField("Nome da etapa", text: $step.title).textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("runbook-editor.step-title")
                    Picker("Papel no fluxo", selection: $step.kind) {
                        ForEach(StepKind.allCases, id: \.rawValue) { kind in
                            Text(RunbookEditorStepLabels.title(for: kind)).tag(kind.rawValue)
                        }
                        if StepKind(rawValue: step.kind) == nil {
                            Text("Tipo não reconhecido").tag(step.kind)
                        }
                    }.accessibilityIdentifier("runbook-editor.step-kind")
                    Text(RunbookStepDescription(book: book, step: step).purpose)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                dependencies
                Divider()
                RunbookLinesField(
                    title: "Critérios de conclusão", hint: "Um resultado esperado por linha.", values: $step.criteria)
                DisclosureGroup("Opções avançadas", isExpanded: $advanced) {
                    VStack(alignment: .leading, spacing: 16) {
                        if step.usesAgent {
                            StepExecutionControls(step: $step, defaultProvider: book.provider)
                        }
                        Picker("Condição para executar", selection: $step.condition) {
                            Text("Após as dependências terminarem").tag("always")
                            Text("Se todas as dependências passarem").tag("on_pass")
                            Text("Se uma dependência falhar ou bloquear").tag("on_failure")
                            Text("Se houver alterações no projeto").tag("has_changes")
                            if !["always", "on_pass", "on_failure", "has_changes"].contains(step.condition) {
                                Text("Condição não reconhecida").tag(step.condition)
                            }
                        }
                        RunbookLinesField(
                            title: "Arquivos e pastas previstos", hint: "Um caminho por linha.", values: $step.paths)
                    }.padding(.top, 12)
                }.font(.callout)
            }
            .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dependencies: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Depende de").font(.headline)
            Text("Esta etapa aguarda as etapas marcadas.").font(.caption).foregroundStyle(.secondary)
            if steps.count == 1 && missingDependencies.isEmpty {
                Text("A primeira etapa pode começar sem dependências.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, candidate in
                if candidate.id != step.id {
                    let selected = step.dependencies.contains(candidate.id)
                    let cycle = RunbookEditorValidation.createsCycle(
                        stepID: step.id, dependencyID: candidate.id, steps: steps)
                    Toggle(
                        isOn: Binding(
                            get: { step.dependencies.contains(candidate.id) },
                            set: { enabled in
                                if enabled && !step.dependencies.contains(candidate.id) {
                                    step.dependencies.append(candidate.id)
                                } else if !enabled {
                                    step.dependencies.removeAll { $0 == candidate.id }
                                }
                            })
                    ) {
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Text(candidate.title.isEmpty ? "Etapa sem nome" : candidate.title).font(.callout)
                            if cycle && !selected {
                                Text("Depende desta etapa").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .toggleStyle(.checkbox).disabled(cycle && !selected)
                    .help(cycle && !selected ? "Esta conexão criaria um ciclo." : "Aguardar \(candidate.title)")
                    .accessibilityIdentifier("runbook-editor.dependency." + candidate.id)
                }
            }
            ForEach(Array(missingDependencies.enumerated()), id: \.offset) { _, id in
                HStack {
                    Label("Conexão inválida", systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(FrondaTheme.warning)
                    Spacer()
                    Button("Remover conexão") { step.dependencies.removeAll { $0 == id } }
                        .font(.caption)
                }
            }
        }
    }
}

private struct RunbookLinesField: View {
    let title: String
    let hint: String
    @Binding var values: [String]
    @State private var text: String

    init(title: String, hint: String, values: Binding<[String]>) {
        self.title = title
        self.hint = hint
        self._values = values
        self._text = State(initialValue: values.wrappedValue.joined(separator: "\n"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.callout.weight(.medium))
            TextEditor(text: $text).font(.callout)
                .scrollContentBackground(.hidden)
                .padding(7).frame(height: 76)
                .background(FrondaTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(FrondaTheme.border, lineWidth: 1))
                .accessibilityLabel(title)
            Text(hint).font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of: text) { _, value in
            values = value.components(separatedBy: .newlines).filter { !$0.isEmpty }
        }
    }
}
