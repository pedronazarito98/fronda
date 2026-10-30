import SwiftUI

struct SettingsExecutionControls: View {
    @Binding var concurrency: Int
    @Binding var perProject: Int
    @Binding var perProvider: Int
    @Binding var tokenBudget: Int
    @Binding var contextBudget: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Distribua o trabalho").font(.headline)
            HStack(spacing: 10) {
                concurrencyChoice("Foco", detail: "1 tarefa", symbol: "circle.dotted", value: 1)
                concurrencyChoice("Equilibrado", detail: "2 tarefas", symbol: "square.split.2x1", value: 2)
                concurrencyChoice("Em paralelo", detail: "4 tarefas", symbol: "square.grid.2x2", value: 4)
            }
            Stepper("Total de tarefas simultâneas: \(concurrency)", value: $concurrency, in: 1...8)
            HStack(spacing: 24) {
                Stepper("Por projeto: \(perProject)", value: $perProject, in: 1...8)
                Stepper("Por executor: \(perProvider)", value: $perProvider, in: 1...8)
            }
            Text("Os limites por projeto e executor se aplicam dentro do total disponível.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("Orçamentos padrão").font(.headline)
            Stepper("Por tarefa: \(tokenBudget.formatted()) tokens", value: $tokenBudget, in: 1000...500000, step: 1000)
            Stepper(
                "Contexto: \(contextBudget.formatted()) tokens estimados", value: $contextBudget, in: 1000...100000,
                step: 1000)
            Text(
                "O orçamento do fluxo prevalece ao criar uma tarefa e pode ser personalizado. A estimativa do contexto é separada do consumo reportado pelo executor."
            )
            .font(.caption).foregroundStyle(.secondary)
        }.font(.callout).padding(.vertical, 6)
    }

    private func concurrencyChoice(_ title: String, detail: String, symbol: String, value: Int) -> some View {
        Button {
            concurrency = value
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: symbol)
                    Spacer()
                    if concurrency == value { Image(systemName: "checkmark.circle.fill") }
                }.foregroundStyle(FrondaTheme.accent)
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            .padding(13).frame(maxWidth: .infinity, alignment: .leading)
            .background(
                concurrency == value ? FrondaTheme.accent.opacity(0.08) : FrondaTheme.surface,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(
                    concurrency == value ? FrondaTheme.accent : FrondaTheme.border, lineWidth: 1)
            }
        }.buttonStyle(.plain)
            .accessibilityLabel("\(title), até \(value) tarefas simultâneas")
            .accessibilityAddTraits(concurrency == value ? .isSelected : [])
    }
}
