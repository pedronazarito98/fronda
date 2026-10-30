import HarnessDomain
import SwiftUI

struct CommandCenterView: View {
    var store: AppStore
    @State private var layout = HomeLayoutStore()
    @State private var organizing = false
    @Environment(\.workspaceNavigation) private var navigation
    @Environment(\.workspaceShowsSummary) private var showsSummary

    private var visibleRuns: [Run] { store.snapshot.runs.filter { $0.state != .archived } }
    private var attentionRuns: [Run] {
        visibleRuns.filter(RunDisplay.needsAttention).sorted(by: RunDisplay.attentionOrder)
    }
    private var continuingRuns: [Run] {
        visibleRuns.filter { !$0.state.terminal && !RunDisplay.needsAttention($0) }.sorted {
            if $0.state.active != $1.state.active { return $0.state.active }
            return $0.updatedAt == $1.updatedAt ? $0.id < $1.id : $0.updatedAt > $1.updatedAt
        }
    }
    private var recentRuns: [Run] {
        visibleRuns.sorted { $0.updatedAt == $1.updatedAt ? $0.id < $1.id : $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if organizing { organizationControls }
                HomeCardBoard(layout: layout, organizing: organizing, count: count) { cardContent($0) }
                footer
            }
            .padding(28).frame(maxWidth: 1440).frame(maxWidth: .infinity)
        }
        .rememberScrollPosition("center")
        .accessibilityIdentifier("command-center")
        .onChange(of: organizing) { _, value in navigation?.isEditingLayout = value }
        .onDisappear { navigation?.isEditingLayout = false }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    title
                    Spacer(minLength: 20)
                    headerActions
                }
                VStack(alignment: .leading, spacing: 16) {
                    title
                    headerActions
                }
            }
            if showsSummary {
                HStack(spacing: 15) {
                    if !attentionRuns.isEmpty {
                        Button {
                            if let run = attentionRuns.first { store.route = "run:" + run.id }
                        } label: {
                            Label("\(attentionRuns.count) pedem atenção", systemImage: "hand.raised")
                        }.buttonStyle(.plain).foregroundStyle(FrondaTheme.clay)
                            .accessibilityIdentifier("home.attention-summary")
                    }
                    Text(
                        store.activeRuns.isEmpty
                            ? "Seu espaço para criar e acompanhar." : "\(store.activeRuns.count) em execução"
                    )
                    .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    HomeEnvironmentButton(store: store)
                }.font(.caption)
            }
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Visão geral").font(.system(size: 20, weight: .semibold))
        }
    }

    private var headerActions: some View {
        HStack(spacing: 10) {
            Button(organizing ? "Concluir" : "Organizar", systemImage: organizing ? "checkmark" : "slider.horizontal.3")
            {
                organizing.toggle()
            }.accessibilityIdentifier("home.organize")
                .help(
                    organizing ? "Concluir a organização dos cards" : "Mover, redimensionar e escolher os cards da Home"
                )
            if !organizing {
                Button("Nova tarefa", systemImage: "plus") { store.showComposer = true }
                    .buttonStyle(.borderedProminent)
            }
        }.controlSize(.regular).fixedSize()
    }

    private var organizationControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Arraste pela alça ou redimensione pelo canto. A grade mostra o encaixe em tempo real. Esc cancela.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    customizationActions
                    Spacer()
                    organizationHelp
                }
                VStack(alignment: .leading, spacing: 12) {
                    customizationActions
                    organizationHelp
                }
            }
        }
        .padding(18).background(FrondaTheme.accent.opacity(0.06), in: .rect(cornerRadius: 14))
    }

    private var customizationActions: some View {
        HStack(spacing: 12) {
            Menu("Cards visíveis", systemImage: "rectangle.grid.2x2") {
                ForEach(layout.cards) { card in
                    Button {
                        layout.toggle(card.kind)
                    } label: {
                        Label(card.kind.title, systemImage: card.hidden ? "plus" : "checkmark")
                    }.disabled(!card.hidden && layout.visible.count == 1)
                }
            }.fixedSize().accessibilityIdentifier("home.visible-cards")
            Button("Desfazer", systemImage: "arrow.uturn.backward", action: layout.undo)
                .disabled(!layout.canUndo).accessibilityIdentifier("home.undo-layout")
            Button("Restaurar", action: layout.restore).accessibilityIdentifier("home.restore-layout")
        }.controlSize(.small)
    }

    private var organizationHelp: some View {
        Text("As opções de cada card também permitem mover e redimensionar pelo teclado.")
            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack {
            Button {
                store.route = "guide"
            } label: {
                Label("Guia Fronda", systemImage: "questionmark.circle")
            }.buttonStyle(.plain).foregroundStyle(FrondaTheme.accent)
            Spacer()
            Button {
                store.perform("queue.toggle")
            } label: {
                Label(
                    store.snapshot.preferences.queuePaused ? "Retomar fila" : "Pausar fila",
                    systemImage: store.snapshot.preferences.queuePaused ? "play.circle" : "pause.circle")
            }.buttonStyle(.plain)
                .disabled(!store.connected || store.busy.contains("queue.toggle"))
        }.font(.caption).foregroundStyle(.secondary)
    }

    private func count(for kind: HomeCardKind) -> Int? {
        switch kind {
        case .attention: attentionRuns.count
        case .progress: continuingRuns.count
        case .recent: recentRuns.count
        case .projects: store.snapshot.projects.count
        case .start: nil
        }
    }

    @ViewBuilder private func cardContent(_ card: HomeCardConfiguration) -> some View {
        switch card.kind {
        case .attention: HomeWorkContent(store: store, kind: card.kind, size: card.size, runs: attentionRuns)
        case .progress: HomeWorkContent(store: store, kind: card.kind, size: card.size, runs: continuingRuns)
        case .recent: HomeWorkContent(store: store, kind: card.kind, size: card.size, runs: recentRuns)
        case .projects: HomeProjectContent(store: store, size: card.size)
        case .start: HomeStartContent(store: store, size: card.size)
        }
    }
}
