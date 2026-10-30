import HarnessDomain
import SwiftUI

struct ValidationCommandFields: View {
    @Binding var command: Validator
    let scope: ValidationCommandScope
    let onRemove: () -> Void
    @State private var approvalInvalidated = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Editar comando", systemImage: "slider.horizontal.3").font(.subheadline.weight(.semibold))
                Spacer()
                Button("Remover", role: .destructive, action: onRemove)
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("\(scope.rawValue).command.remove")
            }
            field("Nome") {
                TextField("Ex.: Verificar tipos", text: $command.name)
                    .accessibilityIdentifier("\(scope.rawValue).command.name")
            }
            field("Executável") {
                TextField("Ex.: pnpm", text: executionBinding(\.executable))
                    .font(.system(size: 12, design: .monospaced))
                    .accessibilityIdentifier("\(scope.rawValue).command.executable")
            }
            field("Argumentos · um por linha") {
                TextField("Ex.: run\ntypecheck", text: argumentsBinding, axis: .vertical)
                    .lineLimit(2...5).font(.system(size: 12, design: .monospaced))
                    .accessibilityIdentifier("\(scope.rawValue).command.arguments")
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Comando para revisão").font(.caption).foregroundStyle(.secondary)
                Text(command.executable.isEmpty ? "Informe o executável acima." : command.displayCommand)
                    .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(FrondaTheme.canvas, in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityIdentifier("\(scope.rawValue).command.preview")
            }
            HStack(spacing: 20) {
                Toggle("Obrigatório", isOn: $command.required)
                Toggle("Somente leitura", isOn: executionBinding(\.readOnly))
            }.toggleStyle(.checkbox)
            Stepper(value: executionBinding(\.timeoutSeconds), in: 1...3600, step: 10) {
                HStack {
                    Text("Tempo limite")
                    Spacer()
                    Text("\(command.timeoutSeconds) s").monospacedDigit().foregroundStyle(.secondary)
                }
            }.font(.callout)
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                Toggle("Aprovo a execução deste comando literal", isOn: $command.approved)
                    .toggleStyle(.checkbox)
                    .disabled(command.executable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("\(scope.rawValue).command.approved")
                Text(
                    approvalInvalidated && !command.approved
                        ? "O comando foi alterado. Confira a nova versão antes de aprovar novamente."
                        : "A aprovação autoriza este comando nas tarefas, dentro das permissões do projeto."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            content()
        }
    }

    private func executionBinding<Value: Equatable>(_ keyPath: WritableKeyPath<Validator, Value>) -> Binding<Value> {
        Binding(
            get: { command[keyPath: keyPath] },
            set: { value in
                guard value != command[keyPath: keyPath] else { return }
                var updated = command
                updated[keyPath: keyPath] = value
                approvalInvalidated = approvalInvalidated || updated.approved
                updated.approved = false
                command = updated
            })
    }

    private var argumentsBinding: Binding<String> {
        Binding(
            get: { command.arguments.joined(separator: "\n") },
            set: { text in
                let arguments = text.isEmpty ? [] : text.components(separatedBy: "\n")
                executionBinding(\.arguments).wrappedValue = arguments
            })
    }
}
