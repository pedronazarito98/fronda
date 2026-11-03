import HarnessDomain
import SwiftUI

struct RunPlanView: View {
    let store: AppStore
    let run: Run
    @Binding var section: RunWorkspaceSection
    @Binding var selectedStepID: String?
    @Binding var followsCurrentStep: Bool
    @Binding var showsFollowup: Bool
    @Binding var showsDetails: Bool
    let userAction: RunUserAction?
    let onUserAction: (RunUserAction) -> Void
    @State private var compactFollowup = false
    @State private var pendingCompactAction: (runID: String, action: RunUserAction)?
    @State private var editing = false
    @State private var inspectingStep: InspectedStep?
    @State private var selectedLoopID: String?
    @State private var inspectingInline = false

    private struct InspectedStep: Identifiable { let id: String }

    private var journey: RunJourneyModel { RunJourneyModel(run: run) }
    private var followup: RunFollowupModel { RunFollowupModel(run: run, isConnected: store.connected) }
    private var selection: Binding<String?> {
        Binding(
            get: { selectedStepID },
            set: {
                selectedStepID = $0
                selectedLoopID = nil
                followsCurrentStep = $0 == journey.currentStepID
            })
    }
    private var loops: [RunFlowMapLoop] {
        guard let policy = run.runbook.loopPolicy else { return [] }
        return [
            RunFlowMapLoop(
                id: policy.id, title: policy.title,
                stepIDs: [policy.implementationStepID, policy.validationStepID],
                summary: followup.loopSummary ?? "Até \(policy.maxIterations) ciclos",
                returnLabel: "Se a validação falhar e houver limite disponível",
                didRepeat: RunFollowupLoopProjection(run: run).didRepeat)
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 880
            let showStages = geometry.size.width >= 1100
            VStack(spacing: 0) {
                toolbar(wide: wide)
                Divider()
                if showsDetails {
                    RunPlanDetailsView(store: store, run: run)
                } else {
                    if !wide && showsFollowup { compactSummary }
                    HStack(spacing: 0) {
                        if showStages {
                            stageSidebar.frame(width: 220)
                            Divider()
                        }
                        VStack(spacing: 0) {
                            RunFlowMap(
                                run: run, selectedStepID: selection, loops: loops,
                                selectedLoopID: selectedLoopID, isConnected: store.connected,
                                onInspectStep: { id in
                                    selection.wrappedValue = id
                                    if wide {
                                        inspectingInline = true
                                        showsFollowup = true
                                    } else {
                                        inspectingStep = InspectedStep(id: id)
                                    }
                                },
                                onSelectLoop: {
                                    selectedLoopID = $0
                                    inspectingInline = false
                                    selectedStepID = nil
                                    followsCurrentStep = false
                                    showsFollowup = true
                                    compactFollowup = !wide
                                })
                            if let selected = journey.steps.first(where: { $0.id == selectedStepID }) {
                                selectionBar(selected)
                            } else if let loop = loops.first(where: { $0.id == selectedLoopID }) {
                                HStack {
                                    Text("Grupo selecionado: \(loop.title)").font(.caption).lineLimit(1)
                                    Spacer(minLength: 4)
                                    Button("Ir para agora", action: followCurrent)
                                }.controlSize(.small).padding(12)
                            }
                        }
                        if wide && showsFollowup {
                            Divider()
                            inspectorSidebar.frame(width: 310)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $editing) { PlanEditorView(store: store, run: run) }
        .sheet(isPresented: $compactFollowup, onDismiss: dispatchPendingAction) {
            VStack(spacing: 0) {
                HStack {
                    Text("Acompanhamento").font(.headline)
                    Spacer()
                    Button("Concluído") { compactFollowup = false }
                }.padding(20)
                Divider()
                followupSidebar
            }.frame(minWidth: 360, idealWidth: 410, minHeight: 460, idealHeight: 620)
        }
        .sheet(item: $inspectingStep) { inspection in
            RunStepActivitySheet(store: store, runID: run.id, stepID: inspection.id, onOpen: open)
        }
        .onAppear { if followsCurrentStep { selectedStepID = journey.currentStepID } }
        .onChange(of: journey.currentStepID) { _, id in
            if followsCurrentStep { selectedStepID = id }
        }
        .onChange(of: run.plan.map(\.id)) { _, ids in
            if let selectedStepID, !ids.contains(selectedStepID) {
                self.selectedStepID = journey.currentStepID
                followsCurrentStep = true
            }
        }
    }

    private var followupSidebar: some View {
        RunFollowupSidebar(
            run: run, isConnected: store.connected, isBusy: store.busy.contains(run.id),
            userAction: userAction, onUserAction: requestAction, onOpen: open
        ).background(FrondaTheme.surface)
    }

    @ViewBuilder private var inspectorSidebar: some View {
        if inspectingInline, let selected = journey.steps.first(where: { $0.id == selectedStepID }) {
            VStack(spacing: 0) {
                HStack {
                    Text("Etapa selecionada").font(.caption.weight(.semibold))
                    Spacer()
                    Button("Acompanhar agora", action: followCurrent)
                        .help("Voltar a acompanhar a etapa atual")
                }.padding(14)
                if let userAction, store.connected {
                    HStack {
                        Label("Sua vez", systemImage: "hand.raised").foregroundStyle(FrondaTheme.warning)
                        Spacer()
                        Button(userAction.title) { requestAction(userAction) }
                            .disabled(store.busy.contains(run.id))
                    }.font(.caption).padding(.horizontal, 14).padding(.bottom, 12)
                }
                Divider()
                RunJourneyDetail(store: store, run: run, selected: selected, onOpen: open) {
                    selection.wrappedValue = $0
                }
            }.background(FrondaTheme.surface)
        } else {
            followupSidebar
        }
    }

    private var stageSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(run.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                    Label(
                        store.snapshot.projects.first(where: { $0.id == run.projectID })?.name ?? "Projeto",
                        systemImage: "folder"
                    ).font(.caption).foregroundStyle(.secondary)
                    FrondaBadge(
                        run.state.label, symbol: RunDisplay.symbol(for: run.state),
                        color: RunDisplay.color(for: run.state))
                    if journey.totalCount > 0 {
                        ProgressView(value: Double(journey.completedCount), total: Double(journey.totalCount))
                            .tint(FrondaTheme.accent)
                        Text(journey.progressSummary).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Divider()
                Text("Etapas da tarefa").font(.headline).accessibilityAddTraits(.isHeader)
                DisclosureGroup("Objetivo e orientações") {
                    Text(run.source.text).font(.caption).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.font(.caption)
                ForEach(journey.steps) { step in
                    Button {
                        selection.wrappedValue = step.id
                        inspectingInline = true
                        showsFollowup = true
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: step.state.symbol)
                                .foregroundStyle(step.state.color).frame(width: 18)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title).font(.callout.weight(.medium)).lineLimit(2)
                                Text(step.state.label).font(.caption).foregroundStyle(step.state.color)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(9).frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            step.id == selectedStepID ? step.state.color.opacity(0.10) : .clear,
                            in: RoundedRectangle(cornerRadius: 9)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Ver atividade e resultado de \(step.title)")
                    .accessibilityIdentifier("task.step." + step.id)
                }
                if let summary = followup.loopSummary {
                    Divider()
                    Label(summary, systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.medium)).foregroundStyle(FrondaTheme.reference)
                }
            }.padding(16)
        }.background(FrondaTheme.surface)
    }

    private func toolbar(wide: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                viewPicker
                Spacer()
                actions(wide: wide)
            }
            VStack(alignment: .leading, spacing: 10) {
                viewPicker
                HStack {
                    actions(wide: wide)
                    Spacer()
                }
            }
        }.fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 20).padding(.vertical, 12)
    }

    private var viewPicker: some View {
        HStack(spacing: 12) {
            Label(showsDetails ? "Proposta e etapas" : "Fluxo da tarefa", systemImage: "leaf")
                .font(.headline).foregroundStyle(FrondaTheme.accent)
            Button(showsDetails ? "Voltar ao fluxo" : "Ver proposta") { showsDetails.toggle() }
                .help(showsDetails ? "Voltar ao mapa e acompanhamento" : "Ler a proposta e as etapas do plano")
        }
    }

    private func actions(wide: Bool) -> some View {
        HStack(spacing: 10) {
            if !wide && !showsDetails {
                Button("Acompanhar", systemImage: "sidebar.right") { compactFollowup = true }
            }
            Button("Editar plano", systemImage: "slider.horizontal.3") { editing = true }
                .disabled(run.state.active || run.state == .archived || !store.connected)
                .help("Editar etapas, critérios e limites do ciclo antes da execução")
                .accessibilityIdentifier("plan.edit")
        }.controlSize(.small)
    }

    private var compactSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                compactStatus
                Spacer(minLength: 0)
                compactAction
            }
            VStack(alignment: .leading, spacing: 8) {
                compactStatus
                compactAction
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(FrondaTheme.surfaceRaised)
    }

    private var compactStatus: some View {
        HStack(spacing: 10) {
            Image(systemName: followup.currentAppearance.symbol).foregroundStyle(followup.currentAppearance.color)
            VStack(alignment: .leading, spacing: 3) {
                if userAction != nil {
                    Text("Sua vez").font(.caption2.weight(.semibold)).foregroundStyle(FrondaTheme.warning)
                }
                Text(followup.currentSummary(for: userAction)).font(.caption.weight(.semibold))
                Text(followup.loopSummary ?? userAction?.detail ?? followup.currentDetail)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
        }
    }

    @ViewBuilder private var compactAction: some View {
        if let userAction {
            Button(userAction.title) { requestAction(userAction) }
                .buttonStyle(.borderedProminent).controlSize(.small)
                .disabled(store.busy.contains(run.id) || !store.connected)
                .help(userAction.detail).accessibilityIdentifier("plan.compact-user-action")
        }
    }

    private func requestAction(_ action: RunUserAction) {
        if compactFollowup {
            pendingCompactAction = (run.id, action)
            compactFollowup = false
        } else {
            onUserAction(action)
        }
    }

    private func dispatchPendingAction() {
        guard let pending = pendingCompactAction else { return }
        pendingCompactAction = nil
        guard pending.runID == run.id, pending.action == userAction,
            store.connected, !store.busy.contains(run.id)
        else { return }
        onUserAction(pending.action)
    }

    private func selectionBar(_ selected: RunJourneyStep) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Text("Selecionado: \(selected.title)").font(.caption).lineLimit(1)
                Spacer(minLength: 4)
                if !followsCurrentStep {
                    Button("Ir para agora", action: followCurrent)
                }
                Button("Ver atividade da etapa") { inspectingStep = InspectedStep(id: selected.id) }
            }.controlSize(.small).padding(12)
        }.background(FrondaTheme.surface)
    }

    private func open(_ destination: RunWorkspaceSection) {
        compactFollowup = false
        if destination == .plan { showsDetails = true } else { section = destination }
    }

    private func followCurrent() {
        inspectingInline = false
        selection.wrappedValue = journey.currentStepID
        followsCurrentStep = true
    }
}
