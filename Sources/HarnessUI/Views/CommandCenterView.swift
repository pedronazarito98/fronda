import HarnessDomain
import SwiftUI

struct CommandCenterView: View {
    @Bindable var store: AppStore
    @State private var intent = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 27) {
                HStack(alignment: .top) {
                    PageHeading(
                        eyebrow: "Seu trabalho, em perspectiva", title: "Command Center",
                        subtitle: "Da intenção à evidência. Cada execução tem seu lugar.")
                    Button {
                        store.perform("queue.toggle")
                    } label: {
                        Label(
                            store.snapshot.preferences.queuePaused ? "Retomar fila" : "Pausar fila",
                            systemImage: store.snapshot.preferences.queuePaused ? "play" : "pause")
                    }.controlSize(.small)
                }
                Surface(padding: 23) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "sparkle").foregroundStyle(HarnessTheme.accent)
                            Text("O que vamos construir?").font(.system(size: 17, weight: .medium))
                            Spacer()
                            Text("⌘ N").font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                        }
                        TextField(
                            "Descreva uma tarefa, cole uma issue ou uma URL de PR…", text: $intent, axis: .vertical
                        ).textFieldStyle(.plain).font(.system(size: 14)).lineLimit(2...4).padding(.vertical, 10)
                            .onSubmit { compose() }
                        Divider()
                        HStack {
                            Label("Contexto selecionado por você", systemImage: "slider.horizontal.3").font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                compose()
                            } label: {
                                Label("Preparar run", systemImage: "arrow.up.right")
                            }.buttonStyle(.borderedProminent).controlSize(.large)
                        }
                    }
                }
                HStack(spacing: 14) {
                    Metric(
                        title: "Em execução", value: "\(store.activeRuns.count)", symbol: "waveform.path", color: .blue)
                    Metric(
                        title: "Aguardando você", value: "\(store.pendingDecisions)", symbol: "hand.raised",
                        color: .orange)
                    Metric(
                        title: "Na fila", value: "\(store.snapshot.runs.filter { $0.state == .queued }.count)",
                        symbol: "line.3.horizontal", color: .secondary)
                    Metric(
                        title: "Tokens reportados",
                        value: store.snapshot.runs.reduce(0) { $0 + $1.reportedTokens }.formatted(),
                        symbol: "chart.bar.xaxis", color: .green)
                }
                if store.snapshot.projects.isEmpty {
                    Surface {
                        HStack(spacing: 24) {
                            Image(systemName: "folder.badge.plus").font(.system(size: 36, weight: .ultraLight))
                                .foregroundStyle(HarnessTheme.accent).frame(width: 70)
                            VStack(alignment: .leading, spacing: 7) {
                                Text("Comece pelo seu projeto").font(.system(size: 18, weight: .semibold))
                                Text(
                                    "Adicione um repositório Git para selecionar contexto, configurar validações e trabalhar em worktrees isoladas."
                                ).font(.callout).foregroundStyle(.secondary).fixedSize(
                                    horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 16)
                            Button("Adicionar projeto…") { store.addProject() }.controlSize(.large)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 13) {
                        SectionHeading(
                            title: "Em foco",
                            detail: "\(store.snapshot.runs.filter { !$0.state.terminal }.count) runs em andamento")
                        if store.snapshot.runs.isEmpty {
                            Surface(padding: 0) {
                                EmptyPanel(
                                    symbol: "play.rectangle", title: "Tudo pronto para sua primeira run",
                                    detail:
                                        "Escolha um runbook abaixo ou descreva seu objetivo. O plano e o contexto aparecem antes da execução."
                                )
                            }
                        }
                        ForEach(store.snapshot.runs.filter { $0.state != .archived }.prefix(4)) { run in
                            RunRow(store: store, run: run)
                        }
                    }
                }
                HStack(alignment: .top, spacing: 22) {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeading(title: "Um bom ponto de partida", detail: "RUNBOOKS")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(store.snapshot.runbooks.prefix(4)) { book in
                                Button {
                                    store.composerText = ""
                                    store.showComposer = true
                                } label: {
                                    Surface(padding: 16) {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Image(systemName: book.symbol).font(.system(size: 18)).foregroundStyle(
                                                HarnessTheme.accent)
                                            Text(book.name).font(.system(size: 13, weight: .semibold))
                                            Text(book.subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                                                .lineLimit(2).frame(height: 30, alignment: .topLeading)
                                        }
                                    }
                                }.buttonStyle(.plain)
                            }
                        }
                    }.frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeading(title: "Seus executores", detail: "PROVIDERS")
                        Surface(padding: 17) {
                            VStack(alignment: .leading, spacing: 19) {
                                ForEach(store.snapshot.providers) { provider in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "terminal").foregroundStyle(.secondary)
                                            Text(provider.kind.rawValue).fontWeight(.medium)
                                            Spacer()
                                            Circle().fill(provider.state == "AVAILABLE" ? .green : .orange).frame(
                                                width: 6, height: 6)
                                        }
                                        Text(provider.version).font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                        Text(
                                            provider.state == "AVAILABLE"
                                                ? "Pronto para uma nova execução" : provider.detail
                                        ).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(
                                            horizontal: false, vertical: true)
                                    }
                                    if provider.kind == .codex { Divider() }
                                }
                                SettingsLink { Label("Configurar providers", systemImage: "arrow.up.right") }.font(
                                    .caption
                                ).buttonStyle(.plain).foregroundStyle(HarnessTheme.accent)
                            }
                        }
                    }.frame(width: 270)
                }
                HStack {
                    Image(systemName: "internaldrive")
                    Text("Seus projetos, contexto e evidências ficam neste Mac.")
                    Spacer()
                    Text("HARNESS / 01").font(.system(size: 9, design: .monospaced)).tracking(1.2)
                }.font(.system(size: 10)).foregroundStyle(.tertiary).padding(.top, 2)
            }.padding(32).frame(maxWidth: 1250)
        }
    }
    private func compose() {
        store.composerText = intent
        store.showComposer = true
    }
}

struct RunRow: View {
    var store: AppStore
    let run: Run
    var body: some View {
        Button {
            store.route = "run:" + run.id
        } label: {
            Surface(padding: 16) {
                HStack(spacing: 16) {
                    Image(systemName: run.runbook.symbol).font(.system(size: 20, weight: .light)).foregroundStyle(
                        HarnessTheme.accent
                    ).frame(width: 30)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(run.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text(
                            "\(store.snapshot.projects.first { $0.id == run.projectID }?.name ?? "Projeto")  ·  \(run.provider.rawValue)  ·  \(run.completedSteps)/\(run.plan.count) etapas"
                        ).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(text: run.state.rawValue)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }.buttonStyle(.plain)
    }
}
