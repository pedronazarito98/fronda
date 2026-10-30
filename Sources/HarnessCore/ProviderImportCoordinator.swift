import Foundation
import HarnessDomain
import HarnessInfrastructure

extension RunCoordinator {
    func previewProviderImport(_ request: RPCRequest) async throws -> ProviderImportPreview {
        guard let kind = ProviderKind(rawValue: request.text) else { throw HarnessError("Provider inválido.") }
        let project = request.id.isEmpty ? nil : try project(request.id)
        var preview = await Task.detached(priority: .userInitiated) {
            ProviderContextScanner.scan(provider: kind, project: project)
        }.value
        for index in preview.items.indices {
            let item = preview.items[index]
            preview.items[index].alreadyImported =
                preferences.extensions?.contains {
                    $0.importSourceID == item.id && $0.importFingerprint == item.fingerprint
                } == true
        }
        importPreviews = importPreviews.filter { Date().timeIntervalSince($0.value.date) < 900 }
        if importPreviews.count >= 8 { importPreviews.removeAll() }
        importPreviews[preview.id] = (preview, Date())
        return preview
    }

    func applyProviderImport(_ request: RPCRequest) throws -> Int {
        guard let entry = importPreviews[request.id], Date().timeIntervalSince(entry.date) < 900 else {
            throw HarnessError("A prévia expirou. Busque os itens novamente antes de importar.")
        }
        let ids = Set(request.arguments)
        let selected = entry.preview.items.filter { ids.contains($0.id) }
        guard !selected.isEmpty, selected.count == ids.count, selected.allSatisfy(\.selectable),
            selected.filter({ $0.kind == .settings }).count <= 1
        else { throw HarnessError("Selecione itens válidos e apenas um padrão de modelo e esforço.") }
        var updated = preferences
        var catalog = preferences.extensions ?? []
        let projectIDs = entry.preview.projectID.map { [$0] } ?? []
        let changedIDs = Set(
            catalog.filter { old in
                selected.contains {
                    $0.id == old.importSourceID
                        && ($0.fingerprint != old.importFingerprint || old.projectIDs != projectIDs)
                }
            }.map(\.id))
        guard
            !runs.contains(where: { run in
                (run.state.active || jobs[run.id] != nil || extensionBusy.contains(run.id))
                    && (run.extensionBindings ?? []).contains { changedIDs.contains($0.extensionID) }
            })
        else { throw HarnessError("Pause as tarefas que usam estes itens antes de atualizá-los.") }
        for item in selected {
            if let execution = item.execution {
                var defaults = updated.providerDefaults ?? [:]
                defaults[entry.preview.provider.rawValue] = try execution.validated()
                updated.providerDefaults = defaults
            }
            guard var configuration = item.configuration else { continue }
            let old = catalog.first { $0.importSourceID == item.id }
            if let old, old.importFingerprint == item.fingerprint && old.projectIDs == projectIDs { continue }
            configuration.id = old?.id ?? makeID()
            configuration.version = (old?.version ?? 0) + 1
            configuration.importSourceID = item.id
            configuration.importFingerprint = item.fingerprint
            configuration.projectIDs = projectIDs
            configuration.enabled = configuration.kind != .mcp
            configuration.status = configuration.kind == .mcp ? "NOT_CHECKED" : "AVAILABLE"
            configuration.detail = item.detail
            // Reimported connections must be reviewed again; do not carry tool grants to changed commands.
            configuration.tools = []
            configuration.authorizationReference = nil
            catalog.removeAll { $0.id == configuration.id }
            catalog.append(configuration)
        }
        updated.extensions = catalog
        try store.save(updated, id: "global", table: "preferences")
        preferences = updated
        importPreviews.removeValue(forKey: request.id)
        for var value in runs
        where ![.archived, .cancelled].contains(value.state)
            && (value.extensionBindings ?? []).contains(where: { changedIDs.contains($0.extensionID) })
        {
            value.contextApproved = false
            value.pack = nil
            invalidateProposal(&value)
            value.state = .draft
            value.reason = "Contexto importado foi atualizado. Prepare e revise novamente."
            try record(value, kind: "provider.context_imported", message: value.reason)
        }
        return selected.count
    }

    func importedRules(_ value: Run) throws -> String {
        let rules = (value.extensionBindings ?? []).compactMap { binding in
            preferences.extensions?.first { $0.id == binding.extensionID && $0.importedKind == .rule }
        }
        return rules.map {
            "\n<imported_rule trust=\"untrusted\" name=\"\($0.name)\">\n\($0.skillContent)\n</imported_rule>"
        }.joined()
    }
}
