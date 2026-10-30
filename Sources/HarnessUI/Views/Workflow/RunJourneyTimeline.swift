import SwiftUI

struct RunJourneyTimeline: View {
    let model: RunJourneyModel
    @Binding var selectedStepID: String?

    private var selectedID: String? { model.step(id: selectedStepID)?.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Jornada da tarefa").font(.system(size: 14, weight: .semibold))
                Text(model.progressSummary).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            if model.steps.isEmpty {
                Text("As etapas aparecem quando o plano estiver disponível.")
                    .font(.callout).foregroundStyle(.secondary).padding(12)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(model.steps) { step in
                                RunJourneyTimelineRow(
                                    step: step, selected: step.id == selectedID,
                                    isLast: step.id == model.steps.last?.id
                                ) {
                                    selectedStepID = step.id
                                }
                                .id(step.id)
                            }
                        }
                        .padding(.horizontal, 2).padding(.bottom, 8)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        if let selectedID { proxy.scrollTo(selectedID, anchor: .center) }
                    }
                    .onChange(of: selectedID) { _, id in
                        if let id { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
        }
        .padding(.horizontal, 10).padding(.top, 20).padding(.bottom, 12)
    }
}

private struct RunJourneyTimelineRow: View {
    let step: RunJourneyStep
    let selected: Bool
    let isLast: Bool
    let select: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: select) {
            HStack(alignment: .top, spacing: 11) {
                marker
                VStack(alignment: .leading, spacing: 5) {
                    if step.isCurrent {
                        HStack(spacing: 4) {
                            Circle().fill(step.state.color).frame(width: 4, height: 4)
                            Text("ETAPA ATUAL").font(.system(size: 8, weight: .semibold)).tracking(0.8)
                        }
                        .foregroundStyle(step.state.color)
                    }
                    Text(step.title).font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                    Text(step.state.label).font(.system(size: 10, weight: .medium))
                        .foregroundStyle(step.state.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 11).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? FrondaTheme.accent.opacity(0.10) : hovered ? FrondaTheme.surface : .clear,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? FrondaTheme.accent.opacity(0.42) : .clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .background(alignment: .topLeading) {
            if !isLast {
                Rectangle().fill(FrondaTheme.border)
                    .frame(width: 1).padding(.leading, 24).padding(.top, 38).padding(.bottom, -20)
                    .accessibilityHidden(true).allowsHitTesting(false)
            }
        }
        .onHover { hovered = $0 }
        .help(step.blocker ?? step.dependencySummary ?? step.detail)
        .accessibilityLabel(
            "\(step.number). \(step.title). \(step.state.label)." + (step.isCurrent ? " Etapa atual." : "")
        )
        .accessibilityHint("Mostrar o resultado e os detalhes desta etapa")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("journey.step." + step.id)
    }

    private var marker: some View {
        ZStack {
            Circle().fill(FrondaTheme.surface)
            Circle().fill(step.state.color.opacity(step.isCurrent || step.isFinished ? 0.13 : 0.04))
            Circle().strokeBorder(
                step.isCurrent ? step.state.color : FrondaTheme.border,
                style: StrokeStyle(lineWidth: step.isCurrent ? 1.5 : 1, dash: step.state == .skipped ? [2, 2] : []))
            if step.state == .notStarted {
                Text(step.number.formatted()).font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: step.state.symbol).font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(step.state.color)
            }
        }
        .frame(width: 27, height: 27)
        .accessibilityHidden(true)
    }
}
