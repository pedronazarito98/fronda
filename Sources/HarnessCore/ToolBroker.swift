import Foundation
import HarnessDomain
import HarnessInfrastructure

extension RunCoordinator {
    func handleTool(runID: String, name: String, arguments: JSONValue) async -> String {
        do {
            var value = try run(runID)
            let project = try project(value.projectID)
            guard value.state == .running else {
                throw HarnessError("Ferramentas só estão disponíveis durante uma tentativa ativa.")
            }
            let activeStep = value.attempts.last(where: { $0.status == "RUNNING" })?.stepID ?? ""
            if ["harness_write_file", "harness_validate"].contains(name),
                activeStep == "review" || value.plan.contains(where: { $0.id == activeStep && $0.kind == "review" })
            {
                throw HarnessError("POLICY_DENIED: revisão independente aceita somente leitura e busca.")
            }
            switch name {
            case "harness_read_file":
                let url = try ContextFirewall.containedPath(arguments["path"].string, root: value.workspace)
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size < 256_000 else { throw HarnessError("Arquivo excede 256 KB.") }
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8), !text.contains("\0") else {
                    throw HarnessError("Arquivo não textual")
                }
                try record(value, kind: "tool.file_read", message: arguments["path"].string)
                return "sha256: \(Coding.hash(data))\n" + ContextFirewall.redact(text)
            case "harness_search":
                return try Coding.string(
                    store.search(projectID: project.id, query: arguments["query"].string, limit: 12).map { item in
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
                try record(value, kind: "tool.file_written", message: "\(path); conteúdo \(Coding.hash(content)).")
                try await reconcile(runID)
                value = try run(runID)
                if let index = value.changedFiles.firstIndex(where: { $0.path == path }) {
                    value.changedFiles[index].linkedCriteria = value.criteria.map(\.id)
                    try record(
                        value, kind: "evidence.file_linked",
                        message: "Arquivo \(path) ligado aos critérios da execução aprovada.")
                }
                return "Written \(path), sha256: \(Coding.hash(content)). Prior validation is stale."
            default: throw HarnessError("Ferramenta não suportada.")
            }
        } catch { return "ERROR: " + ContextFirewall.redact(error.localizedDescription) }
    }
}
