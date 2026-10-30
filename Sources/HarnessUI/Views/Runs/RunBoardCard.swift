import HarnessDomain
import SwiftUI

struct RunBoardCard: View {
    let store: AppStore
    let run: Run
    let navigation: WorkspaceNavigation
    @State private var showingActions = false
    @State private var hovered = false

    private var selected: Bool {
        let tab = store.workspace.selected
        return tab.primary.location.route == "run:" + run.id || tab.secondary?.location.route == "run:" + run.id
    }
    private var stage: RunBoardStage { .stage(for: run) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 6) {
                Button {
                    openBeside()
                } label: {
                    Text(run.title).font(.system(size: 12, weight: .medium)).lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain)
                Button {
                    showingActions.toggle()
                } label: {
                    Image(systemName: "ellipsis").frame(width: 20, height: 20).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .accessibilityLabel("Opções de \(run.title)")
                .help("Escolher onde abrir esta tarefa")
                .popover(isPresented: $showingActions, arrowEdge: .trailing) { actions }
            }
            Button {
                openBeside()
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    Label(run.stageLabel, systemImage: run.state.active ? "circle.dotted" : "doc.text")
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    Text(run.source.text).font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(3).multilineTextAlignment(.leading)
                    if RunDisplay.needsAttention(run) {
                        Label(RunDisplay.nextAction(for: run), systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(FrondaTheme.warning).lineLimit(2)
                    } else {
                        Label(run.state.label, systemImage: RunDisplay.symbol(for: run.state))
                            .font(.system(size: 10)).foregroundStyle(stage.color).lineLimit(1)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(
                selected ? FrondaTheme.accent : FrondaTheme.border.opacity(hovered ? 1 : 0.65), lineWidth: 1)
        )
        .shadow(color: .black.opacity(hovered || selected ? 0.05 : 0), radius: 4, y: 2)
        .onHover { hovered = $0 }
        .contextMenu { contextActions }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(run.title), \(stage.rawValue), \(run.state.label)")
        .accessibilityIdentifier("board.card." + run.id)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(run.title).font(.headline).lineLimit(2).padding(8)
            Divider()
            action("Abrir tarefa", symbol: "doc.text") { navigation.visit("run:" + run.id) }
            action("Abrir em nova aba", symbol: "plus.square.on.square") {
                store.workspace.openTab(WorkspaceLocation(route: "run:" + run.id))
            }
            action("Abrir ao lado", symbol: "rectangle.split.2x1", perform: openBeside)
            Divider()
            Label(run.state.label, systemImage: RunDisplay.symbol(for: run.state))
                .font(.caption).foregroundStyle(.secondary).padding(8)
        }.padding(8).frame(width: 240)
    }

    private func action(_ title: String, symbol: String, perform: @escaping () -> Void) -> some View {
        Button {
            showingActions = false
            perform()
        } label: {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity, alignment: .leading)
                .padding(8).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    @ViewBuilder private var contextActions: some View {
        Button("Abrir tarefa") { navigation.visit("run:" + run.id) }
        Button("Abrir em nova aba") { store.workspace.openTab(WorkspaceLocation(route: "run:" + run.id)) }
        Button("Abrir ao lado", action: openBeside)
    }

    private func openBeside() {
        store.workspace.openBeside(WorkspaceLocation(route: "run:" + run.id), from: navigation)
    }
}
