import Charts
import HarnessDomain
import SwiftUI

struct TokensView: View {
    var store: AppStore
    let run: Run
    @State private var editingBudget = false
    @State private var budget = 32000
    @State private var savingBudget = false
    @State private var budgetError: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    SectionHeading(title: "Tokens e orçamento", detail: "MÉTRICA COM ORIGEM")
                    Button("Exportar CSV") { store.perform("tokens.export", id: run.id) }
                }
                HStack {
                    Text(
                        hasReportedUsage
                            ? "\(run.reportedTokens.formatted()) / \(run.budget.formatted()) tokens reportados"
                            : "Consumo não informado · limite \(run.budget.formatted()) tokens"
                    ).font(.headline)
                    Spacer()
                    Button("Ajustar orçamento") {
                        budget = run.budget
                        budgetError = nil
                        editingBudget = true
                    }
                    .disabled(!canEditBudget || editingBudget)
                }
                if editingBudget { budgetEditor }
                if run.isPauseRequested {
                    Text("Aguarde a confirmação da pausa antes de alterar o limite.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if run.needsPauseReview {
                    Text("Confira a interrupção antes de alterar o limite.")
                        .font(.caption).foregroundStyle(FrondaTheme.warning)
                } else if run.state.active || run.state == .queued {
                    Text("Pause a tarefa para alterar o limite de tokens com segurança.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if hasReportedUsage {
                    ProgressView(value: min(Double(run.reportedTokens), Double(run.budget)), total: Double(run.budget))
                        .tint(run.reportedTokens >= run.budget ? .red : FrondaTheme.accent)
                }
                HStack(spacing: 14) {
                    Metric(
                        title: "Entrada reportada", value: reported(\.input), symbol: "arrow.down.right", color: .blue)
                    Metric(
                        title: "Saída reportada", value: reported(\.output), symbol: "arrow.up.right",
                        color: FrondaTheme.accent)
                    Metric(
                        title: "Cache reportado", value: reported(\.cachedInput), symbol: "arrow.clockwise",
                        color: .green)
                }
                if hasReportedUsage {
                    Surface {
                        Chart(run.tokens) { record in
                            if let input = record.input {
                                BarMark(x: .value("Etapa", record.step), y: .value("Tokens", input)).foregroundStyle(
                                    by: .value("Tipo", "Entrada reportada"))
                            }
                            if let output = record.output {
                                BarMark(x: .value("Etapa", record.step), y: .value("Tokens", output)).foregroundStyle(
                                    by: .value("Tipo", "Saída reportada"))
                            }
                        }.chartForegroundStyleScale([
                            "Entrada reportada": Color.blue, "Saída reportada": FrondaTheme.accent,
                        ]).frame(height: 190)
                    }
                }
                if let pack = run.pack {
                    Surface {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Comparação estimada de payload").font(.headline)
                            HStack {
                                Metric(
                                    title: "Corpus candidato", value: "~\(pack.baselineTokens.formatted())",
                                    symbol: "doc.on.doc")
                                Metric(
                                    title: "Contexto selecionado", value: "~\(pack.estimatedTokens.formatted())",
                                    symbol: "line.3.horizontal.decrease", color: FrondaTheme.accent)
                            }
                            Text(
                                pack.estimateMethod
                                    + ". O corpus é o conjunto de candidatos desta compilação. Esta comparação não representa consumo real nem economia financeira."
                            ).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                SectionHeading(title: "Ledger por tentativa")
                ForEach(run.tokens) { record in
                    Surface(padding: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("\(record.provider.rawValue) · \(record.step)").font(.headline)
                                Text(record.attemptID.prefix(12)).font(.caption.monospaced()).foregroundStyle(
                                    .secondary)
                                Text("Fonte: \(record.source) · modelo: \(record.model)").font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 7) {
                                Text(
                                    "\(record.input.map { $0.formatted() } ?? "—") in / \(record.output.map { $0.formatted() } ?? "—") out"
                                ).font(.caption.monospaced())
                                Text("Pack estimado: \(record.estimatedPackInput.formatted())").font(.caption)
                                    .foregroundStyle(.secondary)
                                if let cost = record.cost {
                                    Text("US$ \(cost, specifier: "%.4f") · \(record.costSource)").font(.caption)
                                } else {
                                    Text("Custo indisponível").font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }.padding(24)
        }
    }
    private var budgetEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Limite desta tarefa").font(.headline)
            HStack {
                TextField("Limite em tokens", value: $budget, format: .number)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 150)
                Button("Aplicar limite", action: saveBudget)
                    .buttonStyle(.borderedProminent)
                    .disabled(!(1000...500000).contains(budget) || !canEditBudget || savingBudget)
                Button("Cancelar") {
                    editingBudget = false
                    budgetError = nil
                }.disabled(savingBudget)
            }
            Text("Entre 1.000 e 500.000 tokens. O consumo pode ser reportado após a requisição e ultrapassar o limite.")
                .font(.caption).foregroundStyle(.secondary)
            if let budgetError { Text(budgetError).font(.caption).foregroundStyle(FrondaTheme.danger) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrondaTheme.canvas, in: RoundedRectangle(cornerRadius: 10))
    }
    private func saveBudget() {
        guard canEditBudget, (1000...500000).contains(budget), !savingBudget else { return }
        savingBudget = true
        budgetError = nil
        Task {
            defer { savingBudget = false }
            do {
                var request = RPCRequest("run.budget")
                request.id = run.id
                request.number = budget
                request.expectedSequence = run.sequence
                _ = try await store.send(request)
                await store.refresh()
                editingBudget = false
            } catch {
                budgetError = error.localizedDescription
            }
        }
    }
    private var canEditBudget: Bool {
        store.connected && !run.state.active && run.pauseAllowsContinuation
            && ![.queued, .cancelled, .archived].contains(run.state)
    }
    private var hasReportedUsage: Bool {
        run.tokens.contains { $0.input != nil || $0.output != nil }
    }
    private func reported(_ keyPath: KeyPath<TokenRecord, Int?>) -> String {
        let values = run.tokens.compactMap { $0[keyPath: keyPath] }
        return values.isEmpty ? "—" : values.reduce(0, +).formatted()
    }
}
