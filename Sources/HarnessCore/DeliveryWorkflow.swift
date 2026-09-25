import Foundation
import HarnessDomain
import HarnessInfrastructure

extension RunCoordinator {
    func requireDeliveryReady(_ value: Run, kind: String) throws {
        guard ["git.commit", "git.push", "github.pr"].contains(kind) else { return }
        guard value.state == .ready, jobs[value.id] == nil, value.workflowEvidenceComplete,
            value.reviewRevision == value.revision, value.humanReviewRevision == value.revision,
            value.planApproved, value.contextApproved,
            value.findings.allSatisfy({ !["OPEN", "ACCEPTED_RISK"].contains($0.state) }),
            !value.criteria.isEmpty, value.criteria.allSatisfy({ $0.state == "SATISFIED" && !$0.evidence.isEmpty })
        else {
            throw HarnessError(
                "DELIVERY_BLOCKED: conclua etapas, validações, cenários e revisão no snapshot atual antes de publicar.")
        }
        let mandatory = value.runbook.validators(for: try project(value.projectID)).filter(\.required)
        guard !mandatory.isEmpty,
            mandatory.allSatisfy({ validator in
                value.validations.contains {
                    $0.validator == validator && $0.status == .pass && $0.exitCode == 0 && $0.revision == value.revision
                }
            })
        else { throw HarnessError("DELIVERY_BLOCKED: comandos obrigatórios precisam de PASS atual.") }
    }

    func carryForwardDeliveryEvidence(_ before: Run, runID: String) throws {
        var value = try run(runID)
        // The caller verified the complete changed content and a clean working tree after hooks.
        for i in value.validations.indices
        where before.validations.contains(where: {
            $0.id == value.validations[i].id && $0.status == .pass && $0.revision == before.revision
        }) {
            value.validations[i].revision = value.revision
            value.validations[i].status = .pass
        }
        for i in value.plan.indices {
            if let prior = before.plan.first(where: { $0.id == value.plan[i].id }) {
                value.plan[i].status = prior.status
            }
        }
        value.criteria = before.criteria
        value.findings = before.findings.filter { $0.author != "Scope Guard" }
        value.findings += PolicyEngine.findings(run: value, project: try project(value.projectID))
        value.reviewRevision = before.reviewRevision == before.revision ? value.revision : ""
        value.humanReviewRevision = before.humanReviewRevision == before.revision ? value.revision : ""
        if var workflow = value.workflow {
            for i in workflow.observations.indices
            where workflow.observations[i].phase != .before && workflow.observations[i].revision == before.revision {
                workflow.observations[i].revision = value.revision
            }
            value.workflow = workflow
        }
        try record(
            value, kind: "delivery.content_attested",
            message:
                "Conteúdo idêntico após staging e hooks; evidências de \(before.revision) vinculadas a \(value.revision)."
        )
        try finalize(runID)
    }

    func refreshDelivery(_ id: String) async throws {
        let value = try run(id)
        guard !value.state.active, let route = value.workflow?.delivery.pullRequestPath,
            route.range(of: #"^repos/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pulls/[0-9]+$"#, options: .regularExpression)
                != nil,
            let account = preferences.integrationAccounts.first(where: {
                $0.kind == "GitHub" && $0.connected && $0.id == value.workflow?.delivery.accountID
                    && $0.endpoint == value.workflow?.delivery.endpoint
            })
        else { throw HarnessError("Conecte o GitHub e crie ou reconcilie o PR desta tarefa.") }
        let (pr, _) = try await IntegrationClient.request(account: account, path: route)
        let head = pr["head"]["sha"].string
        guard !head.isEmpty, pr["head"]["ref"].string == value.branch else {
            throw HarnessError("O PR não corresponde à branch entregue.")
        }
        var updated = try run(id)
        if pr["merged"].bool {
            guard head == updated.workflow?.delivery.pushedSHA else {
                throw HarnessError(
                    "O HEAD do PR difere da entrega registrada. Preserve a worktree e reconcilie a entrega.")
            }
            updated.workflow?.delivery.mergedAt = Date()
            updated.workflow?.delivery.mergedHead = head
        }
        try record(
            updated, kind: pr["merged"].bool ? "delivery.merge_confirmed" : "delivery.pr_checked",
            message: pr["merged"].bool
                ? "Merge confirmado pela API do GitHub." : "PR ainda não integrado; diário permanece em rascunho.")
    }

    func closeDelivery(_ id: String) async throws {
        var value = try run(id)
        if !value.mode.writes {
            guard value.state == .ready, value.workflow != nil, jobs[id] == nil else {
                throw HarnessError("Conclua a revisão da investigação antes de encerrar.")
            }
            value.workflow?.delivery.closedAt = Date()
            value.state = .archived
            try record(
                value, kind: "delivery.investigation_closed",
                message: "Investigação consolidada; checkout original preservado.")
            return
        }
        guard !value.state.active, jobs[id] == nil, value.workflow?.delivery.closedAt == nil,
            let expectedHead = value.workflow?.delivery.mergedHead
        else { throw HarnessError("Confirme o merge antes de encerrar.") }
        try await refreshDelivery(id)
        value = try run(id)
        let project = try project(value.projectID)
        guard value.workspace == paths.worktrees.appendingPathComponent(value.id).path, value.workspace != project.path
        else { throw HarnessError("Worktree não pertence a esta tarefa.") }
        if !FileManager.default.fileExists(atPath: value.workspace),
            value.workflow?.delivery.cleanupHead == expectedHead
        {
            try finishDeliveryClosure(id)
            return
        }
        let head = try await GitWorkspace.git(["rev-parse", "HEAD"], at: value.workspace).trimmingCharacters(
            in: .whitespacesAndNewlines)
        let clean = try await GitWorkspace.git(
            ["status", "--porcelain=v1", "--untracked-files=all", "--ignored"], at: value.workspace
        ).isEmpty
        guard head == expectedHead, clean else {
            throw HarnessError("A worktree contém arquivos ou commits adicionais. Nada foi removido.")
        }
        _ = try exportEvidence(id, options: EvidenceExportOptions())
        value = try run(id)
        value.workflow?.delivery.cleanupHead = head
        try record(value, kind: "delivery.cleanup_prepared", message: "Limpeza vinculada ao HEAD integrado \(head).")
        _ = try await GitWorkspace.git(["worktree", "unlock", value.workspace], at: project.path)
        do { _ = try await GitWorkspace.git(["worktree", "remove", value.workspace], at: project.path) } catch {
            _ = try? await GitWorkspace.git(["worktree", "lock", value.workspace], at: project.path)
            throw error
        }
        try finishDeliveryClosure(id)
    }

    private func finishDeliveryClosure(_ id: String) throws {
        var value = try run(id)
        value.workflow?.delivery.closedAt = Date()
        value.state = .archived
        try record(
            value, kind: "delivery.closed",
            message: "Merge e HEAD conferidos. Worktree limpa removida sem força; diário e mídia preservados.")
        try store.execute("DELETE FROM workspace_leases WHERE run_id=?", [id])
    }
}
