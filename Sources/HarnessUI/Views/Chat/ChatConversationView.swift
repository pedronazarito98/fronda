import HarnessDomain
import SwiftUI

struct ChatConversationView: View {
    let store: AppStore
    let conversation: Conversation?
    let showsTaskRail: Bool
    let openGraph: (String, Int?) -> Void
    private let conversationID: String
    @Environment(\.colorScheme) private var scheme
    @State private var submitting = false
    @State private var sendError: String?
    @State private var guidanceMode = true
    @State private var guidanceDestination: String?

    init(
        store: AppStore, conversation: Conversation?, showsTaskRail: Bool,
        openGraph: @escaping (String, Int?) -> Void
    ) {
        self.store = store
        self.conversation = conversation
        self.showsTaskRail = showsTaskRail
        self.openGraph = openGraph
        conversationID = store.chatID
    }

    private var defaultDraft: ChatComposerDraft {
        ChatComposerDraft(
            lastTurn: conversation?.turns.last, preferences: store.snapshot.preferences,
            providers: store.snapshot.providers)
    }

    private var guidanceRun: Run? {
        guard let id = conversation?.turns.reversed().first(where: { $0.runID != nil })?.runID,
            let run = store.snapshot.runs.first(where: { $0.id == id }),
            run.state.active || run.state == .queued
        else { return nil }
        return run
    }

    private var draftBinding: Binding<ChatComposerDraft> {
        Binding(
            get: { store.chatDrafts[conversationID] ?? defaultDraft },
            set: { updated in
                guard !submitting else { return }
                var next = updated
                if let current = store.chatDrafts[conversationID] {
                    next.requestID = current.requestID
                    if next.projectID != current.projectID { next.adjustingRunID = nil }
                    guard next != current else { return }
                }
                next.requestID = makeID()
                store.chatDrafts[conversationID] = next
                sendError = nil
            })
    }

    var body: some View {
        VStack(spacing: 0) {
            if let conversation, !conversation.turns.isEmpty {
                ChatConversationTranscript(
                    store: store, conversation: conversation, showsTaskRail: showsTaskRail,
                    guidanceDestination: $guidanceDestination, openGraph: openGraph)
            } else {
                Spacer(minLength: 0)
                welcomeTitle
                    .frame(maxWidth: 766)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 26)
            }
            composer.padding(.top, 6).padding(.bottom, 17)
            if conversation?.turns.isEmpty != false { Spacer() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FrondaTheme.surface.ignoresSafeArea())
        .tint(FrondaTheme.accent)
        .onChange(of: conversation?.turns.last?.id, initial: true) { _, id in
            if let id { clearAcceptedDraft(requestID: id) }
        }
        .onChange(of: guidanceRun?.id) { _, _ in guidanceMode = true }
    }

    private var welcomeTitle: some View {
        VStack(spacing: 15) {
            brandSymbol
            Text("O que vamos fazer?")
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .tracking(-0.5)
                .foregroundStyle(FrondaTheme.accent)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Descreva sua tarefa para começar uma conversa ou trabalhar em um projeto.")
                .font(.system(size: 15))
                .foregroundStyle(FrondaTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 430)
        }
    }

    @ViewBuilder private var brandSymbol: some View {
        if let image = scheme == .dark ? FrondaAssets.symbolDark : FrondaAssets.symbolLight {
            Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
                .frame(width: 45, height: 45).accessibilityHidden(true)
        } else {
            Image(systemName: "leaf").font(.system(size: 30)).foregroundStyle(FrondaTheme.accent)
                .accessibilityHidden(true)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 6) {
            ChatAttentionBanner(store: store) { guidanceID in
                guidanceDestination = guidanceID
            }
            if let sendError {
                Label(sendError, systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(FrondaTheme.danger)
                    .textSelection(.enabled).padding(.horizontal, 4)
            }
            ChatComposer(
                store: store, draft: draftBinding, submitting: submitting,
                recentProjectID: conversation?.turns.reversed().compactMap(\.projectID).first,
                pendingTurn: conversation?.turns.last.flatMap { $0.status == .pending ? $0 : nil },
                hasQueuedMessages: conversation?.queuedTurns?.isEmpty == false,
                guidanceRun: guidanceRun, guidanceMode: $guidanceMode, send: submit
            )
        }
        .padding(.horizontal, 22).frame(maxWidth: 810).frame(maxWidth: .infinity)
    }

    private func submit() {
        let sent = draftBinding.wrappedValue
        guard !submitting, store.connected,
            !sent.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        if let run = guidanceRun, guidanceMode {
            submitting = true
            sendError = nil
            Task {
                defer { submitting = false }
                do {
                    try await store.guideRun(
                        id: run.id, text: sent.prompt, attachments: sent.attachments, requestID: sent.requestID)
                    clearSentGuidance(requestID: sent.requestID)
                } catch {
                    sendError = error.localizedDescription
                }
            }
            return
        }
        if let pending = conversation?.turns.last, pending.status == .pending,
            pending.runID != nil || sent.projectID != nil
        {
            sendError = "Para enviar enquanto aguarda a resposta, escolha Conversar."
            return
        }
        if sent.projectID != nil, conversation?.queuedTurns?.isEmpty == false {
            sendError = "Continue ou remova as mensagens na fila antes de iniciar outra tarefa."
            return
        }
        if let run = guidanceRun, sent.projectID == run.projectID {
            sendError = "Esta tarefa ainda está em andamento. Use Orientar tarefa para enviar instruções a ela."
            return
        }
        if let id = sent.adjustingRunID {
            guard let run = store.snapshot.runs.first(where: { $0.id == id }),
                run.state == .paused, run.pauseAllowsContinuation,
                run.projectID == sent.projectID,
                conversation?.turns.reversed().compactMap(\.runID).first == id
            else {
                sendError = "A execução mudou. Selecione o projeto novamente para preparar outro pedido."
                return
            }
        }
        submitting = true
        sendError = nil
        Task {
            defer { submitting = false }
            do {
                let configuration = try sent.execution.validated()
                try await store.submitChat(
                    conversationID: conversationID, prompt: sent.prompt, attachments: sent.attachments,
                    provider: sent.provider, execution: configuration, projectID: sent.projectID,
                    autonomy: sent.autonomy, requestID: sent.requestID)
                clearAcceptedDraft(requestID: sent.requestID)
            } catch {
                sendError = error.localizedDescription
            }
        }
    }

    private func clearAcceptedDraft(requestID: String) {
        guard var draft = store.chatDrafts[conversationID], draft.requestID == requestID else { return }
        draft.clearSentContent()
        store.chatDrafts[conversationID] = draft
    }

    private func clearSentGuidance(requestID: String) {
        guard var draft = store.chatDrafts[conversationID], draft.requestID == requestID else { return }
        draft.clearSentGuidance()
        store.chatDrafts[conversationID] = draft
    }
}
