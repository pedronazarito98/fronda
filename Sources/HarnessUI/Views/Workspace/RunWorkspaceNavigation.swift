import SwiftUI

/// A task is the return point. Supporting pages keep their own destinations for history and deep links.
struct RunWorkspaceNavigation: View {
    @Binding var selection: RunWorkspaceSection
    @State private var consulting = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                location
                Spacer(minLength: 12)
                shortcuts
            }
            VStack(alignment: .leading, spacing: 8) {
                location
                shortcuts
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 22).padding(.vertical, 8)
        .background(FrondaTheme.surface)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navegação da tarefa")
    }

    private var location: some View {
        HStack(spacing: 7) {
            if selection.isTaskHome {
                Label("Tarefa", systemImage: "list.bullet.rectangle")
            } else {
                Button("Tarefa", systemImage: "list.bullet.rectangle") { selection = .conversation }
                    .buttonStyle(.link).accessibilityIdentifier("run.home")
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Text(selection == .plan ? "Mapa" : selection.rawValue)
                    .lineLimit(1)
            }
        }.font(.callout.weight(.medium))
    }

    private var shortcuts: some View {
        HStack(spacing: 10) {
            if selection != .plan && !selection.isTaskHome {
                Button("Mapa", systemImage: "point.3.connected.trianglepath.dotted") { selection = .plan }
                    .accessibilityIdentifier("run.tab.Plano")
                    .help("Acompanhar as etapas e suas dependências no mapa")
            }
            if selection != .files {
                Button("Arquivos", systemImage: "folder") { selection = .files }
                    .accessibilityIdentifier("run.files")
                    .help("Ler alterações, cópias do contexto e evidências")
            }
            Button {
                consulting.toggle()
            } label: {
                Label("Consultar", systemImage: "list.bullet")
            }
            .help("Encontrar materiais, conferências e histórico da tarefa")
            .accessibilityIdentifier("run.more-sections")
            .popover(isPresented: $consulting, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Consultar").font(.headline)
                    group(
                        "Plano e contexto", detail: "Proposta, arquivos usados e alterações.",
                        symbol: "doc.text", sections: [.proposal, .context, .changes])
                    Divider()
                    group(
                        "Conferência e entrega", detail: "Verificações, cenários, revisão e evidências.",
                        symbol: "checkmark.shield", sections: [.checkup, .validation, .scenarios, .review, .evidence])
                    Divider()
                    group(
                        "Histórico", detail: "Atividade, tentativas e consumo informado.",
                        symbol: "clock", sections: [.activity, .tokens])
                }.padding(18).frame(width: 340)
            }
        }.fixedSize(horizontal: true, vertical: false)
    }

    private func group(_ title: String, detail: String, symbol: String, sections: [RunWorkspaceSection]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol).font(.callout.weight(.semibold)).foregroundStyle(FrondaTheme.accent)
            Text(detail).font(.caption).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack { destinations(sections) }
                VStack(alignment: .leading) { destinations(sections) }
            }
        }
    }

    @ViewBuilder private func destinations(_ sections: [RunWorkspaceSection]) -> some View {
        ForEach(sections) { destination in
            Button {
                selection = destination
                consulting = false
            } label: {
                Text(destination.rawValue)
            }
            .buttonStyle(.link).font(.caption)
            .help("Abrir \(destination.rawValue) desta tarefa")
        }
    }
}
