import HarnessDomain
import SwiftUI

struct RunWorkspace: View {
    var store: AppStore
    let runID: String
    @Environment(\.workspaceNavigation) private var navigation
    @State private var fallbackSection = RunWorkspaceSection.conversation
    @SceneStorage private var selectedJourneyStepID: String?
    @SceneStorage private var followsCurrentStep: Bool
    @SceneStorage private var steering: String
    @State private var confirmingCancel = false
    @SceneStorage private var inspector: Bool
    @SceneStorage private var followup: Bool
    @State private var actionSheet: RunActionSheet?
    @SceneStorage private var expandedSteering: Bool
    @SceneStorage private var focusMode: Bool

    @Environment(\.openWindow) private var openWindow

    init(store: AppStore, runID: String, namespace: String = "window") {
        self.store = store
        self.runID = runID
        let key = "fronda.\(namespace).run.\(runID)"
        _selectedJourneyStepID = SceneStorage(key + ".step")
        _followsCurrentStep = SceneStorage(wrappedValue: true, key + ".follows")
        _steering = SceneStorage(wrappedValue: "", key + ".steering")
        _inspector = SceneStorage(wrappedValue: false, key + ".inspector")
        _followup = SceneStorage(wrappedValue: true, key + ".followup")
        _expandedSteering = SceneStorage(wrappedValue: false, key + ".planSteering")
        _focusMode = SceneStorage(wrappedValue: false, key + ".focus")
    }

    private var section: RunWorkspaceSection {
        let destination = navigation?.location.section ?? fallbackSection
        return destination.isTaskHome ? .conversation : destination
    }
    private var sectionSelection: Binding<RunWorkspaceSection> {
        Binding(
            get: { section },
            set: { destination in
                if let navigation {
                    navigation.visit(WorkspaceLocation(route: "run:" + runID, section: destination))
                } else {
                    fallbackSection = destination
                }
            })
    }

    private var run: Run? { store.snapshot.runs.first { $0.id == runID } }
    private var metadataInspector: Binding<Bool> {
        Binding(get: { section != .plan && !section.isTaskHome && inspector }, set: { inspector = $0 })
    }
    private var busy: Bool { store.busy.contains(runID) }
    private var receivesShortcuts: Bool { navigation == nil || navigation?.id == store.navigation.id }
    private var canSendSteering: Bool {
        store.connected && !busy && run?.state != .archived
            && !steering.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if let run {
            Group {
                if navigation != nil {
                    workspace(run)
                        .popover(isPresented: metadataInspector, arrowEdge: .trailing) {
                            RunInspector(store: store, run: run, section: sectionSelection, isPresented: $inspector)
                                .frame(width: 320, height: 560)
                        }
                } else {
                    workspace(run)
                        .inspector(isPresented: metadataInspector) {
                            RunInspector(store: store, run: run, section: sectionSelection, isPresented: $inspector)
                                .inspectorColumnWidth(min: 250, ideal: 280, max: 340)
                        }
                }
            }
            .sheet(item: $actionSheet) { sheet in
                if let current = self.run {
                    sheet.content(store: store, run: current) { destination in
                        actionSheet = nil
                        sectionSelection.wrappedValue = destination
                    }
                }
            }
            .confirmationDialog("Cancelar esta tarefa?", isPresented: $confirmingCancel) {
                Button("Cancelar tarefa", role: .destructive) { store.perform("run.cancel", id: run.id) }
            } message: {
                Text("A execução será interrompida. Worktree, arquivos e histórico serão preservados.")
            }
            .onChange(of: runID) { _, _ in
                actionSheet = nil
                fallbackSection = .conversation
                selectedJourneyStepID = nil
                followsCurrentStep = true
                steering = ""
            }
            .onChange(of: section) { _, destination in
                if !destination.isTaskHome && !steering.isEmpty { expandedSteering = true }
            }
        } else {
            EmptyPanel(
                symbol: "play.rectangle", title: "Selecione uma tarefa",
                detail: "A execução aparecerá aqui assim que o coordenador confirmar sua criação.")
        }
    }

    private func workspace(_ run: Run) -> some View {
        let action = userAction(for: run)
        return VStack(spacing: 0) {
            RunWorkspaceHeader(
                store: store, run: run, section: sectionSelection,
                inspector: section == .plan || section.isTaskHome ? $followup : $inspector, focusMode: $focusMode,
                showsInlineAction: (section.isTaskHome || section == .plan) && followup,
                userAction: action, onUserAction: performUserAction,
                openWindow: { openWindow(id: "run", value: run.id) },
                cancel: { confirmingCancel = true })
            RunWorkspaceNavigation(selection: sectionSelection)
            Divider()
            content(run, action: action)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FrondaTheme.surface)
            HStack {
                Button(
                    expandedSteering ? "Recolher orientação" : "Orientar execução",
                    systemImage: expandedSteering ? "chevron.down" : "text.bubble"
                ) { expandedSteering.toggle() }
                .buttonStyle(.plain).font(.caption)
                .help("Enviar uma orientação para a tarefa")
                Spacer()
            }.padding(.horizontal, 22).padding(.vertical, 10)
            if expandedSteering { steeringBar(run) }
        }
        .tint(FrondaTheme.accent)
        .modifier(RunJourneyCoach(store: store, run: run, section: sectionSelection))
    }

    @ViewBuilder private func content(_ run: Run, action: RunUserAction?) -> some View {
        switch section {
        case .conversation, .overview:
            RunPlanView(
                store: store, run: run, section: sectionSelection, selectedStepID: $selectedJourneyStepID,
                followsCurrentStep: $followsCurrentStep, showsFollowup: $followup,
                showsDetails: Binding(get: { false }, set: { if $0 { sectionSelection.wrappedValue = .proposal } }),
                userAction: action, onUserAction: performUserAction)
        case .files: RunFilesView(store: store, run: run, section: sectionSelection)
        case .plan, .proposal:
            RunPlanView(
                store: store, run: run, section: sectionSelection, selectedStepID: $selectedJourneyStepID,
                followsCurrentStep: $followsCurrentStep, showsFollowup: $followup,
                showsDetails: Binding(
                    get: { section == .proposal }, set: { sectionSelection.wrappedValue = $0 ? .proposal : .plan }),
                userAction: action, onUserAction: performUserAction)
        case .changes: DiffView(store: store, run: run)
        case .validation: ValidationView(store: store, run: run)
        case .checkup: RunCheckupView(store: store, run: run, section: sectionSelection)
        case .review: ReviewView(store: store, run: run)
        case .context: ContextView(store: store, run: run)
        case .activity: ActivityView(store: store, run: run)
        case .tokens: TokensView(store: store, run: run)
        case .evidence: EvidenceView(store: store, run: run)
        case .scenarios: ScenarioEvidenceView(store: store, run: run)
        }
    }

    private func userAction(for run: Run) -> RunUserAction? {
        guard store.connected else { return nil }
        let project = store.snapshot.projects.first { $0.id == run.projectID }
        return RunUserAction.next(for: run, project: project)
    }

    private func performUserAction(_ action: RunUserAction) {
        guard store.connected, !busy, let run, userAction(for: run) == action else { return }
        if let destination = action.destination {
            sectionSelection.wrappedValue = destination
            return
        }
        switch action {
        case .prepareContext, .resume:
            store.perform("run.resume", id: run.id) { $0.expectedSequence = run.sequence }
        case .editLoopPolicy: actionSheet = .loopPolicy
        case .recordReproduction: actionSheet = .reproduction
        case .recordVerification: actionSheet = .verification
        case .reviewOperations: actionSheet = .operations
        default: break
        }
    }

    private func steeringBar(_ run: Run) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Peça um ajuste…", text: $steering, axis: .vertical)
                .textFieldStyle(.plain).lineLimit(1...5)
                .accessibilityIdentifier("run.steering")
                .disabled(run.state == .archived)
            HStack(alignment: .center, spacing: 10) {
                RunExecutionPickers(store: store, run: run)
                Spacer(minLength: 0)
                if busy { ProgressView().controlSize(.small) }
                Button(action: sendSteering) {
                    Image(systemName: "arrow.up").font(.system(size: 14, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderedProminent).buttonBorderShape(.circle)
                .keyboardShortcut(receivesShortcuts ? KeyboardShortcut(.return, modifiers: .command) : nil)
                .disabled(!canSendSteering)
                .help("Enviar orientação (⌘↩)").accessibilityLabel("Enviar orientação")
                .accessibilityIdentifier("run.send-steering")
            }
        }
        .padding(16)
        .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(FrondaTheme.border.opacity(0.8)))
        .padding(.horizontal, 20).padding(.bottom, 16).padding(.top, 8)
        .background(FrondaTheme.surface)
    }

    private func sendSteering() {
        guard canSendSteering else { return }
        let text = steering.trimmingCharacters(in: .whitespacesAndNewlines)
        steering = ""
        store.perform("run.steer", id: runID) { $0.text = text }
    }
}
