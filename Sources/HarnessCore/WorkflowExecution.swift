import Foundation
import HarnessDomain
import HarnessInfrastructure
import HarnessProviders

extension RunCoordinator {
    func invalidateProposal(_ value: inout Run) {
        guard value.workflow != nil else { return }
        value.workflow?.proposal = ""
        value.planApproved = false
        let affected = dependentSteps(
            in: value, roots: Set(value.plan.filter { ["investigation", "plan"].contains($0.kind) }.map(\.id)))
        for i in value.plan.indices where affected.contains(value.plan[i].id) { value.plan[i].status = .notRun }
        value.reviewRevision = ""
        value.humanReviewRevision = ""
    }

    func prepareProposal(_ step: RunbookStep, runID: String, provider: ProviderInfo, isPlan: Bool) async throws {
        let value = try run(runID)
        guard value.contextApproved else { throw HarnessError("Revise o contexto antes de investigar.") }
        try setStep(step.id, runID: runID, status: .running, message: "Análise em modo de leitura.")
        let task =
            isPlan
            ? "Produza um plano concreto em pt-BR: diagnóstico, arquivos reais, critérios de aceite, passos, riscos e comandos de validação. Não implemente. Diferencie observações de hipóteses."
            : "Investigue o fluxo real no código. Identifique componentes, serviços, padrões existentes e causa provável. Não implemente nem afirme ter reproduzido sem evidência observada."
        let prompt =
            (value.pack?.payload ?? "") + "\n" + task + "\nDiagnóstico: "
            + (value.workflow?.investigation ?? "") + "\nCenários observados: "
            + (try Coding.string(value.workflow?.observations ?? []))
        let outcome = try await callProvider(runID, provider: provider, readOnly: true, prompt: prompt, stepID: step.id)
        try Task.checkCancellation()
        try await reconcile(runID)
        guard outcome.status == "completed", !outcome.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            try setStep(step.id, runID: runID, status: .fail, message: "Análise não concluída.")
            throw HarnessError("A análise não produziu um resultado. Revise a tentativa antes de retomar.")
        }
        var updated = try run(runID)
        guard updated.revision == value.revision else {
            throw HarnessError("O código mudou durante a investigação. Recompile o contexto.")
        }
        if isPlan { updated.workflow?.proposal = outcome.text } else { updated.workflow?.investigation = outcome.text }
        try record(
            updated, kind: isPlan ? "plan.proposed" : "investigation.completed",
            message: "Resultado disponível para revisão.", artifact: paths.putArtifact(outcome.text))
        try setStep(
            step.id, runID: runID, status: isPlan ? .blocked : .pass,
            message: isPlan ? "Aguardando aprovação do plano." : "Diagnóstico preservado.")
    }

    func waitForScenario(_ step: RunbookStep, runID: String, satisfied: Bool) async throws {
        try setStep(
            step.id, runID: runID, status: satisfied ? .pass : .blocked,
            message: satisfied ? "Cenário observado registrado." : "Registre o cenário e sua evidência para continuar.")
        if !satisfied {
            var value = try run(runID)
            value.state = .waitingUser
            value.reason =
                step.kind == "reproduction"
                ? "Reproduza o problema e registre o resultado antes de implementar."
                : "Confira o comportamento e registre evidência no snapshot atual."
            try record(value, kind: "scenario.awaiting_evidence", message: value.reason)
        }
    }

    func recordScenario(_ request: RPCRequest, automated: Bool = false) async throws {
        let previous = try run(request.id)
        guard automated || (!previous.state.active && jobs[request.id] == nil), previous.workflow != nil,
            !previous.workspace.isEmpty,
            previous.state != .archived, var evidence = request.observation
        else { throw HarnessError("Pause a tarefa e prepare seu ambiente antes de registrar um cenário.") }
        try await reconcile(request.id)
        var value = try run(request.id)
        guard value.revision == previous.revision else {
            throw HarnessError("SNAPSHOT_STALE: o código mudou. Observe o cenário novamente.")
        }
        guard [.pass, .fail, .blocked, .notRun].contains(evidence.status),
            [evidence.scenario, evidence.expected, evidence.observed, evidence.environment].allSatisfy({
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }),
            !evidence.criterionIDs.isEmpty, Set(evidence.criterionIDs).isSubset(of: Set(value.criteria.map(\.id)))
        else {
            throw HarnessError("Informe cenário, esperado, observado, ambiente e critérios válidos.")
        }
        if evidence.phase == .before {
            guard !value.planApproved,
                !value.plan.contains(where: { $0.kind == "implementation" && $0.status != .notRun })
            else { throw HarnessError("A reprodução inicial precisa anteceder a implementação.") }
        } else {
            guard value.planApproved else { throw HarnessError("A conferência ocorre depois da aprovação do plano.") }
        }
        evidence.id = makeID()
        evidence.createdAt = Date()
        evidence.revision = value.revision
        evidence.scenario = ContextFirewall.redact(evidence.scenario.trimmingCharacters(in: .whitespacesAndNewlines))
        evidence.expected = ContextFirewall.redact(evidence.expected)
        evidence.observed = ContextFirewall.redact(evidence.observed)
        evidence.environment = ContextFirewall.redact(evidence.environment)
        evidence.source = automated ? "Provider com artefato vinculado" : "Observação humana"
        evidence.mediaHash = nil
        evidence.mediaExtension = nil
        if let artifactID = evidence.artifactID {
            let (artifact, _) = try artifactFile(runID: value.id, artifactID: artifactID)
            guard artifact.revision == value.revision,
                Set(evidence.criterionIDs).isSubset(of: Set(artifact.criterionIDs))
            else {
                throw HarnessError("Evidência pertence a outro snapshot ou critério.")
            }
            if artifact.mimeType.hasPrefix("image/") || artifact.mimeType.hasPrefix("video/") {
                let (_, url) = try artifactFile(runID: value.id, artifactID: artifactID)
                let folder = paths.root.appendingPathComponent("media", isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try paths.atomicWrite(
                    Data(contentsOf: url),
                    to: folder.appendingPathComponent(artifact.hash + "." + artifact.fileExtension))
                evidence.mediaHash = artifact.hash
                evidence.mediaExtension = artifact.fileExtension
            }
        } else if !request.path.isEmpty {
            let media = try importScenarioMedia(request.path)
            evidence.mediaHash = media.hash
            evidence.mediaExtension = media.ext
        }
        if value.workflow?.kind == .interface && evidence.phase == .visual && evidence.status == .pass
            && evidence.mediaHash == nil
        {
            throw HarnessError("A conferência visual exige uma imagem ou vídeo do cenário.")
        }
        value.workflow?.observations.removeAll {
            $0.phase == evidence.phase && $0.scenario == evidence.scenario && $0.revision == evidence.revision
        }
        value.workflow?.observations.append(evidence)
        value.humanReviewRevision = ""
        if value.state == .ready { value.state = .partial }
        try record(
            value, kind: "scenario.observed",
            message:
                "\(evidence.phase.label): \(evidence.scenario) · \(evidence.status.rawValue). \(evidence.source ?? "Observação humana")."
        )
    }

    private func importScenarioMedia(_ path: String) throws -> (hash: String, ext: String) {
        let absolute = URL(fileURLWithPath: path).standardizedFileURL.path
        let source = try ContextFirewall.localFile(absolute)
        let ext = source.pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "heic", "mp4", "mov", "webm"].contains(ext),
            let size = try source.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]).fileSize,
            size > 0, size <= 100_000_000
        else { throw HarnessError("Selecione uma imagem ou vídeo de até 100 MB.") }
        let data = try Data(contentsOf: source)
        let hash = Coding.hash(data)
        let folder = paths.root.appendingPathComponent("media", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try paths.atomicWrite(data, to: folder.appendingPathComponent(hash + "." + ext))
        return (hash, ext)
    }

    func evidenceMedia(_ request: RPCRequest) throws -> String {
        let value = try run(request.id)
        guard let item = value.workflow?.observations.first(where: { $0.id == request.relatedID }),
            let hash = item.mediaHash, hash.count == 64, hash.allSatisfy(\.isHexDigit),
            let ext = item.mediaExtension, ["png", "jpg", "jpeg", "heic", "mp4", "mov", "webm"].contains(ext)
        else { throw HarnessError("Mídia indisponível.") }
        let url = paths.root.appendingPathComponent("media").appendingPathComponent(hash + "." + ext)
        guard Coding.hash(try Data(contentsOf: url)) == hash else {
            throw HarnessError("Integridade da mídia não confirmada.")
        }
        return url.path
    }
}
