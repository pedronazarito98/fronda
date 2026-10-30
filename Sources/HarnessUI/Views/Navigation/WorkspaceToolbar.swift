import SwiftUI

struct WorkspaceToolbar: ToolbarContent {
    let store: AppStore
    let navigation: WorkspaceNavigation
    let windowWidth: CGFloat

    var body: some ToolbarContent {
        WorkspaceHistoryControls(navigation: navigation)
        if #available(macOS 26.0, *) {
            ToolbarItem(placement: .principal) { tabs }.sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .principal) { tabs }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                store.showPalette = true
            } label: {
                Label("Buscar", systemImage: "magnifyingglass")
            }.help("Buscar e executar comando (⌘K)")
                .disabled(store.showComposer || store.showPalette)
            Button {
                store.workspace.selected.showsSummary.toggle()
            } label: {
                Label("Alternar resumo fixado", systemImage: store.workspace.selected.showsSummary ? "pin.fill" : "pin")
            }
            .help("Mostrar ou ocultar o resumo fixado da aba")
            .accessibilityValue(store.workspace.selected.showsSummary ? "Visível" : "Oculto")
            .accessibilityIdentifier("workspace.summary")
            Button {
                if store.workspace.selected.secondary != nil {
                    store.workspace.closeSide()
                } else {
                    store.workspace.openBeside(.newTab)
                }
            } label: {
                Label("Alternar visualização lado a lado", systemImage: "rectangle.split.2x1")
            }
            .help(
                store.workspace.selected.secondary == nil
                    ? "Abrir um painel e escolher o conteúdo" : "Fechar o painel direito"
            )
            .accessibilityIdentifier("workspace.split")
        }
        if #available(macOS 27.0, *) {
            ToolbarItem(placement: .primaryAction) { newTask }.visibilityPriority(.init(higherThan: .high))
        } else if #available(macOS 26.1, *) {
            ToolbarItem(placement: .primaryAction) { newTask }.visibilityPriority(.high)
        } else {
            ToolbarItem(placement: .primaryAction) { newTask }
        }
    }

    private var tabs: some View {
        let width = max(220, windowWidth - 440)
        return WorkspaceTabBar(store: store, availableWidth: width)
            .frame(minWidth: 220, idealWidth: width, maxWidth: width)
    }

    private var newTask: some View {
        Button {
            store.showComposer = true
        } label: {
            Label("Nova tarefa", systemImage: "square.and.pencil")
        }
        .help("Nova tarefa (⌘N)").accessibilityIdentifier("toolbar.new-run")
        .disabled(store.showComposer || store.showPalette)
    }
}
