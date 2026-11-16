import HarnessDomain
import SwiftUI

/// Activity is tied to the originating turn, including when a later request reuses its worktree.
struct ChatActivityFeed: View {
    let store: AppStore
    let run: Run
    let turn: ConversationTurn
    @State private var events: [RunEvent] = []
    @State private var expanded = false
    @State private var loaded = false
    @State private var error: String?
    @State private var retry = 0
    @State private var loadingEarlier = false
    @State private var hasEarlier = false

    private struct RefreshKey: Equatable {
        let sequence: Int
        let connected: Bool
        let retry: Int
    }

    private var key: RefreshKey {
        RefreshKey(sequence: turn.runSnapshotSequence ?? run.sequence, connected: store.connected, retry: retry)
    }

    private var activity: [RunStepActivityEvent] {
        let hasToolDetails = events.contains { $0.kind == "tool.call_started" }
        return events.filter { event in
            if hasToolDetails && ["provider.item/started", "provider.item/completed"].contains(event.kind) {
                return false
            }
            if let owner = event.conversationTurnID { return owner == turn.id }
            // Older events lack turn attribution. The saved sequence bounds historical results.
            return event.occurredAt >= turn.createdAt
                && (turn.runSnapshotSequence.map { event.sequence <= $0 } ?? true)
        }.compactMap(RunStepActivityEvent.init)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChatLoopStatus(store: store, run: run, sequence: turn.runSnapshotSequence, showsDetails: false)
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(FrondaTheme.textMuted)
                    .accessibilityHidden(true)
                Text("Atividade").font(.caption.weight(.semibold))
                if store.connected && run.state.active && turn.runSnapshotSequence == nil {
                    HStack(spacing: 4) {
                        Circle().fill(FrondaTheme.running).frame(width: 5, height: 5)
                        Text("Ao vivo")
                    }
                    .font(.caption2.weight(.medium)).foregroundStyle(FrondaTheme.running)
                }
                Spacer()
                if activity.count > 5 || hasEarlier {
                    Button(expanded ? "Mostrar menos" : "Ver toda a atividade") { expanded.toggle() }
                        .font(.caption).buttonStyle(.link)
                }
            }
            if let error {
                HStack {
                    Text(error).font(.caption).foregroundStyle(FrondaTheme.warning)
                    Button("Tentar novamente") { retry += 1 }.font(.caption).buttonStyle(.link)
                }
            } else if !loaded && !store.connected {
                Text("Conecte o coordenador para carregar a atividade.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if !loaded {
                ProgressView("Carregando atividade…").controlSize(.small)
            } else if activity.isEmpty {
                Text(
                    run.state.active
                        ? "Aguardando atividade do agente…" : "Ainda não há atividade registrada neste envio."
                )
                .font(.caption).foregroundStyle(.secondary)
                if expanded && hasEarlier {
                    Button(loadingEarlier ? "Carregando…" : "Carregar acontecimentos anteriores") {
                        Task { await loadEarlier() }
                    }.font(.caption).buttonStyle(.link).disabled(loadingEarlier || !store.connected)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(expanded ? activity : Array(activity.suffix(5))) { row in
                        activityRow(row)
                    }
                }
                .background(alignment: .leading) {
                    Rectangle().fill(FrondaTheme.border).frame(width: 1).padding(.leading, 8)
                }
                if !expanded && activity.count > 5 {
                    Text("\(activity.count - 5) acontecimentos anteriores")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if expanded && hasEarlier {
                    Button(loadingEarlier ? "Carregando…" : "Carregar acontecimentos anteriores") {
                        Task { await loadEarlier() }
                    }.font(.caption).buttonStyle(.link).disabled(loadingEarlier || !store.connected)
                }
            }
        }
        .padding(.horizontal, 3).padding(.vertical, 4)
        .task(id: key) { await load(key) }
        .accessibilityIdentifier("chat.activity")
    }

    private func activityRow(_ row: RunStepActivityEvent) -> some View {
        let appearance = row.category.appearance
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: appearance.symbol).font(.system(size: 10, weight: .medium))
                .foregroundStyle(appearance.color).frame(width: 17, height: 18)
                .background(FrondaTheme.canvas, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title).font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = row.detail, !detail.isEmpty {
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 5) {
                    if let stepID = row.event.stepID, let step = run.plan.first(where: { $0.id == stepID }) {
                        Text(step.title).lineLimit(1)
                        Text("·").accessibilityHidden(true)
                    }
                    Text(row.event.occurredAt.formatted(date: .omitted, time: .shortened))
                        .monospacedDigit()
                }
                .font(.caption2).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    @MainActor private func load(_ target: RefreshKey) async {
        guard target.connected else { return }
        do {
            var request = RPCRequest("events")
            request.id = run.id
            if let sequence = turn.runSnapshotSequence { request.number = sequence + 1 }
            let incoming = try await store.send(request).events ?? []
            guard !Task.isCancelled, key == target else { return }
            let first = incoming.first?.sequence ?? 0
            let earlier = events.filter { $0.sequence < first }
            let previouslyHadEarlier = hasEarlier
            events = earlier + incoming
            hasEarlier = earlier.isEmpty ? incoming.count == 1000 : previouslyHadEarlier
            loaded = true
            error = nil
        } catch {
            guard !Task.isCancelled, key == target else { return }
            self.error = "Não foi possível carregar a atividade."
        }
    }

    @MainActor private func loadEarlier() async {
        guard let earliest = events.first?.sequence, !loadingEarlier else { return }
        loadingEarlier = true
        defer { loadingEarlier = false }
        do {
            var request = RPCRequest("events")
            request.id = run.id
            request.number = earliest
            let earlier = try await store.send(request).events ?? []
            let existing = Set(events.map(\.id))
            events.insert(contentsOf: earlier.filter { !existing.contains($0.id) }, at: 0)
            hasEarlier = earlier.count == 1000
        } catch {
            self.error = "Não foi possível carregar a atividade anterior."
        }
    }

}

/// Presents only cycle state and evidence already recorded by the coordinator.
struct ChatLoopStatus: View {
    let store: AppStore
    let run: Run
    let sequence: Int?
    let showsDetails: Bool

    private var projection: RunFollowupLoopProjection { RunFollowupLoopProjection(run: run) }

    private var isHistorical: Bool { sequence != nil }

    private var currentVerification: RunFollowupLoopProjection.CurrentVerification {
        projection.currentVerification(project: store.snapshot.projects.first { $0.id == run.projectID })
    }

    private var cycleStatus: String {
        guard let execution = run.loopExecution else { return "Ainda não iniciado" }
        if execution.state != .passed {
            if run.isPauseRequested { return "Solicitando pausa…" }
            if run.needsPauseReview { return "Parada não confirmada" }
            if run.hasAcknowledgedPause { return "Interrupção conferida por você" }
        }
        if execution.state == .passed {
            if isHistorical { return "Verificações aprovadas naquela rodada" }
            switch currentVerification {
            case .approved: return "Verificações aprovadas"
            case .pending: return "Verificações atuais pendentes"
            case .failed: return "Verificação atual com falha"
            case .unavailable: return "Verificações atuais indisponíveis"
            }
        }
        return execution.state.label
    }

    private var cycleTitle: String {
        guard let policy = projection.policy else { return "Correção automática não ativa" }
        guard let iteration = run.currentLoopIteration else {
            return "Ciclo de correção · até \(policy.maxIterations) rodadas"
        }
        return "Ciclo \(iteration.number) de até \(policy.maxIterations)"
    }

    var body: some View {
        if projection.policy != nil || run.mode.writes {
            VStack(alignment: .leading, spacing: 6) {
                Label(cycleTitle, systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FrondaTheme.accent)
                if projection.policy != nil {
                    Text(statusDescription)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let reason = recordedReason, showsDetails {
                        Text(reason).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    }
                    if projection.didRepeat && showsDetails {
                        Text("Por que repetiu: " + projection.repetitionReason)
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    }
                    if showsDetails {
                        if !projection.history.isEmpty { RunFollowupHistory(items: projection.history) }
                        DisclosureGroup("Limites do ciclo") {
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(projection.limits, id: \.self) { limit in
                                    Text(limit).font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(.top, 7)
                        }.font(.caption)
                    }
                    if !isHistorical && executionNeedsReview {
                        Button("Ver verificações") {
                            store.graph = nil
                            store.runDetail = ChatRunDetail(runID: run.id, page: .section(.validation))
                        }
                        .buttonStyle(.link).font(.caption).disabled(!store.connected)
                        .accessibilityIdentifier("chat.cycle.validation")
                    }
                } else {
                    Text("Confira as verificações obrigatórias e o plano para usar um ciclo de correção.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !isHistorical {
                        Button("Ver verificações") {
                            store.graph = nil
                            store.runDetail = ChatRunDetail(runID: run.id, page: .section(.validation))
                        }
                        .buttonStyle(.link).font(.caption).disabled(!store.connected)
                        .accessibilityIdentifier("chat.cycle.validation")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("chat.cycle-status")
        }
    }

    private var statusDescription: String {
        if isHistorical { return "Estado registrado: " + cycleStatus }
        if !store.connected { return "Último estado recebido: " + cycleStatus }
        return cycleStatus
    }

    private var executionNeedsReview: Bool {
        guard run.loopExecution?.state == .passed else { return false }
        switch currentVerification {
        case .approved: return false
        case .pending, .failed, .unavailable: return true
        }
    }

    private var recordedReason: String? {
        guard let execution = run.loopExecution else { return nil }
        if execution.state != .passed {
            if run.isPauseRequested { return "O Fronda aguarda o encerramento dos processos acompanhados." }
            if run.needsPauseReview || run.hasAcknowledgedPause {
                return "O Fronda não confirmou a parada dos processos nem possíveis efeitos externos."
            }
        }
        if execution.state == .passed {
            if isHistorical {
                return execution.reason.isEmpty ? nil : "Na rodada registrada: " + execution.reason
            }
            switch currentVerification {
            case .approved: break
            case .pending:
                return
                    "A rodada passou antes, mas as verificações atuais estão pendentes, interrompidas ou sem confirmação nesta versão."
            case .failed:
                return "A rodada passou antes, mas uma verificação mais recente registrou falha nesta versão."
            case .unavailable:
                return "A rodada passou antes; não foi possível conferir a configuração atual das verificações."
            }
        }
        return execution.reason.isEmpty ? nil : execution.reason
    }
}
