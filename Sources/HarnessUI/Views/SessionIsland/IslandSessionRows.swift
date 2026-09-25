import AppKit
import HarnessDomain
import SwiftUI

struct IslandRunRow: View {
    let run: Run
    let connected: Bool
    let open: () -> Void

    private var needsAttention: Bool {
        connected && [.waitingUser, .recovering, .blocked, .failed].contains(run.state)
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                Image(systemName: needsAttention ? "hand.raised.fill" : "terminal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(needsAttention ? Color.orange : HarnessTheme.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 5) {
                    Text(run.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    HStack(spacing: 5) {
                        Text(run.provider.rawValue)
                        Text("·")
                        Text(run.state.label).foregroundStyle(needsAttention ? Color.orange : Color.secondary)
                    }.font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    if !run.plan.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView(value: Double(run.completedSteps), total: Double(run.plan.count))
                                .tint(HarnessTheme.accent)
                            Text("\(run.completedSteps)/\(run.plan.count)")
                                .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: needsAttention ? "arrow.right.circle.fill" : "arrow.up.right")
                    .font(.system(size: needsAttention ? 18 : 10))
                    .foregroundStyle(needsAttention ? Color.orange : Color.secondary)
            }.padding(.horizontal, 10).frame(height: 82).contentShape(.rect)
        }.buttonStyle(IslandRowStyle()).opacity(connected ? 1 : 0.6)
            .help(run.tokens.isEmpty ? "Tokens não reportados" : "\(run.reportedTokens.formatted()) tokens reportados")
            .accessibilityHint(
                needsAttention ? "Abre a run que precisa de atenção no Harness" : "Abre os detalhes da run no Harness")
    }
}

struct IslandExternalSessionRow: View {
    let session: ExternalSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let stale = session.isStale(at: context.date)
            let waiting = !stale && session.state == .waiting
            HStack(spacing: 10) {
                Image(systemName: waiting ? "hand.raised.fill" : "terminal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(waiting ? Color.orange : HarnessTheme.accent).frame(width: 28)
                VStack(alignment: .leading, spacing: 5) {
                    Text(session.project).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(session.provider.rawValue + " · " + (stale ? "Sem atualização recente" : session.state.label))
                        .font(.system(size: 10)).foregroundStyle(waiting ? Color.orange : Color.secondary).lineLimit(1)
                    Text("Último evento \(session.updatedAt, style: .relative) atrás")
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
                if session.provider == .codex {
                    Button {
                        if let url = URL(string: "codex://threads/" + session.sessionID) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Image(systemName: waiting ? "arrow.right.circle.fill" : "arrow.up.right")
                            .font(.system(size: waiting ? 18 : 10))
                            .foregroundStyle(waiting ? Color.orange : Color.secondary)
                    }.buttonStyle(.plain).help("Abrir sessão no Codex")
                        .accessibilityLabel("Abrir sessão no Codex")
                }
            }.padding(.horizontal, 10).frame(height: 82)
                .background(.primary.opacity(0.025), in: .rect(cornerRadius: 14))
        }
    }
}
