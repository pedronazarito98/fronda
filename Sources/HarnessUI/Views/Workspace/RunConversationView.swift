import HarnessDomain
import SwiftUI

struct RunConversationView: View {
    let store: AppStore
    let run: Run
    @Binding var section: RunWorkspaceSection
    @Environment(\.workspaceNavigation) private var navigation
    @Environment(\.openWindow) private var openWindow
    @State private var expandedObjective = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .trailing, spacing: 8) {
                    Text("Objetivo e orientações").font(.caption).foregroundStyle(.secondary)
                    Text(run.source.text)
                        .font(.system(size: 13)).textSelection(.enabled)
                        .lineLimit(expandedObjective ? nil : 8)
                        .padding(16).background(FrondaTheme.canvas, in: RoundedRectangle(cornerRadius: 16))
                    if run.source.text.count > 400 {
                        Button(expandedObjective ? "Recolher objetivo" : "Ler objetivo completo") {
                            expandedObjective.toggle()
                        }
                        .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .trailing).padding(.leading, 28)

                if !run.report.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Resultado mais recente", systemImage: "leaf").font(.caption).foregroundStyle(.secondary)
                        MarkdownView(run.report)
                    }
                } else if let investigation = run.workflow?.investigation, !investigation.isEmpty {
                    MarkdownView(investigation)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            run.state.active ? "Trabalho em andamento" : run.stageLabel,
                            systemImage: RunDisplay.symbol(for: run.state)
                        ).font(.subheadline.weight(.medium))
                        Text(run.reason.isEmpty ? "O resultado aparecerá aqui conforme a tarefa avançar." : run.reason)
                            .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }

                VStack(spacing: 10) {
                    document(
                        "Plano da tarefa", detail: "\(run.plan.count) etapas · revisão \(run.planRevision)",
                        destination: .plan)
                    if !run.changedFiles.isEmpty {
                        document("Alterações", detail: "\(run.changedFiles.count) arquivos", destination: .changes)
                    }
                }
                Button {
                    store.workspace.openBeside(
                        WorkspaceLocation(route: "run:" + run.id, section: .plan), from: navigation)
                    openWindow(id: "main")
                } label: {
                    Label("Abrir plano ao lado", systemImage: "arrow.up.right")
                }.buttonStyle(.plain).font(.callout).foregroundStyle(FrondaTheme.clay)

                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Próximo passo").font(.subheadline.weight(.semibold))
                    Text(RunDisplay.nextAction(for: run)).font(.callout).foregroundStyle(.secondary)
                    if let step = run.currentStep {
                        Button(step.title) { section = RunWorkspaceSection.destination(for: step) }
                            .buttonStyle(.plain).font(.caption).foregroundStyle(FrondaTheme.accent)
                    }
                }
            }
            .padding(24).frame(maxWidth: 780).frame(maxWidth: .infinity)
        }
        .rememberScrollPosition("run.\(run.id).conversation")
        .accessibilityIdentifier("run.conversation")
    }

    private func document(_ title: String, detail: String, destination: RunWorkspaceSection) -> some View {
        Button {
            section = destination
        } label: {
            HStack(spacing: 12) {
                Image(systemName: destination.symbol).font(.system(size: 22)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 13, weight: .medium))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
            }
            .padding(14).contentShape(Rectangle())
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FrondaTheme.border))
        }.buttonStyle(.plain)
    }
}
