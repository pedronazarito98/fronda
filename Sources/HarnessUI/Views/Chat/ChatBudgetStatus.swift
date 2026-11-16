import HarnessDomain
import SwiftUI

private func budgetDuration(_ seconds: Double) -> String {
    let total = max(0, Int(seconds.rounded(.down)))
    if total >= 3600 { return "\(total / 3600)h \((total % 3600) / 60)min" }
    if total >= 60 { return "\(total / 60)min \(total % 60)s" }
    return "\(total)s"
}

/// The values here are observations, not a guarantee of a maximum bill or duration.
struct ChatBudgetStatus: View {
    let store: AppStore
    let run: Run
    @State private var expanded = false
    @State private var editing = false
    @State private var proposedBudget = 0
    @State private var saving = false
    @State private var error: String?

    private var hasUsage: Bool {
        run.tokens.contains { $0.input != nil || $0.output != nil }
    }

    private var liveClock: Bool {
        store.connected && run.state.active && run.loopExecution?.activeSince != nil
    }

    var body: some View {
        Group {
            if liveClock {
                TimelineView(.periodic(from: .now, by: 5)) { context in
                    content(at: context.date)
                }
            } else {
                content(at: run.updatedAt)
            }
        }
        .accessibilityIdentifier("chat.budget.status")
    }

    private func content(at date: Date) -> some View {
        let elapsed = elapsedSeconds(at: date)
        let timeLimit = run.loopExecution?.policy.maxDurationSeconds ?? run.runbook.loopPolicy?.maxDurationSeconds
        let tokenRatio = hasUsage && run.budget > 0 ? Double(run.reportedTokens) / Double(run.budget) : 0
        let timeRatio = timeLimit.map { $0 > 0 ? elapsed / Double($0) : 0 } ?? 0
        let nearLimit = tokenRatio >= 0.8 || timeRatio >= 0.8

        return VStack(alignment: .leading, spacing: 7) {
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 10) {
                    if hasUsage {
                        ProgressView(value: min(tokenRatio, 1))
                            .tint(tokenRatio >= 0.8 ? FrondaTheme.warning : FrondaTheme.accent)
                            .accessibilityLabel("Consumo reportado de tokens")
                            .accessibilityValue("\(run.reportedTokens.formatted()) de \(run.budget.formatted())")
                    }
                    if let timeLimit, run.loopExecution != nil {
                        ProgressView(value: min(timeRatio, 1))
                            .tint(timeRatio >= 0.8 ? FrondaTheme.warning : FrondaTheme.accent)
                            .accessibilityLabel("Tempo ativo do ciclo de correção")
                            .accessibilityValue("\(budgetDuration(elapsed)) de \(budgetDuration(Double(timeLimit)))")
                    }
                    Text(
                        "Tokens são informados pelo executor e podem chegar depois do uso. O tempo é conferido entre etapas; uma etapa em andamento pode ultrapassá-lo. Nenhum dos dois é um teto de custo."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    if let pack = run.pack {
                        Text(
                            "Último contexto preparado: ~\(pack.estimatedTokens.formatted()) tokens estimados. A estimativa não inclui a resposta nem todo o processamento posterior."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    if !store.connected {
                        Text("Mostrando o último estado recebido; os valores podem estar desatualizados.")
                            .font(.caption).foregroundStyle(FrondaTheme.warning)
                    } else if run.isPauseRequested {
                        Text("Aguarde a confirmação da pausa antes de alterar os limites.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if run.needsPauseReview {
                        Text("Confira a interrupção antes de alterar os limites.")
                            .font(.caption).foregroundStyle(FrondaTheme.warning)
                    } else if run.state.active || run.state == .queued {
                        Text("Pause a tarefa para alterar o limite de tokens com segurança.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    budgetEditor
                    if timeLimit != nil && !run.state.active && run.pauseAllowsContinuation
                        && ![.queued, .cancelled, .archived].contains(run.state)
                        && store.connected
                    {
                        Button("Ajustar tempo do ciclo") {
                            store.graph = nil
                            store.runDetail = ChatRunDetail(runID: run.id, page: .action(.loopPolicy))
                        }
                        .buttonStyle(.link)
                        .accessibilityIdentifier("chat.budget.edit-cycle")
                        Text("Alterar o plano pode exigir uma nova aprovação.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 7)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Image(systemName: nearLimit ? "exclamationmark.circle" : "gauge.with.dots.needle.50percent")
                        .foregroundStyle(nearLimit ? FrondaTheme.warning : FrondaTheme.textMuted)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tokenSummary)
                        if let timeLimit {
                            Text(
                                run.loopExecution == nil
                                    ? "Ciclo: até \(budgetDuration(Double(timeLimit))) quando iniciar"
                                    : run.isPauseRequested || run.needsPauseReview
                                        ? "Ciclo: último registro \(budgetDuration(elapsed)) de \(budgetDuration(Double(timeLimit)))"
                                        : "Ciclo: \(budgetDuration(elapsed)) de \(budgetDuration(Double(timeLimit))) ativos"
                            )
                        }
                    }
                    .font(.caption).foregroundStyle(FrondaTheme.textMuted)
                    .monospacedDigit()
                    Spacer(minLength: 0)
                    if nearLimit {
                        Text(tokenRatio >= 1 || timeRatio >= 1 ? "Limite atingido" : "Perto do limite")
                            .font(.caption.weight(.semibold)).foregroundStyle(FrondaTheme.warning)
                    }
                }
            }
            .font(.caption)
        }
    }

    private var tokenSummary: String {
        if hasUsage { return "\(run.reportedTokens.formatted()) de \(run.budget.formatted()) tokens reportados" }
        return run.state.active || run.state == .queued
            ? "Aguardando consumo reportado · limite \(run.budget.formatted()) tokens"
            : "Consumo não informado · limite \(run.budget.formatted()) tokens"
    }

    private func elapsedSeconds(at date: Date) -> Double {
        guard let loop = run.loopExecution else { return 0 }
        return loop.elapsedSeconds + (loop.activeSince.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    @ViewBuilder private var budgetEditor: some View {
        if !run.state.active && run.pauseAllowsContinuation
            && ![.queued, .cancelled, .archived].contains(run.state) && store.connected
        {
            if editing {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("Limite em tokens", value: $proposedBudget, format: .number)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 130)
                        .accessibilityIdentifier("chat.budget.input")
                    Button("Salvar") { saveBudget() }
                        .buttonStyle(.borderedProminent)
                        .disabled(saving || !(1000...500000).contains(proposedBudget))
                        .accessibilityIdentifier("chat.budget.save")
                    Button("Cancelar") {
                        editing = false
                        error = nil
                    }
                    .disabled(saving)
                }
                .controlSize(.small)
                Text("Escolha entre 1.000 e 500.000 tokens. A alteração vale para esta tarefa.")
                    .font(.caption).foregroundStyle(.secondary)
                if let error { Text(error).font(.caption).foregroundStyle(FrondaTheme.danger) }
            } else {
                Button("Ajustar limite desta tarefa") {
                    proposedBudget = run.budget
                    error = nil
                    editing = true
                }
                .buttonStyle(.link)
                .disabled(store.busy.contains(run.id))
                .accessibilityIdentifier("chat.budget.edit")
            }
        }
    }

    private func saveBudget() {
        guard !run.state.active, run.pauseAllowsContinuation, run.state != .queued,
            (1000...500000).contains(proposedBudget), !saving
        else { return }
        saving = true
        error = nil
        Task {
            defer { saving = false }
            do {
                var request = RPCRequest("run.budget")
                request.id = run.id
                request.number = proposedBudget
                request.expectedSequence = run.sequence
                _ = try await store.send(request)
                await store.refresh()
                editing = false
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

/// A new project task uses the default budget; a continued task keeps its existing budget.
struct ChatBudgetPreview: View {
    let store: AppStore
    let projectID: String
    @State private var expanded = false
    @Environment(\.openSettings) private var openSettings

    private var existingRun: Run? {
        guard let conversation = store.selectedChat else { return nil }
        for turn in conversation.turns.reversed() {
            if let id = turn.runID,
                let run = store.snapshot.runs.first(where: {
                    $0.id == id && $0.projectID == projectID && $0.mode.writes
                })
            {
                return run
            }
        }
        return nil
    }

    private var previewLabel: String {
        guard let run = existingRun else {
            return "\(store.snapshot.preferences.tokenBudget.formatted()) tokens · limite inicial"
        }
        if run.tokens.contains(where: { $0.input != nil || $0.output != nil }) {
            return "\(run.reportedTokens.formatted()) de \(run.budget.formatted()) tokens reportados · tarefa existente"
        }
        return "\(run.budget.formatted()) tokens · limite da tarefa existente"
    }

    private var previewCycleLimit: Int? {
        if let run = existingRun {
            if let explicit = run.runbook.loopPolicy { return explicit.maxDurationSeconds }
            guard run.chatLoopAutoEligible == true else { return nil }
            return LoopPolicy(implementationStepID: "", validationStepID: "").maxDurationSeconds
        }
        guard let book = store.snapshot.runbooks.first(where: { $0.id == "builtin-0" }) else { return nil }
        return book.loopPolicy?.maxDurationSeconds
            ?? LoopPolicy(implementationStepID: "", validationStepID: "").maxDurationSeconds
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
                Text(
                    "O executor informa o consumo durante ou depois da etapa; o valor pode ultrapassar esse limite. Se a correção automática estiver ativa, ela também terá um limite de tempo próprio, conferido entre etapas."
                )
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                if let previewCycleLimit {
                    Text(
                        "Se o ciclo de correção for ativado: até \(budgetDuration(Double(previewCycleLimit))) ativos; não é o prazo total da tarefa."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                if existingRun == nil {
                    Button("Ajustar padrão em Ajustes") {
                        store.settingsSection = "Geral"
                        openSettings()
                    }
                    .buttonStyle(.link)
                    Text("Em Geral → Avançado, altere o orçamento por tarefa.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Para mudar o limite desta tarefa, use o cartão de consumo quando ela estiver parada.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 5)
        } label: {
            Label(previewLabel, systemImage: "gauge.with.dots.needle.50percent")
                .font(.caption).foregroundStyle(FrondaTheme.textMuted)
        }
        .accessibilityIdentifier("chat.budget.preview")
    }
}
