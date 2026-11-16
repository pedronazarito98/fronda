import Foundation
import HarnessDomain
import HarnessInfrastructure

extension RunCoordinator {
    func handleTool(runID: String, name: String, attemptID: String? = nil, arguments: JSONValue) async -> String {
        activeToolCalls[runID, default: 0] += 1
        defer {
            let remaining = (activeToolCalls[runID] ?? 1) - 1
            if remaining > 0 { activeToolCalls[runID] = remaining } else { activeToolCalls[runID] = nil }
        }
        guard let attemptID else { return await performTool(runID: runID, name: name, arguments: arguments) }
        guard let attempt = try? run(runID).attempts.last(where: { $0.id == attemptID && $0.status == "RUNNING" })
        else {
            return "ERROR: A tentativa desta ferramenta não está ativa."
        }
        let scope = StepEventScope(runID: runID, stepID: attempt.stepID, attemptID: attempt.id)
        return await StepEventScope.$current.withValue(scope) {
            if let current = try? run(runID) {
                try? record(
                    current, kind: "tool.call_started", message: toolDescription(name, arguments: arguments),
                    activitySubject: name)
            }
            let result = await performTool(runID: runID, name: name, arguments: arguments)
            if let current = try? run(runID) {
                let structured = result.data(using: .utf8).flatMap { try? Coding.decode(JSONValue.self, from: $0) }
                let failed = result.hasPrefix("ERROR") || structured?["isError"].bool == true
                let description: String
                if result.hasPrefix("ERROR") {
                    description = String(result.prefix(600))
                } else if failed {
                    description = "A ferramenta conectada informou uma falha."
                } else {
                    description = toolResultDescription(name, result: result)
                }
                try? record(
                    current, kind: failed ? "tool.call_failed" : "tool.call_finished",
                    message: description, activitySubject: name)
            }
            return result
        }
    }

    private func toolDescription(_ name: String, arguments: JSONValue) -> String {
        let path = arguments["path"].string
        let safePath =
            !path.isEmpty && ContextFirewall.exclusion(path) == nil
            ? String(ContextFirewall.redact(path).prefix(200)) : ""
        switch name {
        case "harness_read_file": return safePath.isEmpty ? "Lendo arquivo" : "Lendo \(safePath)"
        case "harness_write_file": return safePath.isEmpty ? "Alterando arquivo" : "Alterando \(safePath)"
        case "harness_search": return "Pesquisando arquivos do projeto"
        case "harness_validate": return "Executando verificação autorizada"
        case "harness_capabilities": return "Consultando ferramentas disponíveis"
        case "harness_skill_read": return "Consultando instruções autorizadas"
        case "harness_extension_call": return "Executando ferramenta conectada"
        case "harness_scenario_record": return "Registrando resultado de cenário"
        case "harness_evidence_list": return "Consultando evidências da tarefa"
        case "harness_evidence_record": return "Registrando evidência"
        case "harness_evidence_read": return "Consultando evidência autorizada"
        default: return "Acionando ferramenta"
        }
    }

    private func toolResultDescription(_ name: String, result: String) -> String {
        switch name {
        case "harness_read_file": return "Conteúdo do arquivo entregue ao agente."
        case "harness_write_file": return "Alteração registrada na pasta de trabalho."
        case "harness_search":
            if let data = result.data(using: .utf8), let entries = try? Coding.decode([ContextItem].self, from: data) {
                return "Busca concluída: \(entries.count) arquivo(s) encontrado(s)."
            }
            return "Busca concluída."
        case "harness_validate":
            if let data = result.data(using: .utf8), let outcome = try? Coding.decode(ValidationResult.self, from: data)
            {
                return "Verificação \(outcome.validator.name): \(outcome.status.rawValue)."
            }
            return "Verificação concluída. Confira o resultado na etapa de validação."
        case "harness_capabilities": return "Ferramentas disponíveis informadas ao agente."
        case "harness_skill_read": return "Instruções entregues ao agente."
        case "harness_extension_call": return "Ferramenta conectada retornou uma resposta."
        case "harness_scenario_record": return "Resultado de cenário registrado."
        case "harness_evidence_list": return "Lista de evidências entregue ao agente."
        case "harness_evidence_record": return "Evidência registrada."
        case "harness_evidence_read": return "Evidência entregue ao agente."
        default: return "Ferramenta concluiu a operação."
        }
    }

    private func performTool(runID: String, name: String, arguments: JSONValue) async -> String {
        do {
            var value = try run(runID)
            let project = try project(value.projectID)
            guard value.state == .running else {
                throw HarnessError("Ferramentas só estão disponíveis durante uma tentativa ativa.")
            }
            if HarnessTools.capabilities.contains(where: { $0["name"].string == name }) {
                return try await extensionTool(runID: runID, name: name, arguments: arguments)
            }
            let activeStep = value.attempts.last(where: { $0.status == "RUNNING" })?.stepID ?? ""
            if ["harness_write_file", "harness_validate"].contains(name),
                activeStep == "review"
                    || value.plan.contains(where: {
                        $0.id == activeStep && ["review", "investigation", "plan"].contains($0.kind)
                    })
            {
                throw HarnessError("POLICY_DENIED: revisão independente aceita somente leitura e busca.")
            }
            switch name {
            case "harness_read_file":
                let url = try ContextFirewall.containedPath(arguments["path"].string, root: value.workspace)
                let workspace = URL(fileURLWithPath: value.workspace).resolvingSymlinksInPath().standardizedFileURL
                let relative = url.pathComponents.dropFirst(workspace.pathComponents.count).joined(separator: "/")
                guard !isExcludedFromTools(relative, run: value, project: project) else {
                    throw HarnessError("POLICY_DENIED: arquivo excluído do contexto.")
                }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size < 256_000 else { throw HarnessError("Arquivo excede 256 KB.") }
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8), !text.contains("\0") else {
                    throw HarnessError("Arquivo não textual")
                }
                try record(value, kind: "tool.file_read", message: arguments["path"].string)
                return "sha256: \(Coding.hash(data))\n" + ContextFirewall.redact(text)
            case "harness_search":
                let matches = try store.search(projectID: project.id, query: arguments["query"].string, limit: 12)
                    .filter { !isExcludedFromTools($0.path, run: value, project: project) }
                try record(value, kind: "tool.search", message: "\(matches.count) arquivos encontrados.")
                return try Coding.string(
                    matches.map { item in
                        var item = item
                        item.content = String(item.content.prefix(8000))
                        return item
                    })
            case "harness_validate":
                guard
                    let validator = value.runbook.validators(for: project).first(where: {
                        $0.id == arguments["validatorID"].string
                    })
                else { throw HarnessError("Validator não cadastrado.") }
                return try Coding.string(await validate(runID, validator: validator))
            case "harness_write_file":
                let path = arguments["path"].string
                let content = arguments["content"].string
                let suggestedCriteria = try suggestedCriteriaIDs(arguments, run: value)
                let url = try PolicyEngine.writable(path: path, run: value, project: project)
                guard content.utf8.count < 1_000_000, ContextFirewall.redact(content) == content else {
                    throw HarnessError("Conteúdo sensível ou grande demais; gravação bloqueada.")
                }
                let previous = (try? Data(contentsOf: url)).map(Coding.hash) ?? ""
                guard previous == arguments["expectedHash"].string else {
                    throw HarnessError("REVISION_CONFLICT: leia o arquivo novamente antes de editar.")
                }
                if let reason = PolicyEngine.sensitiveReason(path) {
                    var approval = Approval()
                    approval.kind = "file.write"
                    approval.title = reason
                    approval.destination = path
                    approval.payload = try Coding.string(arguments)
                    approval.revision = value.revision
                    approval.payloadHash = digest(approval)
                    value.approvals.append(approval)
                    try record(value, kind: "permission.requested", message: "\(reason) \(path)")
                    return
                        "ERROR: APPROVAL_REQUIRED. Proposal saved in Decisions. Stop editing this file and explain the pending decision."
                }
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(content.utf8).write(to: url, options: .atomic)
                try record(
                    value, kind: "tool.file_written", message: "\(path); conteúdo \(Coding.hash(content)).",
                    activitySubject: path)
                try await reconcile(runID)
                if let suggestedCriteria {
                    try recordSuggestedFileCriteria(suggestedCriteria, path: path, runID: runID)
                }
                return "Written \(path), sha256: \(Coding.hash(content)). Prior validation is stale."
            default: throw HarnessError("Ferramenta não suportada.")
            }
        } catch {
            if StepEventScope.current?.attemptID != nil,
                HarnessTools.definitions.contains(where: { $0["name"].string == name }), let current = try? run(runID)
            {
                try? record(
                    current, kind: "tool.failed", message: "A ferramenta não concluiu a operação.",
                    activitySubject: name)
            }
            return "ERROR: " + ContextFirewall.redact(error.localizedDescription)
        }
    }

    func suggestedCriteriaIDs(_ arguments: JSONValue, run: Run) throws -> [String]? {
        guard arguments["criterionIDs"] != .null else { return nil }
        guard case .array(let items) = arguments["criterionIDs"],
            items.allSatisfy({
                if case .string = $0 { return true }
                return false
            })
        else { throw HarnessError("Os critérios sugeridos devem ser uma lista de IDs.") }
        let ids = items.map(\.string)
        guard Set(ids).count == ids.count, Set(ids).isSubset(of: Set(run.criteria.map(\.id))) else {
            throw HarnessError("Sugira somente critérios existentes da tarefa, sem repetir IDs.")
        }
        return ids
    }

    func recordSuggestedFileCriteria(_ ids: [String], path: String, runID: String) throws {
        var value = try run(runID)
        guard let index = value.changedFiles.firstIndex(where: { $0.path == path }) else { return }
        var file = value.changedFiles[index]
        var origins = file.criterionLinkOrigins ?? [:]
        let original = Set(file.linkedCriteria)
        let retained = file.linkedCriteria.filter { origins[$0] != .agent }
        for id in file.linkedCriteria where origins[id] == .agent { origins.removeValue(forKey: id) }
        for id in ids where !original.contains(id) || file.criterionLinkOrigins?[id] == .agent { origins[id] = .agent }
        let retainedIDs = Set(retained)
        file.linkedCriteria = retained + ids.filter { !retainedIDs.contains($0) }
        file.criterionLinkOrigins = origins.isEmpty ? nil : origins
        value.changedFiles[index] = file
        try record(
            value, kind: "evidence.file_link_suggested", message: "O agente sugeriu critérios relacionados a \(path).")
    }

    private func isExcludedFromTools(_ path: String, run: Run, project: Project) -> Bool {
        let exclusions = (run.exclusions + project.exclusions).map { $0.lowercased() }
        return ContextFirewall.exclusion(path) != nil
            || ContextFirewall.matches(path.lowercased(), patterns: exclusions)
    }
}
