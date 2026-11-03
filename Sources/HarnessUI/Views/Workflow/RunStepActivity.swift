import HarnessDomain
import SwiftUI

struct RunStepActivity: View {
    let store: AppStore
    let run: Run
    let selected: RunJourneyStep
    @State private var events = [RunEvent]()
    @State private var cursors = [Int]()
    @State private var loaded = false
    @State private var error: String?
    @State private var retry = 0

    private struct Request: Equatable {
        let runID: String
        let stepID: String
        let before: Int
        let sequence: Int
        let online: Bool
        let retry: Int
    }

    private var request: Request {
        Request(
            runID: run.id, stepID: selected.id, before: cursors.last ?? 0, sequence: cursors.isEmpty ? run.sequence : 0,
            online: store.connected, retry: retry)
    }

    private var attempts: [Attempt] { run.attempts.filter { $0.stepID == selected.id } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Atividade da etapa").font(.headline)
                Spacer(minLength: 8)
                if !store.connected {
                    FrondaBadge("Sem conexão", symbol: "wifi.slash", color: FrondaTheme.warning)
                } else if selected.state == .running && run.state.active && cursors.isEmpty {
                    FrondaBadge("Ao vivo", symbol: "dot.radiowaves.left.and.right", color: FrondaTheme.running)
                }
            }
            if let error {
                Label(error, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(FrondaTheme.warning)
                Button("Tentar carregar de novo") { retry += 1 }.disabled(!store.connected)
            }
            let rows = events.reversed().compactMap(RunStepActivityEvent.init)
            if !rows.isEmpty {
                ForEach(rows) { row in eventRow(row) }
            } else if !loaded && store.connected && error == nil {
                ProgressView("Carregando atividade…").controlSize(.small)
            } else if error == nil {
                lastKnownResult
            }
            if !cursors.isEmpty || events.count == RunEvent.stepPageLimit {
                HStack(spacing: 12) {
                    if !cursors.isEmpty {
                        Button("Mais recentes") { _ = cursors.popLast() }
                    }
                    if events.count == RunEvent.stepPageLimit, let earliest = events.first {
                        Button("Anteriores") { cursors.append(earliest.sequence) }
                    }
                }.controlSize(.small).disabled(!store.connected)
            }
            if !attempts.isEmpty { RunStepAttempts(attempts: attempts, run: run) }
        }
        .task(id: request) { await refresh(request) }
        .accessibilityIdentifier("step.activity")
    }

    private var emptyDescription: String {
        if !store.connected { return "O coordenador está desconectado. O estado exibido é o último recebido." }
        if !events.isEmpty { return "Esta página contém apenas atualizações técnicas do executor." }
        if selected.state == .notStarted { return "Os registros aparecerão quando esta etapa começar." }
        return "Nenhuma atividade detalhada vinculada a esta etapa. Consulte os resultados disponíveis abaixo."
    }

    @ViewBuilder private var lastKnownResult: some View {
        if cursors.isEmpty, selected.step.kind == "context", let pack = run.pack,
            run.plan.filter({ $0.kind == "context" }).count == 1
        {
            Label(
                "Contexto preparado em \(pack.createdAt.formatted(date: .abbreviated, time: .shortened))",
                systemImage: "doc.on.doc"
            )
            .font(.callout)
            Text("\(pack.items.filter(\.included).count) arquivos selecionados para \(pack.provider.rawValue).")
                .font(.caption).foregroundStyle(.secondary)
        } else if cursors.isEmpty, let last = attempts.last {
            Label("Última tentativa de \(last.provider.rawValue)", systemImage: "cpu").font(.callout)
            Text(
                "Iniciada em \(last.startedAt.formatted(date: .abbreviated, time: .standard)). Os horários e resultados estão em Tentativas do executor."
            )
            .font(.caption).foregroundStyle(.secondary)
        } else {
            Text(emptyDescription).font(.callout).foregroundStyle(.secondary)
                .accessibilityIdentifier("step.activity-empty")
        }
    }

    private func eventRow(_ row: RunStepActivityEvent) -> some View {
        let appearance = row.category.appearance
        let attempt = row.event.attemptID.flatMap { id in attempts.firstIndex { $0.id == id } }
        let cycle = RunStepAttempts.cycleNumber(row.event.loopIterationID, run: run)
        let attribution = [cycle.map { "Ciclo \($0)" }, attempt.map { "Tentativa \($0 + 1)" }]
            .compactMap { $0 }.joined(separator: " · ")
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: appearance.symbol).font(.callout.weight(.medium))
                .foregroundStyle(appearance.color).frame(width: 24, height: 24)
                .background(appearance.color.opacity(0.09), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title).font(.callout.weight(.medium))
                if let detail = row.detail, !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                if !attribution.isEmpty {
                    Text(attribution).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(row.event.occurredAt.formatted(date: .omitted, time: .standard))
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                .help(row.event.occurredAt.formatted(date: .long, time: .standard))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [
                row.title, row.detail ?? "", attribution,
                row.event.occurredAt.formatted(date: .abbreviated, time: .standard),
            ]
            .filter { !$0.isEmpty }.joined(separator: ", "))
    }

    @MainActor private func refresh(_ target: Request) async {
        guard target.online else { return }
        do {
            let incoming = try await store.stepActivityPage(
                runID: target.runID, stepID: target.stepID, before: target.before)
            guard !Task.isCancelled, request == target else { return }
            events = incoming
            loaded = true
            error = nil
        } catch {
            guard !Task.isCancelled, request == target else { return }
            self.error = "Não foi possível carregar a atividade."
        }
    }
}
