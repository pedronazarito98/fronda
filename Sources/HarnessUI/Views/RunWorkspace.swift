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
        _focusMode = SceneStorage(wrappedValue: false, key + ".focus")
    }

    private var section: RunWorkspaceSection {
        navigation?.location.section ?? fallbackSection
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
                        .popover(isPresented: $inspector, arrowEdge: .trailing) {
                            RunInspector(store: store, run: run, section: sectionSelection, isPresented: $inspector)
                                .frame(width: 320, height: 560)
                        }
                } else {
                    workspace(run)
                        .inspector(isPresented: $inspector) {
                            RunInspector(store: store, run: run, section: sectionSelection, isPresented: $inspector)
                                .inspectorColumnWidth(min: 250, ideal: 280, max: 340)
                        }
                }
            }
            .confirmationDialog("Cancelar esta tarefa?", isPresented: $confirmingCancel) {
                Button("Cancelar tarefa", role: .destructive) { store.perform("run.cancel", id: run.id) }
            } message: {
                Text("A execução será interrompida. Worktree, arquivos e histórico serão preservados.")
            }
            .onChange(of: runID) { _, _ in
                fallbackSection = .conversation
                selectedJourneyStepID = nil
                followsCurrentStep = true
                steering = ""
            }
        } else {
            EmptyPanel(
                symbol: "play.rectangle", title: "Selecione uma tarefa",
                detail: "A execução aparecerá aqui assim que o coordenador confirmar sua criação.")
        }
    }

    private func workspace(_ run: Run) -> some View {
        VStack(spacing: 0) {
            RunWorkspaceHeader(
                store: store, run: run, section: sectionSelection, inspector: $inspector, focusMode: $focusMode,
                openWindow: { openWindow(id: "run", value: run.id) },
                cancel: { confirmingCancel = true })
            RunWorkspaceNavigation(selection: sectionSelection, run: run)
            Divider()
            content(run)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FrondaTheme.surface)
            steeringBar(run)
        }
        .tint(FrondaTheme.accent)
        .modifier(RunJourneyCoach(store: store, run: run, section: sectionSelection))
    }

    @ViewBuilder private func content(_ run: Run) -> some View {
        switch section {
        case .conversation: RunConversationView(store: store, run: run, section: sectionSelection)
        case .overview:
            WorkflowOverview(
                run: run, section: sectionSelection, selectedStepID: $selectedJourneyStepID,
                followsCurrentStep: $followsCurrentStep)
        case .plan: RunPlanView(store: store, run: run)
        case .changes: DiffView(store: store, run: run)
        case .validation: ValidationView(store: store, run: run)
        case .review: ReviewView(store: store, run: run)
        case .context: ContextView(store: store, run: run)
        case .activity: ActivityView(store: store, run: run)
        case .tokens: TokensView(store: store, run: run)
        case .evidence: EvidenceView(store: store, run: run)
        case .scenarios: ScenarioEvidenceView(store: store, run: run)
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
