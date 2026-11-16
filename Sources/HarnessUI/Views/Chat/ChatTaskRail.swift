import HarnessDomain
import SwiftUI

/// A quiet overview of the latest project run, always derived from the coordinator's state.
struct ChatTaskRail: View {
    let store: AppStore

    private var reference: ChatRunReference? {
        guard let turn = store.selectedChat?.turns.reversed().first(where: { $0.runID != nil }),
            let id = turn.runID
        else { return nil }
        return ChatRunReference(runID: id, sequence: turn.runSnapshotSequence)
    }

    var body: some View {
        Group {
            if let reference, let run = store.snapshot.runs.first(where: { $0.id == reference.runID }) {
                ChatRunRevision(store: store, current: run, sequence: reference.sequence) { displayed in
                    trail(for: displayed, sequence: reference.sequence)
                }
                .id(reference)
            } else if reference != nil {
                ContentUnavailableView(
                    "Execução indisponível", systemImage: "exclamationmark.circle",
                    description: Text("Não foi possível encontrar as etapas desta conversa.")
                )
            } else {
                emptyTrail
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FrondaTheme.surface)
        .accessibilityIdentifier("chat.task-rail")
    }

    private var emptyTrail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRILHA DA TAREFA")
                .font(.caption2.weight(.semibold)).tracking(1.3).foregroundStyle(FrondaTheme.accent)
            Text("Pronto para começar")
                .font(.system(size: 23, weight: .semibold, design: .serif))
            Text("As etapas aparecem aqui quando você iniciar um trabalho em um projeto.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
    }

    private func trail(for run: Run, sequence: Int?) -> some View {
        let journey = RunJourneyModel(run: run)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TRILHA DA TAREFA")
                        .font(.caption2.weight(.semibold)).tracking(1.3).foregroundStyle(FrondaTheme.accent)
                    Text("Etapas do trabalho")
                        .font(.system(size: 23, weight: .semibold, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                    Text(run.title).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(journey.progressSummary).font(.caption.weight(.medium)).foregroundStyle(FrondaTheme.textMuted)
                }

                ChatLoopStatus(store: store, run: run, sequence: sequence, showsDetails: true)

                if journey.steps.isEmpty {
                    Text("As etapas aparecerão quando o plano estiver disponível.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(journey.steps) { step in
                            stage(step, run: run, sequence: sequence, total: journey.totalCount)
                        }
                    }
                    .background(alignment: .leading) {
                        Rectangle().fill(FrondaTheme.border)
                            .frame(width: 1).padding(.leading, 20).padding(.vertical, 22)
                    }
                }

                Divider()
                Button {
                    store.runDetail = nil
                    store.graph = ChatRunReference(runID: run.id, sequence: sequence)
                } label: {
                    Label("Ver grafo", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain).accessibilityIdentifier("chat.trail.graph")
                Button {
                    store.graph = nil
                    store.runDetail = ChatRunDetail(runID: run.id, page: .section(.files), sequence: sequence)
                } label: {
                    Label("Arquivos e entregas", systemImage: "doc.text")
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(sequence != nil)
                .help(sequence == nil ? "Abrir arquivos e entregas" : "Arquivos da revisão anterior indisponíveis aqui")
                .accessibilityIdentifier("chat.trail.files")
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stage(_ step: RunJourneyStep, run: Run, sequence: Int?, total: Int) -> some View {
        let node = RunFlowMapNodeModel(
            journey: step, run: run, project: store.snapshot.projects.first { $0.id == run.projectID },
            connected: store.connected, showsCurrent: sequence == nil)
        let needsCurrentCheck =
            step.step.kind == "validation" && step.state == .passed
            && sequence == nil && node.appearance != .confirmed
        return HStack(alignment: .top, spacing: 12) {
            Image(
                systemName: needsCurrentCheck
                    ? node.statusSymbol : (step.state == .passed ? "checkmark.circle.fill" : "circle")
            )
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(
                needsCurrentCheck ? node.appearance.color : (node.isCurrent ? FrondaTheme.accent : step.state.color)
            )
            .frame(width: 22, height: 24)
            .background(FrondaTheme.surface, in: Circle())
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    store.runDetail = ChatRunDetail(runID: run.id, page: .step(step.id), sequence: sequence)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Etapa \(step.number) de \(total)")
                            .font(.caption.weight(.medium)).foregroundStyle(FrondaTheme.textMuted)
                        Text(step.title).font(.callout.weight(.semibold))
                        Text(node.status).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "Etapa \(step.number), \(step.title), \(node.isCurrent ? "atual, " : "")\(node.status)"
                )
                .accessibilityHint("Abrir atividade e resultados desta etapa")
                if node.isCurrent && sequence == nil {
                    RunInterventionControls(store: store, run: run)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(node.isCurrent ? FrondaTheme.accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 12))
    }
}
