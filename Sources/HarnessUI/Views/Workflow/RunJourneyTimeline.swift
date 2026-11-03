import HarnessDomain
import SwiftUI

struct RunJourneyTimeline: View {
    let run: Run
    let connected: Bool
    let inspect: (String) -> Void

    var body: some View {
        let journey = RunJourneyModel(run: run)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Etapas da tarefa").font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(journey.progressSummary).font(.caption).foregroundStyle(.secondary)
            }
            if journey.steps.isEmpty {
                Text("As etapas aparecerão quando o plano estiver disponível.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("Abra uma etapa para conferir ações, tentativas e resultados.")
                    .font(.caption).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(journey.steps) { step in
                        let node = RunFlowMapNodeModel(journey: step, run: run, connected: connected)
                        row(node)
                        if step.id != journey.steps.last?.id { Divider().padding(.leading, 46) }
                    }
                }
                .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(FrondaTheme.border) }
            }
        }
    }

    private func row(_ node: RunFlowMapNodeModel) -> some View {
        Button {
            inspect(node.id)
        } label: {
            HStack(spacing: 12) {
                Text(node.journey.number.formatted()).font(.caption.monospacedDigit().weight(.semibold))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(node.appearance.color)
                    .background(node.appearance.color.opacity(0.10), in: Circle())
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        rowTitle(node)
                        Spacer(minLength: 8)
                        badge(node)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        rowTitle(node)
                        badge(node)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary).accessibilityHidden(true)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(node.journey.isCurrent && connected ? node.appearance.color.opacity(0.04) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Ver atividade e resultados de " + node.title)
        .accessibilityLabel("Etapa \(node.journey.number), \(node.title), \(node.status)")
        .accessibilityHint("Abrir a atividade desta etapa")
        .accessibilityIdentifier("task.step." + node.id)
    }

    private func rowTitle(_ node: RunFlowMapNodeModel) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(node.title).font(.callout.weight(.medium)).multilineTextAlignment(.leading)
            HStack(spacing: 4) {
                Image(systemName: node.roleSymbol)
                    .foregroundStyle(node.journey.step.usesAgent ? FrondaTheme.reference : FrondaTheme.accent)
                    .accessibilityHidden(true)
                Text(node.role).foregroundStyle(.secondary)
            }.font(.caption2)
        }.fixedSize(horizontal: false, vertical: true)
    }

    private func badge(_ node: RunFlowMapNodeModel) -> some View {
        FrondaBadge(node.status, symbol: node.statusSymbol, color: node.appearance.color)
    }
}
