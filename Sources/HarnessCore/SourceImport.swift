import Foundation
import HarnessDomain
import HarnessInfrastructure

extension RunCoordinator {
    func fetchSource(_ request: RPCRequest) async throws -> SourcePreview {
        let kind = SourceKind.detect(request.text)
        guard [.github, .jira].contains(kind) else { throw HarnessError("Informe uma chave Jira ou URL de PR GitHub.") }
        guard
            let account = preferences.integrationAccounts.first(where: {
                $0.kind == (kind == .github ? "GitHub" : "Jira") && $0.connected
            })
        else { throw HarnessError("Configure a conexão em Ajustes → Integrações.") }
        if kind == .github { return try await githubSource(request, account: account) }
        return try await jiraSource(request, account: account)
    }

    private func githubSource(_ request: RPCRequest, account: IntegrationAccount) async throws -> SourcePreview {
        guard let url = URL(string: request.text), url.scheme == "https" else {
            throw HarnessError("URL de PR inválida.")
        }
        let expectedHost =
            URL(string: account.endpoint)?.host == "api.github.com" ? "github.com" : URL(string: account.endpoint)?.host
        guard url.host == expectedHost else {
            throw HarnessError("O host da fonte não corresponde à conexão selecionada.")
        }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 4, parts[2] == "pull", Int(parts[3]) != nil else {
            throw HarnessError("Informe uma URL /owner/repo/pull/number.")
        }
        let repository = "repos/\(parts[0])/\(parts[1])"
        let route = repository + "/pulls/\(parts[3])"
        let (pr, etag) = try await IntegrationClient.request(account: account, path: route)
        var files = [JSONValue]()
        for page in 1...30 {
            let (batch, _) = try await IntegrationClient.request(
                account: account, path: route + "/files?per_page=100&page=\(page)")
            files += batch.array
            if batch.array.count < 100 { break }
        }
        guard files.count == pr["changed_files"].int else {
            throw HarnessError("A API não retornou todos os arquivos deste PR. Restrinja o diff antes de importar.")
        }
        let sha = pr["head"]["sha"].string
        let (checks, _) = try await IntegrationClient.request(
            account: account, path: repository + "/commits/\(sha)/check-runs?per_page=100")
        var selectedComments = [JSONValue]()
        if !request.arguments.isEmpty {
            for page in 1...10 {
                let (comments, _) = try await IntegrationClient.request(
                    account: account, path: repository + "/issues/\(parts[3])/comments?per_page=100&page=\(page)")
                selectedComments += comments.array.filter {
                    request.arguments.contains($0["id"].int.map(String.init) ?? "")
                }
                if selectedComments.count == Set(request.arguments).count || comments.array.count < 100 { break }
            }
            guard selectedComments.count == Set(request.arguments).count else {
                throw HarnessError("Um comentário escolhido não foi localizado entre os comentários da conversa do PR.")
            }
        }
        var preview = SourcePreview()
        preview.intent.kind = .github
        preview.intent.sourceURL = request.text
        preview.intent.revision = sha + " / " + etag
        preview.intent.text = ContextFirewall.redact(
            "GitHub source: \(request.text)\nRevision: \(preview.intent.revision)\n\(pr["title"].string)\n\(pr["body"].string)\nFiles: \(try Coding.string(files))\nChecks: \(try Coding.string(checks))\nSelected comments: \(try Coding.string(selectedComments))"
        )
        return preview
    }

    private func jiraSource(_ request: RPCRequest, account: IntegrationAccount) async throws -> SourcePreview {
        guard let range = request.text.range(of: #"\b[A-Z][A-Z0-9]+-\d+\b"#, options: .regularExpression) else {
            throw HarnessError("Chave Jira não reconhecida.")
        }
        let key = String(request.text[range])
        let field = try project(request.id).jiraAcceptanceField ?? ""
        guard field.isEmpty || field.range(of: #"^customfield_[0-9]+$"#, options: .regularExpression) != nil else {
            throw HarnessError("Configure um ID válido de campo de aceite no projeto.")
        }
        let fields = "summary,description,updated,issuetype,status,attachment" + (field.isEmpty ? "" : "," + field)
        let (issue, etag) = try await IntegrationClient.request(account: account, path: "issue/\(key)?fields=" + fields)
        var selectedComments = [JSONValue]()
        if !request.arguments.isEmpty {
            for start in stride(from: 0, to: 1000, by: 100) {
                let (batch, _) = try await IntegrationClient.request(
                    account: account, path: "issue/\(key)/comment?maxResults=100&startAt=\(start)")
                let comments = batch["comments"].array
                selectedComments += comments.filter { request.arguments.contains($0["id"].string) }
                if selectedComments.count == Set(request.arguments).count
                    || start + comments.count >= (batch["total"].int ?? 0)
                {
                    break
                }
            }
            guard selectedComments.count == Set(request.arguments).count else {
                throw HarnessError("Um comentário escolhido não está disponível nesta issue.")
            }
        }
        var preview = SourcePreview()
        preview.intent.kind = .jira
        preview.intent.issueKey = key
        preview.intent.issueType = issue["fields"]["issuetype"]["name"].string
        preview.intent.sourceURL = request.text
        preview.intent.revision = issue["fields"]["updated"].string + " / " + etag
        preview.attachments = issue["fields"]["attachment"].array.map {
            RemoteAttachment(id: $0["id"].string, name: $0["filename"].string, size: $0["size"].int ?? -1)
        }
        if !field.isEmpty {
            preview.criteria = JiraDocumentText.criteria(issue["fields"][field]).map(ContextFirewall.redact)
        }
        let selectedIDs = Set(
            request.path.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        let selected = preview.attachments.filter { selectedIDs.contains($0.id) }
        guard selected.count == selectedIDs.count, selected.count <= 40 else {
            throw HarnessError("Selecione até 40 anexos existentes nesta issue.")
        }
        guard selected.allSatisfy({ (0...10_000_000).contains($0.size) }),
            selected.reduce(0, { $0 + $1.size }) <= 20_000_000
        else { throw HarnessError("Selecione anexos de até 10 MB, totalizando até 20 MB por importação.") }
        var sections = [String]()
        for attachment in selected {
            try AttachmentCompiler.validateFilename(attachment.name)
            let data = try await IntegrationClient.jiraAttachment(
                account: account, id: attachment.id, expectedSize: attachment.size)
            let item = try AttachmentCompiler.compile(data: data, filename: attachment.name)
            sections.append(
                "<authorized_attachment id=\"\(attachment.id)\" sha256=\"\(item.hash)\">\nFilename: \(attachment.name)\n\(item.content)\n</authorized_attachment>"
            )
        }
        preview.intent.text = ContextFirewall.redact(
            "Jira \(key) · \(preview.intent.revision)\nConnection: \(account.endpoint)\nOriginal fields: \(try Coding.string(issue))\nSelected comments: \(try Coding.string(selectedComments))\n"
                + sections.joined(separator: "\n"))
        return preview
    }
}
