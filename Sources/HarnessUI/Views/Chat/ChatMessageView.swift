import HarnessDomain
import SwiftUI

struct ChatMessageView: View {
    let store: AppStore
    let turn: ConversationTurn
    let conversationID: String
    let isMostRecent: Bool
    let showsTaskRail: Bool
    @State private var retryID = makeID()
    @State private var retrying = false
    @State private var retryError: String?
    @Environment(\.colorScheme) private var colorScheme
    let openGraph: (String, Int?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            userMessage
            HStack(alignment: .top, spacing: 14) {
                assistantMark
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 7) {
                        Text("Fronda").font(.system(size: 13, weight: .semibold))
                        Text(turn.execution.model ?? turn.provider.rawValue)
                            .lineLimit(1).truncationMode(.middle).foregroundStyle(FrondaTheme.textMuted)
                        if let effort = turn.execution.effort {
                            Text(ExecutionControls.effortLabel(effort).components(separatedBy: " · ")[0])
                                .foregroundStyle(FrondaTheme.textMuted)
                        }
                    }.font(.caption)
                    if let id = turn.runID, let run = store.snapshot.runs.first(where: { $0.id == id }) {
                        ChatRunRevision(store: store, current: run, sequence: turn.runSnapshotSequence) { snapshot in
                            VStack(alignment: .leading, spacing: 12) {
                                ChatExecutionCard(
                                    store: store, run: snapshot, snapshotSequence: turn.runSnapshotSequence,
                                    compact: showsTaskRail && isMostRecent && turn.runSnapshotSequence == nil
                                ) {
                                    openGraph(id, turn.runSnapshotSequence)
                                }
                                VStack(alignment: .leading, spacing: 10) {
                                    ChatActivityFeed(store: store, run: snapshot, turn: turn)
                                    ChatDeliverySummary(store: store, run: snapshot, sequence: turn.runSnapshotSequence)
                                    ChatCriteriaSummary(
                                        store: store, run: snapshot,
                                        isCurrent: turn.id
                                            == store.selectedChat?.turns.reversed()
                                            .first(where: { $0.runID != nil })?.id && turn.runSnapshotSequence == nil)
                                }
                            }
                        }.id(ChatRunReference(runID: id, sequence: turn.runSnapshotSequence))
                    }
                    response
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var userMessage: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "person")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FrondaTheme.textMuted)
                .frame(width: 31, height: 31)
                .background(FrondaTheme.canvas, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(turn.prompt).font(.system(size: 14)).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                    .padding(.horizontal, 17).padding(.vertical, 13)
                    .background(FrondaTheme.canvas, in: RoundedRectangle(cornerRadius: 15))
                    .accessibilityRepresentation { Text("Você: " + turn.prompt) }
                    .accessibilityIdentifier("chat.user-message")
                if !turn.attachments.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(turn.attachments) { attachment in
                            Label(attachment.name, systemImage: "paperclip")
                                .lineLimit(1).truncationMode(.middle)
                                .accessibilityLabel("Anexo, " + attachment.name)
                        }
                    }.font(.caption).foregroundStyle(FrondaTheme.textMuted)
                }
            }
            .frame(maxWidth: 660, alignment: .leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var assistantMark: some View {
        let symbol = colorScheme == .dark ? FrondaAssets.symbolDark : FrondaAssets.symbolLight
        Group {
            if let symbol {
                Image(nsImage: symbol).resizable().scaledToFit().padding(5)
            } else {
                Image(systemName: "leaf").font(.system(size: 12))
            }
        }
        .frame(width: 31, height: 31)
        .foregroundStyle(FrondaTheme.accent)
        .background(FrondaTheme.accent.opacity(0.1), in: Circle())
        .accessibilityHidden(true)
    }

    @ViewBuilder private var response: some View {
        switch turn.status {
        case .pending:
            if !turn.reply.isEmpty { MarkdownView(turn.reply) }
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(turn.runID == nil ? "Respondendo…" : "Preparando execução…").font(.callout).foregroundStyle(
                    .secondary)
            }
        case .completed:
            if !turn.reply.isEmpty { MarkdownView(turn.reply) }
        case .failed, .cancelled:
            Label(
                turn.status == .failed ? "Falha na resposta" : "Resposta interrompida",
                systemImage: turn.status == .failed ? "exclamationmark.circle" : "stop.circle"
            )
            .font(.callout.weight(.medium))
            .foregroundStyle(turn.status == .failed ? FrondaTheme.danger : FrondaTheme.textMuted)
            if !turn.reply.isEmpty {
                Text(turn.reply).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityRepresentation { Text(turn.reply) }
            }
            if isMostRecent {
                if store.selectedChat?.queuedTurns?.isEmpty != false {
                    Button("Tentar novamente", systemImage: "arrow.clockwise", action: retry)
                        .buttonStyle(.link).font(.callout)
                        .disabled(retrying || !store.connected)
                        .accessibilityIdentifier("chat.retry")
                } else {
                    Text("Continue ou remova as mensagens na fila antes de tentar novamente.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let retryError {
                    Text(retryError).font(.caption).foregroundStyle(FrondaTheme.danger)
                }
            }
        }
    }

    private func retry() {
        guard !retrying else { return }
        retrying = true
        retryError = nil
        Task {
            defer { retrying = false }
            do {
                try await store.retryChat(conversationID: conversationID, turnID: turn.id, requestID: retryID)
            } catch {
                retryError = error.localizedDescription
            }
        }
    }
}
