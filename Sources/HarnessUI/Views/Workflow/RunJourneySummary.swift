import HarnessDomain
import SwiftUI

struct RunJourneySummary: View {
    let run: Run
    var openChanges: (() -> Void)? = nil
    var openValidation: (() -> Void)? = nil
    var openEvidence: (() -> Void)? = nil

    private var completedSteps: Int { run.plan.filter { $0.status == .pass }.count }
    private var skippedSteps: Int { run.plan.filter { $0.status == .skipped }.count }
    private var remainingSteps: Int { max(0, run.plan.count - completedSteps - skippedSteps) }
    private var confirmedCriteria: Int { run.criteria.filter { $0.state == "SATISFIED" }.count }
    private var validationResults: [ValidationResult] {
        Dictionary(grouping: run.validations, by: { $0.validator.id })
            .compactMap { $0.value.max { $0.createdAt < $1.createdAt } }
    }
    private var validationSummary: String {
        let statuses = validationResults.map { result in
            if result.status != .running, result.status != .notRun,
                !run.revision.isEmpty, result.revision != run.revision
            {
                return GateStatus.stale
            }
            return result.status
        }
        let order: [GateStatus] = [.pass, .fail, .blocked, .stale, .running, .notRun, .cancelled, .skipped]
        return
            order
            .compactMap { (status: GateStatus) -> String? in
                let count = statuses.filter { $0 == status }.count
                guard count > 0 else { return nil }
                return "\(count) \(status.rawValue.replacingOccurrences(of: "_", with: " "))"
            }
            .joined(separator: " · ")
    }
    private var evidenceSummary: String {
        var parts = [String]()
        let artifacts = run.evidenceArtifacts ?? []
        let observations = run.workflow?.observations ?? []
        if !artifacts.isEmpty {
            parts.append("\(artifacts.count) \(artifacts.count == 1 ? "arquivo" : "arquivos")")
        }
        if !observations.isEmpty {
            parts.append("\(observations.count) \(observations.count == 1 ? "cenário" : "cenários")")
        }
        if !run.criteria.isEmpty, confirmedCriteria > 0 || !parts.isEmpty {
            parts.append("\(confirmedCriteria)/\(run.criteria.count) critérios confirmados")
        }
        if parts.isEmpty, !run.report.isEmpty { parts.append("Relatório disponível") }
        return parts.joined(separator: " · ")
    }
    private var hasResults: Bool {
        !run.changedFiles.isEmpty || !run.validations.isEmpty || !evidenceSummary.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    progressLabel
                    Spacer(minLength: 8)
                    stateLabel
                }
                VStack(alignment: .leading, spacing: 8) {
                    progressLabel
                    stateLabel
                }
            }
            if !run.plan.isEmpty {
                HStack(spacing: 5) {
                    ForEach(run.plan) { step in
                        JourneyStepSegment(step: step)
                    }
                }
                Text(remainingDescription)
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if hasResults {
                Divider()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 18)], alignment: .leading, spacing: 12) {
                    if !run.changedFiles.isEmpty {
                        result(
                            title: "Arquivos alterados", detail: run.changedFiles.count.formatted(),
                            symbol: "doc.on.doc", identifier: "journey.changes", action: openChanges)
                    }
                    if !run.validations.isEmpty {
                        result(
                            title: "Validações", detail: validationSummary, symbol: "checkmark.shield",
                            identifier: "journey.validation", action: openValidation)
                    }
                    if !evidenceSummary.isEmpty {
                        result(
                            title: "Evidências", detail: evidenceSummary, symbol: "doc.richtext",
                            identifier: "journey.evidence", action: openEvidence)
                    }
                }
            }
        }
        .padding(17)
        .background(FrondaTheme.surface, in: RoundedRectangle(cornerRadius: FrondaTheme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: FrondaTheme.cornerRadius)
                .strokeBorder(FrondaTheme.border, lineWidth: 1)
        }
    }

    private var progressLabel: some View {
        Text(
            run.plan.isEmpty
                ? "O plano aparecerá após preparar o contexto."
                : "\(completedSteps) de \(run.plan.count) etapas concluídas"
        )
        .font(.system(size: 13, weight: .semibold)).monospacedDigit()
        .accessibilityIdentifier("journey.progress")
    }

    private var stateLabel: some View {
        Label(run.state.label, systemImage: RunDisplay.symbol(for: run.state))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(RunDisplay.color(for: run.state))
            .fixedSize()
            .accessibilityIdentifier("journey.state")
    }

    private var remainingDescription: String {
        let remaining = "\(remainingSteps) \(remainingSteps == 1 ? "etapa restante" : "etapas restantes")"
        guard skippedSteps > 0 else { return remaining }
        return "\(skippedSteps) \(skippedSteps == 1 ? "etapa dispensada" : "etapas dispensadas") · \(remaining)"
    }

    @ViewBuilder private func result(
        title: String, detail: String, symbol: String, identifier: String, action: (() -> Void)?
    ) -> some View {
        if let action {
            Button(action: action) {
                resultLabel(title: title, detail: detail, symbol: symbol, interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title): \(detail)")
            .accessibilityHint("Abrir \(title.lowercased())")
            .accessibilityIdentifier(identifier)
            .help(detail)
        } else {
            resultLabel(title: title, detail: detail, symbol: symbol, interactive: false)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(identifier)
        }
    }

    private func resultLabel(title: String, detail: String, symbol: String, interactive: Bool) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(FrondaTheme.accent)
                .padding(.top, 2).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(title).font(.system(size: 11, weight: .medium))
                    if interactive {
                        Image(systemName: "arrow.up.right").font(.system(size: 9))
                            .foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                }
                Text(detail).font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(2).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct JourneyStepSegment: View {
    let step: RunbookStep

    private var color: Color {
        switch step.status {
        case .pass: FrondaTheme.success
        case .running: FrondaTheme.accent
        case .fail: FrondaTheme.danger
        case .blocked, .stale: FrondaTheme.warning
        default: FrondaTheme.textMuted
        }
    }
    private var symbol: String {
        switch step.status {
        case .pass: "checkmark"
        case .running: "ellipsis"
        case .fail: "xmark"
        case .blocked, .stale: "exclamationmark"
        case .skipped: "minus"
        case .cancelled: "stop.fill"
        case .notRun: "circle"
        }
    }
    private var statusLabel: String {
        switch step.status {
        case .pass: "Concluída"
        case .running: "Em execução"
        case .fail: "Falhou"
        case .blocked: "Bloqueada"
        case .stale: "Desatualizada"
        case .skipped: "Dispensada"
        case .cancelled: "Cancelada"
        case .notRun: "Não executada"
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity).frame(height: 15)
            .background(color.opacity(step.status == .notRun ? 0.05 : 0.16), in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        color.opacity(step.status == .running ? 0.65 : 0.20),
                        style: StrokeStyle(lineWidth: 1, dash: step.status == .skipped ? [3, 2] : []))
            }
            .help("\(step.title): \(statusLabel)")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(step.title)
            .accessibilityValue(statusLabel)
            .accessibilityIdentifier("journey.segment." + step.id)
    }
}
