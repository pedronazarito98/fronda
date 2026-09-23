import Foundation
import HarnessDomain
import HarnessInfrastructure

extension RunCoordinator {
    func digest(_ approval: Approval) -> String {
        Coding.hash(
            [
                approval.kind, approval.destination, approval.payload, approval.revision, approval.accountID ?? "",
                approval.endpoint ?? "", approval.providerRequestID,
            ].joined(separator: "\n"))
    }
    func prepareAction(_ request: RPCRequest) async throws -> String {
        try await reconcile(request.id)
        var value = try run(request.id)
        guard !value.state.active, !value.workspace.isEmpty, var approval = request.approval else {
            throw HarnessError("Pause a execução e prepare uma proposta concreta.")
        }
        guard
            ["git.commit", "git.push", "github.pr", "github.comment", "jira.comment", "jira.transition"].contains(
                approval.kind)
        else { throw HarnessError("Ação externa desconhecida.") }
        approval.id = makeID()
        approval.revision = value.revision
        approval.state = "PREPARED"
        guard
            !value.approvals.contains(where: {
                ["UNKNOWN", "SENDING", "APPROVED"].contains($0.state) && $0.kind == approval.kind
                    && (approval.kind.hasPrefix("git.") || $0.destination == approval.destination)
            })
        else { throw HarnessError("Reconcilie a operação anterior antes de preparar outra no mesmo destino.") }
        if approval.kind.hasPrefix("git.") {
            guard value.mode.writes, value.workspace != (try project(value.projectID)).path else {
                throw HarnessError("Publicação Git só é permitida na worktree da run.")
            }
            approval.destination =
                approval.kind == "git.commit"
                ? value.workspace : (try project(value.projectID)).remote + " → " + value.branch
            guard !approval.payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw HarnessError("Descreva a operação/mensagem antes de preparar.")
            }
            if approval.kind == "git.commit" { approval.payload += "\n\n" + actionMarker(approval) }
        } else {
            guard let data = approval.payload.data(using: .utf8),
                (try? JSONDecoder().decode(JSONValue.self, from: data)) != nil
            else { throw HarnessError("O corpo da operação deve ser JSON válido.") }
            guard !approval.destination.isEmpty, !approval.destination.contains("://"),
                !approval.destination.contains("..")
            else { throw HarnessError("Informe o caminho REST dentro da conexão configurada.") }
            try validateDestination(approval)
            let kind = approval.kind.hasPrefix("github.") ? "GitHub" : "Jira"
            guard let account = preferences.integrationAccounts.first(where: { $0.kind == kind && $0.connected }) else {
                throw HarnessError("AUTH_REQUIRED: conecte \(kind) para preparar esta ação.")
            }
            approval.accountID = account.id
            approval.endpoint = account.endpoint
            approval.payload = try markedPayload(approval)
            if approval.kind == "jira.transition" {
                let requested = try JSONDecoder().decode(JSONValue.self, from: Data(approval.payload.utf8))[
                    "transition"]["id"].string
                let (transitions, _) = try await IntegrationClient.request(account: account, path: approval.destination)
                guard let transition = transitions["transitions"].array.first(where: { $0["id"].string == requested })
                else { throw HarnessError("Transição Jira indisponível para o estado atual.") }
                approval.providerRequestID = transition["to"]["id"].string
            }
        }
        guard ContextFirewall.redact(approval.payload) == approval.payload else {
            throw HarnessError("A proposta contém possível segredo.")
        }
        approval.payloadHash = digest(approval)
        value.approvals.append(approval)
        try record(
            value, kind: "integration.action_prepared",
            message: "\(approval.kind) · \(approval.destination) · digest \(approval.payloadHash)")
        return approval.id
    }
    func decideAction(_ request: RPCRequest) async throws {
        var value = try run(request.id)
        guard let index = value.approvals.firstIndex(where: { $0.id == request.relatedID }) else {
            throw HarnessError("Proposta não encontrada.")
        }
        var approval = value.approvals[index]
        guard approval.state == "PREPARED", approval.expiresAt > Date() else {
            throw HarnessError(
                "Proposta expirada, concluída ou com resultado incerto. Prepare uma nova operação após reconciliar.")
        }
        if !request.flag {
            value.approvals[index].state = "REJECTED"
            try record(value, kind: "permission.rejected", message: "Recusado: \(approval.title). Política preservada.")
            return
        }
        guard !value.state.active else {
            throw HarnessError("Aguarde o término da tentativa antes de aprovar uma escrita.")
        }
        value.approvals[index].state = "APPROVED"
        try record(value, kind: "permission.approved", message: "Aprovado somente o digest \(approval.payloadHash).")
        let snapshot = try await GitWorkspace.snapshot(path: value.workspace, base: value.baseSHA)
        guard snapshot.revision == approval.revision, digest(approval) == approval.payloadHash else {
            value = try run(request.id)
            value.approvals[index].state = "STALE"
            try record(
                value, kind: "permission.stale", message: "Snapshot da proposta mudou; nenhuma operação enviada.")
            throw HarnessError("SNAPSHOT_STALE: a proposta mudou. Prepare e revise novamente.")
        }
        value = try run(request.id)
        value.approvals[index].state = "SENDING"
        try record(value, kind: "integration.action_sending", message: approval.kind)
        do {
            let result: String
            switch approval.kind {
            case "file.write":
                let args = try JSONDecoder().decode(JSONValue.self, from: Data(approval.payload.utf8))
                let url = try PolicyEngine.writable(
                    path: approval.destination, run: value, project: project(value.projectID))
                let old = (try? Data(contentsOf: url)).map(Coding.hash) ?? ""
                guard old == args["expectedHash"].string else {
                    throw HarnessError("REVISION_CONFLICT no arquivo proposto.")
                }
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(args["content"].string.utf8).write(to: url, options: .atomic)
                result = "Arquivo gravado: \(approval.destination)"
            case "git.commit":
                guard !value.changedFiles.isEmpty else { throw HarnessError("Não há arquivos alterados para commit.") }
                for file in value.changedFiles {
                    _ = try PolicyEngine.writable(path: file.path, run: value, project: project(value.projectID))
                }
                _ = try await GitWorkspace.git(["add", "--"] + value.changedFiles.map(\.path), at: value.workspace)
                result = try await GitWorkspace.git(["commit", "-m", approval.payload], at: value.workspace)
            case "git.push":
                guard value.branch.hasPrefix("harness/"), value.changedFiles.isEmpty || !value.diff.isEmpty else {
                    throw HarnessError("Branch não pertence ao Harness.")
                }
                let remote = try project(value.projectID).remote
                guard !remote.isEmpty, !remote.hasPrefix("-"), approval.destination == remote + " → " + value.branch
                else { throw HarnessError("Destino Git divergiu da prévia aprovada.") }
                result = try await GitWorkspace.git(
                    ["push", remote, "HEAD:refs/heads/\(value.branch)"], at: value.workspace, timeout: 120)
            default:
                let kind = approval.kind.hasPrefix("github") ? "GitHub" : "Jira"
                guard
                    let account = preferences.integrationAccounts.first(where: {
                        $0.id == approval.accountID && $0.kind == kind && $0.connected
                            && $0.endpoint == approval.endpoint
                    })
                else {
                    throw HarnessError("AUTH_REQUIRED: reconecte a conta da proposta sem alterar o endpoint aprovado.")
                }
                let response = try await IntegrationClient.request(
                    account: account, path: approval.destination, method: "POST", body: approval.payload)
                result = try Coding.string(response.0)
            }
            value = try run(request.id)
            approval.state = "CONFIRMED"
            approval.result = ContextFirewall.redact(result)
            value.approvals[index] = approval
            try record(value, kind: "integration.action_confirmed", message: "\(approval.kind): \(result.prefix(2000))")
            try await reconcile(request.id)
        } catch {
            value = try run(request.id)
            value.approvals[index].state = "UNKNOWN"
            value.approvals[index].result = error.localizedDescription
            try record(
                value, kind: "integration.action_unknown",
                message: "Não repetir automaticamente. Verifique o destino: \(error.localizedDescription)")
            throw error
        }
    }
    func saveIntegration(_ request: RPCRequest) async throws {
        guard var account = request.preferences?.integrationAccounts.first,
            let endpoint = URL(string: account.endpoint), endpoint.scheme == "https", endpoint.user == nil,
            endpoint.password == nil
        else { throw HarnessError("Conexão HTTPS inválida.") }
        account.keychainReference = "integration-" + account.id
        if !request.text.isEmpty { try HarnessKeychain.save(request.text, reference: account.keychainReference) }
        let check = account.kind == "GitHub" ? "user" : "myself"
        _ = try await IntegrationClient.request(account: account, path: check)
        account.connected = true
        preferences.integrationAccounts.removeAll { $0.id == account.id }
        preferences.integrationAccounts.append(account)
        try store.save(preferences, id: "global", table: "preferences")
    }
}
