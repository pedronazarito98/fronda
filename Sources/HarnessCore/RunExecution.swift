import Foundation
import HarnessDomain
import HarnessInfrastructure
import HarnessProviders

extension RunCoordinator {
    func createRun(_ request: RPCRequest) async throws -> String {
        guard var value = request.run, !value.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HarnessError("Descreva o objetivo da run.")
        }
        let project = try project(value.projectID)
        value.id = makeID()
        value.title = ContextFirewall.redact(value.title)
        value.source.text = ContextFirewall.redact(value.source.text)
        value.baseSHA = try await GitWorkspace.git(["rev-parse", "HEAD"], at: project.path).trimmingCharacters(
            in: .whitespacesAndNewlines)
        value.plan = try value.runbook.orderedSteps()
        if let kind = value.runbook.workKind {
            var workflow = CardWorkflow()
            workflow.kind = kind
            workflow.reference = value.source.issueKey ?? value.source.sourceURL
            value.workflow = workflow
        } else {
            value.workflow = nil
        }
        for i in value.plan.indices { value.plan[i].status = .notRun }
        if value.criteria.isEmpty {
            value.criteria = [Criterion(text: "Objetivo atendido e revisado com evidência no snapshot vigente.")]
        }
        value.state = .queued
        value.budget = max(1000, value.budget)
        value.workspace = ""
        value.sequence = 0
        value.planApproved = false
        value.contextApproved = false
        value.extensionBindings = nil
        value.extensionInvocations = nil
        value.evidenceArtifacts = nil
        value.attempts = []
        value.validations = []
        value.approvals = []
        value.tokens = []
        value.pack = nil
        value.findings = []
        value.reviewRevision = ""
        value.humanReviewRevision = ""
        value.revision = ""
        value.changedFiles = []
        value.diff = ""
        value.report = ""
        for i in value.criteria.indices {
            value.criteria[i].state = "UNVERIFIED"
            value.criteria[i].evidence = []
        }
        try record(
            value, kind: "run.created",
            message: "Objetivo capturado. Base \(value.baseSHA). O checkout original será preservado.")
        schedule()
        return value.id
    }
    func schedule() {
        guard providersReady, !shuttingDown, !preferences.queuePaused else { return }
        for value in runs.filter({ $0.state == .queued }).sorted(by: {
            $0.priority == $1.priority ? $0.createdAt < $1.createdAt : $0.priority > $1.priority
        }) {
            guard jobs.count < preferences.concurrency else { break }
            guard jobs[value.id] == nil, !extensionBusy.contains(value.id) else { continue }
            let active = runs.filter { jobs[$0.id] != nil }
            guard active.filter({ $0.projectID == value.projectID }).count < preferences.perProjectConcurrency,
                active.filter({ $0.provider == value.provider }).count < preferences.perProviderConcurrency
            else { continue }
            var scheduled = value
            scheduled.state = .preparing
            do { try record(scheduled, kind: "scheduler.acquired", message: "Slot adquirido para esta run.") } catch {
                continue
            }
            jobs[value.id] = Task { [weak self] in
                await self?.execute(value.id)
            }
        }
    }
    func finishJob(_ id: String) {
        jobs[id] = nil
        codexSessions[id] = nil
        claudeSessions[id] = nil
        let connections = extensionConnections.filter { $0.key.hasPrefix(id + ":") }
        for key in connections.keys { extensionConnections.removeValue(forKey: key) }
        Task { for connection in connections.values { await connection.close() } }
        schedule()
    }
    func execute(_ id: String) async {
        defer { finishJob(id) }
        do {
            var value = try run(id)
            let project = try project(value.projectID)
            if !value.contextApproved || (value.workflow == nil && !value.planApproved) || value.workspace.isEmpty {
                try await prepareRun(id)
                return
            }
            guard !project.requireStrongIsolation else {
                throw HarnessError(
                    "BLOCKED: esta política exige isolamento forte, não comprovado para o processo do provider.")
            }
            guard !(project.disabledProviders ?? []).contains(value.provider) else {
                throw HarnessError("POLICY_DENIED: provider desativado para este projeto.")
            }
            let current = try await GitWorkspace.snapshot(path: value.workspace, base: value.baseSHA)
            guard current.revision == value.revision else {
                try await reconcile(id)
                var changed = try run(id)
                invalidateProposal(&changed)
                try record(changed, kind: "plan.invalidated", message: "Mudança externa exige revisão da proposta.")
                try await prepareRun(id)
                return
            }
            guard value.reportedTokens < value.budget else {
                throw HarnessError("Orçamento esgotado. Ajuste o teto para iniciar outra tentativa.")
            }
            value = try run(id)
            value.state = .running
            value.reason = "Executando etapas pendentes do plano aprovado"
            try record(value, kind: "run.started", message: "Execução iniciada em \(value.workspace).")
            var plan = value.runbook
            plan.steps = value.plan
            for step in try plan.orderedSteps() {
                try Task.checkCancellation()
                value = try run(id)
                guard value.state.active else { return }
                guard let current = value.plan.first(where: { $0.id == step.id }),
                    ![.pass, .skipped].contains(current.status)
                else { continue }
                if try !shouldExecute(step, run: value) { continue }
                let selectedKind = step.provider ?? value.provider
                guard !(project.disabledProviders ?? []).contains(selectedKind) else {
                    throw HarnessError("Provider desta etapa desativado no projeto.")
                }
                let selected = providers.first { $0.kind == selectedKind } ?? ProviderInfo(kind: selectedKind)
                try await executeStep(step, runID: id, provider: selected)
                if !(try run(id)).state.active { return }
                if try run(id).approvals.contains(where: { $0.state == "PREPARED" }) {
                    value = try run(id)
                    value.state = .waitingUser
                    value.reason = "Uma alteração requer sua decisão."
                    try record(value, kind: "run.waiting_user", message: value.reason)
                    return
                }
            }
            try finalize(id)
        } catch is CancellationError {
            if var value = try? run(id), value.state.active {
                value.state = .paused
                value.reason = "Interrompida em checkpoint lógico."
                try? record(value, kind: "run.paused", message: value.reason)
            }
        } catch {
            if var value = try? run(id), value.state != .cancelled, value.state != .paused {
                let budgetExhausted = value.state == .blocked && value.reason.contains("Orçamento")
                value.state = .blocked
                if !budgetExhausted { value.reason = ContextFirewall.redact(error.localizedDescription) }
                for i in value.attempts.indices where value.attempts[i].status == "RUNNING" {
                    value.attempts[i].status = "FAILED"
                    value.attempts[i].finishedAt = Date()
                }
                try? record(value, kind: "run.blocked", message: value.reason)
            }
        }
    }
    func prepareRun(_ id: String) async throws {
        var value = try run(id)
        var project = try project(value.projectID)
        value.state = .preparing
        try record(value, kind: "run.preparing", message: "Preparando worktree, plano e contexto.")
        if value.workspace.isEmpty {
            let workspace = try await GitWorkspace.acquire(project: project, run: value, paths: paths)
            value = try run(id)
            value.workspace = workspace.0
            value.branch = workspace.1
            if value.mode.writes { try store.lease(path: workspace.0, runID: value.id, base: value.baseSHA) }
            try record(value, kind: "workspace.leased", message: "Workspace \(workspace.0); base \(value.baseSHA).")
        }
        try Task.checkCancellation()
        value = try run(id)
        let git = try await GitWorkspace.snapshot(path: value.workspace, base: value.baseSHA)
        project.path = value.workspace
        let candidates = try await IndexEngine.scan(
            project: project, query: value.title + " " + value.source.text, pins: value.pins)
        let items =
            try await ContextRelations.history(candidates, projectPath: project.path)
            + AttachmentCompiler.compile(value.source.attachments)
        try Task.checkCancellation()
        value = try run(id)
        value.revision = git.revision
        value.diff = git.diff
        value.changedFiles = git.files
        value.extensionBindings = selectExtensions(for: value)
        let remaining = max(1000, value.budget - value.reportedTokens)
        value.pack = try ContextCompiler.compile(
            run: value, candidates: items, budget: min(preferences.contextBudget, remaining),
            validators: value.runbook.validators(for: project),
            weights: project.contextWeights ?? ContextRelations.defaultWeights)
        value.contextApproved = false
        value.state = .waitingUser
        value.reason =
            value.workflow == nil
            ? "Inspecione o contexto, o destino e o plano antes de executar."
            : "Revise o contexto e os executores antes da investigação em modo de leitura."
        for i in value.plan.indices
        where value.plan[i].kind == "context" || (value.workflow == nil && value.plan[i].kind == "plan") {
            value.plan[i].status = .pass
        }
        let hash = try paths.putArtifact(value.pack?.payload ?? "")
        try record(
            value, kind: "context.pack_compiled",
            message:
                "Pack v\(value.pack?.version ?? 1) · \(value.pack?.estimatedTokens ?? 0) tokens estimados · destino \(value.provider.rawValue).",
            artifact: hash)
    }
    func callProvider(_ id: String, provider: ProviderInfo, readOnly: Bool, prompt: String, stepID: String) async throws
        -> AgentOutcome
    {
        var value = try run(id)
        guard value.reportedTokens < value.budget else {
            throw HarnessError("Orçamento atingido antes da próxima etapa.")
        }
        let activeAttempts = runs.filter { $0.id != id }.flatMap(\.attempts).filter {
            $0.provider == provider.kind && $0.status == "RUNNING"
        }
        guard activeAttempts.count < preferences.perProviderConcurrency else {
            throw HarnessError("Executor ocupado. Retome quando houver um slot disponível.")
        }
        let stage = value.plan.first { $0.id == stepID }?.kind ?? "review"
        let prompt = prompt + (try extensionContext(value, stage: stage))
        guard (prompt.utf8.count + 3) / 4 <= max(1000, value.budget - value.reportedTokens) else {
            throw HarnessError("Capacidades e evidências excedem o orçamento restante.")
        }
        var attempt = Attempt()
        guard provider.state == "AVAILABLE" else {
            throw HarnessError(provider.detail.isEmpty ? "Provider indisponível." : provider.detail)
        }
        attempt.provider = provider.kind
        attempt.model = value.plan.first { $0.id == stepID }?.model
        attempt.packID = value.pack?.id ?? ""
        attempt.stepID = stepID
        attempt.promptHash = try paths.putArtifact(prompt)
        value.attempts.append(attempt)
        var estimate = TokenRecord()
        estimate.attemptID = attempt.id
        estimate.provider = provider.kind
        estimate.estimatedPackInput = (prompt.utf8.count + 3) / 4
        estimate.step = attempt.stepID
        value.tokens.append(estimate)
        try record(
            value, kind: "provider.attempt_started",
            message: "\(provider.kind.rawValue) · \(attempt.stepID); payload \(Coding.hash(prompt)).",
            artifact: paths.putArtifact(prompt))
        let attemptID = attempt.id
        let events: AgentEventHandler = { [weak self] kind, payload in
            await self?.providerEvent(id, attemptID: attemptID, kind: kind, payload: payload)
        }
        let tools: AgentToolHandler = { [weak self] name, args in
            guard let self else { return "ERROR: coordinator unavailable" }
            if readOnly && name == "harness_write_file" { return "ERROR: read-only attempt" }
            if readOnly && name == "harness_validate" {
                return "ERROR: validation is owned by the coordinator; inspect the supplied process evidence"
            }
            return await self.handleTool(runID: id, name: name, arguments: args)
        }
        let outcome: AgentOutcome
        if provider.kind == .codex {
            let session = CodexSession()
            codexSessions[id] = session
            outcome = try await session.run(
                binary: provider.path, run: value, prompt: prompt, readOnly: readOnly, selectedModel: attempt.model,
                onEvent: events, onTool: tools)
        } else {
            let session = ClaudeSession()
            claudeSessions[id] = session
            let directory = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
                .deletingLastPathComponent()
            let executable =
                directory.lastPathComponent == "MacOS"
                ? directory.deletingLastPathComponent().appendingPathComponent("Helpers/harness").path
                : directory.appendingPathComponent("HarnessCLI").path
            let config = try Coding.string(
                JSONValue.object([
                    "mcpServers": .object([
                        "harness": .object([
                            "command": .string(executable),
                            "args": .array([
                                .string("--root"), .string(paths.root.path), .string("mcp"), .string("--run"),
                                .string(id),
                            ]), "env": .object([:]),
                        ])
                    ])
                ]))
            outcome = try await session.run(
                binary: provider.path, run: value, prompt: prompt, mcpConfiguration: config, readOnly: readOnly,
                selectedModel: attempt.model, onEvent: events)
        }
        value = try run(id)
        if let index = value.attempts.firstIndex(where: { $0.id == attemptID }) {
            value.attempts[index].status = outcome.status.uppercased()
            value.attempts[index].sessionID = outcome.sessionID
            value.attempts[index].finishedAt = Date()
        }
        if var usage = outcome.usage, let index = value.tokens.firstIndex(where: { $0.attemptID == attemptID }) {
            usage.attemptID = attemptID
            usage.step = attempt.stepID
            usage.estimatedPackInput = estimate.estimatedPackInput
            value.tokens[index] = usage
        }
        try record(
            value, kind: "usage.reported",
            message:
                "Métrica \(outcome.usage?.source ?? "estimated") registrada sem somar estimativa ao consumo reportado.")
        return outcome
    }
    func providerEvent(_ id: String, attemptID: String, kind: String, payload: JSONValue) async {
        guard var value = try? run(id) else { return }
        if kind == "session.started", let index = value.attempts.firstIndex(where: { $0.id == attemptID }) {
            value.attempts[index].sessionID = payload["sessionID"].string
        }
        let previousTotal = value.reportedTokens
        if kind == "thread/tokenUsage/updated",
            let index = value.tokens.firstIndex(where: { $0.attemptID == attemptID })
        {
            let usage = payload["tokenUsage"]["total"]
            value.tokens[index].input = usage["inputTokens"].int
            value.tokens[index].output = usage["outputTokens"].int
            value.tokens[index].cachedInput = usage["cachedInputTokens"].int
            value.tokens[index].source = "reported"
        }
        let item = payload["item"]
        let description = [kind, item["type"].string, payload["message"].string].filter { !$0.isEmpty }.joined(
            separator: " · ")
        try? record(value, kind: "provider.\(kind)", message: description)
        value = (try? run(id)) ?? value
        if previousTotal < value.budget * 8 / 10 && value.reportedTokens >= value.budget * 8 / 10 {
            try? record(
                value, kind: "budget.warning",
                message: "80% do orçamento atingido; contexto opcional será reduzido na próxima compilação.")
        }
        value = (try? run(id)) ?? value
        if previousTotal < value.budget && value.reportedTokens >= value.budget {
            value.state = .blocked
            value.reason = "Orçamento de tokens atingido. Altere o teto explicitamente para retomar."
            try? record(value, kind: "budget.exhausted", message: value.reason)
            await codexSessions[id]?.interrupt()
            await claudeSessions[id]?.interrupt()
        }
    }
    func stopRun(_ id: String, cancel: Bool) async throws {
        var value = try run(id)
        value.state = cancel ? .cancelled : .paused
        value.reason =
            cancel
            ? "Cancelada pelo usuário. Evidências preservadas." : "Checkpoint lógico. Retomar cria uma nova tentativa."
        for i in value.attempts.indices where value.attempts[i].status == "RUNNING" {
            value.attempts[i].status = "INTERRUPTED"
            value.attempts[i].finishedAt = Date()
        }
        try record(value, kind: cancel ? "run.cancelled" : "run.paused", message: value.reason)
        jobs[id]?.cancel()
        extensionProcesses[id]?.stop()
        let connections = extensionConnections.filter { $0.key.hasPrefix(id + ":") }
        for key in connections.keys { extensionConnections.removeValue(forKey: key) }
        for connection in connections.values { await connection.close() }
        await codexSessions[id]?.interrupt()
        await claudeSessions[id]?.interrupt()
    }
    func steer(_ request: RPCRequest) async throws {
        guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HarnessError("Escreva a orientação.")
        }
        var value = try run(request.id)
        value.source.text += "\n\nOrientação \(Date().formatted()): \(ContextFirewall.redact(request.text))"
        value.planRevision += 1
        value.humanReviewRevision = ""
        value.reviewRevision = ""
        let roots = Set(
            value.plan.filter { step in
                if !request.relatedID.isEmpty { return step.id == request.relatedID }
                return step.kind == "implementation"
                    && (request.path.isEmpty || step.paths.isEmpty
                        || ContextFirewall.matches(request.path, patterns: step.paths))
            }.map(\.id))
        let affected = dependentSteps(in: value, roots: roots)
        for i in value.plan.indices where affected.contains(value.plan[i].id) && value.plan[i].status != .running {
            value.plan[i].status = .notRun
        }
        if value.plan.contains(where: { affected.contains($0.id) && $0.kind == "validation" }) {
            for i in value.validations.indices { value.validations[i].status = .stale }
        }
        try record(value, kind: "decision.steering", message: request.text)
        if let session = codexSessions[value.id], value.state.active {
            try await session.steer(request.text)
        } else {
            value = try run(request.id)
            invalidateProposal(&value)
            value.contextApproved = false
            value.state = .draft
            try record(value, kind: "context.invalidated", message: "Orientação exige nova compilação de contexto.")
        }
    }
}
