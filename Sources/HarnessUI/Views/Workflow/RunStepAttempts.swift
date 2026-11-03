import HarnessDomain
import SwiftUI

struct RunStepAttempts: View {
    let attempts: [Attempt]
    let run: Run

    var body: some View {
        DisclosureGroup("Tentativas do executor (\(attempts.count))") {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(attempts.enumerated().reversed()), id: \.element.id) { index, attempt in
                    VStack(alignment: .leading, spacing: 4) {
                        let status = appearance(for: attempt)
                        HStack {
                            Text("Tentativa \(index + 1) · \(attempt.provider.rawValue)").font(.callout.weight(.medium))
                            Spacer()
                            FrondaBadge(status.label, symbol: status.symbol, color: status.color)
                        }
                        let cycle = Self.cycleNumber(attempt.loopIterationID, run: run)
                        let metadata = [cycle.map { "Ciclo \($0)" }, attempt.model, attempt.effort].compactMap { $0 }
                        if !metadata.isEmpty {
                            Text(metadata.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Início \(attempt.startedAt.formatted(date: .abbreviated, time: .standard))")
                        if let end = attempt.finishedAt {
                            Text("Término \(end.formatted(date: .abbreviated, time: .standard))")
                        }
                    }.font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.top, 8)
        }
        .font(.callout.weight(.medium))
    }

    private func appearance(for attempt: Attempt) -> (label: String, symbol: String, color: Color) {
        switch attempt.status {
        case "RUNNING" where attempt.finishedAt == nil && run.state.active:
            ("Em execução", "play.circle", FrondaTheme.running)
        case "COMPLETED": ("Concluída", "checkmark.circle", FrondaTheme.success)
        case "FAILED", "ERROR": ("Falhou", "xmark.circle", FrondaTheme.danger)
        case "INTERRUPTED", "CANCELLED": ("Interrompida", "stop.circle", FrondaTheme.warning)
        case "INTERRUPTED_UNKNOWN", "UNKNOWN", "RUNNING":
            ("Sem término confirmado", "questionmark.circle", FrondaTheme.warning)
        default: (attempt.status, "circle", FrondaTheme.textMuted)
        }
    }

    static func cycleNumber(_ id: String?, run: Run) -> Int? {
        guard let id else { return nil }
        if let active = run.loopExecution?.iterations.first(where: { $0.id == id }) { return active.number }
        for history in run.loopHistory ?? [] {
            if let archived = history.iterations.first(where: { $0.id == id }) { return archived.number }
        }
        return nil
    }
}
