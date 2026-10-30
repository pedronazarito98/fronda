import HarnessDomain
import SwiftUI

struct RunRow: View {
    var store: AppStore
    let run: Run
    @State private var hovering = false

    private var projectName: String {
        store.snapshot.projects.first { $0.id == run.projectID }?.name ?? "Projeto indisponível"
    }
    private var color: Color { RunDisplay.color(for: run.state) }

    var body: some View {
        Button {
            store.route = "run:" + run.id
        } label: {
            Surface(padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: run.runbook.symbol)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(FrondaTheme.accent)
                            .frame(width: 38, height: 38)
                            .background(FrondaTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(run.title).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text("\(projectName) · \(run.provider.rawValue)")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        if store.busy.contains(run.id) {
                            ProgressView().controlSize(.small).accessibilityLabel("Atualizando tarefa")
                        } else {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(hovering ? FrondaTheme.accent : .secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            stateLabel
                            Spacer(minLength: 6)
                            Text(RunDisplay.nextAction(for: run)).font(.caption).foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            stateLabel
                            Text(RunDisplay.nextAction(for: run)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !run.plan.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView(value: Double(run.completedSteps), total: Double(run.plan.count))
                                .tint(color).controlSize(.small)
                                .accessibilityLabel("Etapas validadas")
                                .accessibilityValue("\(run.completedSteps) de \(run.plan.count)")
                            Text("\(run.completedSteps)/\(run.plan.count)")
                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: FrondaTheme.cornerRadius)
                    .strokeBorder(hovering ? FrondaTheme.accent.opacity(0.4) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("\(run.stageLabel) · Atualizada \(run.updatedAt.formatted(date: .abbreviated, time: .shortened))")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(run.title), \(projectName), \(run.state.label)")
        .accessibilityValue("\(run.completedSteps) de \(run.plan.count) etapas validadas")
        .accessibilityHint(RunDisplay.nextAction(for: run))
        .accessibilityIdentifier("run-row.\(run.id)")
        .contextMenu {
            Button("Abrir tarefa", systemImage: "arrow.up.right") { store.route = "run:" + run.id }
            if !run.workspace.isEmpty {
                Button("Mostrar workspace no Finder", systemImage: "folder") { store.reveal(run.workspace) }
            }
        }
    }

    private var stateLabel: some View {
        Label(run.state.label, systemImage: RunDisplay.symbol(for: run.state))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(color.opacity(0.08), in: Capsule())
            .fixedSize()
    }
}
