import HarnessDomain
import SwiftUI

struct RunWorkspaceHeader: View {
    var store: AppStore
    let run: Run
    @Binding var section: RunWorkspaceSection
    @Binding var inspector: Bool
    @Binding var focusMode: Bool
    let showsInlineAction: Bool
    let userAction: RunUserAction?
    let onUserAction: (RunUserAction) -> Void
    let openWindow: () -> Void
    let cancel: () -> Void
    @SceneStorage("fronda.workspace.inspectorBeforeFocus") private var inspectorBeforeFocus = false
    @State private var editingExecution = false
    @Environment(\.workspaceNavigation) private var navigation
    @Environment(\.workspaceShowsSummary) private var showsSummary
    @Environment(\.workspaceIsSidePane) private var isSidePane
    @Environment(\.openWindow) private var openNativeWindow

    private var busy: Bool { store.busy.contains(run.id) }
    private var actionsDisabled: Bool { busy || !store.connected }
    private var receivesShortcuts: Bool { navigation == nil || navigation?.id == store.navigation.id }
    private var projectName: String {
        store.snapshot.projects.first { $0.id == run.projectID }?.name ?? "Projeto"
    }
    private var isHistory: Bool {
        [.archived, .cancelled].contains(run.state) || run.workflow?.delivery.closedAt != nil
    }

    private var atDestination: Bool {
        return userAction?.destination == section
    }

    private var approvalTitle: String? {
        guard [.waitingUser, .partial].contains(run.state), let pack = run.pack,
            !run.revision.isEmpty, pack.revision == run.revision
        else { return nil }
        switch userAction {
        case .reviewContext where !run.contextApproved:
            return run.workflow == nil ? "Aprovar plano e envio" : "Autorizar investigação"
        case .reviewProposal where run.contextApproved && !run.planApproved && run.workflow?.proposal.isEmpty == false:
            return "Aprovar implementação"
        default: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(run.title).font(.system(size: 17, weight: .semibold))
                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("run.title")
                actionsMenu
                if let navigation, store.workspace.selected.secondary != nil {
                    Button("Escolher conteúdo", systemImage: "square.grid.2x2") { navigation.visit(.newTab) }
                        .labelStyle(.iconOnly).help("Escolher outra página, projeto ou tarefa para este painel")
                }
                if !isSidePane {
                    Button("Abrir em outra janela", systemImage: "macwindow.badge.plus", action: openWindow)
                        .labelStyle(.iconOnly).help("Abrir tarefa em outra janela")
                        .accessibilityIdentifier("run.open-window")
                }
                Button {
                    if !inspector { focusMode = false }
                    inspector.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .help("Mostrar ou ocultar detalhes (⌃⌘I)")
                .keyboardShortcut(receivesShortcuts ? KeyboardShortcut("i", modifiers: [.command, .control]) : nil)
                .accessibilityLabel(inspector ? "Ocultar detalhes" : "Mostrar detalhes")
                .accessibilityIdentifier("run.inspector")
                Button("Abrir em nova aba", systemImage: "arrow.up.forward.square") {
                    store.workspace.openTab(navigation?.location ?? WorkspaceLocation(route: "run:" + run.id))
                    openNativeWindow(id: "main")
                }.labelStyle(.iconOnly).help("Abrir tarefa em nova aba")
                if isSidePane {
                    Button("Fechar painel", systemImage: "xmark") { store.workspace.closeSide() }
                        .help("Fechar o painel direito sem interromper a execução")
                        .labelStyle(.iconOnly).accessibilityIdentifier("workspace.close-side")
                }
            }.buttonStyle(.plain)
            if showsSummary && !focusMode {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        summary
                        Spacer(minLength: 8)
                        actionButtons
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        summary
                        actionButtons
                    }
                }
            } else {
                actionButtons
            }
        }
        .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 10)
        .background(FrondaTheme.surface)
        .sheet(isPresented: $editingExecution) { RunExecutionEditor(store: store, run: run) }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: "pin").accessibilityHidden(true)
                Text(projectName + " · " + RunBoardStage.stage(for: run).rawValue).lineLimit(1)
                FrondaBadge(
                    store.connected ? run.state.label : "Último estado · " + run.state.label,
                    symbol: store.connected ? RunDisplay.symbol(for: run.state) : "wifi.slash",
                    color: store.connected ? RunDisplay.color(for: run.state) : FrondaTheme.textMuted
                )
                .accessibilityLabel(run.state.rawValue + " · " + run.state.label)
                .accessibilityIdentifier("run.state")
            }.font(.caption2).foregroundStyle(.secondary)
            if !showsInlineAction, let guidance {
                Text(guidance).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    .help(guidance).accessibilityIdentifier("run.next-step")
            }
        }
    }

    private var guidance: String? {
        if !store.connected { return "Sem conexão com o coordenador. Exibindo o último estado recebido." }
        if let userAction { return userAction.detail }
        if run.state == .queued {
            return store.snapshot.preferences.queuePaused
                ? "A fila está pausada." : "A tarefa começará quando houver capacidade disponível."
        }
        if run.state == .running, let step = run.currentStep { return "Etapa em execução: " + step.title }
        if run.state == .preparing { return "O contexto está sendo preparado para revisão." }
        return nil
    }

    @ViewBuilder private var actionButtons: some View {
        HStack(spacing: 8) {
            if busy && !run.state.active { ProgressView().controlSize(.small) }
            if let userAction {
                if !showsInlineAction && !atDestination {
                    Button(userAction.title) { onUserAction(userAction) }
                        .buttonStyle(.borderedProminent)
                        .help(userAction.detail)
                        .disabled(actionsDisabled)
                        .accessibilityIdentifier(actionIdentifier(userAction))
                }
                if let approvalTitle {
                    if atDestination {
                        approvalButton(approvalTitle).buttonStyle(.borderedProminent)
                    } else if section == .conversation {
                        approvalButton(approvalTitle).buttonStyle(.bordered)
                    }
                }
                if userAction == .recover && section == .changes {
                    Button("Reconciliar arquivos") { store.perform("run.reconcile", id: run.id) }
                        .disabled(actionsDisabled)
                    resumeButton("Retomar etapas")
                } else if userAction == .inspectBlocker && section == .activity
                    && [.failed, .blocked].contains(run.state)
                {
                    resumeButton("Tentar novamente")
                }
            } else {
                passiveActions
            }
        }.controlSize(.regular)
    }

    private func actionIdentifier(_ action: RunUserAction) -> String {
        switch action {
        case .reviewContext: "run.context"
        case .prepareContext, .resume: "run.resume"
        default: "run.next-action"
        }
    }

    private func approvalButton(_ title: String) -> some View {
        Button(title, action: approve)
            .accessibilityIdentifier("run.approve")
            .help(userAction?.detail ?? "Autorizar a próxima etapa da tarefa")
            .disabled(actionsDisabled)
    }

    private func resumeButton(_ title: String) -> some View {
        Button(title) { store.perform("run.resume", id: run.id) }
            .buttonStyle(.borderedProminent)
            .disabled(actionsDisabled)
            .accessibilityIdentifier("run.resume")
    }

    @ViewBuilder private var passiveActions: some View {
        if run.state.active {
            Button("Pausar execução", systemImage: "pause") { store.perform("run.pause", id: run.id) }
                .accessibilityIdentifier("run.pause")
                .help("Interrompe a tentativa atual e preserva o estado para retomada.")
                .disabled(!store.connected)
        } else if run.state == .queued {
            if store.snapshot.preferences.queuePaused {
                Button("Retomar fila") { store.perform("queue.toggle") }.buttonStyle(.borderedProminent)
                    .disabled(!store.connected || store.busy.contains("queue.toggle"))
            } else if section != .activity {
                Button("Acompanhar atividade") { section = .activity }
            }
        } else if isHistory && section != .activity {
            Button("Consultar histórico") { section = .activity }
        }
    }

    private var actionsMenu: some View {
        Menu {
            Button("Modelo, esforço e agentes por etapa", systemImage: "cpu") { editingExecution = true }
                .disabled(run.state.active || actionsDisabled || run.state == .archived)
            Button("Abrir em outra janela", systemImage: "macwindow.badge.plus", action: openWindow)
            Button(focusMode ? "Sair do modo foco" : "Modo foco", action: toggleFocus)
                .keyboardShortcut(receivesShortcuts ? KeyboardShortcut("f", modifiers: [.command, .option]) : nil)
                .accessibilityIdentifier("run.focus")
            Divider()
            if run.state.active {
                Button("Pausar execução") { store.perform("run.pause", id: run.id) }
                    .disabled(!store.connected)
            } else if run.state != .archived {
                Button(run.contextApproved ? "Retomar etapas" : "Preparar contexto") {
                    store.perform("run.resume", id: run.id)
                }.disabled(actionsDisabled)
            }
            Button("Bifurcar abordagem") { store.perform("run.fork", id: run.id) }
                .disabled(actionsDisabled)
            Button("Reconciliar arquivos") { store.perform("run.reconcile", id: run.id) }
                .disabled(actionsDisabled)
            Button("Exportar evidências") { store.perform("evidence.export", id: run.id) }
                .disabled(actionsDisabled)
            Button("Arquivar") { store.perform("run.archive", id: run.id) }
                .disabled(actionsDisabled || run.state == .archived)
            Divider()
            Button("Cancelar tarefa", role: .destructive, action: cancel)
                .disabled(!store.connected || run.state == .archived)
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help("Mais ações").accessibilityLabel("Mais ações da tarefa")
        .accessibilityIdentifier("run.actions")
    }

    private func toggleFocus() {
        if focusMode {
            inspector = inspectorBeforeFocus
        } else {
            inspectorBeforeFocus = inspector
            inspector = false
        }
        focusMode.toggle()
    }

    private func approve() {
        guard !actionsDisabled, approvalTitle != nil else { return }
        store.perform("run.approve", id: run.id) { $0.expectedSequence = run.sequence }
    }
}
