import Foundation
import HarnessDomain
import HarnessInfrastructure
import HarnessProviders

extension RunCoordinator {
    func shouldExecute(_ step: RunbookStep, run value: Run) throws -> Bool {
        let dependencies = value.plan.filter { step.dependencies.contains($0.id) }
        guard !dependencies.contains(where: { [.notRun, .running, .stale].contains($0.status) }) else {
            throw HarnessError("Etapa \(step.title) aguarda suas dependências.")
        }
        let selected: Bool
        switch step.condition {
        case "always": selected = true
        case "on_pass": selected = dependencies.allSatisfy { $0.status == .pass }
        case "on_failure": selected = dependencies.contains { [.fail, .blocked].contains($0.status) }
        case "has_changes": selected = !value.changedFiles.isEmpty
        default: throw HarnessError("Condição não suportada: \(step.condition)")
        }
        if !selected {
            try setStep(step.id, runID: value.id, status: .skipped, message: "Condição \(step.condition) não atendida.")
        }
        return selected
    }

    func setStep(_ stepID: String, runID: String, status: GateStatus, message: String) throws {
        var value = try run(runID)
        guard let offset = value.plan.firstIndex(where: { $0.id == stepID }) else {
            throw HarnessError("Etapa inexistente.")
        }
        value.plan[offset].status = status
        try record(
            value, kind: "step.\(status.rawValue.lowercased())", message: "\(value.plan[offset].title): \(message)")
    }

    func executeStep(_ step: RunbookStep, runID id: String, provider: ProviderInfo) async throws {
        var value = try run(id)
        switch step.kind {
        case "investigation":
            try await prepareProposal(step, runID: id, provider: provider, isPlan: false)
        case "plan" where value.workflow != nil:
            if value.workflow?.proposal.isEmpty == true {
                try await prepareProposal(step, runID: id, provider: provider, isPlan: true)
            }
            value = try run(id)
            if !value.planApproved {
                value.state = .waitingUser
                value.reason = "Diagnóstico e plano disponíveis. Aprove a implementação para continuar."
                try record(value, kind: "plan.awaiting_approval", message: value.reason)
            }
        case "reproduction":
            try await captureScenarioIfAvailable(step, runID: id, provider: provider)
            value = try run(id)
            let reproduced =
                value.workflow?.observations.contains {
                    $0.phase == .before && $0.status == .pass && $0.revision == value.revision
                } == true
            try await waitForScenario(step, runID: id, satisfied: reproduced)
        case "verification":
            try await captureScenarioIfAvailable(step, runID: id, provider: provider)
            value = try run(id)
            try await waitForScenario(step, runID: id, satisfied: value.workflowEvidenceComplete)
        case "context", "plan":
            guard value.planApproved && value.contextApproved else {
                throw HarnessError("Plano e contexto precisam de aprovação.")
            }
            try setStep(step.id, runID: id, status: .pass, message: "Revisão aprovada pelo usuário.")
        case "implementation":
            guard value.planApproved else { throw HarnessError("A implementação exige aprovação do plano.") }
            let failures = value.attempts.filter {
                $0.stepID == step.id && ["FAILED", "INTERRUPTED_UNKNOWN"].contains($0.status)
            }.count
            guard failures <= value.runbook.retries else {
                throw HarnessError("Limite de retries da etapa atingido. Revise o plano ou bifurque a abordagem.")
            }
            try setStep(step.id, runID: id, status: .running, message: "Provider iniciado.")
            let prompt =
                (value.pack?.payload ?? "")
                + "\nApproved proposal: \(value.workflow?.proposal ?? "")\nCurrent step: \(step.title). Step criteria: \(step.criteria.joined(separator: ", ")). Paths: \(step.paths.joined(separator: ", "))."
            let outcome = try await callProvider(
                id, provider: provider, readOnly: !value.mode.writes, prompt: prompt, stepID: step.id)
            try Task.checkCancellation()
            value = try run(id)
            value.report = outcome.text
            try record(
                value, kind: "provider.result", message: "Tentativa terminou: \(outcome.status).",
                artifact: paths.putArtifact(outcome.text))
            try await reconcile(id)
            try setStep(
                step.id, runID: id, status: outcome.status == "completed" ? .pass : .fail, message: outcome.status)
            guard outcome.status == "completed" else {
                throw HarnessError("Provider não concluiu a etapa. Consulte a atividade e tente novamente.")
            }
        case "validation":
            try setStep(step.id, runID: id, status: .running, message: "Executando catálogo aprovado.")
            await validateRun(id)
        case "review":
            try setStep(step.id, runID: id, status: .running, message: "Tentativa independente, somente leitura.")
            let diffLimit = max(1000, preferences.contextBudget * 2)
            let reviewDiff = String(value.diff.prefix(diffLimit))
            let prompt = """
                Review independently in read-only mode. Do not modify files or run commands. Use supplied evidence, Harness evidence tools, and authorized read-only capabilities. Inspect shared images/video frames before visual conclusions. Return a concise pt-BR review of correctness, scope, acceptance criteria and gaps. Distinguish findings from passed checks. Do not claim PASS without process evidence.
                Objective: \(value.title)
                Criteria: \(value.criteria.map(\.text).joined(separator: "; "))
                Approved proposal: \(value.workflow?.proposal ?? "")
                Observed scenarios: \(try Coding.string(value.workflow?.observations ?? []))
                Snapshot: \(value.revision)
                Changed paths: \(value.changedFiles.map(\.path).joined(separator: ", "))
                Diff excerpt (\(reviewDiff.utf8.count) of \(value.diff.utf8.count) bytes; use harness_read_file/search for omitted details): \(reviewDiff)
                Validation: \(value.validations.map { "\($0.validator.name): \($0.status.rawValue) exit \($0.exitCode.map(String.init) ?? "unobserved") snapshot \($0.revision)\n\($0.output.prefix(2000))" }.joined(separator: "\n"))
                """
            let reviewedRevision = value.revision
            let review = try await callProvider(id, provider: provider, readOnly: true, prompt: prompt, stepID: step.id)
            try Task.checkCancellation()
            try await reconcile(id)
            value = try run(id)
            guard review.status == "completed", reviewedRevision == value.revision else {
                try setStep(step.id, runID: id, status: .stale, message: "Revisão interrompida ou snapshot alterado.")
                return
            }
            value.reviewRevision = value.revision
            var finding = ReviewFinding()
            finding.title = "Parecer independente de \(provider.kind.rawValue)"
            finding.author = provider.kind.rawValue
            finding.evidence = review.text
            finding.revision = value.revision
            value.findings.append(finding)
            try record(
                value, kind: "review.completed", message: "Parecer independente disponível para revisão humana.",
                artifact: paths.putArtifact(review.text))
            try setStep(step.id, runID: id, status: .pass, message: "Parecer preservado para decisão humana.")
        case "evidence": break  // Final status is derived after all runnable stages.
        default: throw HarnessError("Tipo de etapa não suportado: \(step.kind)")
        }
    }

    func dependentSteps(in value: Run, roots: Set<String>) -> Set<String> {
        var affected = roots
        var changed = true
        while changed {
            changed = false
            for step in value.plan
            where !affected.contains(step.id) && !Set(step.dependencies).isDisjoint(with: affected) {
                affected.insert(step.id)
                changed = true
            }
        }
        return affected
    }

    func retryStep(_ request: RPCRequest) throws {
        var value = try run(request.id)
        guard !value.state.active, value.plan.contains(where: { $0.id == request.relatedID }) else {
            throw HarnessError("Pause a run e selecione uma etapa existente.")
        }
        let affected = dependentSteps(in: value, roots: [request.relatedID])
        if value.plan.contains(where: {
            affected.contains($0.id) && ["investigation", "plan", "reproduction"].contains($0.kind)
        }) {
            value.workflow?.proposal = ""
            value.planApproved = false
        }
        if value.plan.contains(where: { affected.contains($0.id) && $0.kind == "reproduction" }) {
            value.workflow?.observations.removeAll { $0.phase == .before }
        }
        if value.plan.contains(where: { affected.contains($0.id) && $0.kind == "verification" }) {
            value.workflow?.observations.removeAll { $0.phase != .before }
        }
        for i in value.plan.indices where affected.contains(value.plan[i].id) { value.plan[i].status = .notRun }
        if value.plan.contains(where: { affected.contains($0.id) && $0.kind == "validation" }) {
            for i in value.validations.indices { value.validations[i].status = .stale }
        }
        value.reviewRevision = ""
        value.humanReviewRevision = ""
        value.state = .paused
        try record(
            value, kind: "step.retry_requested",
            message: "Etapas invalidadas: \(affected.sorted().joined(separator: ", ")).")
    }
}
