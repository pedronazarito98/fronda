import HarnessDomain
import SwiftUI

struct RunTaskHomeView: View {
    let store: AppStore
    let run: Run
    @Binding var section: RunWorkspaceSection
    let userAction: RunUserAction?
    let onUserAction: (RunUserAction) -> Void
    let inspectStep: (String) -> Void
    @State private var expandedObjective = false
    @State private var expandedReport = false

    private var observedStep: RunbookStep? {
        store.connected ? run.observedActiveStep : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            if let userAction {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        actionDescription(userAction)
                        Spacer(minLength: 8)
                        actionButton(userAction)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        actionDescription(userAction)
                        actionButton(userAction)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity)
                Divider()
            }
            taskContent
        }
    }

    private func actionDescription(_ action: RunUserAction) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("Sua vez", systemImage: "hand.raised")
                .font(.subheadline.weight(.semibold)).foregroundStyle(FrondaTheme.warning)
            Text(action.detail).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func actionButton(_ action: RunUserAction) -> some View {
        Button(action.title) { onUserAction(action) }
            .buttonStyle(.borderedProminent)
            .disabled(store.busy.contains(run.id) || !store.connected)
            .accessibilityIdentifier("conversation.user-action")
    }

    private var taskContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let step = observedStep {
                    Button {
                        inspectStep(step.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(step.title, systemImage: "waveform.path")
                                .font(.headline).foregroundStyle(FrondaTheme.running)
                            RunCurrentActivityLine(store: store, run: run, stepID: step.id)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14).background(
                            FrondaTheme.running.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain).help("Ver a atividade desta etapa")
                }
                if !run.source.text.isEmpty {
                    DisclosureGroup("Objetivo e orientações", isExpanded: $expandedObjective) {
                        Text(run.source.text).font(.callout).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                    }.font(.callout.weight(.medium))
                }
                if let loop = RunFollowupModel(run: run, isConnected: store.connected).loopSummary {
                    FrondaBadge(loop, symbol: "arrow.triangle.2.circlepath", color: FrondaTheme.reference)
                }
                RunJourneyTimeline(run: run, connected: store.connected, inspect: inspectStep)
                resources
                if !run.report.isEmpty || run.workflow?.investigation.isEmpty == false {
                    Divider()
                    DisclosureGroup("Resultado mais recente", isExpanded: $expandedReport) {
                        MarkdownView(run.report.isEmpty ? run.workflow?.investigation ?? "" : run.report)
                            .padding(.top, 8)
                    }.font(.callout.weight(.medium))
                }
            }
            .padding(24).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .rememberScrollPosition("run.\(run.id).task")
        .accessibilityIdentifier("run.conversation")
    }

    private var resources: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Conferir o trabalho").font(.headline).accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 175), spacing: 8)], alignment: .leading, spacing: 8) {
                if run.pack != nil || run.plan.contains(where: { $0.kind == "context" }) {
                    link(.context, title: "Contexto da tarefa", color: FrondaTheme.reference)
                }
                if !run.validations.isEmpty || run.plan.contains(where: { $0.kind == "validation" })
                    || store.snapshot.projects.first(where: { $0.id == run.projectID }).map({
                        !run.runbook.validators(for: $0).isEmpty
                    }) == true
                {
                    link(.validation, title: "Verificações", color: FrondaTheme.running)
                }
                if !run.changedFiles.isEmpty {
                    link(.changes, title: "Alterações (\(run.changedFiles.count))", color: FrondaTheme.accent)
                }
                if !run.findings.isEmpty { link(.review, title: "Achados da revisão", color: FrondaTheme.warning) }
                if !(run.evidenceArtifacts ?? []).isEmpty || run.state == .ready {
                    link(.evidence, title: "Evidências da entrega", color: FrondaTheme.accent)
                }
            }
        }
    }

    private func link(_ destination: RunWorkspaceSection, title: String, color: Color) -> some View {
        Button {
            section = destination
        } label: {
            HStack(spacing: 8) {
                Image(systemName: destination.symbol).foregroundStyle(color)
                Text(title).font(.callout)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(FrondaTheme.border) }
            .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("run.tab." + destination.rawValue)
    }
}
