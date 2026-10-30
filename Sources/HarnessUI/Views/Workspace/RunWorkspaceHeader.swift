import HarnessDomain
import SwiftUI

struct RunWorkspaceHeader: View {
    var store: AppStore
    let run: Run
    @Binding var section: RunWorkspaceSection
    @Binding var inspector: Bool
    @Binding var focusMode: Bool
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
    private enum NextStep {
        case running, context, plan, reproduction, verification, delivery, decisions
        case blocked, recovery, partial, queued, resume, prepare, history
    }
    private var nextStepKind: NextStep {
        if run.state.active { return .running }
        if [.archived, .cancelled].contains(run.state) || run.workflow?.delivery.closedAt != nil { return .history }
        if [.blocked, .failed].contains(run.state) { return .blocked }
        if run.state == .recovering { return .recovery }
        if run.state == .waitingUser {
            if !run.contextApproved { return .context }
            if !run.planApproved && !(run.workflow?.proposal.isEmpty ?? true) { return .plan }
            if run.currentStep?.kind == "reproduction" { return .reproduction }
            if run.currentStep?.kind == "verification" { return .verification }
            if run.approvals.contains(where: { $0.state == "PREPARED" }) { return .decisions }
        }
        if run.state == .ready { return .delivery }
        if run.state == .partial { return .partial }
        if run.state == .queued { return .queued }
        return run.contextApproved ? .resume : .prepare
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
                HStack(spacing: 8) {
                    Image(systemName: "pin").accessibilityHidden(true)
                    Text(projectName + " · " + RunBoardStage.stage(for: run).rawValue).lineLimit(1)
                    Spacer(minLength: 0)
                    Text(run.state.label).font(.system(size: 10, weight: .medium))
                        .foregroundStyle(RunDisplay.color(for: run.state))
                        .accessibilityLabel(run.state.rawValue + " · " + run.state.label)
                        .accessibilityIdentifier("run.state")
                }.font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if showsSummary && !focusMode { nextStep } else { primaryActions }
        }
        .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 12)
        .background(FrondaTheme.surface)
        .sheet(isPresented: $editingExecution) { RunExecutionEditor(store: store, run: run) }
    }

    private var nextStep: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 20) {
                nextStepLabel
                Spacer(minLength: 8)
                primaryActions
            }
            VStack(alignment: .leading, spacing: 12) {
                nextStepLabel
                primaryActions
            }
        }
    }

    private var nextStepLabel: some View {
        HStack(alignment: .top, spacing: 10) {
            if run.state.active {
                ProgressView().controlSize(.small).padding(.top, 2)
                    .accessibilityLabel("Execução em andamento")
            } else {
                Image(systemName: run.state == .ready ? "checkmark.seal" : "arrow.turn.down.right")
                    .foregroundStyle(FrondaTheme.accent).padding(.top, 2).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(nextStepTitle).font(.caption.weight(.semibold)).foregroundStyle(FrondaTheme.accent).lineLimit(1)
                Text(nextStepDescription)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    .help(nextStepDescription)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("run.next-step")
    }

    private var nextStepTitle: String {
        switch nextStepKind {
        case .running: "Em andamento"
        case .history: "Histórico preservado"
        case .queued: "Aguardando execução"
        case .resume: "Execução pausada"
        case .prepare: "Próximo passo"
        default: "O que precisa de você"
        }
    }

    private var nextStepDescription: String {
        switch nextStepKind {
        case .running:
            run.state == .preparing
                ? "O contexto está sendo preparado para você conferir."
                : "\(run.provider.rawValue) está na etapa “\(run.currentStep?.title ?? "Execução")”."
        case .context:
            run.workflow == nil
                ? "Confira o contexto, o destino e o plano antes de autorizar o envio."
                : "Confira os arquivos e o conteúdo que o executor receberá antes de autorizar a investigação."
        case .plan: "Confira a proposta e aprove o plano para iniciar a implementação."
        case .reproduction: "Registre como o problema acontece, o resultado esperado e o que foi observado."
        case .verification: "Confira o cenário no código atual e registre a evidência do resultado."
        case .delivery: "Confira as alterações, os critérios e as evidências antes de preparar a publicação."
        case .decisions: "Uma operação aguarda sua confirmação. Confira o que será alterado antes de aprovar."
        case .blocked:
            run.reason.isEmpty
                ? "Confira o impedimento e o que precisa ser resolvido antes de tentar novamente." : run.reason
        case .recovery: "Confira o estado da worktree e reconcilie os arquivos antes de continuar."
        case .partial: "Há resultados que precisam de revisão. Confira as pendências e suas evidências."
        case .queued:
            store.snapshot.preferences.queuePaused
                ? "A fila está pausada. Retome a fila quando quiser continuar."
                : "A tarefa começará quando houver capacidade disponível."
        case .resume: "Retome o trabalho para continuar da próxima etapa pendente."
        case .prepare: "Prepare o contexto para conferir o material que será enviado ao executor."
        case .history: "Consulte o histórico e os resultados preservados desta tarefa."
        }
    }

    private var primaryActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { primaryActionButtons }
            VStack(alignment: .leading, spacing: 8) { primaryActionButtons }
        }.controlSize(.regular)
    }

    @ViewBuilder private var primaryActionButtons: some View {
        if busy && !run.state.active { ProgressView().controlSize(.small) }
        switch nextStepKind {
        case .running:
            Button("Pausar", systemImage: "pause") { store.perform("run.pause", id: run.id) }
                .accessibilityIdentifier("run.pause")
                .disabled(!store.connected)
        case .context:
            Button("Revisar contexto") { section = .context }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("run.context")
            Button(run.workflow == nil ? "Aprovar plano e envio" : "Autorizar investigação") {
                approve()
            }
            .accessibilityIdentifier("run.approve")
            .disabled(actionsDisabled)
        case .plan:
            Button("Revisar plano") { section = .plan }.buttonStyle(.borderedProminent)
            Button("Aprovar implementação") { approve() }
                .accessibilityIdentifier("run.approve")
                .disabled(actionsDisabled)
        case .reproduction:
            Button("Registrar reprodução", systemImage: "viewfinder") { section = .scenarios }
                .buttonStyle(.borderedProminent)
        case .verification:
            Button("Conferir cenário", systemImage: "checkmark.viewfinder") { section = .scenarios }
                .buttonStyle(.borderedProminent)
        case .delivery:
            Button("Revisar entrega", systemImage: "doc.richtext") { section = .evidence }
                .buttonStyle(.borderedProminent)
        case .decisions:
            Button("Revisar operação", systemImage: "checkmark.bubble") { section = .evidence }
                .buttonStyle(.borderedProminent)
        case .blocked:
            Button("Conferir impedimento") { section = .activity }.buttonStyle(.borderedProminent)
            Button("Tentar novamente") { store.perform("run.resume", id: run.id) }
                .accessibilityIdentifier("run.resume").disabled(actionsDisabled)
        case .recovery:
            Button("Conferir recuperação") { section = .activity }.buttonStyle(.borderedProminent)
        case .partial:
            Button("Revisar pendências") { section = .evidence }.buttonStyle(.borderedProminent)
            Button("Retomar etapas") { store.perform("run.resume", id: run.id) }
                .accessibilityIdentifier("run.resume").disabled(actionsDisabled)
        case .queued:
            if store.snapshot.preferences.queuePaused {
                Button("Retomar fila") { store.perform("queue.toggle") }.buttonStyle(.borderedProminent)
                    .disabled(!store.connected || store.busy.contains("queue.toggle"))
            } else {
                Button("Acompanhar atividade") { section = .activity }
            }
        case .history:
            Button("Consultar histórico") { section = .activity }
        case .resume, .prepare:
            Button(run.contextApproved ? "Retomar etapas" : "Preparar contexto", systemImage: "play") {
                store.perform("run.resume", id: run.id)
            }
            .buttonStyle(.borderedProminent).accessibilityIdentifier("run.resume")
            .disabled(actionsDisabled)
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
            Section("Navegar") {
                ForEach(RunWorkspaceSection.allCases) { destination in
                    Button {
                        section = destination
                    } label: {
                        Label(destination.rawValue, systemImage: destination.symbol)
                    }
                }
            }
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
        store.perform("run.approve", id: run.id) { $0.expectedSequence = run.sequence }
    }
}
