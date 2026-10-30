import HarnessDomain
import SwiftUI

struct MenuBarView: View {
    var store: AppStore
    var island: SessionIslandController
    var companion: MascotCompanionController
    @Environment(\.openWindow) private var openWindow

    private var work: [Run] {
        store.snapshot.runs.filter { RunDisplay.needsAttention($0) || !$0.state.terminal }
            .sorted(by: RunDisplay.attentionOrder)
    }
    private var attentionCount: Int { work.filter(RunDisplay.needsAttention).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                FrondaWordmark(width: 120)
                Spacer()
                Button {
                    openMain()
                } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.plain).help("Abrir Fronda").accessibilityLabel("Abrir Fronda")
            }
            HStack(spacing: 12) {
                Label("\(store.activeRuns.count) em execução", systemImage: "circle.dotted")
                Spacer(minLength: 0)
                if attentionCount > 0 {
                    Label("\(attentionCount) para conferir", systemImage: "hand.raised")
                        .foregroundStyle(FrondaTheme.warning)
                }
            }.font(.caption).foregroundStyle(.secondary)
            Divider()
            if work.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Tudo em dia").font(.callout.weight(.medium))
                    Text("Prepare uma tarefa e acompanhe por aqui.").font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            }
            ForEach(work.prefix(5)) { run in
                Button {
                    open(run.id)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: RunDisplay.symbol(for: run.state))
                            .foregroundStyle(RunDisplay.color(for: run.state)).frame(width: 18).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(run.title).font(.system(size: 12, weight: .medium)).lineLimit(2)
                            Text(RunDisplay.nextAction(for: run)).font(.caption2).foregroundStyle(.secondary).lineLimit(
                                1)
                        }
                        Spacer(minLength: 0)
                    }.contentShape(Rectangle()).padding(.vertical, 3)
                }.buttonStyle(.plain)
            }
            Divider()
            HStack {
                Button("Nova tarefa…") {
                    openMain()
                    store.showComposer = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.showComposer || store.showPalette)
                Spacer()
                Button {
                    store.perform("queue.toggle")
                } label: {
                    Image(systemName: store.snapshot.preferences.queuePaused ? "play" : "pause")
                }
                .help(store.snapshot.preferences.queuePaused ? "Retomar fila" : "Pausar fila")
                .accessibilityLabel(store.snapshot.preferences.queuePaused ? "Retomar fila" : "Pausar fila")
                .disabled(!store.connected || store.busy.contains("queue.toggle"))
            }
            Button(companion.enabled ? "Ocultar companheiro" : "Mostrar companheiro", systemImage: "leaf") {
                companion.toggle()
            }.buttonStyle(.plain).font(.caption).accessibilityIdentifier("menubar.mascot-toggle")
            Button {
                island.toggle()
            } label: {
                HStack {
                    Label("Central de sessões", systemImage: "rectangle.topthird.inset.filled")
                    Spacer()
                    Text("⌥⌘I").font(.system(size: 10, design: .monospaced))
                }.font(.caption).foregroundStyle(.secondary)
            }.buttonStyle(.plain)
        }
        .padding(20).frame(width: 350).tint(FrondaTheme.accent)
        .preferredColorScheme(store.colorScheme)
    }

    private func openMain() {
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func open(_ id: String) {
        store.route = "run:" + id
        openMain()
    }
}
