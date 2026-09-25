import Foundation
import HarnessDomain
import HarnessInfrastructure

extension RunCoordinator {
    func registerArtifact(runID: String, input: JSONValue, source: String, localPath: Bool = false) throws
        -> EvidenceArtifact
    {
        var value = try run(runID)
        guard !value.workspace.isEmpty, value.state != .archived,
            input["revision"].string == value.revision, !value.revision.isEmpty
        else {
            throw HarnessError("SNAPSHOT_STALE: informe a revisão atual de uma tarefa preparada.")
        }
        let criteria = input["criterionIDs"].array.map(\.string)
        guard !criteria.isEmpty, Set(criteria).isSubset(of: Set(value.criteria.map(\.id))),
            !input["title"].string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw HarnessError("Informe título e critérios válidos para a evidência.")
        }
        let path = input["path"].string
        let url: URL
        let outputRoot = paths.root.appendingPathComponent("captures").appendingPathComponent(runID).path
        if path.hasPrefix("@output/") {
            url = try ContextFirewall.containedPath(String(path.dropFirst(8)), root: outputRoot)
        } else if path.hasPrefix(outputRoot + "/") {
            url = try ContextFirewall.containedPath(String(path.dropFirst(outputRoot.count + 1)), root: outputRoot)
        } else if localPath && path.hasPrefix("/") {
            let absolute = URL(fileURLWithPath: path).standardizedFileURL.path
            if absolute.hasPrefix(value.workspace + "/") {
                url = try ContextFirewall.containedPath(
                    String(absolute.dropFirst(value.workspace.count + 1)), root: value.workspace)
            } else {
                url = try ContextFirewall.localFile(absolute)
            }
        } else {
            url = try ContextFirewall.containedPath(path, root: value.workspace)
        }
        let ext = url.pathExtension.lowercased()
        let types = [
            "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "heic": "image/heic",
            "mp4": "video/mp4", "mov": "video/quicktime", "webm": "video/webm",
            "txt": "text/plain", "md": "text/markdown", "json": "application/json", "html": "text/html",
        ]
        guard let mime = types[ext] else { throw HarnessError("Formato de evidência não suportado.") }
        var data = try boundedFile(url, limit: mime.hasPrefix("video/") ? 100_000_000 : 10_000_000)
        if mime.hasPrefix("text/") || ext == "json" {
            guard let text = String(data: data, encoding: .utf8) else {
                throw HarnessError("Relatório precisa ser UTF-8.")
            }
            data = Data(ContextFirewall.redact(text).utf8)
        }
        var item = EvidenceArtifact()
        item.title = ContextFirewall.redact(String(input["title"].string.prefix(500)))
        item.hash = Coding.hash(data)
        item.fileExtension = ext
        item.mimeType = mime
        item.byteCount = data.count
        item.revision = value.revision
        item.criterionIDs = criteria
        item.source = source
        item.attemptID = value.attempts.last(where: { $0.status == "RUNNING" })?.id
        item.providerReadable = input["providerReadable"].bool
        if let duplicate = value.evidenceArtifacts?.first(where: {
            $0.hash == item.hash && $0.revision == item.revision && $0.criterionIDs == criteria
                && $0.providerReadable == item.providerReadable
        }) {
            return duplicate
        }
        let folder = paths.root.appendingPathComponent("evidence", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try paths.atomicWrite(data, to: folder.appendingPathComponent(item.hash + "." + ext))
        value.evidenceArtifacts = (value.evidenceArtifacts ?? []) + [item]
        value.reviewRevision = ""
        value.humanReviewRevision = ""
        for i in value.plan.indices where ["review", "evidence"].contains(value.plan[i].kind) {
            value.plan[i].status = .notRun
        }
        if value.state == .ready { value.state = .partial }
        try record(
            value, kind: "evidence.received",
            message: "\(item.title) · \(source) · \(item.hash). Artefato recebido, avaliação pendente.")
        return item
    }

    func artifactFile(runID: String, artifactID: String) throws -> (EvidenceArtifact, URL) {
        let value = try run(runID)
        guard let item = value.evidenceArtifacts?.first(where: { $0.id == artifactID }),
            item.hash.count == 64, item.hash.allSatisfy(\.isHexDigit),
            item.fileExtension.allSatisfy({ $0.isLetter || $0.isNumber })
        else { throw HarnessError("Artefato não encontrado.") }
        let url = paths.root.appendingPathComponent("evidence").appendingPathComponent(
            item.hash + "." + item.fileExtension)
        guard Coding.hash(try boundedFile(url, limit: 100_000_000)) == item.hash else {
            throw HarnessError("Integridade da evidência não confirmada.")
        }
        return (item, url)
    }

    func readEvidence(runID: String, arguments: JSONValue) async throws -> JSONValue {
        let (item, url) = try artifactFile(runID: runID, artifactID: arguments["artifactID"].string)
        guard item.providerReadable else { throw HarnessError("A evidência não foi liberada para o provider.") }
        let content: JSONValue
        if item.mimeType.hasPrefix("image/") || item.mimeType.hasPrefix("video/") {
            content = try await EvidenceMediaReader.imageContent(url: url, second: arguments["second"].double ?? 0)
        } else {
            let data = try boundedFile(url, limit: 256_000)
            content = .object([
                "content": .array([
                    .object([
                        "type": .string("text"),
                        "text": .string(ContextFirewall.redact(String(decoding: data, as: UTF8.self))),
                    ])
                ]), "isError": .bool(false),
            ])
        }
        let value = try run(runID)
        try record(
            value, kind: "evidence.provided_to_reviewer",
            message:
                "Artefato \(item.id) · revisão \(item.revision) · segundo \(arguments["second"].double ?? 0). Conteúdo fornecido; análise depende do parecer."
        )
        return content
    }
}
