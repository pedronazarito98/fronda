import Foundation
import HarnessDomain
import HarnessInfrastructure
import HarnessProviders

public actor RunCoordinator {
    let paths: StoragePaths
    let store: EventStore
    var projects: [Project]
    var runs: [Run]
    var runbooks: [Runbook]
    var preferences: AppPreferences
    var providers = [ProviderInfo]()
    var providersReady = false
    private var inFlightRequests = [String: Task<RPCResponse, Never>]()
    private(set) var shuttingDown = false
    var exclusiveOperations = Set<String>()
    var extensionProcesses = [String: RunningProcess]()
    var extensionConnections = [String: MCPConnection]()
    var extensionBusy = Set<String>()
    var jobs = [String: Task<Void, Never>]()
    var codexSessions = [String: CodexSession]()
    var claudeSessions = [String: ClaudeSession]()
    var lastIndexCheck = Date.distantPast
    public init(paths: StoragePaths) throws {
        self.paths = paths
        store = try EventStore(paths: paths)
        projects = try store.load(Project.self, table: "projects")
        for offset in projects.indices where projects[offset].indexState == "INDEXING" {
            projects[offset].indexState = "STALE"
            projects[offset].indexMessage = "Indexação interrompida; será retomada pelo coordenador."
            try store.save(projects[offset], id: projects[offset].id, table: "projects")
        }
        runs = try store.load(Run.self, table: "runs")
        runbooks = try store.load(Runbook.self, table: "runbooks")
        preferences = try store.load(AppPreferences.self, table: "preferences").first ?? AppPreferences()
        if runbooks.isEmpty {
            runbooks = Runbook.builtins
            for book in runbooks { try store.save(book, id: book.id, table: "runbooks") }
        }
        // Upgrade only untouched built-ins; run copies and user revisions remain immutable.
        for replacement in Runbook.builtins {
            if let index = runbooks.firstIndex(where: { $0.id == replacement.id && $0.version == 1 }) {
                runbooks[index] = replacement
                try store.save(replacement, id: replacement.id, table: "runbooks")
            }
        }
        let persistedRuns = runs
        for offset in persistedRuns.indices
        where persistedRuns[offset].state.active
            || (persistedRuns[offset].extensionInvocations ?? []).contains(where: { $0.state == "RUNNING" })
            || persistedRuns[offset].approvals.contains(where: { ["SENDING", "APPROVED"].contains($0.state) })
        {
            var run = persistedRuns[offset]
            let previous = run.sequence
            run.state = .recovering
            run.reason = "O coordenador foi interrompido. Revise o diff e retome por uma nova tentativa."
            for i in run.attempts.indices where run.attempts[i].status == "RUNNING" {
                run.attempts[i].status = "INTERRUPTED_UNKNOWN"
            }
            for i in run.validations.indices where run.validations[i].status == .running {
                run.validations[i].status = .blocked
                run.validations[i].output = "Término não observado antes da interrupção."
            }
            for i in run.approvals.indices where ["SENDING", "APPROVED"].contains(run.approvals[i].state) {
                run.approvals[i].state = "UNKNOWN"
            }
            if var calls = run.extensionInvocations {
                for i in calls.indices where calls[i].state == "RUNNING" { calls[i].state = "UNKNOWN" }
                run.extensionInvocations = calls
            }
            run.sequence += 1
            var event = RunEvent()
            event.runID = run.id
            event.sequence = run.sequence
            event.kind = "run.recovering"
            event.message = run.reason
            try store.append(run: run, event: event, previousSequence: previous)
            runs[offset] = run
        }
    }
    public func start() async {
        providers = await ProviderGateway.probe(overrides: preferences.providers)
        providersReady = true
        schedule()
    }
    public func prepareShutdown(force: Bool) throws {
        guard force || (!runs.contains(where: { $0.state.active }) && jobs.isEmpty) else {
            throw HarnessError("Há runs ativas. Pause ou cancele antes de reiniciar o coordenador.")
        }
        shuttingDown = true
    }
    func run(_ id: String) throws -> Run {
        guard let run = runs.first(where: { $0.id == id }) else { throw HarnessError("Run não encontrada.") }
        return run
    }
    func project(_ id: String) throws -> Project {
        guard let project = projects.first(where: { $0.id == id }) else {
            throw HarnessError("Projeto não encontrado.")
        }
        return project
    }
    func record(_ input: Run, kind: String, message: String, artifact: String = "") throws {
        var run = input
        let previous = runs.first(where: { $0.id == run.id })?.sequence ?? 0
        run.sequence = previous + 1
        run.updatedAt = Date()
        var event = RunEvent()
        event.runID = run.id
        event.sequence = run.sequence
        event.kind = kind
        event.message = ContextFirewall.redact(message)
        event.revision = run.revision
        event.artifactHash = artifact
        try store.append(run: run, event: event, previousSequence: previous)
        if let index = runs.firstIndex(where: { $0.id == run.id }) { runs[index] = run } else { runs.append(run) }
    }
    func saveProject(_ project: Project) throws {
        try store.save(project, id: project.id, table: "projects")
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
    }
    func snapshot() -> Snapshot {
        var result = Snapshot()
        result.projects = projects
        result.runs = runs.sorted { $0.updatedAt > $1.updatedAt }
        result.runbooks = runbooks
        result.providers = providers
        result.preferences = preferences
        result.storageBytes =
            (try? paths.database.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        return result
    }
    public func handle(_ request: RPCRequest) async -> RPCResponse {
        if let pending = inFlightRequests[request.requestID] { return await pending.value }
        let pending = Task { await processRequest(request) }
        inFlightRequests[request.requestID] = pending
        let response = await pending.value
        inFlightRequests[request.requestID] = nil
        return response
    }
    private func processRequest(_ request: RPCRequest) async -> RPCResponse {
        var response = RPCResponse()
        do {
            guard !shuttingDown else {
                throw HarnessError("SERVICE_STOPPING: o coordenador está encerrando. Tente novamente após a reconexão.")
            }
            if let cached = try store.cachedResponse(request.requestID) { return cached }
            if let expected = request.expectedSequence, !request.id.isEmpty,
                let existing = runs.first(where: { $0.id == request.id }), expected != existing.sequence
            {
                throw HarnessError("REVISION_CONFLICT: a run mudou. Recarregue a proposta antes de confirmar.")
            }
            let readOnly = [
                "snapshot", "events", "search", "replay", "diagnostics", "run.get", "attempt.payload", "evidence.media",
                "evidence.file",
            ]
            let exclusive =
                !request.id.isEmpty && runs.contains { $0.id == request.id } && !readOnly.contains(request.action)
                && !["tool.call", "run.pause", "run.cancel"].contains(request.action)
            if exclusive {
                guard !exclusiveOperations.contains(request.id) else {
                    throw HarnessError("RUN_BUSY: aguarde a operação atual desta tarefa.")
                }
                exclusiveOperations.insert(request.id)
            }
            defer { if exclusive { exclusiveOperations.remove(request.id) } }
            response = try await dispatch(request)
            if !["snapshot", "events", "search", "replay", "diagnostics", "run.get", "artifact", "evidence.media"]
                .contains(
                    request.action)
            {
                try store.cache(response, id: request.requestID)
            }
        } catch { response.error = ContextFirewall.redact(error.localizedDescription) }
        return response
    }
    func dispatch(_ request: RPCRequest) async throws -> RPCResponse {
        var response = RPCResponse()
        switch request.action {
        case "snapshot": response.snapshot = snapshot()
        case "run.get": response.run = try run(request.id)
        case "events": response.events = try store.events(request.id, before: request.number)
        case "replay": response.run = try store.replay(request.id, sequence: request.number)
        case "search": response.items = try store.search(projectID: request.id, query: request.text)
        case "project.add":
            let new = try await GitWorkspace.inspect(path: request.path, bookmark: request.project?.bookmark)
            guard !projects.contains(where: { $0.path == new.path }) else {
                throw HarnessError("Este projeto já está cadastrado.")
            }
            try saveProject(new)
            response.id = new.id
            Task { await indexProject(new.id) }
        case "project.update":
            guard let value = request.project else { throw HarnessError("Projeto inválido.") }
            if let field = value.jiraAcceptanceField, !field.isEmpty,
                field.range(of: #"^customfield_[0-9]+$"#, options: .regularExpression) == nil
            {
                throw HarnessError("O campo de critérios Jira deve usar o ID customfield_12345.")
            }
            guard !runs.contains(where: { $0.projectID == value.id && exclusiveOperations.contains($0.id) }) else {
                throw HarnessError("Aguarde a operação em andamento antes de alterar a política do projeto.")
            }
            let old = try project(value.id)
            guard value.path == old.path else { throw HarnessError("Recadastre a pasta para alterar o acesso.") }
            try saveProject(value)
            if old.validators != value.validators || old.allowedPaths != value.allowedPaths
                || old.lockedPaths != value.lockedPaths || old.disabledProviders != value.disabledProviders
                || old.requireStrongIsolation != value.requireStrongIsolation
            {
                for var affected in runs where affected.projectID == value.id && affected.state != .archived {
                    for i in affected.validations.indices
                    where !affected.runbook.validators(for: value).contains(affected.validations[i].validator) {
                        affected.validations[i].status = .stale
                    }
                    affected.humanReviewRevision = ""
                    affected.reviewRevision = ""
                    for i in affected.plan.indices
                    where ["validation", "review", "evidence"].contains(affected.plan[i].kind) {
                        affected.plan[i].status = .stale
                    }
                    if affected.state == .ready {
                        affected.state = .partial
                        affected.reason = "Política ou catálogo de comandos mudou. Revalide e revise o resultado."
                    }
                    try record(
                        affected, kind: "project.policy_revised",
                        message: "Política e catálogo do projeto revisados; evidências dependentes invalidadas.")
                    if affected.state.active
                        && (value.requireStrongIsolation || (value.disabledProviders ?? []).contains(affected.provider))
                    {
                        try await stopRun(affected.id, cancel: false)
                    }
                }
            }
        case "project.index": Task { await indexProject(request.id) }
        case "project.reauthorize":
            var value = try project(request.id)
            let observed = try await GitWorkspace.inspect(path: request.path, bookmark: request.project?.bookmark)
            value.path = observed.path
            value.bookmark = observed.bookmark
            value.head = observed.head
            value.branch = observed.branch
            value.remote = observed.remote
            try saveProject(value)
            Task { await indexProject(value.id) }
        case "providers.probe":
            providers = await ProviderGateway.probe(overrides: preferences.providers)
            response.snapshot = snapshot()
        case "preferences.save":
            guard var value = request.preferences else { throw HarnessError("Preferências inválidas") }
            value.concurrency = min(8, max(1, value.concurrency))
            value.contextBudget = max(1000, min(100000, value.contextBudget))
            value.extensions = preferences.extensions
            preferences = value
            try store.save(value, id: "global", table: "preferences")
            schedule()
        case "queue.toggle":
            preferences.queuePaused.toggle()
            try store.save(preferences, id: "global", table: "preferences")
            schedule()
        case "runbook.save":
            guard var book = request.runbook else { throw HarnessError("Runbook inválido") }
            _ = try book.orderedSteps()
            book.version = (runbooks.first { $0.id == book.id }?.version ?? 0) + 1
            try store.execute(
                "INSERT INTO runbook_revisions(id,version,payload) VALUES(?,?,?)",
                [book.id, String(book.version), try Coding.string(book)])
            try store.save(book, id: book.id, table: "runbooks")
            if let i = runbooks.firstIndex(where: { $0.id == book.id }) {
                runbooks[i] = book
            } else {
                runbooks.append(book)
            }
        case "run.create": response.id = try await createRun(request)
        case "run.start", "run.resume":
            var value = try run(request.id)
            guard !value.state.active, jobs[value.id] == nil, value.state != .archived else {
                throw HarnessError("Esta run já está ativa ou foi arquivada.")
            }
            value.state = .queued
            value.reason = "Aguardando slot de execução"
            try record(value, kind: "run.queued", message: value.reason)
            schedule()
        case "run.approve":
            var value = try run(request.id)
            guard value.pack != nil, !value.state.active, value.state != .archived, jobs[value.id] == nil else {
                throw HarnessError("Prepare e inspecione o contexto antes de aprovar.")
            }
            if value.workflow != nil {
                let current = try await GitWorkspace.snapshot(path: value.workspace, base: value.baseSHA)
                guard current.revision == value.revision, value.pack?.revision == current.revision else {
                    try await reconcile(request.id)
                    var stale = try run(request.id)
                    invalidateProposal(&stale)
                    stale.contextApproved = false
                    stale.pack = nil
                    stale.state = .draft
                    stale.reason = "O código mudou desde a preparação. Prepare o contexto novamente."
                    try record(stale, kind: "context.stale", message: stale.reason)
                    throw HarnessError("SNAPSHOT_STALE: prepare e confira o contexto atualizado antes de autorizar.")
                }
                value = try run(request.id)
            }
            if value.workflow != nil && !value.contextApproved {
                value.contextApproved = true
                value.planApproved = false
            } else {
                if value.workflow != nil {
                    guard !(value.workflow?.proposal.isEmpty ?? true) else {
                        throw HarnessError("Aguarde a proposta fundamentada antes de aprovar a implementação.")
                    }
                    for i in value.plan.indices where value.plan[i].kind == "plan" { value.plan[i].status = .pass }
                }
                value.planApproved = true
                value.contextApproved = true
            }
            value.state = .queued
            try record(
                value,
                kind: value.planApproved ? "permission.plan_and_egress_approved" : "permission.investigation_approved",
                message:
                    "Plano revisão \(value.planRevision); payload \(value.pack?.hash ?? "") aprovado para \(value.provider.rawValue)."
            )
            schedule()
        case "run.pause", "run.cancel": try await stopRun(request.id, cancel: request.action == "run.cancel")
        case "run.archive":
            var value = try run(request.id)
            guard !value.state.active else { throw HarnessError("Pause a execução antes de arquivar.") }
            value.state = .archived
            try record(value, kind: "run.archived", message: "Run arquivada; worktree e evidências preservadas.")
        case "run.reconcile": try await reconcile(request.id)
        case "run.steer": try await steer(request)
        case "run.budget":
            var value = try run(request.id)
            guard request.number >= 1000, request.number <= 500000 else {
                throw HarnessError("Orçamento deve ficar entre 1.000 e 500.000 tokens.")
            }
            value.budget = request.number
            try record(
                value, kind: "budget.changed", message: "Teto alterado explicitamente para \(value.budget) tokens.")
        case "run.provider":
            var value = try run(request.id)
            guard !value.state.active, let provider = ProviderKind(rawValue: request.text) else {
                throw HarnessError("Pause a run antes de trocar o provider.")
            }
            value.provider = provider
            value.workflow?.proposal = ""
            if value.workflow != nil { value.planApproved = false }
            value.contextApproved = false
            value.state = .draft
            let affected = dependentSteps(
                in: value,
                roots: Set(
                    value.plan.filter { ["investigation", "plan", "implementation", "review"].contains($0.kind) }.map(
                        \.id)))
            for i in value.plan.indices where affected.contains(value.plan[i].id) { value.plan[i].status = .notRun }
            for i in value.validations.indices { value.validations[i].status = .stale }
            value.reviewRevision = ""
            value.humanReviewRevision = ""
            try record(
                value, kind: "provider.changed",
                message: "Próxima tentativa usará \(provider.rawValue). O contexto exige nova prévia.")
        case "run.fork":
            let source = try run(request.id)
            var copy = Run()
            copy.projectID = source.projectID
            copy.title = request.text.isEmpty ? source.title + " · alternativa" : request.text
            copy.source = source.source
            if let original = source.workflow {
                var workflow = CardWorkflow()
                workflow.kind = original.kind
                workflow.reference = original.reference
                copy.workflow = workflow
            }
            copy.criteria = source.criteria
            copy.runbook = source.runbook
            copy.mode = source.mode
            copy.provider = source.provider
            copy.plan = source.plan
            copy.scope = source.scope
            copy.baseSHA = source.baseSHA
            copy.forkOf = source.id
            copy.state = .queued
            copy.budget = source.budget
            for i in copy.plan.indices { copy.plan[i].status = .notRun }
            for i in copy.criteria.indices {
                copy.criteria[i].state = "UNVERIFIED"
                copy.criteria[i].evidence = []
            }
            copy.pins = source.pins
            copy.exclusions = source.exclusions
            copy.lockedPaths = source.lockedPaths
            try record(
                copy, kind: "run.forked",
                message: "Abordagem independente a partir de \(source.id). Base \(source.baseSHA).")
            response.id = copy.id
            schedule()
        case "run.select":
            let value = try run(request.id)
            try record(
                value, kind: "decision.approach_selected",
                message: "Abordagem escolhida pelo usuário. Nenhum merge foi executado.")
        case "context.update": try await updateContext(request)
        case "plan.save": try savePlan(request)
        case "step.skip": try skipStep(request)
        case "step.retry": try retryStep(request)
        case "validation.run":
            var value = try run(request.id)
            guard !value.state.active, jobs[value.id] == nil else {
                throw HarnessError("Aguarde ou pause a tentativa ativa.")
            }
            value.state = .running
            value.reason = "Executando validação solicitada pelo usuário."
            try record(value, kind: "validation.suite_started", message: value.reason)
            jobs[value.id] = Task {
                await validateRun(value.id, validatorID: request.relatedID)
                if let current = try? run(value.id), current.state == .running { try? finalize(value.id) }
                finishJob(value.id)
            }
        case "review.resolve": try resolveFinding(request)
        case "review.accept":
            guard !(try run(request.id)).state.active, jobs[request.id] == nil else {
                throw HarnessError("Aguarde o término da execução antes de confirmar a revisão.")
            }
            try await reconcile(request.id)
            var value = try run(request.id)
            value.humanReviewRevision = value.revision
            if request.flag {
                for i in value.criteria.indices {
                    value.criteria[i].state = "SATISFIED"
                    value.criteria[i].evidence = ["human-review:\(value.revision)"]
                }
            }
            try record(
                value, kind: "review.human_confirmed",
                message: "Revisão humana confirmada no snapshot \(value.revision).")
            try finalize(request.id)
        case "extension.save": response.id = try saveExtension(request)
        case "extension.discover":
            response.payload = try Coding.decode(
                JSONValue.self, from: Coding.encode(await discoverExtension(request.id)))
        case "extension.select":
            var value = try run(request.id)
            guard !value.state.active else { throw HarnessError("Pause a tarefa antes de ajustar capacidades.") }
            var overrides = value.extensionOverrides ?? [:]
            overrides[request.relatedID] = request.flag
            value.extensionOverrides = overrides
            value.contextApproved = false
            value.pack = nil
            invalidateProposal(&value)
            value.state = .draft
            try record(
                value, kind: "extension.selection_changed", message: "Seleção atualizada. Prepare o contexto novamente."
            )
        case "extension.resolve":
            var value = try run(request.id)
            guard !value.state.active, !extensionBusy.contains(value.id), !request.text.isEmpty,
                let index = value.extensionInvocations?.firstIndex(where: { $0.id == request.relatedID }),
                ["RUNNING", "UNKNOWN"].contains(value.extensionInvocations?[index].state ?? "")
            else {
                throw HarnessError(
                    "Confira o destino e descreva a resolução de uma chamada incerta com a tarefa pausada.")
            }
            value.extensionInvocations?[index].state = "RESOLVED"
            try record(value, kind: "extension.call_resolved", message: request.text)
        case "extension.call":
            let value = try run(request.id)
            guard !value.state.active else {
                throw HarnessError("Aguarde a tentativa ativa para executar manualmente.")
            }
            response.payload = try await invokeExtension(
                runID: request.id, stage: value.currentStep?.kind ?? "review", input: request.payload ?? .null)
        case "evidence.register":
            let previous = try run(request.id)
            guard !previous.state.active else {
                throw HarnessError("Use a ferramenta da tentativa ativa ou pause a tarefa para importar pela CLI.")
            }
            try await reconcile(request.id)
            let item = try registerArtifact(
                runID: request.id, input: request.payload ?? .null, source: "CLI / Interface", localPath: true)
            response.id = item.id
        case "evidence.file": response.path = try artifactFile(runID: request.id, artifactID: request.relatedID).1.path
        case "evidence.share":
            var value = try run(request.id)
            guard !value.state.active,
                let index = value.evidenceArtifacts?.firstIndex(where: { $0.id == request.relatedID })
            else { throw HarnessError("Pause a tarefa para alterar o compartilhamento.") }
            value.evidenceArtifacts?[index].providerReadable = request.flag
            value.reviewRevision = ""
            value.humanReviewRevision = ""
            for i in value.plan.indices where value.plan[i].kind == "review" { value.plan[i].status = .notRun }
            if value.state == .ready { value.state = .partial }
            try record(
                value, kind: "evidence.sharing_changed",
                message: request.flag ? "Artefato liberado para o provider." : "Artefato restrito ao Harness.")
        case "scenario.record": try await recordScenario(request)
        case "evidence.media": response.path = try evidenceMedia(request)
        case "delivery.refresh": try await refreshDelivery(request.id)
        case "delivery.close": try await closeDelivery(request.id)
        case "evidence.export":
            response.path = try exportEvidence(request.id, options: request.exportOptions ?? EvidenceExportOptions())
        case "tokens.export": response.path = try exportTokens(request.id)
        case "approval.prepare": response.id = try await prepareAction(request)
        case "approval.decide": try await decideAction(request)
        case "approval.reconcile": try await reconcileAction(request)
        case "source.fetch":
            let preview = try await fetchSource(request)
            response.sourcePreview = preview
            response.text = preview.intent.text
        case "integration.save": try await saveIntegration(request)
        case "tool.call":
            response.text = await handleTool(
                runID: request.id, name: request.text,
                arguments: request.payload
                    ?? .object([
                        "path": .string(request.path), "content": .string(request.arguments.first ?? ""),
                        "expectedHash": .string(request.arguments.dropFirst().first ?? ""),
                        "query": .string(request.path),
                        "validatorID": .string(request.relatedID),
                    ]))
        case "diagnostics":
            response.text =
                "Harness 1.0.0\nmacOS \(ProcessInfo.processInfo.operatingSystemVersionString)\nSQLite/FTS5 disponível\nXPC local autenticado\n\(providers.map { "\($0.kind.rawValue): \($0.version) · \($0.state)" }.joined(separator: "\n"))\nSlots em uso: \(jobs.count) / \(preferences.concurrency)\nRuns com slot: \(jobs.keys.sorted().joined(separator: ", "))\nSem telemetria. Parsers Tree-sitter fixados por revisão, com fallback lexical."
        case "attempt.payload":
            let value = try run(request.id)
            guard let attempt = value.attempts.first(where: { $0.id == request.relatedID }),
                let hash = attempt.promptHash, hash.count == 64, hash.allSatisfy({ $0.isHexDigit })
            else { throw HarnessError("Payload indisponível para esta tentativa anterior.") }
            let data = try Data(contentsOf: paths.artifacts.appendingPathComponent(hash))
            guard Coding.hash(data) == hash else { throw HarnessError("Falha na integridade do artefato.") }
            response.text = String(decoding: data, as: UTF8.self)
        default: throw HarnessError("Comando não suportado: \(request.action)")
        }
        return response
    }
    func indexProject(_ id: String) async {
        do {
            var value = try project(id)
            guard value.indexState != "INDEXING" else { return }
            value.indexState = "INDEXING"
            try saveProject(value)
            if let bookmark = value.bookmark {
                var stale = false
                let resolved = try URL(
                    resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting], relativeTo: nil,
                    bookmarkDataIsStale: &stale)
                guard !stale, resolved.standardizedFileURL.path == value.path else {
                    throw HarnessError(
                        "ACCESS_REQUIRED: pasta movida ou bookmark obsoleto. Renove o acesso ao projeto.")
                }
            }
            let indexed = try await IndexEngine.stream(project: value) { [weak self] items in
                try await self?.storeIndexBatch(items, projectID: id)
            }
            try store.pruneIndex(projectID: id, keeping: Set(indexed))
            value = try project(id)
            value.indexedFiles = indexed.count
            value.indexedAt = Date()
            value.head = try await GitWorkspace.git(["rev-parse", "HEAD"], at: value.path).trimmingCharacters(
                in: .whitespacesAndNewlines)
            value.branch = try await GitWorkspace.git(["branch", "--show-current"], at: value.path).trimmingCharacters(
                in: .whitespacesAndNewlines)
            value.dirty = !(try await GitWorkspace.git(["status", "--porcelain=v1"], at: value.path)).isEmpty
            let errors = try store.parseErrorCount(projectID: id)
            value.indexState = errors == 0 ? "READY" : "DEGRADED"
            value.indexMessage =
                "FTS5 + Tree-sitter: TS/TSX, JS/JSX, Swift, Python e Go. \(errors) arquivos com árvore parcial. Demais linguagens: busca lexical."
            try saveProject(value)
        } catch {
            if var value = try? project(id) {
                value.indexState = "ERROR"
                value.indexMessage = error.localizedDescription
                try? saveProject(value)
            }
        }
    }
    func storeIndexBatch(_ items: [ContextItem], projectID: String) throws {
        try store.index(items, projectID: projectID)
    }
    public func maintenance() async {
        guard !shuttingDown else { return }
        for value in runs
        where !value.workspace.isEmpty && !value.state.active && value.state != .archived
            && !exclusiveOperations.contains(value.id)
        {
            try? await reconcile(value.id)
        }
        if Date().timeIntervalSince(lastIndexCheck) > 30 {
            lastIndexCheck = Date()
            for project in projects where project.indexState != "INDEXING" { await indexProject(project.id) }
        }
        schedule()
    }
}
