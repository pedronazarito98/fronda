import Charts
import HarnessDomain
import SwiftUI

struct TokensView: View {
    var store: AppStore
    let run: Run
    @State private var editingBudget = false
    @State private var budget = 32000
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    SectionHeading(title: "Tokens e orçamento", detail: "MÉTRICA COM ORIGEM")
                    Button("Exportar CSV") { store.perform("tokens.export", id: run.id) }
                }
                HStack {
                    Text("\(run.reportedTokens.formatted()) / \(run.budget.formatted()) tokens reportados").font(
                        .headline)
                    Spacer()
                    Button("Ajustar orçamento…") {
                        budget = run.budget
                        editingBudget = true
                    }
                }
                ProgressView(value: min(Double(run.reportedTokens), Double(run.budget)), total: Double(run.budget))
                    .tint(run.reportedTokens >= run.budget ? .red : FrondaTheme.accent)
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
                if !run.tokens.isEmpty {
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
        .sheet(isPresented: $editingBudget) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Teto de consumo").font(.title2)
                Stepper("\(budget.formatted()) tokens", value: $budget, in: 1000...500000, step: 1000)
                Text(
                    "O provider pode reportar consumo após a requisição. O Fronda interrompe a sessão e impede novas etapas quando o teto é observado."
                ).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Cancelar") { editingBudget = false }
                    Spacer()
                    Button("Aplicar teto") {
                        store.perform("run.budget", id: run.id) { $0.number = budget }
                        editingBudget = false
                    }.buttonStyle(.borderedProminent)
                }
            }.padding(26).frame(width: 530)
        }
    }
    private func reported(_ keyPath: KeyPath<TokenRecord, Int?>) -> String {
        let values = run.tokens.compactMap { $0[keyPath: keyPath] }
        return values.isEmpty ? "—" : values.reduce(0, +).formatted()
    }
}
