import HarnessDomain
import SwiftUI

private enum ChatTranscriptItem: Identifiable {
    case turn(ConversationTurn)
    case queued(ConversationTurn)
    case guidance(RunGuidance, Run)

    var id: String {
        switch self {
        case .turn(let turn): "turn-" + turn.id
        case .queued(let turn): "queued-" + turn.id
        case .guidance(let guidance, _): "guidance-" + guidance.id
        }
    }

    var createdAt: Date {
        switch self {
        case .turn(let turn): turn.createdAt
        case .queued(let turn): turn.createdAt
        case .guidance(let guidance, _): guidance.createdAt
        }
    }
}

private struct ChatTranscriptChunk: Identifiable {
    let items: [ChatTranscriptItem]

    var id: String { "chat.chunk." + (items.first?.id ?? "empty") }
}

struct ChatConversationTranscript: View {
    let store: AppStore
    let conversation: Conversation
    let showsTaskRail: Bool
    @Binding var guidanceDestination: String?
    let openGraph: (String, Int?) -> Void
    @State private var followsLatest = true
    @State private var userScrolling = false
    @State private var nearBottom = true
    @State private var highlightedGuidance: String?
    @State private var pendingGuidanceDestination: String?
    @State private var omittingAttachmentsID: String?
    @State private var attachmentDecisionErrors: [String: String] = [:]
    private let endID = "chat.transcript.end"

    private var items: [ChatTranscriptItem] {
        let turns = conversation.turns.map(ChatTranscriptItem.turn)
        let turnIDs = Set(conversation.turns.map(\.id))
        let turnOrder = Dictionary(
            uniqueKeysWithValues: conversation.turns.enumerated().map { ($0.element.id, $0.offset) })
        let runIDs = Set(conversation.turns.compactMap(\.runID))
        let guidance = store.snapshot.runs.filter { runIDs.contains($0.id) }.flatMap { run in
            (run.guidance ?? []).compactMap { item -> ChatTranscriptItem? in
                guard let turnID = item.conversationTurnID, turnIDs.contains(turnID) else { return nil }
                return .guidance(item, run)
            }
        }
        let queued = (conversation.queuedTurns ?? []).map(ChatTranscriptItem.queued)
        func order(_ item: ChatTranscriptItem) -> (Int, Int) {
            switch item {
            case .turn(let turn): (turnOrder[turn.id] ?? Int.max, 0)
            case .guidance(let message, _): (message.conversationTurnID.flatMap { turnOrder[$0] } ?? Int.max, 1)
            case .queued: (Int.max, 2)
            }
        }
        return (turns + guidance + queued).enumerated().sorted { left, right in
            guard left.element.createdAt == right.element.createdAt else {
                return left.element.createdAt < right.element.createdAt
            }
            let leftOrder = order(left.element)
            let rightOrder = order(right.element)
            if leftOrder.0 != rightOrder.0 { return leftOrder.0 < rightOrder.0 }
            if leftOrder.1 != rightOrder.1 { return leftOrder.1 < rightOrder.1 }
            return left.offset < right.offset
        }.map(\.element)
    }

    var body: some View {
        let transcriptItems = items
        let chunks = stride(from: 0, to: transcriptItems.count, by: 12).map { start in
            ChatTranscriptChunk(items: Array(transcriptItems[start..<min(start + 12, transcriptItems.count)]))
        }
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 36) {
                    ForEach(chunks) { chunk in
                        VStack(alignment: .leading, spacing: 36) {
                            ForEach(chunk.items) { item in
                                Group {
                                    switch item {
                                    case .turn(let turn):
                                        ChatMessageView(
                                            store: store, turn: turn, conversationID: conversation.id,
                                            isMostRecent: turn.id == conversation.turns.last?.id,
                                            showsTaskRail: showsTaskRail, openGraph: openGraph)
                                    case .queued(let turn):
                                        queuedMessage(turn)
                                    case .guidance(let guidance, let run):
                                        guidanceMessage(guidance, run: run)
                                            .background {
                                                if highlightedGuidance == guidance.id,
                                                    [.queued, .uncertain].contains(guidance.status)
                                                        || (guidance.status != .dismissed
                                                            && guidance.attachmentError?.isEmpty == false
                                                            && guidance.continueWithoutAttachments != true)
                                                {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(FrondaTheme.warning.opacity(0.08))
                                                }
                                            }
                                    }
                                }
                                .accessibilityElement(children: .contain)
                            }
                        }
                        .onAppear { revealGuidance(in: chunk, proxy: proxy) }
                        .onChange(of: pendingGuidanceDestination) { _, _ in
                            revealGuidance(in: chunk, proxy: proxy)
                        }
                    }
                    Color.clear.frame(height: 1).id(endID)
                }
                .padding(.vertical, 28).padding(.horizontal, 22)
                .frame(maxWidth: 812).frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentSize.height - geometry.visibleRect.maxY < 64
            } action: { _, bottom in
                nearBottom = bottom
                if userScrolling { followsLatest = bottom }
            }
            .onScrollPhaseChange { _, phase in
                switch phase {
                case .tracking, .interacting:
                    userScrolling = true
                    pendingGuidanceDestination = nil
                case .idle:
                    if userScrolling { followsLatest = nearBottom }
                    userScrolling = false
                default: break
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentSize.height
            } action: { _, _ in
                if followsLatest && !userScrolling { proxy.scrollTo(endID, anchor: .bottom) }
            }
            .onChange(of: transcriptItems.last?.id) { _, _ in
                followsLatest = true
                proxy.scrollTo(endID, anchor: .bottom)
            }
            .onChange(of: guidanceDestination) { _, id in
                guard let id else { return }
                guard
                    let chunk = chunks.first(where: { chunk in
                        chunk.items.contains { $0.id == "guidance-" + id }
                    })
                else {
                    guidanceDestination = nil
                    return
                }
                followsLatest = false
                highlightedGuidance = id
                pendingGuidanceDestination = id
                guidanceDestination = nil
                proxy.scrollTo(chunk.id, anchor: .center)
            }
            .overlay(alignment: .bottom) {
                if !followsLatest && !nearBottom {
                    Button("Ir para a mensagem mais recente", systemImage: "arrow.down") {
                        followsLatest = true
                        proxy.scrollTo(endID, anchor: .bottom)
                    }
                    .labelStyle(.iconOnly).buttonStyle(.bordered).buttonBorderShape(.circle)
                    .help("Ir para a mensagem mais recente").padding(.bottom, 8)
                }
            }
        }
    }

    private func revealGuidance(in chunk: ChatTranscriptChunk, proxy: ScrollViewProxy) {
        guard let id = pendingGuidanceDestination,
            chunk.items.contains(where: { $0.id == "guidance-" + id })
        else { return }
        DispatchQueue.main.async {
            guard pendingGuidanceDestination == id else { return }
            proxy.scrollTo("guidance-" + id, anchor: .center)
            pendingGuidanceDestination = nil
        }
    }

    private func guidanceMessage(_ guidance: RunGuidance, run: Run) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "person")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FrondaTheme.textMuted)
                .frame(width: 31, height: 31)
                .background(FrondaTheme.canvas, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(guidance.text)
                    .font(.system(size: 14)).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                    .padding(.horizontal, 17).padding(.vertical, 13)
                    .background(FrondaTheme.canvas, in: RoundedRectangle(cornerRadius: 15))
                    .accessibilityRepresentation { Text("Sua orientação: " + guidance.text) }
                if let attachments = guidance.attachments, !attachments.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(attachments) { attachment in
                            Label(attachment.name, systemImage: "paperclip")
                                .lineLimit(1).truncationMode(.middle)
                                .accessibilityLabel("Anexo, " + attachment.name)
                        }
                    }
                    .font(.caption).foregroundStyle(FrondaTheme.textMuted)
                    if attachments.contains(where: {
                        let name = $0.name.lowercased()
                        return [".png", ".jpg", ".jpeg", ".heic", ".tiff"].contains(where: name.hasSuffix)
                    }) {
                        Text("Imagens: apenas texto reconhecido; pixels não enviados.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if attachments.contains(where: { $0.name.lowercased().hasSuffix(".pdf") }) {
                        Text("PDFs: somente texto extraído.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Label(guidanceLabel(guidance, run: run), systemImage: guidanceIcon(guidance.status))
                    .font(.caption)
                    .foregroundStyle(guidance.status == .uncertain ? FrondaTheme.danger : FrondaTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("chat.guidance.status")
                if let error = guidance.attachmentError, guidance.continueWithoutAttachments != true,
                    guidance.status != .dismissed
                {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(FrondaTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("chat.guidance.attachment-error")
                    if guidance.status == .delivered {
                        Text(
                            [.cancelled, .archived].contains(run.state)
                                ? "A orientação foi entregue, mas seus anexos não estão disponíveis. Reanexe os arquivos se forem necessários em outra tarefa."
                                : "A orientação já foi entregue, mas os anexos não poderão ser reenviados nas próximas etapas. Reanexe os arquivos se ainda forem necessários."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        if guidance.conversationTurnID == run.conversationTurnID,
                            ![.cancelled, .archived].contains(run.state)
                        {
                            Button(
                                omittingAttachmentsID == guidance.id
                                    ? "Salvando decisão…" : "Continuar próximos passos sem estes anexos"
                            ) { omitUnavailableAttachments(guidance, run: run) }
                            .buttonStyle(.link).font(.caption)
                            .disabled(
                                !store.connected || store.busy.contains(run.id) || run.state.active
                                    || run.state == .queued || !run.pauseAllowsContinuation
                                    || omittingAttachmentsID != nil
                            )
                            .accessibilityIdentifier("chat.guidance.omit-attachments")
                            if let decisionError = attachmentDecisionErrors[guidance.id] {
                                Text(decisionError)
                                    .font(.caption).foregroundStyle(FrondaTheme.danger)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } else {
                        Text(
                            [.cancelled, .archived].contains(run.state)
                                ? "A tarefa foi encerrada. Reanexe os arquivos se forem necessários em outra tarefa."
                                : "Descarte esta orientação e reanexe os arquivos se ainda forem necessários."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                } else if guidance.continueWithoutAttachments == true {
                    Text("Os anexos não serão reenviados nas próximas etapas.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if guidance.status == .uncertain && guidance.conversationTurnID == run.conversationTurnID
                    && ![.cancelled, .archived].contains(run.state)
                {
                    Text("O agente pode ter recebido esta orientação. Reenvie apenas se isso não causar duplicação.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if run.state.active || run.state == .queued || !run.pauseAllowsContinuation {
                        Text("Aguarde a confirmação da interrupção antes de decidir o que fazer.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        if guidance.attachmentError == nil {
                            Button("Reenviar orientação") {
                                store.perform("run.guidance.retry", id: run.id) { $0.relatedID = guidance.id }
                            }
                        }
                        Button("Não reenviar") {
                            store.perform("run.guidance.dismiss", id: run.id) { $0.relatedID = guidance.id }
                        }
                    }
                    .buttonStyle(.link).font(.caption)
                    .disabled(
                        !store.connected || store.busy.contains(run.id) || run.state.active || run.state == .queued
                            || !run.pauseAllowsContinuation)
                } else if guidance.status == .queued && guidance.conversationTurnID == run.conversationTurnID
                    && guidance.attemptID == nil && !run.state.active && run.state != .queued
                    && ![.cancelled, .archived].contains(run.state) && run.pauseAllowsContinuation
                {
                    Button("Descartar orientação") {
                        store.perform("run.guidance.dismiss", id: run.id) { $0.relatedID = guidance.id }
                    }
                    .buttonStyle(.link).font(.caption)
                    .disabled(!store.connected || store.busy.contains(run.id))
                }
            }
            .frame(maxWidth: 660, alignment: .leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func omitUnavailableAttachments(_ guidance: RunGuidance, run: Run) {
        guard omittingAttachmentsID == nil else { return }
        omittingAttachmentsID = guidance.id
        attachmentDecisionErrors[guidance.id] = nil
        Task {
            defer { omittingAttachmentsID = nil }
            do {
                var request = RPCRequest("run.guidance.omit-attachments")
                request.id = run.id
                request.relatedID = guidance.id
                request.expectedSequence = run.sequence
                _ = try await store.send(request)
                await store.refresh(silent: true)
            } catch {
                attachmentDecisionErrors[guidance.id] = error.localizedDescription
                await store.refresh(silent: true)
            }
        }
    }

    private func guidanceLabel(_ guidance: RunGuidance, run: Run) -> String {
        let status: String
        switch guidance.status {
        case .queued:
            if guidance.attemptID != nil {
                status =
                    run.state.active || run.state == .queued
                    ? "Aguardando confirmação de entrega" : "Entrega não confirmada · tarefa interrompida"
            } else if run.state == .cancelled {
                status = "Não entregue · tarefa cancelada"
            } else if run.state == .archived {
                status = "Não entregue · tarefa arquivada"
            } else {
                status =
                    run.state.active || run.state == .queued
                    ? "Aguardando envio ao agente" : "Aguardando retomada · ainda não entregue"
            }
        case .delivered:
            status = "Entregue ao agente"
        case .uncertain:
            status = "Entrega não confirmada · não repetida automaticamente"
        case .dismissed:
            status = "Orientação dispensada · não será reenviada"
        }
        return store.connected ? status : "Último estado recebido: " + status
    }

    private func guidanceIcon(_ status: RunGuidanceStatus) -> String {
        switch status {
        case .queued: "clock"
        case .delivered: "checkmark.circle"
        case .uncertain: "exclamationmark.circle"
        case .dismissed: "xmark.circle"
        }
    }

    private func queuedMessage(_ turn: ConversationTurn) -> some View {
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
                ForEach(turn.attachments) { attachment in
                    Label(attachment.name, systemImage: "paperclip")
                        .font(.caption).foregroundStyle(FrondaTheme.textMuted)
                }
                HStack(spacing: 12) {
                    Label(
                        conversation.turns.last?.status == .pending
                            ? "Aguardando resposta anterior" : "Fila aguardando sua decisão",
                        systemImage: "clock"
                    )
                    .foregroundStyle(FrondaTheme.textMuted)
                    Button("Remover da fila") {
                        store.perform("conversation.queue.remove", id: conversation.id) { $0.relatedID = turn.id }
                    }
                    .buttonStyle(.link)
                    .disabled(!store.connected || store.busy.contains(conversation.id))
                }
                .font(.caption)
                if conversation.turns.last?.status != .pending, conversation.queuedTurns?.first?.id == turn.id {
                    Button("Continuar fila") {
                        store.perform("conversation.queue.resume", id: conversation.id)
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(!store.connected || store.busy.contains(conversation.id))
                }
            }
            .frame(maxWidth: 660, alignment: .leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("chat.queue.message")
    }
}
