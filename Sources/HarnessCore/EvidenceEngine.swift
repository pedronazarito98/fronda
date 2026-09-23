import Foundation
import HarnessDomain
import HarnessInfrastructure

extension RunCoordinator {
    func exportEvidence(_ id: String, options: EvidenceExportOptions) throws -> String {
        let value = try run(id)
        let events = try store.events(id, limit: -1)
        let folder = paths.exports.appendingPathComponent(
            "\(id.prefix(8))-\(Int(Date().timeIntervalSince1970))-\(makeID().prefix(6))", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let report = """
            # \(value.title)

            Estado: **\(value.state.rawValue)**
            \(value.reason)

            Run: \(value.id)
            Base: \(value.baseSHA)
            Snapshot: \(value.revision)
            Provider: \(value.provider.rawValue)
            Plano: revisão \(value.planRevision)

            ## Critérios
            \(value.criteria.map { "- [\($0.state)] \($0.text) — \($0.evidence.joined(separator: ", "))" }.joined(separator: "\n"))

            ## Alterações
            \(value.changedFiles.map { "- \($0.path) [\($0.status)] — \($0.linkedCriteria.isEmpty ? "sem vínculo" : $0.linkedCriteria.joined(separator: ", "))" }.joined(separator: "\n"))

            ## Validação observada
            \(value.validations.map { "- \($0.validator.displayCommand): \($0.status.rawValue); exit=\($0.exitCode.map(String.init) ?? "não observado"); \($0.duration)s; snapshot=\($0.revision)" }.joined(separator: "\n"))

            ## Revisão
            \(value.findings.map { "- \($0.severity) \($0.title) [\($0.state)]\n  \($0.resolution)" }.joined(separator: "\n"))

            ## Resultado do provider
            \(value.report)

            ## Uso
            Tokens reportados: \(value.reportedTokens). Estimativas de payload não foram somadas a esse valor.
            \(value.tokens.map { "- \($0.provider.rawValue) / \($0.step): input=\($0.input.map(String.init) ?? "indisponível"), output=\($0.output.map(String.init) ?? "indisponível"), fonte=\($0.source), pack estimado=\($0.estimatedPackInput)" }.joined(separator: "\n"))

            Exportação redigida. Não inclui sessões de provider, credenciais, logs brutos ou conteúdo do Context Pack.
            """
        var safeEvents = events
        for i in safeEvents.indices { safeEvents[i].artifactHash = "" }
        let trace = JSONValue.object([
            "criteria": try JSONDecoder().decode(JSONValue.self, from: Coding.encode(value.criteria)),
            "files": try JSONDecoder().decode(JSONValue.self, from: Coding.encode(value.changedFiles)),
            "plan": try JSONDecoder().decode(JSONValue.self, from: Coding.encode(value.plan)),
            "findings": try JSONDecoder().decode(JSONValue.self, from: Coding.encode(value.findings)),
            "validations": .array(
                value.validations.map {
                    .object([
                        "id": .string($0.id), "command": .string($0.validator.displayCommand),
                        "status": .string($0.status.rawValue), "revision": .string($0.revision),
                        "artifactHash": .string($0.artifactHash),
                        "exitCode": $0.exitCode.map { .number(Double($0)) } ?? .null,
                        "outputExcerpt": .string(String($0.output.prefix(2000))),
                    ])
                }),
            "context": .object([
                "id": .string(value.pack?.id ?? ""), "hash": .string(value.pack?.hash ?? ""),
                "items": .array(
                    (value.pack?.items ?? []).map {
                        .object([
                            "path": .string($0.path), "hash": .string($0.hash), "included": .bool($0.included),
                            "reason": .string($0.reason),
                        ])
                    }),
            ]),
        ])
        var files = [
            "report.md": ContextFirewall.redact(options.includeText ? report : metadataReport(value)),
            "trace.json": ContextFirewall.redact(try Coding.string(options.includeText ? trace : metadataTrace(value))),
        ]
        if options.includeDiff && options.includeText { files["diff.patch"] = ContextFirewall.redact(value.diff) }
        if options.includeEvents {
            files["events.json"] =
                options.includeText
                ? try Coding.string(safeEvents)
                : try Coding.string(
                    events.map { event in
                        JSONValue.object([
                            "id": .string(event.id), "sequence": .number(Double(event.sequence)),
                            "kind": .string(event.kind), "revision": .string(event.revision),
                        ])
                    })
        }
        var hashes = [String: String]()
        for (name, text) in files {
            try paths.atomicWrite(Data(text.utf8), to: folder.appendingPathComponent(name))
            hashes[name] = Coding.hash(text)
        }
        let manifest = JSONValue.object([
            "schemaVersion": .number(1), "runID": .string(id), "revision": .string(value.revision),
            "state": .string(value.state.rawValue), "redacted": .bool(true),
            "includesFreeText": .bool(options.includeText), "files": .object(hashes.mapValues(JSONValue.string)),
        ])
        try paths.atomicWrite(Coding.encode(manifest), to: folder.appendingPathComponent("manifest.json"))
        try record(value, kind: "evidence.exported", message: "Pacote redigido exportado: \(folder.lastPathComponent)")
        return folder.path
    }

    private func metadataReport(_ value: Run) -> String {
        """
        # Evidência de execução

        Run: \(value.id)
        Estado: \(value.state.rawValue)
        Snapshot: \(value.revision)
        Provider: \(value.provider.rawValue)
        Plano: revisão \(value.planRevision)
        Critérios: \(value.criteria.count)
        Arquivos alterados: \(value.changedFiles.count)
        Gates: \(value.validations.count)
        Tokens reportados: \(value.reportedTokens)

        Exportação somente de metadados. Textos livres, nomes de arquivos, comandos, outputs e código foram omitidos.
        """
    }

    private func metadataTrace(_ value: Run) -> JSONValue {
        .object([
            "criteria": .array(value.criteria.map { .object(["id": .string($0.id), "state": .string($0.state)]) }),
            "files": .array(
                value.changedFiles.map {
                    .object([
                        "pathHash": .string(Coding.hash($0.path)), "status": .string($0.status),
                        "linkedCriteria": .array($0.linkedCriteria.map(JSONValue.string)),
                    ])
                }),
            "plan": .array(
                value.plan.map {
                    .object(["id": .string($0.id), "kind": .string($0.kind), "status": .string($0.status.rawValue)])
                }),
            "findings": .array(
                value.findings.map {
                    .object(["id": .string($0.id), "state": .string($0.state), "revision": .string($0.revision)])
                }),
            "validations": .array(
                value.validations.map {
                    .object([
                        "id": .string($0.id), "status": .string($0.status.rawValue), "revision": .string($0.revision),
                        "exitCode": $0.exitCode.map { .number(Double($0)) } ?? .null,
                    ])
                }),
            "context": .object(["id": .string(value.pack?.id ?? ""), "hash": .string(value.pack?.hash ?? "")]),
        ])
    }
    func exportTokens(_ id: String) throws -> String {
        let value = try run(id)
        let header = "provider,attempt,step,input,output,cached_input,estimated_pack_input,source,cost,cost_source\n"
        let lines: [String] = value.tokens.map { record in
            let input = record.input.map { String($0) } ?? ""
            let output = record.output.map { String($0) } ?? ""
            let cached = record.cachedInput.map { String($0) } ?? ""
            let cost = record.cost.map { String($0) } ?? ""
            let fields = [
                record.provider.rawValue, record.attemptID, record.step, input, output, cached,
                String(record.estimatedPackInput), record.source, cost, record.costSource,
            ]
            return fields.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ",")
        }
        let rows = lines.joined(separator: "\n")
        let file = paths.exports.appendingPathComponent("\(id)-tokens.csv")
        try paths.atomicWrite(Data((header + rows).utf8), to: file)
        return file.path
    }
}
