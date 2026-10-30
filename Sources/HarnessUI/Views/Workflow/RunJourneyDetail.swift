import HarnessDomain
import SwiftUI

struct RunJourneyDetail: View {
    let run: Run
    let selected: RunJourneyStep
    let onOpen: (RunWorkspaceSection) -> Void
    let onSelectStep: (String) -> Void

    private var destination: RunWorkspaceSection { .destination(for: selected.step) }
    private var actionTitle: String {
        switch selected.step.kind {
        case "context": "Conferir arquivos e contexto"
        case "investigation": "Abrir diagnóstico e plano"
        case "plan": "Revisar plano completo"
        case "implementation": "Examinar alterações"
        case "validation": "Conferir e executar validações"
        case "reproduction": "Registrar ou conferir reprodução"
        case "verification": "Registrar ou conferir resultado"
        case "review": "Abrir revisão e achados"
        case "evidence": "Conferir entrega e evidências"
        default: "Abrir detalhes"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heading
                Button {
                    onOpen(destination)
                } label: {
                    Label(actionTitle, systemImage: destination.symbol)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityIdentifier("journey.open-stage")
                .padding(.bottom, 4)
                if let blocker = selected.blocker, !blocker.isEmpty {
                    Label {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("O que está impedindo o avanço").font(.callout.weight(.semibold))
                            Text(blocker).font(.callout).textSelection(.enabled)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.circle.fill")
                    }
                    .foregroundStyle(FrondaTheme.warning)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(FrondaTheme.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                if let dependencies = selected.dependencySummary {
                    VStack(alignment: .leading, spacing: 9) {
                        Label(dependencies, systemImage: "link")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(run.plan.filter { selected.step.dependencies.contains($0.id) }) { step in
                            Button {
                                onSelectStep(step.id)
                            } label: {
                                Label(step.title, systemImage: "arrow.turn.up.left")
                            }.font(.caption).buttonStyle(.link)
                        }
                    }
                }
                RunJourneyOutputs(run: run, step: selected.step)
                Surface(padding: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "flag.checkered").foregroundStyle(FrondaTheme.accent).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("O que esta etapa entrega").font(.caption.weight(.semibold))
                            Text(selected.expectedOutcome).font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .id(selected.id)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("ETAPA \(selected.number)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Label(selected.state.label, systemImage: selected.state.symbol)
                    .font(.caption.weight(.medium)).foregroundStyle(selected.state.color)
                    .accessibilityIdentifier("journey.selected-status")
            }
            Text(selected.title).font(.system(size: 25, weight: .semibold)).tracking(-0.5)
                .accessibilityIdentifier("journey.selected-title")
            Text(selected.detail).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if selected.step.usesAgent {
                Label(
                    "\((selected.step.provider ?? run.provider).rawValue) · \(selected.step.execution(in: run).summary)",
                    systemImage: "cpu"
                )
                .font(.caption).foregroundStyle(FrondaTheme.accent)
            }
        }
    }
}
