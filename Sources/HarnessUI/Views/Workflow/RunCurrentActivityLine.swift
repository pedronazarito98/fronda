import HarnessDomain
import SwiftUI

struct RunCurrentActivityLine: View {
    let store: AppStore
    let run: Run
    let stepID: String
    @State private var latest: RunStepActivityEvent?
    @State private var message = "Consultando a atividade…"

    private struct Revision: Equatable {
        let runID: String
        let stepID: String
        let sequence: Int
        let connected: Bool
    }

    private var revision: Revision {
        Revision(runID: run.id, stepID: stepID, sequence: run.sequence, connected: store.connected)
    }

    var body: some View {
        HStack(spacing: 8) {
            if let latest, latest.event.runID == run.id, latest.event.stepID == stepID {
                let appearance = latest.category.appearance
                Image(systemName: appearance.symbol).foregroundStyle(appearance.color)
                Text("Última atividade · " + latest.title + (latest.detail.map { " · " + $0 } ?? ""))
                    .lineLimit(2)
                Spacer(minLength: 4)
                Text(latest.event.occurredAt, style: .time).monospacedDigit()
            } else {
                Label(message, systemImage: "clock")
            }
        }
        .font(.caption).foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("step.latest-activity")
        .task(id: revision) { await update(revision) }
    }

    @MainActor private func update(_ target: Revision) async {
        guard target.connected && run.state.active else { return }
        do {
            let page = try await store.stepActivityPage(runID: target.runID, stepID: target.stepID)
            guard !Task.isCancelled, target == revision else { return }
            latest = page.reversed().lazy.compactMap(RunStepActivityEvent.init).first
            message = "Aguardando atividade observada nesta etapa."
        } catch {
            guard !Task.isCancelled, target == revision else { return }
            message = "Não foi possível atualizar a atividade desta etapa."
            latest = nil
        }
    }
}
