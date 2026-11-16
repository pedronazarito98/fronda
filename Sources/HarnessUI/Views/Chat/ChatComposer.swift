import AppKit
import HarnessDomain
import QuickLook
import SwiftUI

struct ChatComposer: View {
    let store: AppStore
    @Binding var draft: ChatComposerDraft
    let submitting: Bool
    let recentProjectID: String?
    let pendingTurn: ConversationTurn?
    let hasQueuedMessages: Bool
    let guidanceRun: Run?
    @Binding var guidanceMode: Bool
    let send: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focused: Bool
    @State private var dropTargeted = false
    @State private var previewURL: URL?
    @State private var projectBeforeConversation: String?

    private var adjustedRunIsPaused: Bool {
        guard let id = draft.adjustingRunID else { return true }
        return store.snapshot.runs.contains {
            $0.id == id && $0.state == .paused && $0.pauseAllowsContinuation && $0.projectID == draft.projectID
        }
    }

    private var canSend: Bool {
        guard store.connected, !submitting,
            !draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return false }
        if isGuiding { return true }
        if let run = guidanceRun, draft.projectID == run.projectID { return false }
        return adjustedRunIsPaused && (!hasQueuedMessages || draft.projectID == nil)
            && (pendingTurn == nil || (pendingTurn?.runID == nil && draft.projectID == nil))
            && (draft.projectID == nil || store.snapshot.projects.contains { $0.id == draft.projectID })
    }

    private var isGuiding: Bool { guidanceRun != nil && guidanceMode }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if guidanceRun != nil {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: isGuiding ? "text.bubble" : "bubble.left")
                        .foregroundStyle(FrondaTheme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isGuiding ? "Orientar tarefa em andamento" : "Conversar normalmente")
                            .font(.caption.weight(.semibold))
                        Text(
                            isGuiding
                                ? "Acompanhe na conversa quando o agente receber a orientação."
                                : "Sua mensagem será enviada ao chat, sem orientar a tarefa em andamento."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Button(isGuiding ? "Conversar" : "Orientar tarefa") { toggleGuidanceMode() }
                        .buttonStyle(.link).font(.caption)
                        .disabled(submitting)
                        .accessibilityIdentifier("chat.guidance.mode")
                }
            }
            if !isGuiding && draft.adjustingRunID != nil {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "pause.circle").foregroundStyle(FrondaTheme.accent)
                    Text(
                        adjustedRunIsPaused
                            ? "O próximo envio inicia uma nova rodada com os arquivos desta execução."
                            : "A execução mudou. Volte a conversar ou selecione um projeto."
                    )
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Voltar a conversar") {
                        draft.projectID = nil
                        draft.adjustingRunID = nil
                    }.buttonStyle(.link).font(.caption).disabled(submitting)
                }
            }
            if !isGuiding, let pendingTurn, pendingTurn.runID == nil {
                Text(
                    draft.projectID == nil
                        ? "Sua mensagem aguardará a resposta atual antes de ser enviada."
                        : "Para enviar enquanto aguarda a resposta, escolha Conversar."
                )
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            if !isGuiding && hasQueuedMessages && draft.projectID != nil {
                Text("Continue ou remova as mensagens na fila antes de iniciar outra tarefa.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !isGuiding, let run = guidanceRun, draft.projectID == run.projectID {
                Text("Para enviar instruções à tarefa em andamento, escolha Orientar tarefa.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if guidanceRun == nil, pendingTurn?.runID != nil {
                Text("Preparando a tarefa. Quando ela iniciar, você poderá orientar o agente por aqui.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField(
                isGuiding ? "Oriente o agente enquanto ele trabalha…" : "Envie uma mensagem ao Fronda…",
                text: $draft.prompt, axis: .vertical
            )
            .textFieldStyle(.plain).font(.system(size: 15))
            .lineLimit(2...8)
            .accessibilityLabel("Mensagem")
            .accessibilityIdentifier("chat.prompt")
            .disabled(submitting)
            .focused($focused)
            .onKeyPress(.return, phases: .down) { press in
                let editingText = NSApp.keyWindow?.firstResponder as? NSTextView
                guard editingText?.hasMarkedText() != true, !press.modifiers.contains(.shift),
                    !press.modifiers.contains(.option)
                else { return .ignored }
                if canSend { send() }
                return .handled
            }
            if !draft.attachments.isEmpty { attachments.disabled(submitting) }
            if isGuiding && !draft.attachments.isEmpty {
                Text(
                    "O agente recebe o texto extraído dos anexos. Em imagens, apenas o texto reconhecido; em PDFs, somente o texto extraído."
                )
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            if !isGuiding, let projectID = draft.projectID, guidanceRun?.projectID != projectID {
                ChatBudgetPreview(store: store, projectID: projectID)
            }
            HStack(alignment: .bottom, spacing: 6) {
                Button(action: chooseFiles) {
                    Image(systemName: "plus").font(.system(size: 15, weight: .medium))
                        .frame(width: 31, height: 31)
                        .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 9))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9).strokeBorder(FrondaTheme.border)
                        }
                }
                .buttonStyle(.plain).foregroundStyle(FrondaTheme.textMuted)
                .disabled(submitting)
                .help("Anexar arquivos ou pastas").accessibilityLabel("Anexar arquivos ou pastas")
                .accessibilityIdentifier("chat.attach")
                if isGuiding {
                    Label("Tarefa atual", systemImage: "arrow.turn.down.right")
                        .font(.caption.weight(.medium)).foregroundStyle(FrondaTheme.textMuted)
                } else {
                    ChatComposerOptions(store: store, draft: $draft, recentProjectID: recentProjectID)
                        .disabled(submitting)
                }
                Spacer(minLength: 0)
                submitControl
            }
        }
        .padding(16)
        .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 17))
        .overlay {
            RoundedRectangle(cornerRadius: 17)
                .strokeBorder(
                    dropTargeted ? FrondaTheme.accent : FrondaTheme.border.opacity(0.9),
                    lineWidth: dropTargeted ? 2 : 1
                )
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.12 : 0.035), radius: 14, x: 0, y: 5)
        .dropDestination(for: URL.self) { urls, _ in
            addFiles(urls)
        } isTargeted: {
            dropTargeted = $0 && !submitting
        }
        .quickLookPreview($previewURL)
        .onAppear { focused = true }
        .onChange(of: submitting) { _, active in
            if !active {
                focused = true
                if guidanceRun == nil { restorePreviousProjectIfNeeded() }
            }
        }
        .onChange(of: draft.adjustingRunID) { _, id in if id != nil { focused = true } }
        .onChange(of: guidanceRun?.id) { _, id in
            if id == nil { restorePreviousProjectIfNeeded() }
        }
    }

    private var attachments: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(draft.attachments, id: \.self) { path in
                    let url = URL(fileURLWithPath: path)
                    HStack(spacing: 6) {
                        Button {
                            previewURL = url
                        } label: {
                            Label(url.lastPathComponent, systemImage: "doc")
                                .lineLimit(1).truncationMode(.middle)
                                .frame(maxWidth: 175)
                        }
                        .help("Visualizar " + url.lastPathComponent)
                        Button {
                            draft.attachments.removeAll { $0 == path }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .medium))
                        }
                        .help("Remover anexo").accessibilityLabel("Remover " + url.lastPathComponent)
                    }
                    .buttonStyle(.plain).font(.caption)
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(FrondaTheme.canvas, in: RoundedRectangle(cornerRadius: 9))
                }
            }
        }.scrollIndicators(.hidden)
    }

    @ViewBuilder private var submitControl: some View {
        HStack(spacing: 6) {
            if let pending = pendingTurn, pending.runID == nil {
                Button(action: store.cancelReply) {
                    Image(systemName: "stop.fill").font(.system(size: 10))
                        .frame(width: 29, height: 29)
                }
                .buttonStyle(.bordered).buttonBorderShape(.circle)
                .help("Interromper resposta").accessibilityLabel("Interromper resposta")
                .accessibilityIdentifier("chat.stop")
            }
            Button(action: send) {
                Group {
                    if submitting {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up.right").font(.system(size: 14, weight: .semibold))
                    }
                }.frame(width: 29, height: 29)
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 10))
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!canSend)
            .help(isGuiding ? "Enviar orientação" : "Enviar mensagem (↩ ou ⌘↩). Use ⇧↩ para uma nova linha.")
            .accessibilityLabel(isGuiding ? "Enviar orientação" : "Enviar mensagem").accessibilityIdentifier(
                "chat.send")
        }
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.title = "Anexar ao chat"
        panel.prompt = "Anexar"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK { _ = addFiles(panel.urls) }
    }

    private func toggleGuidanceMode() {
        if isGuiding {
            projectBeforeConversation = draft.projectID
            draft.projectID = nil
            guidanceMode = false
        } else {
            if draft.projectID == nil, let projectBeforeConversation {
                draft.projectID = projectBeforeConversation
            }
            projectBeforeConversation = nil
            guidanceMode = true
        }
    }

    private func restorePreviousProjectIfNeeded() {
        guard !submitting else { return }
        if draft.projectID == nil, let projectBeforeConversation {
            draft.projectID = projectBeforeConversation
        }
        projectBeforeConversation = nil
    }

    private func addFiles(_ urls: [URL]) -> Bool {
        guard !submitting else { return false }
        var known = Set(draft.attachments)
        let paths = urls.filter(\.isFileURL).map { $0.standardizedFileURL.path }.filter { known.insert($0).inserted }
        guard !paths.isEmpty else { return false }
        draft.attachments.append(contentsOf: paths)
        focused = true
        return true
    }
}
