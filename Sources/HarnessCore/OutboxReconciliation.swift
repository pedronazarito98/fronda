import Foundation
import HarnessDomain
import HarnessInfrastructure

extension RunCoordinator {
    func validateDestination(_ approval: Approval) throws {
        let pattern: String
        switch approval.kind {
        case "github.pr": pattern = #"^repos/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pulls$"#
        case "github.comment": pattern = #"^repos/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/issues/[0-9]+/comments$"#
        case "jira.comment": pattern = #"^issue/[A-Z][A-Z0-9]+-[0-9]+/comment$"#
        case "jira.transition": pattern = #"^issue/[A-Z][A-Z0-9]+-[0-9]+/transitions$"#
        default: throw HarnessError("Tipo de publicação inválido.")
        }
        guard approval.destination.range(of: pattern, options: .regularExpression) != nil else {
            throw HarnessError("O destino REST não corresponde ao tipo de operação escolhido.")
        }
    }
    func actionMarker(_ approval: Approval) -> String { "Harness action: \(approval.id)" }
    func markedPayload(_ approval: Approval) throws -> String {
        var body = try JSONDecoder().decode(JSONValue.self, from: Data(approval.payload.utf8)).object
        if approval.kind.hasPrefix("github.") {
            body["body"] = .string((body["body"]?.string ?? "") + "\n\n<!-- \(actionMarker(approval)) -->")
        } else if approval.kind == "jira.comment" {
            var document = body["body"]?.object ?? [:]
            guard document["type"]?.string == "doc" else {
                throw HarnessError(
                    "Comentários Jira exigem body no formato Atlassian Document Format (doc/version/content).")
            }
            var content = document["content"]?.array ?? []
            content.append(
                .object([
                    "type": .string("paragraph"),
                    "content": .array([.object(["type": .string("text"), "text": .string(actionMarker(approval))])]),
                ]))
            document["content"] = .array(content)
            body["body"] = .object(document)
        }
        return try Coding.string(JSONValue.object(body))
    }
    func reconcileAction(_ request: RPCRequest) async throws {
        var value = try run(request.id)
        guard let index = value.approvals.firstIndex(where: { $0.id == request.relatedID }),
            value.approvals[index].state == "UNKNOWN"
        else { throw HarnessError("Somente resultados incertos exigem reconciliação.") }
        let approval = value.approvals[index]
        var found = false
        var evidence = ""
        var observedPR: JSONValue?
        var observedHead: String?
        if approval.kind == "file.write" {
            let content = try JSONDecoder().decode(JSONValue.self, from: Data(approval.payload.utf8))["content"].string
            let url = try ContextFirewall.containedPath(approval.destination, root: value.workspace)
            found = (try? Data(contentsOf: url)).map(Coding.hash) == Coding.hash(content)
            evidence = "Hash de arquivo consultado localmente."
        } else if approval.kind == "git.push" {
            let remote = try project(value.projectID).remote
            guard !remote.isEmpty, !remote.hasPrefix("-") else { throw HarnessError("Remote inválido.") }
            let head = try await GitWorkspace.git(["rev-parse", "HEAD"], at: value.workspace).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let observed = try await GitWorkspace.git(
                ["ls-remote", "--heads", remote, "refs/heads/" + value.branch], at: value.workspace)
            found = observed.split(separator: "\t").first.map(String.init) == head
            if found { observedHead = head }
            evidence = "SHA da branch remota comparado à HEAD local."
        } else if approval.kind == "git.commit" {
            let latest = try await GitWorkspace.git(["log", "-1", "--format=%B"], at: value.workspace)
            found = latest.contains(actionMarker(approval))
            if found {
                observedHead = try await GitWorkspace.git(["rev-parse", "HEAD"], at: value.workspace)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            evidence = "Marcador da operação consultado no commit local."
        } else {
            guard
                let account = preferences.integrationAccounts.first(where: {
                    $0.id == approval.accountID && $0.connected && $0.endpoint == approval.endpoint
                })
            else { throw HarnessError("Reconecte a conta original antes de consultar o destino.") }
            if approval.kind == "jira.transition" {
                let path = approval.destination.replacingOccurrences(of: "/transitions", with: "?fields=status")
                let (remote, _) = try await IntegrationClient.request(account: account, path: path)
                found =
                    !approval.providerRequestID.isEmpty
                    && remote["fields"]["status"]["id"].string == approval.providerRequestID
                evidence = "Estado de destino observado no Jira."
            } else {
                for page in 1...10 {
                    let query =
                        approval.kind.hasPrefix("github.")
                        ? "?per_page=100&page=\(page)" + (approval.kind == "github.pr" ? "&state=all" : "")
                        : "?maxResults=100&startAt=\((page - 1) * 100)"
                    let (remote, _) = try await IntegrationClient.request(
                        account: account, path: approval.destination + query)
                    let rows = approval.kind.hasPrefix("github.") ? remote.array : remote["comments"].array
                    if let matched = rows.first(where: {
                        (try? Coding.string($0)).map { $0.contains(actionMarker(approval)) } ?? false
                    }) {
                        found = true
                        if approval.kind == "github.pr" { observedPR = matched }
                        break
                    }
                    if rows.count < 100 { break }
                }
                evidence = "Marcador idempotente pesquisado no recurso remoto, sem executar escrita."
            }
        }
        value = try run(request.id)
        if let observedPR, let number = observedPR["number"].int {
            value.workflow?.delivery.pullRequestURL = observedPR["html_url"].string
            value.workflow?.delivery.pullRequestPath = approval.destination + "/" + String(number)
            value.workflow?.delivery.accountID = approval.accountID
            value.workflow?.delivery.endpoint = approval.endpoint
        }
        if let observedHead {
            if approval.kind == "git.commit" { value.workflow?.delivery.commitSHA = observedHead }
            if approval.kind == "git.push" { value.workflow?.delivery.pushedSHA = observedHead }
        }
        value.approvals[index].state = found ? "CONFIRMED" : "UNKNOWN"
        value.approvals[index].result =
            evidence
            + (found
                ? " Resultado confirmado." : " Não encontrado; resultado continua incerto. Nenhuma repetição enviada.")
        try record(value, kind: "integration.action_reconciled", message: value.approvals[index].result)
    }
}
