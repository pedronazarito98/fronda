import Foundation
import HarnessDomain
import HarnessInfrastructure

extension RunCoordinator {
    func reconcile(_ id: String) async throws {
        let previous = try run(id)
        guard !previous.workspace.isEmpty else { return }
        let snapshot = try await GitWorkspace.snapshot(path: previous.workspace, base: previous.baseSHA)
        var value = try run(id)
        guard snapshot.revision != value.revision else { return }
        value.revision = snapshot.revision
        value.diff = snapshot.diff
        value.changedFiles = snapshot.files.map { file in
            var item = file
            item.linkedCriteria = previous.changedFiles.first(where: { $0.path == file.path })?.linkedCriteria ?? []
            return item
        }
        for i in value.validations.indices where value.validations[i].revision != value.revision {
            value.validations[i].status = .stale
        }
        value.humanReviewRevision = ""
        value.reviewRevision = ""
        let roots = Set(
            value.plan.filter { step in
                ["validation", "verification", "review"].contains(step.kind)
                    && (step.paths.isEmpty
                        || snapshot.files.contains(where: { file in
                            ContextFirewall.matches(file.path, patterns: step.paths)
                        }))
            }.map(\.id))
        let affected = dependentSteps(in: value, roots: roots)
        for i in value.plan.indices where affected.contains(value.plan[i].id) { value.plan[i].status = .stale }
        for i in value.criteria.indices { value.criteria[i].state = "UNVERIFIED" }
        value.findings.removeAll { $0.author == "Scope Guard" }
        value.findings += PolicyEngine.findings(run: value, project: try project(value.projectID))
        if value.state == .ready {
            value.state = .partial
            value.reason = "Arquivos mudaram após a validação. Revalide este snapshot."
        }
        try record(
            value, kind: "workspace.reconciled",
            message: "\(value.changedFiles.count) arquivos alterados; resultados anteriores marcados como obsoletos.",
            artifact: paths.putArtifact(value.diff))
    }
    func validateRun(_ id: String, validatorID: String = "") async {
        do {
            let value = try run(id)
            let project = try project(value.projectID)
            guard !value.workspace.isEmpty else { throw HarnessError("Prepare a worktree antes de validar.") }
            for validator in value.runbook.validators(for: project)
            where validatorID.isEmpty || validator.id == validatorID {
                try Task.checkCancellation()
                _ = await validate(id, validator: validator)
            }
            try await reconcile(id)
            var updated = try run(id)
            let mandatory = updated.runbook.validators(for: try self.project(updated.projectID)).filter(\.required)
            let gatesPass =
                !mandatory.isEmpty
                && mandatory.allSatisfy { command in
                    updated.validations.contains {
                        $0.validator == command && $0.status == .pass && $0.exitCode == 0
                            && $0.revision == updated.revision
                    }
                }
            for i in updated.plan.indices where updated.plan[i].kind == "validation" {
                updated.plan[i].status = gatesPass ? .pass : .blocked
            }
            try record(
                updated, kind: "validation.suite_finished",
                message: "Resultados derivados dos processos e do snapshot observado.")
            if !updated.state.active { try finalize(id) }
        } catch {
            if let value = try? run(id) {
                try? record(value, kind: "validation.blocked", message: error.localizedDescription)
            }
        }
    }
    func validate(_ id: String, validator: Validator) async -> ValidationResult {
        var result = ValidationResult()
        result.validator = validator
        do {
            var value = try run(id)
            try PolicyEngine.approveValidator(validator, run: value)
            let before = try await GitWorkspace.snapshot(path: value.workspace, base: value.baseSHA)
            result.revision = before.revision
            result.status = .running
            result.environment = ["cwd": value.workspace, "PATH": RunningProcess.environment["PATH"] ?? ""]
            value = try run(id)
            value.validations.removeAll { $0.validator.id == validator.id }
            value.validations.append(result)
            try record(value, kind: "validation.started", message: validator.displayCommand)
            let process = try await ProcessRunner.run(
                validator.executable, validator.arguments, cwd: value.workspace,
                timeout: max(1, min(3600, validator.timeoutSeconds)))
            result.exitCode = process.exitCode
            result.duration = process.duration
            result.output = String(process.output.suffix(100_000))
            result.artifactHash = try paths.putArtifact(process.output)
            result.status = process.timedOut ? .blocked : (process.exitCode == 0 ? .pass : .fail)
            let after = try await GitWorkspace.snapshot(path: value.workspace, base: value.baseSHA)
            if after.revision != before.revision { result.status = .stale }
            let currentRun = try run(id)
            let currentProject = try project(value.projectID)
            if !currentRun.runbook.validators(for: currentProject).contains(validator) { result.status = .stale }
            if Task.isCancelled {
                result.status = .blocked
                result.output += "\nExecução interrompida pelo usuário."
            }
        } catch {
            result.status = .blocked
            result.output = ContextFirewall.redact(error.localizedDescription)
        }
        if var value = try? run(id) {
            value.validations.removeAll { $0.validator.id == validator.id }
            value.validations.append(result)
            try? record(
                value, kind: "validation.finished",
                message:
                    "\(validator.name): \(result.status.rawValue) · exit \(result.exitCode.map(String.init) ?? "não observado")",
                artifact: result.artifactHash)
        }
        return result
    }
    func finalize(_ id: String) throws {
        var value = try run(id)
        let project = try project(value.projectID)
        let mandatory = value.runbook.validators(for: project).filter(\.required)
        let gatesPass =
            !value.revision.isEmpty && !mandatory.isEmpty
            && mandatory.allSatisfy { command in
                value.validations.contains {
                    $0.validator == command && $0.status == .pass && $0.exitCode == 0 && $0.revision == value.revision
                }
            }
        let reviewed =
            !value.revision.isEmpty && value.reviewRevision == value.revision
            && value.humanReviewRevision == value.revision
        let scopeClean = value.findings.allSatisfy { !["OPEN", "ACCEPTED_RISK"].contains($0.state) }
        let criteriaLinked =
            !value.criteria.isEmpty && value.criteria.allSatisfy { $0.state == "SATISFIED" && !$0.evidence.isEmpty }
        let criterionIDs = Set(value.criteria.map(\.id))
        let traced = value.changedFiles.allSatisfy {
            !$0.linkedCriteria.isEmpty && Set($0.linkedCriteria).isSubset(of: criterionIDs)
        }
        // Evidence is derived here; all other stages need an observed completion or a valid conditional skip.
        let stagesComplete =
            !value.plan.isEmpty
            && value.plan.filter { $0.kind != "evidence" }.allSatisfy { step in
                if step.status == .pass { return true }
                guard step.status == .skipped else { return false }
                let dependencies = value.plan.filter { step.dependencies.contains($0.id) }
                guard dependencies.count == Set(step.dependencies).count,
                    !dependencies.contains(where: { [.notRun, .running, .stale].contains($0.status) })
                else { return false }
                switch step.condition {
                case "on_pass": return !dependencies.allSatisfy { $0.status == .pass }
                case "on_failure": return !dependencies.contains { [.fail, .blocked].contains($0.status) }
                case "has_changes": return value.changedFiles.isEmpty
                default: return false
                }
            }
        let approved = value.planApproved && value.contextApproved
        let complete =
            gatesPass && reviewed && scopeClean && criteriaLinked && traced && stagesComplete && approved
            && value.workflowEvidenceComplete
        value.state = complete ? .ready : .partial
        var reasons = [String]()
        if !value.workflowEvidenceComplete {
            reasons.append("reprodução ou conferência de cenário pendente no snapshot vigente")
        }
        if !gatesPass { reasons.append("gates obrigatórios sem PASS no snapshot vigente") }
        if !reviewed { reasons.append("revisão independente ou humana pendente") }
        if !scopeClean { reasons.append("achados em aberto") }
        if !stagesComplete { reasons.append("etapas obrigatórias sem conclusão") }
        if !approved { reasons.append("plano ou contexto sem aprovação") }
        if !criteriaLinked || !traced { reasons.append("critérios ou arquivos sem vínculo de evidência") }
        value.reason =
            complete
            ? "Gates, revisão, escopo e critérios confirmados no mesmo snapshot." : reasons.joined(separator: "; ")
        for i in value.plan.indices where value.plan[i].kind == "evidence" {
            value.plan[i].status = complete ? .pass : .blocked
        }
        try record(value, kind: complete ? "run.ready" : "run.partial", message: value.reason)
    }
    func resolveFinding(_ request: RPCRequest) throws {
        var value = try run(request.id)
        guard !request.text.isEmpty else { throw HarnessError("Registre a justificativa da resolução.") }
        guard let index = value.findings.firstIndex(where: { $0.id == request.relatedID }) else {
            throw HarnessError("Achado não encontrado.")
        }
        value.findings[index].state = request.flag ? "ACCEPTED_RISK" : "FIXED"
        value.findings[index].resolution = request.text
        try record(value, kind: "review.finding_resolved", message: request.text)
    }
    func updateContext(_ request: RPCRequest) async throws {
        var value = try run(request.id)
        guard !value.state.active else { throw HarnessError("Pause a run para alterar o contexto enviado.") }
        switch request.text {
        case "pin":
            if value.pins.contains(request.path) {
                value.pins.removeAll { $0 == request.path }
            } else {
                value.pins.append(request.path)
                value.exclusions.removeAll { $0 == request.path }
            }
        case "exclude":
            guard request.path != "AGENTS.md" else {
                throw HarnessError(
                    "As regras obrigatórias do projeto permanecem no contexto. Altere as regras no projeto para revisar esse contrato."
                )
            }
            if value.exclusions.contains(request.path) {
                value.exclusions.removeAll { $0 == request.path }
            } else {
                value.exclusions.append(request.path)
                value.pins.removeAll { $0 == request.path }
            }
        case "lock":
            if value.lockedPaths.contains(request.path) {
                value.lockedPaths.removeAll { $0 == request.path }
            } else {
                value.lockedPaths.append(request.path)
            }
        default: throw HarnessError("Ação de contexto inválida")
        }
        value.contextApproved = false
        invalidateProposal(&value)
        try record(value, kind: "context.selection_changed", message: "\(request.text): \(request.path)")
        try await prepareRun(value.id)
    }
    func savePlan(_ request: RPCRequest) throws {
        var value = try run(request.id)
        guard !value.state.active, let edited = request.run else {
            throw HarnessError("Pause a execução para editar o plano.")
        }
        var book = value.runbook
        book.steps = edited.plan
        _ = try book.orderedSteps()
        let broadChange = value.criteria.map(\.text) != edited.criteria.map(\.text) || value.scope != edited.scope
        let changed = Set(
            edited.plan.filter { step in value.plan.first(where: { $0.id == step.id }) != step }.map(\.id))
        value.plan = edited.plan
        let affected = dependentSteps(in: value, roots: broadChange ? Set(value.plan.map(\.id)) : changed)
        for i in value.plan.indices where affected.contains(value.plan[i].id) { value.plan[i].status = .notRun }
        value.criteria = edited.criteria
        value.scope = edited.scope
        value.budget = max(1000, edited.budget)
        value.planRevision += 1
        value.planApproved = false
        invalidateProposal(&value)
        value.contextApproved = false
        value.state = .draft
        if value.plan.contains(where: { affected.contains($0.id) && $0.kind == "validation" }) {
            for i in value.validations.indices { value.validations[i].status = .stale }
        }
        if value.plan.contains(where: { affected.contains($0.id) && $0.kind == "review" }) {
            value.reviewRevision = ""
            value.humanReviewRevision = ""
        }
        try record(
            value, kind: "plan.revised",
            message: "Plano revisão \(value.planRevision) salvo; etapas dependentes requerem nova evidência.")
    }
    func skipStep(_ request: RPCRequest) throws {
        guard !request.text.isEmpty else { throw HarnessError("Pular uma etapa exige justificativa.") }
        var value = try run(request.id)
        guard let index = value.plan.firstIndex(where: { $0.id == request.relatedID }), !value.state.active else {
            throw HarnessError("Etapa indisponível ou run ativa.")
        }
        value.plan[index].status = .skipped
        value.reason = "Exceção: \(request.text)"
        value.state = .partial
        try record(value, kind: "step.skipped", message: request.text)
    }
}
