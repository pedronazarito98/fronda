import HarnessDomain
import SwiftUI

struct NewRunOptions: View {
    @Binding var draft: NewRunDraft
    let book: Runbook?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Opções da tarefa").font(.headline)
                Spacer()
                Button("Concluir") { dismiss() }.controlSize(.small)
            }
            VStack(alignment: .leading, spacing: 7) {
                Picker("Autonomia", selection: modeBinding) {
                    ForEach(AutonomyMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Text(
                    draft.mode.writes
                        ? "Alterações em uma worktree exclusiva." : "O executor trabalha em modo de leitura."
                )
                .font(.caption).foregroundStyle(.secondary)
                if draft.modeIsCustomized, let book {
                    Button("Usar autonomia do fluxo: \(book.mode.rawValue)") {
                        var updatedDraft = draft
                        updatedDraft.mode = book.mode
                        updatedDraft.modeIsCustomized = false
                        draft = updatedDraft
                    }.buttonStyle(.link).font(.caption)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                Text("Escopo").font(.system(size: 12, weight: .semibold))
                TextField("Paths separados por vírgula", text: $draft.scope).textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                Text("Use ** para todo o projeto ou informe caminhos específicos.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Stepper(value: budgetBinding, in: 1000...500000, step: 1000) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Limite de tokens").font(.system(size: 12, weight: .semibold))
                        Text(draft.budget.formatted()).font(.system(size: 18, weight: .medium, design: .rounded))
                    }
                }
                Text(
                    draft.budgetIsCustomized
                        ? "Personalizado para esta tarefa"
                        : book == nil ? "Padrão dos ajustes" : "Padrão do fluxo selecionado"
                )
                .font(.caption).foregroundStyle(.secondary)
                if draft.budgetIsCustomized, let book {
                    Button("Usar orçamento do fluxo: \(book.budget.formatted())") {
                        var updatedDraft = draft
                        updatedDraft.budget = book.budget
                        updatedDraft.budgetIsCustomized = false
                        draft = updatedDraft
                    }.buttonStyle(.link).font(.caption)
                }
            }
        }
        .padding(20).frame(width: 340).tint(FrondaTheme.accent)
    }

    private var modeBinding: Binding<AutonomyMode> {
        Binding(
            get: { draft.mode },
            set: {
                var updatedDraft = draft
                updatedDraft.mode = $0
                updatedDraft.modeIsCustomized = true
                draft = updatedDraft
            })
    }

    private var budgetBinding: Binding<Int> {
        Binding(
            get: { draft.budget },
            set: {
                var updatedDraft = draft
                updatedDraft.budget = $0
                updatedDraft.budgetIsCustomized = true
                draft = updatedDraft
            })
    }
}
