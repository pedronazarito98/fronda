import AppKit
import HarnessDomain
import SwiftUI

struct NewRunView: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var context = ""
    @State private var criteria = ""
    @State private var projectID = ""
    @State private var bookID = ""
    @State private var provider = ProviderKind.codex
    @State private var mode = AutonomyMode.guided
    @State private var scope = "**"
    @State private var budget = 32000
    @State private var attachments = [String]()
    @State private var commentIDs = ""
    @State private var remoteAttachmentIDs = Set<String>()
    @State private var sourcePreview: SourcePreview?
    @State private var fetchedSignature = ""
    @State private var working = false
    @State private var localError: String?
    private var book: Runbook? { store.snapshot.runbooks.first { $0.id == bookID } }
    private var sourceSignature: String {
        [title, projectID, commentIDs, remoteAttachmentIDs.sorted().joined(separator: ",")].joined(separator: "\n")
    }
    private var sourceNeedsRefresh: Bool { sourcePreview != nil && fetchedSignature != sourceSignature }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Nova tarefa").font(.title2.weight(.semibold))
                    Text("Defina o objetivo. Inspecione o contexto antes de executar.").font(.callout).foregroundStyle(
                        .secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }.buttonStyle(.plain).keyboardShortcut(.cancelAction)
            }.padding(25)
            Divider()
            ScrollView {
                Form {
                    Section("Objetivo e fonte") {
                        TextField("Objetivo", text: $title, axis: .vertical).lineLimit(2...4).accessibilityIdentifier(
                            "composer.objective")
                        HStack {
                            Label(SourceKind.detect(title).rawValue, systemImage: "link").font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if SourceKind.detect(title) != .text {
                                Button("Ler fonte conectada") { fetchSource() }.disabled(working || projectID.isEmpty)
                            }
                        }
                        if SourceKind.detect(title) != .text {
                            TextField(
                                "IDs de comentários autorizados (opcional, separados por vírgula)", text: $commentIDs
                            ).font(.caption)
                        }
                        if let sourcePreview, !sourcePreview.attachments.isEmpty {
                            Text("Anexos disponíveis no Jira").font(.caption.weight(.semibold))
                            ForEach(sourcePreview.attachments) { attachment in
                                Toggle(
                                    "\(attachment.name) · \(ByteCountFormatter.string(fromByteCount: Int64(max(0, attachment.size)), countStyle: .file))",
                                    isOn: Binding(
                                        get: { remoteAttachmentIDs.contains(attachment.id) },
                                        set: { selected in
                                            if selected {
                                                remoteAttachmentIDs.insert(attachment.id)
                                            } else {
                                                remoteAttachmentIDs.remove(attachment.id)
                                            }
                                        })
                                ).font(.caption)
                            }
                        }
                        if sourceNeedsRefresh {
                            Label(
                                "A seleção mudou. Leia a fonte novamente para conferir o conteúdo escolhido.",
                                systemImage: "arrow.clockwise"
                            ).font(.caption).foregroundStyle(.orange)
                        }
                        TextField("Contexto adicional", text: $context, axis: .vertical).lineLimit(3...6)
                        TextField("Critérios de aceite (um por linha)", text: $criteria, axis: .vertical).lineLimit(
                            2...5
                        ).accessibilityIdentifier("composer.criteria")
                        HStack {
                            Button("Anexar arquivo…") { attach() }
                            Text(attachments.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", "))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    Section("Workspace") {
                        Picker("Projeto", selection: $projectID) {
                            Text("Selecione um projeto").tag("")
                            ForEach(store.snapshot.projects) { Text($0.name).tag($0.id) }
                        }
                        if let project = store.snapshot.projects.first(where: { $0.id == projectID }) {
                            LabeledContent("Base", value: "\(project.branch) · \(project.head.prefix(10))")
                            if project.dirty {
                                Label(
                                    "O checkout tem alterações. A run partirá da HEAD limpa; suas alterações ficam no lugar.",
                                    systemImage: "info.circle"
                                ).font(.caption).foregroundStyle(.orange)
                            }
                        }
                        Picker("Fluxo de trabalho", selection: $bookID) {
                            ForEach(store.snapshot.runbooks) { Text($0.name).tag($0.id) }
                        }
                        if let kind = book?.workKind {
                            LabeledContent("Tipo", value: kind.label)
                            if kind == .bug {
                                Text("Exige reprodução antes da correção e conferência do mesmo cenário depois.").font(
                                    .caption
                                ).foregroundStyle(.secondary)
                            }
                            if kind == .interface {
                                Text("Exige conferência visual com imagem ou vídeo do resultado.").font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Picker("Executor", selection: $provider) {
                            ForEach(ProviderKind.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Autonomia", selection: $mode) {
                            ForEach(AutonomyMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        TextField("Escopo (paths separados por vírgula)", text: $scope)
                        Stepper(
                            "Orçamento: \(budget.formatted()) tokens", value: $budget, in: 1000...500000, step: 1000)
                    }
                    Section("Antes de enviar") {
                        Label(
                            mode.writes
                                ? "Escrita em worktree exclusiva, a partir da base Git."
                                : "Investigação em modo de leitura.", systemImage: "arrow.triangle.branch")
                        Label(
                            "Você autoriza o contexto para investigar e aprova o plano antes de implementar.",
                            systemImage: "eye")
                        Label("Commit, push, PR e Jira têm aprovação por operação.", systemImage: "checkmark.shield")
                    }.font(.caption).foregroundStyle(.secondary)
                    if let localError { Text(localError).foregroundStyle(.red).font(.caption) }
                }.formStyle(.grouped)
            }
            Divider()
            HStack {
                Button("Adicionar projeto…") { store.addProject() }
                Spacer()
                Button("Cancelar") { dismiss() }
                Button(working ? "Preparando…" : "Criar e preparar contexto") { create() }.buttonStyle(
                    .borderedProminent
                ).disabled(
                    working || sourceNeedsRefresh || projectID.isEmpty
                        || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ).keyboardShortcut(.defaultAction).accessibilityIdentifier("composer.create")
            }.padding(20)
        }.frame(width: 720, height: 770).tint(HarnessTheme.accent)
            .onAppear {
                title = store.composerText
                context = store.composerSource?.text ?? ""
                projectID =
                    store.composerProjectID.isEmpty
                    ? (store.snapshot.projects.first?.id ?? "") : store.composerProjectID
                bookID =
                    store.composerRunbookID.isEmpty
                    ? (store.snapshot.runbooks.first?.id ?? "") : store.composerRunbookID
                budget = store.snapshot.preferences.tokenBudget
            }
            .onDisappear {
                store.composerSource = nil
                store.composerText = ""
                store.composerProjectID = ""
                store.composerRunbookID = ""
            }
            .onChange(of: bookID) { _, _ in
                if let book {
                    mode = book.mode
                    provider = book.provider
                }
            }
    }
    private func create() {
        guard let book else { return }
        working = true
        var run = Run()
        run.title = title
        run.projectID = projectID
        run.runbook = book
        run.provider = provider
        run.mode = mode
        run.budget = budget
        run.source = sourcePreview?.intent ?? store.composerSource ?? SourceIntent()
        run.source.text = context.isEmpty ? title : title + "\n\n" + context
        run.source.kind = store.composerSource?.kind ?? SourceKind.detect(title)
        run.source.attachments = attachments
        if !attachments.isEmpty {
            run.source.kind =
                attachments.contains(where: {
                    ["png", "jpg", "jpeg", "heic"].contains(URL(fileURLWithPath: $0).pathExtension.lowercased())
                }) ? .screenshot : .file
        }
        if [.github, .jira].contains(run.source.kind) { run.source.sourceURL = title }
        run.criteria = criteria.split(separator: "\n").map { Criterion(text: String($0)) }
        run.scope = scope.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var request = RPCRequest("run.create")
        request.run = run
        Task {
            do {
                let response = try await store.send(request)
                await store.refresh()
                store.route = "run:" + response.id
                dismiss()
            } catch { localError = error.localizedDescription }
            working = false
        }
    }
    private func fetchSource() {
        working = true
        localError = nil
        var request = RPCRequest("source.fetch")
        request.text = title
        request.id = projectID
        request.arguments = commentIDs.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        request.path = remoteAttachmentIDs.sorted().joined(separator: ",")
        let signature = sourceSignature
        Task {
            do {
                let response = try await store.send(request)
                context = response.text
                sourcePreview = response.sourcePreview
                fetchedSignature = signature
                if criteria.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    criteria = response.sourcePreview?.criteria.joined(separator: "\n") ?? ""
                }
            } catch { localError = error.localizedDescription }
            working = false
        }
    }
    private func attach() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK { attachments += panel.urls.map(\.path) }
    }
}
