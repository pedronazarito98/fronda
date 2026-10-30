import HarnessDomain
import SwiftUI

struct CommandWorkQueue: View {
    var store: AppStore
    let title: String
    let runs: [Run]
    let total: Int
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(color).accessibilityHidden(true)
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(total.formatted()).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                if total > runs.count {
                    Button("Ver todas as tarefas") { store.route = "runs" }
                        .buttonStyle(.plain).font(.caption).foregroundStyle(FrondaTheme.accent)
                }
            }
            Surface(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(runs) { run in
                        CommandRunLine(store: store, run: run)
                        if run.id != runs.last?.id { Divider().padding(.leading, 51) }
                    }
                }
            }
        }
    }
}

private struct CommandRunLine: View {
    var store: AppStore
    let run: Run
    @State private var hovered = false

    private var project: String {
        store.snapshot.projects.first { $0.id == run.projectID }?.name ?? "Projeto indisponível"
    }

    var body: some View {
        Button {
            store.route = "run:" + run.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: run.runbook.symbol).font(.system(size: 15))
                    .foregroundStyle(FrondaTheme.accent).frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(run.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    Text("\(project) · \(run.stageLabel)")
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 5) {
                    Text(run.state.label).font(.system(size: 10, weight: .medium))
                        .foregroundStyle(RunDisplay.color(for: run.state))
                    Text(RunDisplay.nextAction(for: run)).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovered ? FrondaTheme.accent.opacity(0.04) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(run.title), \(project), \(run.state.label)")
        .accessibilityHint(RunDisplay.nextAction(for: run))
        .accessibilityIdentifier("home.run." + run.id)
        .help("Atualizada \(run.updatedAt.formatted(date: .abbreviated, time: .shortened))")
    }
}
