import HarnessDomain
import SwiftUI

struct IslandActivitySummary {
    let title: String
    let detail: String
    let symbol: String
    let needsAttention: Bool
    let active: Bool
    let startedAt: Date?

    @MainActor static func current(in store: AppStore) -> Self? {
        let runs = store.islandRuns
        let external = store.visibleExternalSessions
        let waitingRun =
            store.connected ? runs.first { [.waitingUser, .recovering, .blocked, .failed].contains($0.state) } : nil
        let waitingExternal = external.first {
            $0.state == .waiting && !$0.isStale(at: .now) && store.externalSessionError == nil
        }
        if let run = waitingRun { return summary(run, connected: true) }
        if let session = waitingExternal { return summary(session, reliable: true) }
        if store.connected, let run = runs.first(where: { $0.state.active }) { return summary(run, connected: true) }
        if let session = external.first(where: { $0.state == .running && !$0.isStale(at: .now) }) {
            return summary(session, reliable: store.externalSessionError == nil)
        }
        if let run = runs.first { return summary(run, connected: store.connected) }
        return external.first.map { summary($0, reliable: store.externalSessionError == nil) }
    }

    private static func summary(_ run: Run, connected: Bool) -> Self {
        let attention = connected && [.waitingUser, .recovering, .blocked, .failed].contains(run.state)
        let active = connected && run.state.active
        return Self(
            title: run.title,
            detail: connected
                ? "\(run.provider.rawValue) · \(run.state.label)" : "Harness desconectado · último estado",
            symbol: attention ? "hand.raised.fill" : "terminal.fill", needsAttention: attention,
            active: active, startedAt: active ? run.attempts.last(where: { $0.finishedAt == nil })?.startedAt : nil)
    }

    private static func summary(_ session: ExternalSession, reliable: Bool) -> Self {
        let fresh = reliable && !session.isStale(at: .now)
        return Self(
            title: session.project,
            detail: "\(session.provider.rawValue) · \(fresh ? session.state.label : "Sem atualização recente")",
            symbol: fresh && session.state == .waiting ? "hand.raised.fill" : "terminal.fill",
            needsAttention: fresh && session.state == .waiting,
            active: fresh && session.state == .running, startedAt: nil)
    }
}

struct IslandPeekView: View {
    let activity: IslandActivitySummary?
    let connected: Bool
    let expand: () -> Void

    var body: some View {
        Button(action: expand) {
            HStack(spacing: 12) {
                Image(systemName: activity?.symbol ?? "square.stack.3d.up")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(activity?.needsAttention == true ? Color.orange : HarnessTheme.accent)
                    .frame(width: 36, height: 36)
                    .background(.primary.opacity(0.045), in: .rect(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 5) {
                    Text(activity?.title ?? "Tudo tranquilo")
                        .font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(activity?.detail ?? (connected ? "Nenhuma sessão em execução" : "Harness desconectado"))
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if let startedAt = activity?.startedAt {
                    Text(startedAt, style: .timer).monospacedDigit()
                        .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize()
                }
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }.padding(.horizontal, 22).frame(height: 76).contentShape(.rect)
        }.buttonStyle(.plain).accessibilityLabel("Ver sessões: " + (activity?.title ?? "nenhuma em execução"))
            .accessibilityIdentifier("island.peek")
    }
}
