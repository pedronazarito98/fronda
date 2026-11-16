import HarnessDomain
import SwiftUI

/// Criteria are user-reviewed expectations, distinct from the result of a single command.
struct ChatCriteriaSummary: View {
    let store: AppStore
    let run: Run
    let isCurrent: Bool
    @State private var expanded = false
    @State private var editing = false
    @State private var draft: [Criterion] = []
    @State private var baseline: Run?
    @State private var saving = false
    @State private var error: String?
    @State private var linkingCriterionID: String?
    @State private var selectedFiles = Set<String>()
    @State private var linkSequence: Int?
    @State private var linkRevision = ""
    @State private var savingLinks = false
    @State private var linkError: String?

    private var canEdit: Bool {
        isCurrent && store.connected && !run.state.active && run.state != .queued && run.pauseAllowsContinuation
            && run.state != .archived && run.state != .cancelled && run.workflow?.delivery.closedAt == nil
    }

    private var hasGenericCriterion: Bool {
        run.criteria.contains { $0.isGenericPlaceholder }
    }

    private var confirmedCount: Int {
        run.criteria.filter(isConfirmed).count
    }

    private var obsoleteLinkCount: Int {
        let current = Set(run.criteria.map(\.id))
        return run.changedFiles.reduce(0) { count, file in
            count + file.linkedCriteria.filter { !current.contains($0) }.count
        }
    }

    private var draftValid: Bool {
        !draft.isEmpty
            && draft.allSatisfy {
                !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.isGenericPlaceholder
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: $expanded) {
                if editing {
                    editor
                } else {
                    criteria
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Critérios de conclusão").font(.callout.weight(.semibold))
                    Spacer(minLength: 4)
                    Text("\(confirmedCount) de \(run.criteria.count) confirmados")
                        .font(.caption).foregroundStyle(FrondaTheme.textMuted)
                }
            }
            if hasGenericCriterion && !expanded {
                Text("O critério é geral. Descreva o resultado esperado para poder conferi-lo.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 5)
        .accessibilityIdentifier("chat.criteria")
    }

    private var criteria: some View {
        VStack(alignment: .leading, spacing: 10) {
            if run.criteria.isEmpty {
                Text("Nenhum critério registrado.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(run.criteria) { criterion in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: isConfirmed(criterion) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isConfirmed(criterion) ? FrondaTheme.success : FrondaTheme.textMuted)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(criterion.text).font(.callout).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(criterionStatus(criterion)).font(.caption).foregroundStyle(.secondary)
                        criterionLinks(criterion)
                    }
                }
            }
            Text("Uma verificação aprovada não confirma, sozinha, todos os critérios.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if obsoleteLinkCount > 0 {
                Text("Há associações anteriores a critérios que não estão mais no plano atual.")
                    .font(.caption).foregroundStyle(FrondaTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                if isCurrent {
                    Button("Remover associações sem critério atual", action: removeObsoleteLinks)
                        .buttonStyle(.link).font(.caption)
                        .disabled(!canEdit || linkingCriterionID != nil || savingLinks || run.revision.isEmpty)
                        .accessibilityIdentifier("chat.criteria.files.remove-obsolete")
                    if let linkError { Text(linkError).font(.caption).foregroundStyle(FrondaTheme.danger) }
                }
            }
            if isCurrent {
                HStack(spacing: 12) {
                    Button("Ajustar critérios") { beginEditing() }
                        .disabled(!canEdit || linkingCriterionID != nil)
                        .help(canEdit ? "Editar o resultado esperado" : "Pause a execução para editar os critérios")
                        .accessibilityIdentifier("chat.criteria.edit")
                    Button("Ver evidências") { open(.evidence) }
                        .accessibilityIdentifier("chat.criteria.evidence")
                    Button("Revisar") { open(.review) }
                        .accessibilityIdentifier("chat.criteria.review")
                }
                .buttonStyle(.link).font(.caption)
            }
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Descreva comportamentos ou resultados que você poderá conferir.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach($draft) { $criterion in
                HStack(alignment: .top, spacing: 6) {
                    TextField("Resultado esperado", text: $criterion.text, axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(1...4)
                    Button {
                        draft.removeAll { $0.id == criterion.id }
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.plain).help("Remover critério").accessibilityLabel("Remover critério")
                }
            }
            Button("Adicionar critério", systemImage: "plus") { draft.append(Criterion()) }
                .buttonStyle(.link).font(.caption)
            Text("Salvar altera o plano: a aprovação e as evidências dependentes precisarão ser revistas.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if draft.contains(where: \.isGenericPlaceholder) {
                Text("Substitua o critério geral por um resultado que possa ser conferido.")
                    .font(.caption).foregroundStyle(FrondaTheme.warning)
            }
            if let error { Text(error).font(.caption).foregroundStyle(FrondaTheme.danger) }
            HStack {
                Button("Cancelar") {
                    editing = false
                    error = nil
                }
                Button(saving ? "Salvando…" : "Salvar critérios", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canEdit || !draftValid || saving)
                    .accessibilityIdentifier("chat.criteria.save")
            }
            .controlSize(.small)
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isConfirmed(_ criterion: Criterion) -> Bool {
        guard !criterion.isGenericPlaceholder, !run.revision.isEmpty else { return false }
        return criterion.state == "SATISFIED" && run.humanReviewRevision == run.revision
            && criterion.evidence.contains("human-review:" + run.revision)
    }

    private func criterionStatus(_ criterion: Criterion) -> String {
        if criterion.isGenericPlaceholder { return "Critério geral · detalhe o que precisa ser conferido" }
        if isConfirmed(criterion) { return "Confirmado na revisão humana desta versão" }
        if !criterion.evidence.isEmpty { return "Há evidência anterior; confirme novamente nesta revisão" }
        return "Ainda não confirmado nesta versão"
    }

    @ViewBuilder private func criterionLinks(_ criterion: Criterion) -> some View {
        let artifacts = (run.evidenceArtifacts ?? []).filter { $0.criterionIDs.contains(criterion.id) }
        let files = run.changedFiles.filter { $0.linkedCriteria.contains(criterion.id) }
        ForEach(Array(artifacts.prefix(2))) { artifact in
            let current = !run.revision.isEmpty && artifact.revision == run.revision
            Text("Evidência: \(artifact.title) · \(current ? "versão atual" : "revisão anterior")")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        if artifacts.count > 2 {
            Text("Mais \(artifacts.count - 2) evidência(s) vinculada(s).")
                .font(.caption).foregroundStyle(.secondary)
        }
        if files.isEmpty, !run.changedFiles.isEmpty {
            Text("Nenhum arquivo relacionado a este critério.")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            ForEach(Array(files.prefix(3))) { file in
                Text("\(file.path) · \(linkOrigin(file, criterionID: criterion.id))")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if files.count > 3 {
                Text("Mais \(files.count - 3) arquivo(s) relacionado(s).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        if isCurrent && !run.changedFiles.isEmpty {
            if linkingCriterionID == criterion.id {
                fileLinkEditor(criterion)
            } else {
                Button("Relacionar arquivos") {
                    selectedFiles = Set(files.map(\.path))
                    linkSequence = run.sequence
                    linkRevision = run.revision
                    linkError = nil
                    linkingCriterionID = criterion.id
                }
                .buttonStyle(.link).font(.caption)
                .disabled(!canEdit || editing || linkingCriterionID != nil || savingLinks || run.revision.isEmpty)
                .help(
                    canEdit
                        ? "Escolher arquivos relacionados a este critério" : "Pause a execução para relacionar arquivos"
                )
                .accessibilityIdentifier("chat.criteria.files.edit")
            }
        }
    }

    private func linkOrigin(_ file: ChangedFile, criterionID: String) -> String {
        switch file.criterionLinkOrigins?[criterionID] {
        case .human: "relacionado por você"
        case .agent: "sugerido pelo agente"
        case nil: "associação anterior, origem não registrada"
        }
    }

    private func fileLinkEditor(_ criterion: Criterion) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Escolha os arquivos relacionados. Esta seleção não confirma que o critério foi atendido.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(run.changedFiles) { file in
                Toggle(
                    isOn: Binding(
                        get: { selectedFiles.contains(file.path) },
                        set: { included in
                            if included { selectedFiles.insert(file.path) } else { selectedFiles.remove(file.path) }
                        }
                    )
                ) {
                    Text(verbatim: file.path).font(.caption).lineLimit(2)
                }
                .toggleStyle(.checkbox)
                .disabled(savingLinks)
            }
            if let linkError { Text(linkError).font(.caption).foregroundStyle(FrondaTheme.danger) }
            HStack(spacing: 8) {
                Button("Cancelar") {
                    linkingCriterionID = nil
                    linkError = nil
                }
                .disabled(savingLinks)
                Button(savingLinks ? "Salvando…" : "Salvar vínculos") { saveFileLinks(criterion) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canEdit || savingLinks || linkSequence == nil || linkRevision.isEmpty)
                    .accessibilityIdentifier("chat.criteria.files.save")
            }.controlSize(.small)
        }
        .padding(.vertical, 6)
    }

    private func saveFileLinks(_ criterion: Criterion) {
        guard canEdit, !savingLinks, let sequence = linkSequence, !linkRevision.isEmpty else { return }
        var request = RPCRequest("criterion.files.save")
        request.id = run.id
        request.relatedID = criterion.id
        request.expectedSequence = sequence
        request.arguments = run.changedFiles.map(\.path).filter { selectedFiles.contains($0) }
        request.payload = .object(["revision": .string(linkRevision)])
        savingLinks = true
        linkError = nil
        Task {
            defer { savingLinks = false }
            do {
                _ = try await store.send(request)
                await store.refresh()
                linkingCriterionID = nil
            } catch {
                linkError = error.localizedDescription
            }
        }
    }

    private func removeObsoleteLinks() {
        guard canEdit, !savingLinks, !run.revision.isEmpty else { return }
        var request = RPCRequest("criterion.files.prune")
        request.id = run.id
        request.expectedSequence = run.sequence
        request.payload = .object(["revision": .string(run.revision)])
        savingLinks = true
        linkError = nil
        Task {
            defer { savingLinks = false }
            do {
                _ = try await store.send(request)
                await store.refresh()
            } catch {
                linkError = error.localizedDescription
            }
        }
    }

    private func beginEditing() {
        guard canEdit else { return }
        baseline = run
        draft = run.criteria.isEmpty ? [Criterion()] : run.criteria
        error = nil
        editing = true
    }

    private func save() {
        guard canEdit, draftValid, !saving, var edited = baseline else { return }
        edited.criteria = draft.map { criterion in
            var updated = criterion
            updated.text = criterion.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return updated
        }
        var request = RPCRequest("plan.save")
        request.id = run.id
        request.expectedSequence = edited.sequence
        request.run = edited
        saving = true
        error = nil
        Task {
            defer { saving = false }
            do {
                _ = try await store.send(request)
                await store.refresh()
                editing = false
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func open(_ section: RunWorkspaceSection) {
        store.graph = nil
        store.runDetail = ChatRunDetail(runID: run.id, page: .section(section))
    }
}
