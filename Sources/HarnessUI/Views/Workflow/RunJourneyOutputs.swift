import HarnessDomain
import SwiftUI

struct RunJourneyOutputs: View {
    let run: Run
    let step: RunbookStep

    private var orderedFindings: [ReviewFinding] {
        run.findings.enumerated().sorted { lhs, rhs in
            let leftIsCurrent = lhs.element.revision == run.revision
            let rightIsCurrent = rhs.element.revision == run.revision
            if leftIsCurrent != rightIsCurrent { return leftIsCurrent }
            // Findings have no timestamp; newer records are appended by the coordinator.
            return lhs.offset > rhs.offset
        }.map { $0.element }
    }
    private var orderedArtifacts: [EvidenceArtifact] {
        (run.evidenceArtifacts ?? []).sorted { lhs, rhs in
            let leftIsCurrent = lhs.revision == run.revision
            let rightIsCurrent = rhs.revision == run.revision
            if leftIsCurrent != rightIsCurrent { return leftIsCurrent }
            return lhs.createdAt == rhs.createdAt ? lhs.id < rhs.id : lhs.createdAt > rhs.createdAt
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch step.kind {
            case "context": context
            case "investigation": investigation
            case "plan": plan
            case "implementation": implementation
            case "validation": validation
            case "review": review
            case "reproduction", "verification": observations
            case "evidence": evidence
            default: pending("Os resultados aparecerão aqui quando esta etapa for executada.")
            }
        }
    }

    @ViewBuilder private var context: some View {
        if let pack = run.pack {
            let files = pack.items.filter(\.included)
            Label("\(files.count) arquivos selecionados", systemImage: "doc.on.doc")
                .font(.headline).foregroundStyle(FrondaTheme.accent)
            Text(
                run.contextApproved
                    ? "Contexto autorizado para \(run.provider.rawValue)."
                    : "Confira o material que será usado por \(run.provider.rawValue) antes de autorizar a investigação."
            ).font(.callout).foregroundStyle(.secondary)
            ForEach(files.prefix(5)) { item in
                outputRow(item.path, detail: item.reason, symbol: "doc.text")
            }
            if files.count > 5 {
                Text("Mais \(files.count - 5) arquivos na seleção completa.").font(.caption).foregroundStyle(.secondary)
            }
            if files.isEmpty { pending("O contexto está preparado, sem arquivos de código incluídos.") }
        } else {
            pending("A seleção de arquivos aparecerá aqui após a preparação do contexto.")
        }
    }

    @ViewBuilder private var investigation: some View {
        if let text = run.workflow?.investigation, !text.isEmpty {
            report("O que foi descoberto", text: text)
        } else {
            pending(
                step.status == .running
                    ? "O executor está investigando o projeto. O diagnóstico aparecerá aqui quando for registrado."
                    : "O diagnóstico ainda não foi registrado.")
        }
    }

    @ViewBuilder private var plan: some View {
        if let proposal = run.workflow?.proposal, !proposal.isEmpty {
            report("Proposta para sua revisão", text: proposal)
        } else if run.workflow == nil, !run.plan.isEmpty {
            Text("\(run.plan.count) etapas definidas para este trabalho").font(.headline)
            Text("Explore as etapas ao lado e confira os critérios antes de autorizar a execução.")
                .font(.callout).foregroundStyle(.secondary)
        } else {
            pending("O plano será proposto a partir do diagnóstico e ficará disponível para sua revisão.")
        }
        criteria
    }

    @ViewBuilder private var implementation: some View {
        if !run.changedFiles.isEmpty {
            Text("O que mudou no projeto").font(.headline)
            ForEach(run.changedFiles.prefix(8)) { file in
                HStack(spacing: 12) {
                    Image(systemName: "doc.text").foregroundStyle(FrondaTheme.accent)
                    Text(file.path).font(.system(size: 12, design: .monospaced)).lineLimit(2)
                    Spacer(minLength: 0)
                    Text("+\(file.additions)").foregroundStyle(FrondaTheme.success)
                    Text("−\(file.deletions)").foregroundStyle(FrondaTheme.danger)
                }.font(.caption.monospacedDigit()).padding(12)
                    .background(FrondaTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            }
            if run.changedFiles.count > 8 {
                Text("Mais \(run.changedFiles.count - 8) arquivos na revisão completa.").font(.caption).foregroundStyle(
                    .secondary)
            }
        } else {
            pending(
                step.status == .running
                    ? "O executor está trabalhando. As alterações aparecerão quando forem registradas."
                    : "Nenhuma alteração registrada nesta revisão.")
        }
        if !run.report.isEmpty { report("Resultado informado pelo executor", text: run.report) }
    }

    @ViewBuilder private var validation: some View {
        let latest = Dictionary(grouping: run.validations, by: { $0.validator.id })
            .compactMap { $0.value.max { $0.createdAt < $1.createdAt } }
            .sorted { $0.validator.name.localizedStandardCompare($1.validator.name) == .orderedAscending }
        if latest.isEmpty {
            pending(
                "Nenhum comando de validação foi executado. Você pode conferir os comandos e acompanhar cada resultado."
            )
        } else {
            Text("Resultados dos comandos").font(.headline)
            ForEach(latest) { result in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.validator.name).font(.callout.weight(.medium))
                        if let exitCode = result.exitCode {
                            Text(
                                "Saída \(exitCode) · \(result.duration.formatted(.number.precision(.fractionLength(1)))) s"
                            )
                            .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    StatusBadge(
                        text: result.revision == run.revision ? result.status.rawValue : GateStatus.stale.rawValue)
                }.padding(14).background(FrondaTheme.surface, in: RoundedRectangle(cornerRadius: 11))
            }
        }
    }

    @ViewBuilder private var review: some View {
        if run.findings.isEmpty {
            pending(
                step.status == .pass
                    ? "A revisão foi concluída sem achados registrados."
                    : "Os achados da revisão aparecerão aqui quando forem registrados.")
        } else {
            Text("Pontos encontrados na revisão").font(.headline)
            ForEach(orderedFindings.prefix(6)) { finding in
                outputRow(
                    finding.title, detail: "\(finding.severity) · \(finding.path) · \(finding.state)",
                    symbol: "text.magnifyingglass",
                    status: finding.revision == run.revision ? finding.state : "STALE")
            }
            if run.findings.count > 6 {
                let remaining = run.findings.count - 6
                Text("Mais \(remaining) \(remaining == 1 ? "achado" : "achados") na revisão completa.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var observations: some View {
        let items = (run.workflow?.observations ?? []).filter {
            step.kind == "reproduction" ? $0.phase == .before : $0.phase != .before
        }
        if items.isEmpty {
            pending(
                step.kind == "reproduction"
                    ? "Registre como o problema acontece, o resultado esperado e o comportamento observado."
                    : "Confira o resultado no cenário real e registre a observação, com imagem ou vídeo quando necessário."
            )
        } else {
            ForEach(items) { item in
                Surface(padding: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(item.scenario).font(.headline)
                            Spacer()
                            StatusBadge(
                                text: item.phase != .before && item.revision != run.revision
                                    ? "STALE" : item.status.rawValue)
                        }
                        Text(item.phase.label).font(.caption).foregroundStyle(.secondary)
                        MarkdownView(item.observed)
                    }
                }
            }
        }
    }

    @ViewBuilder private var evidence: some View {
        criteria
        ForEach(orderedArtifacts.prefix(5)) { artifact in
            outputRow(
                artifact.title, detail: "\(artifact.source) · \(artifact.mimeType)", symbol: "doc.richtext",
                status: artifact.revision == run.revision ? "RECEIVED" : "STALE")
        }
        if orderedArtifacts.count > 5 {
            let remaining = orderedArtifacts.count - 5
            Text("Mais \(remaining) \(remaining == 1 ? "artefato" : "artefatos") na galeria completa.")
                .font(.caption).foregroundStyle(.secondary)
        }
        if let delivery = run.workflow?.delivery, let url = delivery.pullRequestURL {
            outputRow("Pull request registrado", detail: url, symbol: "arrow.triangle.pull")
        }
        if !run.report.isEmpty { report("Resultado da execução", text: run.report) }
        if run.criteria.isEmpty && (run.evidenceArtifacts ?? []).isEmpty && run.report.isEmpty {
            pending("As evidências da execução serão reunidas aqui para conferir a entrega.")
        }
    }

    @ViewBuilder private var criteria: some View {
        if !run.criteria.isEmpty {
            Text("O que precisa ser atendido").font(.headline)
            ForEach(run.criteria) { criterion in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: criterion.state == "SATISFIED" ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(criterion.state == "SATISFIED" ? FrondaTheme.success : .secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(criterion.text).font(.callout)
                        Text(criterion.state == "SATISFIED" ? "Confirmado" : "Ainda não confirmado")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 4)
            }
        }
    }

    private func pending(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle").foregroundStyle(FrondaTheme.accent).padding(.top, 2)
            Text(text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(17).frame(maxWidth: .infinity, alignment: .leading)
            .background(FrondaTheme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func outputRow(_ title: String, detail: String, symbol: String, status: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol).foregroundStyle(FrondaTheme.accent).frame(width: 18)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.callout.weight(.medium)).textSelection(.enabled)
                if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(3) }
            }
            if let status {
                Spacer(minLength: 8)
                StatusBadge(text: status, compact: true).fixedSize()
            }
        }.padding(13).frame(maxWidth: .infinity, alignment: .leading)
            .background(FrondaTheme.surface, in: RoundedRectangle(cornerRadius: 11))
    }

    private func report(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            Surface(padding: 18) { MarkdownView(text) }
        }
    }
}
