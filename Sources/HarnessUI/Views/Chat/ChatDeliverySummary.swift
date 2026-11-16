import HarnessDomain
import SwiftUI

/// A compact, evidence-based account of what is available from this execution.
struct ChatDeliverySummary: View {
    let store: AppStore
    let run: Run
    let sequence: Int?

    private var hasResult: Bool {
        !run.changedFiles.isEmpty || !run.validations.isEmpty || !(run.evidenceArtifacts ?? []).isEmpty
            || [.ready, .partial, .failed, .blocked].contains(run.state)
    }

    private var showsSummary: Bool {
        !run.state.active && run.state != .queued && !run.isPauseRequested && hasResult
    }

    private var currentChecks: [ValidationResult] {
        guard !run.revision.isEmpty else { return [] }
        var seen = Set<String>()
        return run.validations.reversed().filter {
            $0.revision == run.revision && seen.insert($0.validator.id).inserted
        }.reversed()
    }

    private var passedChecks: Int {
        currentChecks.filter { $0.status == .pass && $0.exitCode == 0 }.count
    }

    private var failedChecks: Int {
        currentChecks.filter { $0.status == .fail }.count
    }

    private var pendingChecks: Int { currentChecks.count - passedChecks - failedChecks }

    private var confirmedCriteria: Int {
        run.criteria.filter(isConfirmed).count
    }

    private var currentArtifacts: Int {
        guard !run.revision.isEmpty else { return 0 }
        return (run.evidenceArtifacts ?? []).filter { $0.revision == run.revision }.count
    }

    private var requiredChecks: [Validator]? {
        guard sequence == nil, let project = store.snapshot.projects.first(where: { $0.id == run.projectID }) else {
            return nil
        }
        return run.runbook.validators(for: project).filter(\.required)
    }

    private var missingRequiredChecks: [Validator] {
        (requiredChecks ?? []).filter { validator in
            !currentChecks.contains {
                $0.validator == validator && $0.status == .pass && $0.exitCode == 0
            }
        }
    }

    private var pendingItems: [String] {
        var items = [String]()
        if requiredChecks?.isEmpty == true && run.mode.writes {
            items.append("Cadastrar uma verificação obrigatória para esta tarefa.")
        }
        items += missingRequiredChecks.compactMap { validator in
            if currentChecks.contains(where: { $0.validator.id == validator.id && $0.status == .fail }) { return nil }
            let name = validator.name.isEmpty ? validator.displayCommand : validator.name
            return validator.approved
                ? "Verificação obrigatória sem aprovação nesta versão: \(name)"
                : "Aprovar verificação obrigatória: \(name)"
        }
        if run.criteria.isEmpty {
            items.append("Definir o resultado esperado da tarefa.")
        } else {
            items += run.criteria.filter { !isConfirmed($0) }.map {
                $0.isGenericPlaceholder ? "Detalhar o resultado esperado." : "Confirmar: \($0.text)"
            }
        }
        items += currentChecks.filter { $0.status == .fail }.map {
            "Verificação com falha: \($0.validator.name.isEmpty ? $0.validator.displayCommand : $0.validator.name)"
        }
        if !run.changedFiles.isEmpty {
            let unrelated = run.criteria.filter { criterion in
                !run.changedFiles.contains(where: { $0.linkedCriteria.contains(criterion.id) })
            }
            if !unrelated.isEmpty {
                items.append("\(unrelated.count) critério(s) sem arquivo relacionado; confira se precisam de vínculo.")
            }
        }
        let findings = run.findings.filter { ["OPEN", "ACCEPTED_RISK"].contains($0.state) }
        if !findings.isEmpty {
            items.append("\(findings.count) achado(s) precisam de conferência para concluir.")
        }
        return items
    }

    var body: some View {
        if showsSummary {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label(
                        [.ready, .partial].contains(run.state) ? "Entrega" : "Trabalho até agora",
                        systemImage: "tray.full"
                    )
                    .font(.callout.weight(.semibold))
                    Spacer(minLength: 4)
                    Text(title).font(.caption.weight(.medium)).foregroundStyle(titleColor)
                }

                VStack(alignment: .leading, spacing: 10) {
                    summaryRow("Alterações", icon: "doc.text", detail: changesDescription)
                    if !run.changedFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(run.changedFiles.prefix(3))) { file in
                                Text(file.path).font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                            }
                            if run.changedFiles.count > 3 {
                                Text("Mais \(run.changedFiles.count - 3) arquivo(s).")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(FrondaTheme.textMuted)
                        .padding(.leading, 23)
                    }
                    summaryRow("Verificações", icon: "checkmark.circle", detail: checksDescription)
                    summaryRow("Critérios", icon: "checklist", detail: criteriaDescription)
                    if currentArtifacts > 0 {
                        summaryRow("Evidências", icon: "paperclip", detail: artifactsDescription)
                    }
                    if !pendingItems.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("O que falta").font(.caption.weight(.semibold))
                            ForEach(Array(pendingItems.prefix(3).enumerated()), id: \.offset) { _, item in
                                Text("• " + item).font(.callout).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if pendingItems.count > 3 {
                                Text("Mais \(pendingItems.count - 3) pendência(s) na tarefa.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, 23)
                    }
                }

                if sequence == nil {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 14) { actions }
                        VStack(alignment: .leading, spacing: 8) { actions }
                    }
                    .buttonStyle(.link).font(.caption)
                } else {
                    Text("Resumo registrado neste envio. Os arquivos da pasta podem ter mudado depois.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(FrondaTheme.border.opacity(0.8))
            }
            .accessibilityIdentifier("chat.delivery.summary")
        }
    }

    private var title: String {
        if run.needsPauseReview || run.hasAcknowledgedPause {
            return "Último estado registrado"
        }
        if run.state == .ready
            && (!missingRequiredChecks.isEmpty || (requiredChecks?.isEmpty == true && run.mode.writes))
        {
            return "Verificações precisam de atenção"
        }
        return switch run.state {
        case .ready: "Pronta para conferir"
        case .partial: "Há pendências"
        case .draft: "Em preparação"
        case .waitingUser: "Aguardando decisão"
        case .paused, .recovering: "Resultado até a pausa"
        case .cancelled, .archived: "Último resultado registrado"
        case .blocked, .failed: "Trabalho interrompido"
        default: "Resultado disponível"
        }
    }

    private var titleColor: Color {
        run.state == .ready && missingRequiredChecks.isEmpty && !(requiredChecks?.isEmpty == true && run.mode.writes)
            ? FrondaTheme.success : FrondaTheme.textMuted
    }

    private var changesDescription: String {
        switch run.changedFiles.count {
        case 0: "Nenhuma alteração de arquivo registrada."
        case 1: "1 arquivo com alteração registrada."
        default: "\(run.changedFiles.count) arquivos com alterações registradas."
        }
    }

    private var checksDescription: String {
        guard !currentChecks.isEmpty else {
            return run.validations.isEmpty
                ? "Nenhuma verificação registrada nesta versão."
                : "Nenhum resultado atual; existem verificações de versões anteriores."
        }
        var parts = [String]()
        if passedChecks > 0 { parts.append("\(passedChecks) aprovada(s)") }
        if failedChecks > 0 { parts.append("\(failedChecks) com falha") }
        if pendingChecks > 0 { parts.append("\(pendingChecks) sem resultado confirmado") }
        return parts.joined(separator: " · ") + " nesta versão."
    }

    private var criteriaDescription: String {
        guard !run.criteria.isEmpty else { return "Nenhum critério registrado." }
        return "\(confirmedCriteria) de \(run.criteria.count) confirmado(s) na revisão desta versão."
    }

    private var artifactsDescription: String {
        "\(currentArtifacts) evidência(s) registrada(s) nesta versão."
    }

    @ViewBuilder private var actions: some View {
        if !run.changedFiles.isEmpty {
            Button("Ver alterações") { open(.changes) }
                .accessibilityIdentifier("chat.delivery.changes")
        }
        Button("Arquivos e entregas") { open(.files) }
            .accessibilityIdentifier("chat.delivery.files")
        if !run.validations.isEmpty || !missingRequiredChecks.isEmpty
            || (requiredChecks?.isEmpty == true && run.mode.writes)
        {
            Button("Verificações") { open(.validation) }
                .accessibilityIdentifier("chat.delivery.validation")
        }
        if currentArtifacts > 0 {
            Button("Evidências") { open(.evidence) }
                .accessibilityIdentifier("chat.delivery.evidence")
        }
    }

    private func isConfirmed(_ criterion: Criterion) -> Bool {
        !run.revision.isEmpty && run.humanReviewRevision == run.revision && !criterion.isGenericPlaceholder
            && criterion.state == "SATISFIED" && criterion.evidence.contains("human-review:" + run.revision)
    }

    private func summaryRow(_ title: String, icon: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).frame(width: 15).foregroundStyle(FrondaTheme.textMuted)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func open(_ section: RunWorkspaceSection) {
        store.graph = nil
        store.runDetail = ChatRunDetail(runID: run.id, page: .section(section))
    }
}
