import Foundation
import HarnessDomain
import HarnessInfrastructure

extension RunCoordinator {
    func extensionTool(runID: String, name: String, arguments: JSONValue) async throws -> String {
        let value = try run(runID)
        let stepID = value.attempts.last(where: { $0.status == "RUNNING" })?.stepID ?? value.currentStep?.id ?? ""
        let stage = value.plan.first(where: { $0.id == stepID })?.kind ?? "review"
        switch name {
        case "harness_capabilities": return try Coding.string(capabilityCatalog(value, stage: stage))
        case "harness_skill_read":
            let item = try boundExtension(arguments["extensionID"].string, run: value, stage: stage)
            if item.kind == .instructions {
                guard arguments["path"].string.isEmpty else {
                    throw HarnessError(
                        "Este item contém somente o texto importado. Referências não são abertas automaticamente.")
                }
                try record(value, kind: "instructions.loaded", message: item.name)
                return "<instructions trust=\"untrusted\">\n" + item.skillContent + "\n</instructions>"
            }
            guard item.kind == .skill else { throw HarnessError("Extensão não é uma skill.") }
            let root = URL(fileURLWithPath: item.skillPath).deletingLastPathComponent().path
            let main = try ContextFirewall.containedPath("SKILL.md", root: root)
            guard Coding.hash(try boundedFile(main, limit: 128_000)) == item.skillHash else {
                throw HarnessError("SKILL_CHANGED: importe novamente e revise o contexto.")
            }
            let relative = arguments["path"].string.isEmpty ? "SKILL.md" : arguments["path"].string
            let url = try ContextFirewall.containedPath(relative, root: root)
            let data = try boundedFile(url, limit: 128_000)
            guard let text = String(data: data, encoding: .utf8), !text.contains("\0") else {
                throw HarnessError("Recurso não textual.")
            }
            try record(value, kind: "skill.loaded", message: "\(item.name) · \(relative) · \(Coding.hash(data))")
            let content =
                relative == "SKILL.md" && item.importSourceID != nil
                ? item.skillContent : ContextFirewall.redact(text)
            return "<skill trust=\"untrusted\">\n" + content + "\n</skill>"
        case "harness_scenario_record":
            guard ["reproduction", "verification"].contains(stage), !arguments["artifactID"].string.isEmpty else {
                throw HarnessError("Cenários automatizados precisam de artefato e etapa de reprodução/conferência.")
            }
            var observation = ScenarioEvidence()
            guard let phase = ObservationPhase(rawValue: arguments["phase"].string),
                let status = GateStatus(rawValue: arguments["status"].string),
                stage == "reproduction" ? phase == .before : phase != .before
            else { throw HarnessError("Fase ou resultado inválido.") }
            observation.phase = phase
            observation.status = status
            observation.scenario = arguments["scenario"].string
            observation.expected = arguments["expected"].string
            observation.observed = arguments["observed"].string
            observation.environment = arguments["environment"].string
            observation.artifactID = arguments["artifactID"].string
            observation.criterionIDs = arguments["criterionIDs"].array.map(\.string)
            var request = RPCRequest("scenario.record")
            request.id = runID
            request.observation = observation
            try await recordScenario(request, automated: true)
            return "Cenário registrado com proveniência e artefato."
        case "harness_evidence_list": return try Coding.string(value.evidenceArtifacts ?? [])
        case "harness_evidence_record":
            try await reconcile(runID)
            return try Coding.string(registerArtifact(runID: runID, input: arguments, source: "Provider"))
        case "harness_evidence_read": return try Coding.string(await readEvidence(runID: runID, arguments: arguments))
        case "harness_extension_call":
            return try Coding.string(await invokeExtension(runID: runID, stage: stage, input: arguments))
        default: throw HarnessError("Capacidade desconhecida.")
        }
    }

    func invokeExtension(runID: String, stage: String, input: JSONValue) async throws -> JSONValue {
        var value = try run(runID)
        guard value.state != .archived, value.state != .cancelled, value.contextApproved else {
            throw HarnessError("Revise o contexto e as capacidades primeiro.")
        }
        let item = try boundExtension(input["extensionID"].string, run: value, stage: stage)
        let project = try project(value.projectID)
        guard !project.requireStrongIsolation else {
            throw HarnessError("Isolamento forte de extensões não demonstrado.")
        }
        guard let tool = item.tools.first(where: { $0.name == input["tool"].string && $0.enabled }),
            !isReadOnlyStage(stage, run: value) || tool.readOnly
        else {
            throw HarnessError("Ferramenta não autorizada nesta etapa.")
        }
        guard extensionBusy.insert(runID).inserted else {
            throw HarnessError("Aguarde a chamada de extensão em andamento.")
        }
        defer {
            extensionBusy.remove(runID)
            extensionProcesses.removeValue(forKey: runID)
            schedule()
        }
        let arguments = input["arguments"]
        guard case .object = arguments, (try Coding.encode(arguments)).count <= 128_000 else {
            throw HarnessError("Argumentos precisam ser um objeto JSON de até 128 KB.")
        }
        let inputHash = try Coding.hash(Coding.string(arguments))
        guard
            !(value.extensionInvocations ?? []).contains(where: {
                $0.extensionID == item.id && $0.tool == tool.name && ["RUNNING", "UNKNOWN"].contains($0.state)
            })
        else {
            throw HarnessError(
                "Resultado anterior incerto. Confira o destino e resolva a chamada no Fronda antes de repetir.")
        }
        let outputDirectory = paths.root.appendingPathComponent("captures").appendingPathComponent(runID)
        try FileManager.default.createDirectory(
            at: outputDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var invocation = ExtensionInvocation()
        invocation.extensionID = item.id
        invocation.tool = tool.name
        invocation.argumentHash = inputHash
        invocation.revision = value.revision
        value.extensionInvocations = (value.extensionInvocations ?? []) + [invocation]
        try record(value, kind: "extension.call_started", message: "\(item.name) / \(tool.name) · \(invocation.id)")
        do {
            let result: JSONValue
            if item.kind == .mcp {
                let key = runID + ":" + item.id
                let client: MCPConnection
                if let existing = extensionConnections[key] {
                    client = existing
                } else {
                    client = MCPConnection(configuration: item)
                    extensionConnections[key] = client
                    try await client.connect(cwd: value.workspace)
                    let current = try await client.discover()
                    guard let currentTool = current.first(where: { $0.name == tool.name }),
                        currentTool.inputSchema == tool.inputSchema, currentTool.description == tool.description
                    else {
                        throw HarnessError("MCP_CHANGED: ferramenta mudou; atualize o catálogo antes de usar.")
                    }
                }
                result = try await client.call(name: tool.name, arguments: arguments)
            } else if item.kind == .command {
                let envelope = JSONValue.object([
                    "runID": .string(runID), "revision": .string(value.revision),
                    "workspace": .string(value.workspace), "outputDirectory": .string(outputDirectory.path),
                    "arguments": arguments,
                    "criteria": .array(
                        value.criteria.map { .object(["id": .string($0.id), "text": .string($0.text)]) }),
                ])
                let process = RunningProcess()
                extensionProcesses[runID] = process
                try process.start(
                    executable: item.executable, arguments: item.arguments, cwd: value.workspace,
                    timeout: item.timeoutSeconds, stdin: Coding.string(envelope))
                let outcome = await withTaskCancellationHandler {
                    await process.result(since: Date())
                } onCancel: {
                    process.stop()
                }
                guard outcome.exitCode == 0 else {
                    throw HarnessError(
                        "Comando terminou com código \(outcome.exitCode). Confira os efeitos antes de repetir.")
                }
                guard outcome.stdout.utf8.count <= 2_000_000 else {
                    throw HarnessError("Saída do comando excede 2 MB.")
                }
                result =
                    (try? Coding.decode(JSONValue.self, from: Data(outcome.stdout.utf8)))
                    ?? .object(["text": .string(outcome.stdout)])
            } else {
                throw HarnessError("Skills fornecem instruções, não chamadas executáveis.")
            }
            try Task.checkCancellation()
            let currentState = try run(runID).state
            guard ![RunState.cancelled, .archived].contains(currentState),
                currentState != .paused || value.state == .paused
            else { throw CancellationError() }
            try await reconcile(runID)
            value = try run(runID)
            guard value.revision == invocation.revision else {
                throw HarnessError("SNAPSHOT_STALE: a extensão alterou o código; revalide antes de registrar capturas.")
            }
            let normalized = try await receiveExtensionResult(
                result, runID: runID, source: item.name, revision: invocation.revision)
            value = try run(runID)
            if let index = value.extensionInvocations?.firstIndex(where: { $0.id == invocation.id }) {
                value.extensionInvocations?[index].state = result["isError"].bool ? "FAILED" : "COMPLETED"
                // Preserve textual receipts, never the base64 image payload in the event ledger.
                let receipt = normalized["content"].array.filter { $0["type"].string == "text" }
                value.extensionInvocations?[index].resultHash = try paths.putArtifact(Coding.string(receipt))
            }
            try record(
                value, kind: "extension.call_completed", message: "\(item.name) / \(tool.name) · \(invocation.id)")
            return normalized
        } catch {
            value = try run(runID)
            if let index = value.extensionInvocations?.firstIndex(where: { $0.id == invocation.id }) {
                value.extensionInvocations?[index].state = "UNKNOWN"
            }
            try record(
                value, kind: "extension.call_uncertain",
                message: "\(item.name) · \(invocation.id): " + error.localizedDescription)
            let key = runID + ":" + item.id
            if let connection = extensionConnections.removeValue(forKey: key) { await connection.close() }
            throw error
        }
    }

    private func receiveExtensionResult(_ result: JSONValue, runID: String, source: String, revision: String)
        async throws -> JSONValue
    {
        var content = [JSONValue]()
        if !result["text"].string.isEmpty {
            content.append(
                .object([
                    "type": .string("text"),
                    "text": .string(ContextFirewall.redact(String(result["text"].string.prefix(64_000)))),
                ]))
        }
        for block in result["content"].array {
            if block["type"].string == "text" {
                content.append(
                    .object([
                        "type": .string("text"),
                        "text": .string(ContextFirewall.redact(String(block["text"].string.prefix(64_000)))),
                    ]))
            } else if block["type"].string == "image", ["image/png", "image/jpeg"].contains(block["mimeType"].string),
                let data = Data(base64Encoded: block["data"].string), data.count <= 10_000_000
            {
                let folder = paths.root.appendingPathComponent("captures").appendingPathComponent(runID)
                try FileManager.default.createDirectory(
                    at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                let file = folder.appendingPathComponent(
                    makeID() + (block["mimeType"].string == "image/png" ? ".png" : ".jpg"))
                try paths.atomicWrite(data, to: file)
                defer { try? FileManager.default.removeItem(at: file) }
                let value = try run(runID)
                let item = try registerArtifact(
                    runID: runID,
                    input: .object([
                        "path": .string(file.path), "title": .string("Captura · " + source),
                        "revision": .string(revision), "criterionIDs": .array(value.criteria.map { .string($0.id) }),
                        "providerReadable": .bool(true),
                    ]), source: source, localPath: true)
                content.append(
                    .object([
                        "type": .string("text"),
                        "text": .string(
                            "Imagem registrada no Fronda: \(item.id). Use harness_evidence_read para inspecionar."),
                    ]))
            } else {
                content.append(
                    .object([
                        "type": .string("text"),
                        "text": .string(
                            "Conteúdo MCP \(block["type"].string) não importado. Registre arquivos locais pelo contrato de evidências."
                        ),
                    ]))
            }
        }
        for artifact in result["artifacts"].array {
            var input = artifact.object
            input["revision"] = .string(revision)
            let item = try registerArtifact(runID: runID, input: .object(input), source: source)
            content.append(
                .object(["type": .string("text"), "text": .string("Artefato registrado: \(item.id) · \(item.title)")]))
        }
        if let structured = result.object["structuredContent"] {
            content.append(
                .object([
                    "type": .string("text"),
                    "text": .string(ContextFirewall.redact(String(try Coding.string(structured).prefix(64_000)))),
                ]))
        }
        return .object(["content": .array(content), "isError": .bool(result["isError"].bool)])
    }
}

extension RunCoordinator {
    func captureScenarioIfAvailable(_ step: RunbookStep, runID: String, provider: ProviderInfo) async throws {
        let value = try run(runID)
        let alreadyObserved =
            step.kind == "verification"
            ? value.workflowEvidenceComplete
            : value.workflow?.observations.contains {
                $0.phase == .before && $0.status == .pass && $0.revision == value.revision
            } == true
        guard !alreadyObserved, (value.extensionBindings ?? []).contains(where: { $0.stages.contains(step.kind) })
        else { return }
        try setStep(step.id, runID: runID, status: .running, message: "Captura com capacidades selecionadas.")
        let prompt =
            (value.pack?.payload ?? "") + """
                \nEtapa: \(step.kind). Use as capacidades autorizadas para observar o cenário sem editar o código.
                Registre as imagens/vídeos/relatórios no Fronda e vincule a observação usando harness_scenario_record.
                Se não puder executar ou observar, explique o bloqueio e deixe o cenário pendente. Não invente PASS.
                Cenários anteriores: \(try Coding.string(value.workflow?.observations ?? []))
                Revisão atual: \(value.revision)
                """
        let outcome = try await callProvider(runID, provider: provider, readOnly: true, prompt: prompt, stepID: step.id)
        try Task.checkCancellation()
        let current = try run(runID)
        try record(
            current, kind: "scenario.capture_finished", message: "Captura terminou: \(outcome.status).",
            artifact: paths.putArtifact(outcome.text))
    }
}
