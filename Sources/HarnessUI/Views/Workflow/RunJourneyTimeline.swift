import HarnessDomain
import SwiftUI

struct RunJourneyTimeline: View {
    let run: Run
    let connected: Bool
    var project: Project?
    var showsCurrent = true
    let inspect: (String) -> Void

    var body: some View {
        let journey = RunJourneyModel(run: run)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Etapas").font(.system(size: 17, weight: .semibold, design: .serif))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(journey.progressSummary).font(.caption).foregroundStyle(.secondary)
            }
            if journey.steps.isEmpty {
                Text("As etapas aparecerão quando o plano estiver disponível.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(journey.steps) { step in
                        row(
                            RunFlowMapNodeModel(
                                journey: step, run: run, project: project, connected: connected,
                                showsCurrent: showsCurrent),
                            total: journey.totalCount)
                    }
                }
                .background(alignment: .leading) {
                    Rectangle().fill(FrondaTheme.border)
                        .frame(width: 1)
                        .padding(.leading, 13).padding(.vertical, 22)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func row(_ node: RunFlowMapNodeModel, total: Int) -> some View {
        Button {
            inspect(node.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: node.statusSymbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(node.appearance.color)
                    .frame(width: 27, height: 27)
                    .background(FrondaTheme.surface, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Etapa \(node.journey.number) de \(total) · \(node.status)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(node.isCurrent ? node.appearance.color : .secondary)
                    Text(node.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if node.isCurrent {
                        Text(node.journey.detail)
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary).padding(.top, 6)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 10).padding(.trailing, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Ver atividade e resultados de " + node.title)
        .accessibilityLabel(
            "Etapa \(node.journey.number) de \(total), \(node.title), \(node.isCurrent ? "atual, " : "")\(node.status)"
        )
        .accessibilityHint("Abrir a atividade desta etapa")
        .accessibilityIdentifier("task.step." + node.id)
    }
}
