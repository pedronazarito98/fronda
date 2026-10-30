import HarnessDomain
import SwiftUI

struct NewRunView: View {
    @Bindable var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = NewRunDraft()
    @State private var operation: Operation?
    @State private var localError: String?
    @State private var initialized = false
    @State private var journeyComposer = false
    @State private var restoredProvider: ProviderKind?
    @State private var showingOptions = false
    @FocusState private var focusedField: NewRunField?

    private enum Operation { case source, create }
    private enum PreparationIssue { case objective, project, flow, invalidFlow, source, connection }
    private var book: Runbook? { store.snapshot.runbooks.first { $0.id == draft.bookID } }
    private var flowValidation: Result<[RunbookStep], Error>? {
        book.map { selected in Result { try selected.orderedSteps() } }
    }
    private var orderedSteps: [RunbookStep] {
        guard let flowValidation, case .success(let steps) = flowValidation else { return [] }
        return steps
    }
    private var flowError: String? {
        guard let flowValidation, case .failure(let error) = flowValidation else { return nil }
        return error.localizedDescription
    }
    private var hasProject: Bool { store.snapshot.projects.contains { $0.id == draft.projectID } }
    private var working: Bool { operation != nil }
    private var canCreate: Bool {
        store.connected && !working && !store.busy.contains("run.create") && hasProject && book != nil
            && flowError == nil
            && draft.hasObjective && !draft.sourceNeedsRefresh
    }
    private var preparationIssue: PreparationIssue? {
        if flowError != nil { return .invalidFlow }
        if !draft.hasObjective { return .objective }
        if !hasProject { return .project }
        if book == nil { return .flow }
        if draft.sourceNeedsRefresh { return .source }
        if !store.connected { return .connection }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            NewRunConfiguration(
                draft: $draft, projects: store.snapshot.projects, runbooks: store.snapshot.runbooks,
                providers: store.snapshot.providers, addProject: store.addProject, focusedField: $focusedField
            ).disabled(working)
            Divider()
            HStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        NewRunSourceSection(
                            draft: $draft, canFetch: store.connected && hasProject && !working,
                            fetching: operation == .source, fetchSource: fetchSource, focusedField: $focusedField
                        ).padding(24)
                    }
                    .onChange(of: focusedField) { _, field in
                        if let field, [.objective, .criteria, .source].contains(field) {
                            proxy.scrollTo(field, anchor: .top)
                        }
                    }
                }.frame(maxWidth: .infinity).background(FrondaTheme.surfaceRaised)
                Divider()
                preparationDetails.frame(width: 292).background(FrondaTheme.surface)
            }.disabled(working)
            Divider()
            footer
        }
        .frame(width: 920, height: 680)
        .background(FrondaTheme.canvas)
        .tint(FrondaTheme.accent)
        .interactiveDismissDisabled(working)
        .modifier(NewRunJourney(store: store, draft: $draft, focusedField: $focusedField, working: working))
        .onAppear(perform: initialize)
        .onChange(of: store.firstTaskJourney.isComposing) { _, active in
            if active { journeyComposer = true }
        }
        .onDisappear(perform: clearComposer)
        .onChange(of: draft.bookID) { _, _ in applyBookDefaults() }
        .onChange(of: draft.provider) { _, provider in
            if let restoredProvider {
                self.restoredProvider = nil
                if restoredProvider == provider { return }
            }
            draft.execution =
                store.snapshot.preferences.providerDefaults?[provider.rawValue] ?? ExecutionConfiguration()
        }
        .onChange(of: book?.budget) { _, _ in applyBookBudget() }
        .onChange(of: store.snapshot.projects.map(\.id)) { _, ids in
            if draft.projectID.isEmpty { draft.projectID = ids.first ?? "" }
        }
        .onChange(of: store.snapshot.runbooks.map(\.id)) { _, ids in
            if draft.bookID.isEmpty { draft.bookID = ids.first ?? "" }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.and.pencil").font(.system(size: 19, weight: .light))
                .foregroundStyle(FrondaTheme.accent).frame(width: 34, height: 34)
                .background(FrondaTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 5) {
                Text("Nova tarefa").font(.system(size: 21, weight: .semibold)).tracking(-0.5)
                Text("Prepare o contexto agora. Você acompanha as etapas e revisa o que será executado.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary).frame(width: 28, height: 28)
                    .background(FrondaTheme.surface, in: Circle())
            }.buttonStyle(.plain).help("Fechar").accessibilityLabel("Fechar nova tarefa").disabled(working)
        }.padding(.horizontal, 24).padding(.vertical, 13)
    }

    private var preparationDetails: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let book {
                    NewRunFlowPreview(book: book, steps: orderedSteps, mode: draft.mode, validationError: flowError)
                } else {
                    Text("Escolha um fluxo para conferir o percurso da tarefa.").font(.callout).foregroundStyle(
                        .secondary)
                    Button("Selecionar fluxo") { focusedField = .flow }.buttonStyle(.link)
                }
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Label("Modelo e esforço", systemImage: "cpu").font(.callout.weight(.semibold))
                    ExecutionControls(
                        configuration: $draft.execution, provider: draft.provider,
                        models: store.snapshot.providers.first { $0.kind == draft.provider }?.models ?? [])
                    Button("Consultar modelos") {
                        store.perform("provider.models") { $0.text = draft.provider.rawValue }
                    }
                    .font(.caption).disabled(store.busy.contains("provider.models"))
                }
                Divider()
                Button {
                    showingOptions = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "slider.horizontal.3").foregroundStyle(FrondaTheme.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Opções da tarefa").font(.system(size: 12, weight: .semibold)).foregroundStyle(
                                .primary)
                            Text("\(draft.mode.rawValue) · \(draft.budget.formatted()) tokens")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.secondary)
                    }.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingOptions) { NewRunOptions(draft: $draft, book: book) }
            }
            .padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let localError {
                Label(localError, systemImage: "exclamationmark.circle")
                    .font(.system(size: 11)).foregroundStyle(FrondaTheme.danger).lineLimit(2).help(localError)
            }
            HStack(spacing: 12) {
                preparationSummary
                Spacer()
                if working { ProgressView().controlSize(.small) }
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction).disabled(working)
                Button(operation == .create ? "Preparando…" : "Criar e preparar contexto", action: create)
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(!canCreate)
                    .keyboardShortcut(.defaultAction).accessibilityIdentifier("composer.create")
                    .guideTarget(.prepare)
            }
        }.padding(.horizontal, 26).padding(.vertical, 16).background(FrondaTheme.surface)
    }

    private var preparationSummary: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: preparationIssue == nil ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(preparationIssue == nil ? FrondaTheme.success : FrondaTheme.accent)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 5) {
                Text(preparationTitle).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                if let preparationIssue, !working {
                    Button(resolveTitle(for: preparationIssue)) { resolve(preparationIssue) }
                        .buttonStyle(.link).font(.system(size: 11))
                } else {
                    Text(
                        working
                            ? "Aguarde a confirmação do coordenador."
                            : "Você confere o contexto antes de autorizar o envio."
                    )
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }.frame(maxWidth: 375, alignment: .leading)
    }

    private var preparationTitle: String {
        if operation == .source { return "Lendo a fonte selecionada…" }
        if operation == .create { return "Preparando sua tarefa…" }
        switch preparationIssue {
        case .objective: return "Comece pelo resultado que você quer alcançar"
        case .project: return "Escolha onde esta tarefa vai trabalhar"
        case .flow: return "Defina as etapas de trabalho"
        case .invalidFlow: return "Fluxo precisa de ajustes"
        case .source: return "A fonte precisa ser conferida novamente"
        case .connection: return "Aguardando conexão com o coordenador"
        case nil: return "Pronto para preparar o contexto"
        }
    }

    private func resolveTitle(for issue: PreparationIssue) -> String {
        switch issue {
        case .objective: "Definir objetivo"
        case .project: store.snapshot.projects.isEmpty ? "Adicionar projeto…" : "Selecionar projeto"
        case .flow: store.snapshot.runbooks.isEmpty ? "Atualizar fluxos" : "Selecionar fluxo"
        case .invalidFlow: "Escolher outro fluxo"
        case .source: "Revisar fonte"
        case .connection: "Tentar conectar novamente"
        }
    }

    private func resolve(_ issue: PreparationIssue) {
        switch issue {
        case .objective: focusedField = .objective
        case .project:
            if store.snapshot.projects.isEmpty { store.addProject() } else { focusedField = .project }
        case .flow:
            if store.snapshot.runbooks.isEmpty {
                Task { await store.refresh() }
            } else {
                focusedField = .flow
            }
        case .invalidFlow: focusedField = .flow
        case .source: focusedField = .source
        case .connection:
            Task {
                await store.connect()
                await store.refresh()
            }
        }
    }

    private func initialize() {
        guard !initialized else { return }
        initialized = true
        journeyComposer = store.firstTaskJourney.isComposing
        if store.firstTaskJourney.isComposing, let saved = store.firstTaskJourney.savedDraft {
            restoredProvider = saved.provider
            draft = saved
            return
        }
        draft.title = store.composerText
        draft.context = store.composerSource?.text ?? ""
        draft.projectID =
            store.composerProjectID.isEmpty ? (store.snapshot.projects.first?.id ?? "") : store.composerProjectID
        draft.bookID =
            store.composerRunbookID.isEmpty ? (store.snapshot.runbooks.first?.id ?? "") : store.composerRunbookID
        draft.budget = store.snapshot.preferences.tokenBudget
        applyBookDefaults()
        draft.execution =
            store.snapshot.preferences.providerDefaults?[draft.provider.rawValue] ?? ExecutionConfiguration()
    }

    private func applyBookDefaults() {
        guard let book else { return }
        if !draft.modeIsCustomized { draft.mode = book.mode }
        if !draft.providerIsCustomized { draft.provider = book.provider }
        applyBookBudget()
    }

    private func applyBookBudget() {
        guard let book, !draft.budgetIsCustomized else { return }
        draft.budget = book.budget
    }

    private func clearComposer() {
        store.composerSource = nil
        store.composerText = ""
        store.composerProjectID = ""
        store.composerRunbookID = ""
    }

    private func create() {
        guard canCreate, let book else { return }
        operation = .create
        localError = nil
        var request = RPCRequest("run.create")
        request.run = draft.makeRun(book: book, originalSource: store.composerSource)
        Task {
            do {
                let response = try await store.send(request)
                await store.refresh()
                if journeyComposer { store.firstTaskJourney.createdRun(response.id) }
                store.navigation.visit(
                    WorkspaceLocation(
                        route: "run:" + response.id,
                        section: store.firstTaskJourney.isActive && store.firstTaskJourney.runID == response.id
                            ? .context : nil))
                dismiss()
            } catch { localError = error.localizedDescription }
            operation = nil
        }
    }

    private func fetchSource() {
        guard store.connected, hasProject, !working else { return }
        operation = .source
        localError = nil
        var request = RPCRequest("source.fetch")
        request.text = draft.title
        request.id = draft.projectID
        request.arguments = draft.commentIDs.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        request.path = draft.remoteAttachmentIDs.sorted().joined(separator: ",")
        let signature = draft.sourceSignature
        Task {
            do {
                let response = try await store.send(request)
                draft.context = response.text
                draft.sourcePreview = response.sourcePreview
                draft.fetchedSignature = signature
                if draft.criteria.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    draft.criteria = response.sourcePreview?.criteria.joined(separator: "\n") ?? ""
                }
            } catch { localError = error.localizedDescription }
            operation = nil
        }
    }
}
