import HarnessDomain
import SwiftUI

struct ChatExecutionCard: View {
    let store: AppStore
    let run: Run
    let snapshotSequence: Int?
    var compact = false
    let openGraph: () -> Void

    var body: some View {
        ChatExecutionSummary(
            store: store, run: run, sequence: snapshotSequence, compact: compact, openGraph: openGraph)
    }
}

/// Keeps the next decision visible even when recent instructions are below the execution card.
struct ChatAttentionBanner: View {
    let store: AppStore
    let showGuidance: (String) -> Void

    private var run: Run? {
        guard store.connected,
            let turn = store.selectedChat?.turns.reversed().first(where: { $0.runID != nil }),
            turn.runSnapshotSequence == nil, let id = turn.runID,
            let run = store.snapshot.runs.first(where: { $0.id == id }),
            !run.state.active, ![.queued, .cancelled, .archived].contains(run.state)
        else { return nil }
        guard run.state != .ready || guidanceNeedingDecision(run) != nil else { return nil }
        return run
    }

    private func needsGuidanceDecision(_ run: Run) -> Bool {
        guidanceNeedingDecision(run) != nil
    }

    private func guidanceNeedingDecision(_ run: Run) -> RunGuidance? {
        let messages = (run.guidance ?? []).filter { $0.conversationTurnID == run.conversationTurnID }
        if let requiringDecision = messages.first(where: {
            $0.status == .uncertain
                || ($0.status != .dismissed && $0.attachmentError?.isEmpty == false
                    && $0.continueWithoutAttachments != true)
        }) {
            return requiringDecision
        }
        guard run.state == .waitingUser,
            run.reason == "Há uma orientação aguardando entrega, mas esta tarefa não tem etapa de implementação."
        else { return nil }
        return messages.first { $0.status == .queued && $0.attemptID == nil }
    }

    var body: some View {
        if let run {
            let action = RunUserAction.next(
                for: run, project: store.snapshot.projects.first { $0.id == run.projectID })
            if action != nil || needsGuidanceDecision(run) || run.isPauseRequested {
                HStack {
                    Text(attentionTitle(run))
                    Spacer()
                    actionControl(run)
                }
            }
        }
    }

    private func attentionTitle(_ run: Run) -> String {
        if run.isPauseRequested { return "Solicitando pausa…" }
        if run.needsPauseReview { return "Parada não confirmada" }
        if run.hasAcknowledgedPause { return "Interrupção conferida por você" }
        return run.state == .paused ? "Trabalho pausado" : "Sua atenção é necessária"
    }

    @ViewBuilder private func actionControl(_ run: Run) -> some View {
        if run.pauseAllowsContinuation, let guidance = guidanceNeedingDecision(run) {
            Button("Ver orientação", systemImage: "text.bubble") { showGuidance(guidance.id) }
                .buttonStyle(.borderedProminent).controlSize(.small)
                .accessibilityIdentifier("chat.attention.guidance")
        } else if !needsGuidanceDecision(run) || run.needsPauseReview || run.isPauseRequested {
            RunInterventionControls(store: store, run: run, primaryOnly: true)
        }
    }
}

private struct ChatExecutionSummary: View {
    let store: AppStore
    let run: Run
    let sequence: Int?
    let compact: Bool
    let openGraph: () -> Void
    @State private var expanded = false

    private var next: RunUserAction? {
        guard sequence == nil else { return nil }
        return RunUserAction.next(for: run, project: store.snapshot.projects.first { $0.id == run.projectID })
    }

    private var operationNeedsAttention: Bool {
        !run.state.active && run.pauseAllowsContinuation && run.hasUnresolvedExternalOperations
    }

    var body: some View {
        let followup = RunFollowupModel(run: run, isConnected: store.connected)
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    status(followup)
                    Spacer(minLength: 12)
                    controls
                }
                VStack(alignment: .leading, spacing: 12) {
                    status(followup)
                    controls
                }
            }
            if !compact && !followup.journey.steps.isEmpty {
                progress(followup.journey)
            }
            if sequence == nil {
                guidance(followup)
                ChatBudgetStatus(store: store, run: run)
            }
            if [.blocked, .failed, .recovering].contains(run.state), !run.reason.isEmpty {
                Text(run.reason).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if sequence == nil
                && (([.paused, .recovering].contains(run.state) && run.pauseAllowsContinuation)
                    || (!run.state.active && run.pauseAllowsContinuation && run.hasUnresolvedExternalOperations))
            {
                ChatRecoverySummary(store: store, run: run)
            }
            if sequence == nil {
                RunInterventionControls(store: store, run: run)
            }
            if expanded {
                Divider()
                RunJourneyTimeline(
                    run: run, connected: store.connected,
                    project: store.snapshot.projects.first { $0.id == run.projectID }, showsCurrent: sequence == nil
                ) { id in
                    store.runDetail = ChatRunDetail(runID: run.id, page: .step(id), sequence: sequence)
                }
            }
        }
        .padding(compact ? 10 : 14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FrondaTheme.surface.opacity(0.75))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(FrondaTheme.border.opacity(0.8))
                }
        }

    }

    private func status(_ followup: RunFollowupModel) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: followup.currentAppearance.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(followup.currentAppearance.color)
                .frame(width: 28, height: 28)
                .background(followup.currentAppearance.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(followup.currentSummary(for: next))
                    .font(.callout.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let step = followup.currentStep, sequence == nil,
                    ![.ready, .cancelled, .archived].contains(run.state) && run.workflow?.delivery.closedAt == nil
                {
                    Text("Etapa \(step.number) de \(followup.journey.totalCount) · \(step.title)")
                        .font(.caption).foregroundStyle(FrondaTheme.textMuted)
                } else if !run.plan.isEmpty {
                    Text(followup.journey.progressSummary)
                        .font(.caption).foregroundStyle(FrondaTheme.textMuted)
                }
            }
        }
    }

    private func progress(_ journey: RunJourneyModel) -> some View {
        HStack(spacing: 3) {
            ForEach(journey.steps) { step in
                Capsule()
                    .fill(progressColor(for: step))
                    .frame(maxWidth: .infinity)
                    .frame(height: 3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(journey.progressSummary)
    }

    private func progressColor(for step: RunJourneyStep) -> Color {
        if step.isCurrent { return step.state.color }
        if step.state == .passed { return FrondaTheme.success.opacity(0.65) }
        if step.state == .skipped { return FrondaTheme.textMuted.opacity(0.5) }
        return FrondaTheme.border
    }

    @ViewBuilder private func guidance(_ followup: RunFollowupModel) -> some View {
        if ![.cancelled, .archived].contains(run.state) {
            VStack(alignment: .leading, spacing: 5) {
                Label(guidanceTitle, systemImage: guidanceSymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(guidanceColor)
                Text(guidanceDetail(followup))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(guidanceColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
            .accessibilityIdentifier("chat.execution.guidance")
        }
    }

    private var guidanceTitle: String {
        guard store.connected else { return "Conexão interrompida" }
        if run.isPauseRequested { return "Solicitando pausa…" }
        if run.needsPauseReview { return "Parada não confirmada" }
        if run.hasAcknowledgedPause { return "Interrupção conferida por você" }
        if operationNeedsAttention { return "Precisa da sua atenção" }
        switch run.state {
        case .preparing, .running: return "Em andamento"
        case .queued: return store.snapshot.preferences.queuePaused ? "Fila pausada" : "Na fila"
        case .paused: return "Trabalho pausado"
        case .ready: return "Pronto para revisão"
        case .draft, .waitingUser, .partial, .blocked, .failed, .recovering: return "Precisa da sua atenção"
        case .cancelled, .archived: return "Trabalho encerrado"
        }
    }

    private var guidanceSymbol: String {
        guard store.connected else { return "wifi.slash" }
        if run.isPauseRequested { return "clock" }
        if run.needsPauseReview { return "exclamationmark.triangle" }
        if operationNeedsAttention { return "hand.raised" }
        switch run.state {
        case .preparing, .running: return "sparkle"
        case .queued: return "clock"
        case .paused: return "pause.circle"
        case .ready: return "checkmark.circle"
        case .draft, .waitingUser, .partial, .blocked, .failed, .recovering: return "hand.raised"
        case .cancelled, .archived: return "circle"
        }
    }

    private var guidanceColor: Color {
        guard store.connected else { return FrondaTheme.textMuted }
        if run.isPauseRequested { return FrondaTheme.running }
        if run.needsPauseReview { return FrondaTheme.warning }
        if operationNeedsAttention { return FrondaTheme.warning }
        switch run.state {
        case .preparing, .running: return FrondaTheme.running
        case .draft, .waitingUser, .partial, .blocked, .failed, .recovering: return FrondaTheme.warning
        case .ready: return FrondaTheme.success
        case .queued, .paused, .cancelled, .archived: return FrondaTheme.textMuted
        }
    }

    private func guidanceDetail(_ followup: RunFollowupModel) -> String {
        guard store.connected else { return followup.currentDetail }
        if run.isPauseRequested || run.needsPauseReview
            || run.hasAcknowledgedPause
        {
            return followup.currentDetail
        }
        if operationNeedsAttention, let next { return next.detail }
        if run.state == .queued && store.snapshot.preferences.queuePaused {
            return "A fila está pausada. Retome a fila para continuar o trabalho."
        }
        if run.state == .blocked && run.reason.localizedCaseInsensitiveContains("orçamento") {
            if run.needsBudgetRecheck {
                return "Limite alterado. Retome para verificar se o orçamento é suficiente."
            }
            return run.reportedTokens >= run.budget
                ? "O limite de tokens foi atingido. Ajuste o limite antes de continuar."
                : "O contexto estimado não cabe no orçamento restante. Ajuste o limite ou reduza o contexto."
        }
        if let next, !run.state.active { return next.detail }
        return followup.currentDetail
    }

    private var controls: some View {
        HStack(spacing: 5) {
            Button {
                expanded.toggle()
            } label: {
                Label(expanded ? "Ocultar etapas" : "Etapas", systemImage: expanded ? "chevron.up" : "list.bullet")
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(FrondaTheme.canvas.opacity(0.8), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("chat.execution.steps")
            Button(action: openGraph) {
                Label("Grafo", systemImage: "point.3.connected.trianglepath.dotted")
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(FrondaTheme.canvas.opacity(0.8), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain).accessibilityIdentifier("chat.execution.graph")
            if sequence == nil {
                Menu {
                    Button("Arquivos da execução") { show(.files) }
                    Button("Atividade") { show(.activity) }
                    Button("Consumo e limite de tokens…") { show(.tokens) }
                        .disabled(run.state == .archived || !store.connected)
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 28, height: 28)
                        .background(FrondaTheme.canvas.opacity(0.8), in: RoundedRectangle(cornerRadius: 7))
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel("Ações da execução")
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(FrondaTheme.textMuted)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func show(_ section: RunWorkspaceSection) {
        store.runDetail = ChatRunDetail(runID: run.id, page: .section(section))
    }

}

/// Controls use the coordinator's state and are shared by the conversation and the graph.
struct RunInterventionControls: View {
    let store: AppStore
    let run: Run
    var primaryOnly = false
    @State private var confirmingCancel = false
    @State private var acknowledgingPause = false
    @State private var pauseError: String?

    private var next: RunUserAction? {
        RunUserAction.next(for: run, project: store.snapshot.projects.first { $0.id == run.projectID })
    }
    private var canCancel: Bool {
        run.pauseAllowsContinuation && ![.ready, .cancelled, .archived].contains(run.state)
            && run.workflow?.delivery.closedAt == nil
    }
    private var disabled: Bool { !store.connected || store.busy.contains(run.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { actions }
                VStack(alignment: .leading, spacing: 8) { actions }
            }
            if let pauseError {
                Text(pauseError).font(.caption).foregroundStyle(FrondaTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .controlSize(.small)
        .confirmationDialog("Cancelar esta execução?", isPresented: $confirmingCancel) {
            Button("Cancelar execução", role: .destructive) { store.perform("run.cancel", id: run.id) }
        } message: {
            Text("A execução será encerrada. Os resultados registrados continuam disponíveis.")
        }
    }

    @ViewBuilder private var actions: some View {
        primaryAction
        if !primaryOnly && run.state == .paused && run.pauseAllowsContinuation,
            store.selectedChat?.turns.reversed().compactMap(\.runID).first == run.id,
            store.snapshot.projects.contains(where: { $0.id == run.projectID })
        {
            Button("Ajustar no chat", systemImage: "text.bubble") { prepareAdjustment() }
                .disabled(disabled)
                .help("Preparar um novo pedido com os arquivos desta execução")
                .accessibilityIdentifier("run.adjust-in-chat")
        }
        if !primaryOnly && canCancel {
            Button("Cancelar", systemImage: "stop.circle") { confirmingCancel = true }
                .disabled(disabled)
                .help("Encerrar esta execução e preservar os resultados registrados")
                .accessibilityIdentifier("run.cancel")
        }
    }

    @ViewBuilder private var primaryAction: some View {
        if run.isPauseRequested {
            Label("Solicitando pausa…", systemImage: "clock")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("run.pause.requested")
        } else if run.needsPauseReview {
            Button("Conferi a interrupção", systemImage: "checkmark.circle", action: acknowledgePause)
                .buttonStyle(.borderedProminent).disabled(disabled || acknowledgingPause)
                .help(
                    "Confirme somente após conferir os processos e possíveis efeitos externos. Se ainda houver processo acompanhado, aguarde o encerramento."
                )
                .accessibilityIdentifier("run.pause.acknowledge")
        } else if run.hasUnresolvedExternalOperations, let next {
            actionButton(next)
        } else if run.state == .queued && store.snapshot.preferences.queuePaused {
            Button("Retomar fila", systemImage: "play.fill") { store.perform("queue.toggle") }
                .disabled(!store.connected || store.busy.contains("queue.toggle"))
        } else if run.state.active || run.state == .queued {
            Button("Pausar", systemImage: "pause.fill") { store.perform("run.pause", id: run.id) }
                .disabled(disabled)
                .help("Pausar a execução. Você poderá retomar depois.")
                .accessibilityIdentifier("run.pause")
        } else if run.state == .paused {
            Button("Retomar", systemImage: "play.fill", action: resume)
                .buttonStyle(.borderedProminent).disabled(disabled || ChatRecoverySummary.hasPendingOperation(run))
                .help(
                    ChatRecoverySummary.hasPendingOperation(run)
                        ? "Confira a operação pendente ou sem resultado confirmado antes de retomar."
                        : "Continuar o trabalho pausado."
                )
                .accessibilityIdentifier("run.resume")
        } else if run.state == .partial && run.reason.hasPrefix("Exceção:") {
            Button("Retomar", systemImage: "play.fill", action: resume)
                .buttonStyle(.borderedProminent).disabled(disabled)
        } else if run.state == .blocked && run.reason.localizedCaseInsensitiveContains("orçamento") {
            if run.needsBudgetRecheck {
                Button("Retomar e verificar", systemImage: "play.fill", action: resume)
                    .buttonStyle(.borderedProminent).disabled(disabled)
                    .accessibilityIdentifier("run.resume-budget")
            } else {
                Button("Ajustar limite", systemImage: "slider.horizontal.3") { show(.tokens) }
                    .buttonStyle(.borderedProminent).disabled(disabled)
            }
        } else if let next {
            actionButton(next)
        }
    }

    private func actionButton(_ action: RunUserAction) -> some View {
        Button(action.title) { act(action) }
            .buttonStyle(.borderedProminent).disabled(disabled)
            .accessibilityIdentifier("run.next-action")
    }

    private func show(_ section: RunWorkspaceSection) {
        store.runDetail = ChatRunDetail(runID: run.id, page: .section(section))
    }

    private func prepareAdjustment() {
        guard run.state == .paused, run.pauseAllowsContinuation,
            store.selectedChat?.turns.reversed().compactMap(\.runID).first == run.id,
            store.snapshot.projects.contains(where: { $0.id == run.projectID })
        else { return }
        var draft =
            store.chatDrafts[store.chatID]
            ?? ChatComposerDraft(
                lastTurn: store.selectedChat?.turns.last, preferences: store.snapshot.preferences,
                providers: store.snapshot.providers)
        draft.projectID = run.projectID
        draft.adjustingRunID = run.id
        draft.requestID = makeID()
        store.chatDrafts[store.chatID] = draft
    }

    private func resume() {
        store.perform("run.resume", id: run.id) { $0.expectedSequence = run.sequence }
    }

    private func acknowledgePause() {
        guard !disabled, !acknowledgingPause, run.needsPauseReview else { return }
        acknowledgingPause = true
        pauseError = nil
        Task {
            defer { acknowledgingPause = false }
            do {
                var request = RPCRequest("run.pause.acknowledge")
                request.id = run.id
                request.expectedSequence = run.sequence
                _ = try await store.send(request)
                await store.refresh()
            } catch {
                pauseError = error.localizedDescription
            }
        }
    }

    private func act(_ action: RunUserAction) {
        if let destination = action.destination {
            show(destination)
            return
        }
        let sheet: RunActionSheet
        switch action {
        case .prepareContext, .resume:
            resume()
            return
        case .acknowledgePause:
            acknowledgePause()
            return
        case .editLoopPolicy: sheet = .loopPolicy
        case .recordReproduction: sheet = .reproduction
        case .recordVerification: sheet = .verification
        case .reviewOperations: sheet = .operations
        default: return
        }
        store.runDetail = ChatRunDetail(runID: run.id, page: .action(sheet))
    }
}
