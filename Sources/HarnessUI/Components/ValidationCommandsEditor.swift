import HarnessDomain
import SwiftUI

enum ValidationCommandScope: String {
    case project
    case runbook

    var detail: String {
        switch self {
        case .project: "As tarefas deste projeto usam este catálogo. Salvar não executa os comandos."
        case .runbook: "Estes comandos se somam aos obrigatórios do projeto. Salvar não executa os comandos."
        }
    }
}

struct ValidationCommandsEditor: View {
    @Binding var commands: [Validator]
    let scope: ValidationCommandScope
    @State private var selectedID: String?

    private var selectedIndex: Int? {
        commands.firstIndex { $0.id == selectedID } ?? commands.indices.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Catálogo de comandos").font(.title3.weight(.semibold))
                    Text(scope.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Button(action: addCommand) { Label("Adicionar", systemImage: "plus") }
                    .accessibilityIdentifier("\(scope.rawValue).commands.add")
            }
            if commands.isEmpty {
                EmptyPanel(
                    symbol: "terminal", title: "Nenhum comando cadastrado",
                    detail: "Adicione o executável e seus argumentos. Você pode revisar e aprovar cada comando aqui.")
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        commandList.frame(width: 175)
                        selectedEditor.frame(minWidth: 320)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        commandList
                        selectedEditor
                    }
                }
            }
        }
    }

    @ViewBuilder private var selectedEditor: some View {
        if let index = selectedIndex {
            let command = commands[index]
            Surface(padding: 16) {
                ValidationCommandFields(command: binding(for: command), scope: scope) {
                    removeCommand(command.id)
                }
                .id(command.id)
            }
        }
    }

    private func binding(for command: Validator) -> Binding<Validator> {
        Binding(
            get: { commands.first { $0.id == command.id } ?? command },
            set: { updated in
                guard let index = commands.firstIndex(where: { $0.id == command.id }) else { return }
                commands[index] = updated
            })
    }

    private var commandList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(commands) { command in
                    commandRow(command)
                }
            }.padding(2)
        }
        .frame(height: min(CGFloat(commands.count) * 72 + 4, 360))
        .accessibilityIdentifier("\(scope.rawValue).commands.list")
    }

    private func commandRow(_ command: Validator) -> some View {
        let selected = selectedIndex.map { commands[$0].id == command.id } ?? false
        return Button {
            selectedID = command.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "terminal").foregroundStyle(FrondaTheme.accent)
                    Text(command.name.isEmpty ? "Novo comando" : command.name)
                        .font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                }
                Label(
                    command.approved ? "Aprovado" : "Revisar comando",
                    systemImage: command.approved ? "checkmark.shield" : "circle"
                )
                .font(.caption)
                .foregroundStyle(command.approved ? FrondaTheme.success : FrondaTheme.textMuted)
            }
            .padding(.horizontal, 10).frame(height: 66)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? FrondaTheme.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(command.displayCommand)
        .accessibilityLabel("Editar comando \(command.name.isEmpty ? "sem nome" : command.name)")
        .accessibilityValue(command.approved ? "Aprovado" : "Revisão necessária")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityRemoveTraits(selected ? [] : .isSelected)
        .accessibilityIdentifier("\(scope.rawValue).commands.select.\(command.id)")
    }

    private func addCommand() {
        var command = Validator()
        command.name = "Novo comando"
        commands.append(command)
        selectedID = command.id
    }

    private func removeCommand(_ id: String) {
        commands.removeAll { $0.id == id }
        selectedID = commands.first?.id
    }
}
