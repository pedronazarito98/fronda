import HarnessDomain
import SwiftUI

/// A recovery summary is derived from persisted state, without asserting that interrupted work completed.
struct ChatRecoverySummary: View {
    let store: AppStore
    let run: Run

    private var pendingOperation: Bool {
        Self.hasPendingOperation(run)
    }

    static func hasPendingOperation(_ run: Run) -> Bool {
        run.hasUnresolvedExternalOperations
    }

    private var lastStep: String {
        guard let attempt = run.attempts.last,
            let step = run.plan.first(where: { $0.id == attempt.stepID })
        else { return "Nenhuma tentativa de etapa registrada." }
        return step.title + (attempt.status == "INTERRUPTED_UNKNOWN" ? " · término não confirmado" : "")
    }

    private var checks: String {
        guard let project = store.snapshot.projects.first(where: { $0.id == run.projectID }) else {
            return "Projeto indisponível para conferir as verificações."
        }
        let required = run.runbook.validators(for: project).filter(\.required)
        guard !required.isEmpty else { return "Nenhuma verificação obrigatória cadastrada." }
        let results = RunFollowupEvidence.latestValidations(in: run)
        let confirmed = required.filter { validator in
            results.contains { $0.validator == validator && RunFollowupEvidence.validationIsConfirmed($0, in: run) }
        }.count
        return "\(confirmed) de \(required.count) verificações obrigatórias comprovadas nesta versão."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(
                [.paused, .recovering].contains(run.state) ? "De onde continuar" : "Antes de continuar",
                systemImage: "arrow.uturn.forward.circle"
            )
            .font(.callout.weight(.semibold))
            row("Objetivo", run.title.isEmpty ? "Não registrado." : run.title)
            row("Última tentativa do executor", lastStep)
            row("Versão", run.revision.isEmpty ? "Ainda não registrada." : String(run.revision.prefix(12)))
            row(
                "Autorizações",
                (run.contextApproved ? "Contexto autorizado" : "Contexto pendente")
                    + " · " + (run.planApproved ? "plano aprovado" : "plano pendente"))
            row("Verificações", checks)
            if let remaining = RunFollowupModel(run: run, isConnected: store.connected).remaining.first {
                row("Pendente", remaining)
            }
            if pendingOperation {
                Label(
                    "Há uma operação pendente ou sem resultado confirmado. Confira antes de retomar.",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(FrondaTheme.warning)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
                if run.approvals.contains(where: { ["PREPARED", "APPROVED", "SENDING", "UNKNOWN"].contains($0.state) })
                {
                    Button("Conferir operações") {
                        store.runDetail = ChatRunDetail(runID: run.id, page: .action(.operations))
                    }
                    .buttonStyle(.link).font(.caption)
                }
                if run.extensionInvocations?.contains(where: { ["RUNNING", "UNKNOWN"].contains($0.state) }) == true {
                    Button("Conferir chamadas de ferramentas") {
                        store.runDetail = ChatRunDetail(runID: run.id, page: .section(.evidence))
                    }
                    .buttonStyle(.link).font(.caption)
                }
            } else {
                Text(
                    "Confira as alterações preservadas. Ao retomar, o Fronda confere o estado e inicia outra tentativa se necessário."
                )
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Conferir alterações") {
                        store.runDetail = ChatRunDetail(runID: run.id, page: .section(.changes))
                    }
                    if run.state == .recovering {
                        Button("Retomar") {
                            store.perform("run.resume", id: run.id) { $0.expectedSequence = run.sequence }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!store.connected || store.busy.contains(run.id))
                        .accessibilityIdentifier("run.recovery.resume")
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrondaTheme.canvas.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("chat.recovery")
    }

    private func row(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(title + ":").fontWeight(.medium)
            Text(detail).foregroundStyle(.secondary).textSelection(.enabled)
        }
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
    }
}
