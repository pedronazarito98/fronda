import HarnessDomain
import SwiftUI

struct HomeWorkContent: View {
    let store: AppStore
    let kind: HomeCardKind
    let size: HomeCardSize
    let runs: [Run]
    @Environment(\.workspaceNavigation) private var navigation

    var body: some View {
        if store.loading && runs.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                ProgressView("Carregando tarefas…").controlSize(.small)
                ForEach(0..<2) { _ in
                    RoundedRectangle(cornerRadius: 8).fill(FrondaTheme.border.opacity(0.35)).frame(height: 38)
                }
            }.accessibilityElement(children: .combine)
        } else if runs.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(runs.prefix(size.rowLimit))) { run in
                    HomeRunRow(store: store, run: run, showsDetails: size != .compact) {
                        open(run)
                    }
                    if run.id != runs.prefix(size.rowLimit).last?.id { Divider().padding(.vertical, 10) }
                }
                Spacer(minLength: 12)
                Button(
                    runs.count > size.rowLimit ? "Ver todas · \(runs.count)" : "Ver tarefas", systemImage: "arrow.right"
                ) {
                    store.route = "runs"
                }.buttonStyle(.plain).font(.caption.weight(.medium)).foregroundStyle(FrondaTheme.accent)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer(minLength: 0)
            Image(systemName: !store.connected ? "wifi.slash" : kind == .attention ? "checkmark.circle" : kind.symbol)
                .font(.system(size: 28, weight: .light)).foregroundStyle(FrondaTheme.accent)
                .accessibilityHidden(true)
            Text(emptyTitle).font(.callout.weight(.medium))
            Text(emptyDetail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if !store.connected {
                Button("Tentar novamente") { Task { await store.refresh() } }
            } else if kind != .attention {
                Button("Preparar tarefa", systemImage: "plus") { store.showComposer = true }
                    .buttonStyle(.link)
            }
        }
    }

    private var emptyTitle: String {
        if !store.connected { return "Aguardando conexão" }
        switch kind {
        case .attention: return "Tudo em dia por aqui"
        case .progress: return "Espaço para o próximo trabalho"
        default: return "Retome de onde parou"
        }
    }

    private var emptyDetail: String {
        if !store.connected { return "O trabalho aparece assim que o coordenador local responder." }
        switch kind {
        case .attention: return "Quando uma tarefa precisar de uma decisão sua, ela aparece aqui."
        case .progress: return "Acompanhe aqui as tarefas em preparação, na fila e em execução."
        default: return "Suas tarefas recentes ficam à mão, junto com o contexto de cada uma."
        }
    }

    private func open(_ run: Run) {
        let route = "run:" + run.id
        var section: RunWorkspaceSection = .overview
        if kind == .attention {
            if run.state == .waitingUser && !run.contextApproved {
                section = .context
            } else if run.state == .waitingUser && !run.planApproved && !(run.workflow?.proposal.isEmpty ?? true) {
                section = .plan
            } else if run.state == .ready {
                section = .evidence
            }
        }
        navigation?.visit(WorkspaceLocation(route: route, section: section))
        store.route = route
    }
}

private struct HomeRunRow: View {
    let store: AppStore
    let run: Run
    let showsDetails: Bool
    let open: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: RunDisplay.symbol(for: run.state))
                    .foregroundStyle(RunDisplay.color(for: run.state))
                    .font(.callout).frame(width: 20).padding(.top, 2)
                VStack(alignment: .leading, spacing: 5) {
                    Text(run.title).font(.callout.weight(.medium)).foregroundStyle(.primary)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    if showsDetails {
                        Text(store.snapshot.projects.first { $0.id == run.projectID }?.name ?? "Projeto indisponível")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Text(RunDisplay.nextAction(for: run)).font(.caption)
                        .foregroundStyle(FrondaTheme.accent).lineLimit(2).multilineTextAlignment(.leading)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(7).background(hovered ? FrondaTheme.accent.opacity(0.06) : .clear, in: .rect(cornerRadius: 9))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(run.title), \(run.state.label), \(RunDisplay.nextAction(for: run))")
        .accessibilityIdentifier("home.run." + run.id)
    }
}
