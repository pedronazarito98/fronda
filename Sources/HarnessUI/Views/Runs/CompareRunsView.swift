import HarnessDomain
import SwiftUI

struct CompareRunsView: View {
    var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var left = ""
    @State private var right = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Comparar abordagens").font(.title2.weight(.semibold))
                Spacer()
                Button("Concluir") { dismiss() }
            }
            Text("As abordagens preservam suas worktrees. Escolher uma registra sua decisão.").foregroundStyle(
                .secondary)
            HStack(alignment: .top, spacing: 20) {
                column("A", selection: $left)
                column("B", selection: $right)
            }
        }.padding(28).frame(width: 880, height: 550).onAppear {
            left = store.snapshot.runs.first?.id ?? ""
            right = store.snapshot.runs.dropFirst().first?.id ?? ""
        }
    }
    private func column(_ name: String, selection: Binding<String>) -> some View {
        Surface {
            VStack(alignment: .leading, spacing: 20) {
                Text("ABORDAGEM \(name)").font(.caption.monospaced()).foregroundStyle(FrondaTheme.accent)
                Picker("Run", selection: selection) { ForEach(store.snapshot.runs) { Text($0.title).tag($0.id) } }
                    .labelsHidden()
                if let run = store.snapshot.runs.first(where: { $0.id == selection.wrappedValue }) {
                    StatusBadge(text: run.state.rawValue)
                    LabeledContent("Arquivos", value: "\(run.changedFiles.count)")
                    LabeledContent("Gates em PASS", value: "\(run.validations.filter { $0.status == .pass }.count)")
                    LabeledContent("Achados abertos", value: "\(run.findings.filter { $0.state == "OPEN" }.count)")
                    LabeledContent("Tokens reportados", value: run.reportedTokens.formatted())
                    Text(run.reason).font(.caption).foregroundStyle(.secondary)
                    Button("Escolher abordagem \(name)") {
                        store.perform("run.select", id: run.id)
                        dismiss()
                        store.route = "run:" + run.id
                    }.buttonStyle(.borderedProminent)
                        .disabled(!store.connected || store.busy.contains(run.id) || left == right)
                }
            }
        }
    }
}
