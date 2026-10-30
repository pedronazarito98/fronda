import SwiftUI

struct WorkspaceTabBar: View {
    let store: AppStore
    let availableWidth: CGFloat
    @State private var contentWidth: CGFloat = 0
    private var workspace: WorkspaceSession { store.workspace }

    var body: some View {
        HStack(spacing: 4) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(workspace.tabs) { tab in tabButton(tab).id(tab.id) }
                    }
                    .onGeometryChange(for: CGFloat.self) {
                        $0.size.width
                    } action: {
                        contentWidth = $0
                    }
                }
                .scrollIndicators(.hidden)
                .onChange(of: workspace.selectedID) { _, id in proxy.scrollTo(id) }
            }
            .frame(maxWidth: min(contentWidth, max(0, availableWidth - 32)))
            Button("Nova aba", systemImage: "plus") { workspace.openTab() }
                .labelStyle(.iconOnly).frame(width: 28, height: 30)
                .help("Nova aba (⌘T)").accessibilityIdentifier("workspace.new-tab")
            Spacer(minLength: 0)
        }
        .buttonStyle(.plain)
        .frame(height: 32)
    }

    private func tabButton(_ tab: WorkspaceTab) -> some View {
        let selected = workspace.selectedID == tab.id
        let title = Self.title(for: tab.primary.location.route, store: store)
        return HStack(spacing: 2) {
            Button {
                workspace.selectedID = tab.id
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: Self.symbol(for: tab.primary.location.route))
                        .foregroundStyle(selected ? FrondaTheme.accent : .secondary)
                    Text(title).lineLimit(1).truncationMode(.middle)
                    if tab.secondary != nil { Image(systemName: "rectangle.split.2x1").font(.caption2) }
                }
                .padding(.leading, 12).frame(minWidth: 90, maxWidth: 190, alignment: .leading).frame(height: 30)
                .contentShape(Rectangle())
            }
            .help("Mostrar aba: \(title)")
            .accessibilityAddTraits(selected ? .isSelected : [])
            Button("Fechar aba", systemImage: "xmark") { workspace.closeTab(tab.id) }
                .labelStyle(.iconOnly).font(.system(size: 9)).frame(width: 26, height: 30)
                .help("Fechar aba sem interromper a execução")
        }
        .font(.system(size: 12, weight: selected ? .medium : .regular))
        .foregroundStyle(selected ? .primary : .secondary)
        .background(selected ? FrondaTheme.surfaceRaised : .clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? FrondaTheme.border.opacity(0.7) : .clear)
        }
        .contextMenu {
            Button("Duplicar aba") { workspace.openTab(tab.primary.location) }
            Button("Escolher conteúdo") { tab.primary.visit(.newTab) }
            Button("Fechar aba") { workspace.closeTab(tab.id) }
        }
    }

    static func symbol(for route: String) -> String {
        if route == WorkspaceLocation.newTab.route { return "plus.square" }
        if route.hasPrefix("run:") { return "doc.text" }
        if route.hasPrefix("project:") { return "folder" }
        return WorkspaceDestination(rawValue: route)?.symbol ?? "square.grid.2x2"
    }

    static func title(for route: String, store: AppStore) -> String {
        if route == WorkspaceLocation.newTab.route { return "Nova aba" }
        if route.hasPrefix("run:") {
            return store.snapshot.runs.first { $0.id == String(route.dropFirst(4)) }?.title ?? "Tarefa"
        }
        if route.hasPrefix("project:") {
            return store.snapshot.projects.first { $0.id == String(route.dropFirst(8)) }?.name ?? "Projeto"
        }
        return WorkspaceDestination(rawValue: route)?.title ?? "Visão geral"
    }
}
