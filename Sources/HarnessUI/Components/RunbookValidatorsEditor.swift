import HarnessDomain
import SwiftUI

struct RunbookValidatorsEditor: View {
    @Binding var commands: [Validator]
    var body: some View {
        ForEach($commands) { $command in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField("Nome do gate", text: $command.name)
                    Button("Remover", role: .destructive) { commands.removeAll { $0.id == command.id } }
                }
                TextField("Executável", text: $command.executable)
                TextField(
                    "Um argumento por linha",
                    text: Binding(
                        get: { command.arguments.joined(separator: "\n") },
                        set: {
                            command.arguments = $0.split(separator: "\n", omittingEmptySubsequences: false).map(
                                String.init)
                        }), axis: .vertical)
                HStack {
                    Toggle("Obrigatório", isOn: $command.required)
                    Toggle("Somente leitura", isOn: $command.readOnly)
                }
                Toggle("Aprovo este comando literal", isOn: $command.approved)
                Stepper("Timeout: \(command.timeoutSeconds)s", value: $command.timeoutSeconds, in: 1...3600, step: 10)
            }.padding(.vertical, 8)
        }
        Button("Adicionar comando") { commands.append(Validator()) }
        Text(
            "Somam-se aos gates obrigatórios do projeto. Shell e operações proibidas continuam sujeitos à política do coordenador."
        ).font(.caption).foregroundStyle(.secondary)
    }
}
