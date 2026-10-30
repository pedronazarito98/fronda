import HarnessDomain
import SwiftUI

struct RunInspector: View {
    var store: AppStore
    let run: Run
    @Binding var section: RunWorkspaceSection
    @Binding var isPresented: Bool
    private var actionsDisabled: Bool { !store.connected || store.busy.contains(run.id) }
    private var hasReportedTokens: Bool { run.tokens.contains { $0.input != nil || $0.output != nil } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Detalhes da execução").font(.headline)
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Ocultar detalhes").accessibilityLabel("Ocultar detalhes")
                }
                VStack(alignment: .leading, spacing: 16) {
                    item("Projeto", store.snapshot.projects.first { $0.id == run.projectID }?.name ?? "Projeto")
                    item("Runbook", "\(run.runbook.name) · v\(run.runbook.version)")
                    HStack(alignment: .top, spacing: 20) {
                        item("Executor", run.provider.rawValue)
                        item("Autonomia", run.mode.rawValue)
                    }
                }
                Divider()
                tokens
                Divider()
                VStack(alignment: .leading, spacing: 16) {
                    Label("Ambiente de trabalho", systemImage: "arrow.triangle.branch")
                        .font(.subheadline.weight(.semibold))
                    item("Branch", run.branch.isEmpty ? "Preparação pendente" : run.branch)
                    HStack(alignment: .top, spacing: 20) {
                        item(
                            "Base Git", run.baseSHA.isEmpty ? "Pendente" : String(run.baseSHA.prefix(12)),
                            monospaced: true)
                        item(
                            "Snapshot", run.revision.isEmpty ? "Pendente" : String(run.revision.prefix(12)),
                            monospaced: true)
                    }
                    Button {
                        store.reveal(run.workspace)
                    } label: {
                        Label("Abrir worktree no Finder", systemImage: "folder")
                    }
                    .disabled(run.workspace.isEmpty)
                    .accessibilityIdentifier("run.reveal-worktree")
                }
                DisclosureGroup("Escopo e rastreabilidade") {
                    VStack(alignment: .leading, spacing: 16) {
                        item("Escopo", run.scope.joined(separator: "\n"), monospaced: true)
                        item("Tentativas", run.attempts.count.formatted())
                        item("Criada", run.createdAt.formatted(date: .abbreviated, time: .shortened))
                        item("Última atualização", run.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        item("Identificador", run.id, monospaced: true)
                    }.padding(.top, 14)
                }.font(.caption)
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Menu {
                        ForEach(ProviderKind.allCases) { provider in
                            Button(provider.rawValue) {
                                store.perform("run.provider", id: run.id) { $0.text = provider.rawValue }
                            }
                        }
                    } label: {
                        Label("Trocar executor", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(run.state.active || actionsDisabled)
                    .accessibilityIdentifier("run.change-provider")
                    Text("Cria uma nova tentativa e exige revisão do contexto.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.regularMaterial)
        .accessibilityIdentifier("run.inspector-content")
    }

    private var tokens: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Orçamento de tokens").font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    section = .tokens
                } label: {
                    Image(systemName: "arrow.up.right")
                }
                .buttonStyle(.plain).help("Ver consumo de tokens")
                .accessibilityLabel("Ver consumo de tokens")
            }
            if hasReportedTokens {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(run.reportedTokens.formatted()).font(.system(size: 25, weight: .medium, design: .rounded))
                        .monospacedDigit()
                    Text("/ \(run.budget.formatted())").font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(
                    value: min(Double(run.reportedTokens), Double(max(1, run.budget))),
                    total: Double(max(1, run.budget))
                )
                .tint(run.reportedTokens > run.budget * 8 / 10 ? .orange : FrondaTheme.accent)
                .accessibilityLabel("Consumo do orçamento")
                .accessibilityValue("\(run.reportedTokens) de \(run.budget) tokens")
            } else {
                Text("Não informado").font(.title3.weight(.medium))
                Text("Orçamento: \(run.budget.formatted()) tokens").font(.caption).foregroundStyle(.secondary)
            }
            Text("Consumo informado pelo executor. Valores não informados não são estimados.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func item(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value.isEmpty ? "Não informado" : value)
                .font(.system(size: 11, design: monospaced ? .monospaced : .default))
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }
}
