import SwiftUI

struct WorkspaceRail: View {
    let store: AppStore
    @Binding var expanded: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            Button {
                expanded = true
            } label: {
                if let symbol = colorScheme == .dark ? FrondaAssets.symbolDark : FrondaAssets.symbolLight {
                    Image(nsImage: symbol).resizable().interpolation(.high).scaledToFit().frame(width: 24, height: 24)
                } else {
                    Image(systemName: "sidebar.left")
                }
            }.padding(.vertical, 12).accessibilityLabel("Expandir navegação").help("Expandir navegação")
            Button("Nova tarefa", systemImage: "plus") { store.showComposer = true }
                .help("Preparar nova tarefa (⌘N)")
                .frame(width: 34, height: 34)
                .background(FrondaTheme.surface, in: Circle())
                .overlay(Circle().strokeBorder(FrondaTheme.border))
            ForEach(WorkspaceDestination.allCases) { destination in
                let selected = store.route == destination.rawValue
                Button {
                    store.route = destination.rawValue
                } label: {
                    Image(systemName: destination == .runs ? "rectangle.3.group.fill" : destination.symbol)
                        .frame(width: 36, height: 36)
                        .foregroundStyle(selected ? FrondaTheme.accent : .secondary)
                        .background(
                            selected ? FrondaTheme.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 9))
                }
                .help(destination.title).accessibilityLabel(destination.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .contextMenu {
                    Button("Abrir em nova aba") {
                        store.workspace.openTab(WorkspaceLocation(route: destination.rawValue))
                    }
                    Button("Abrir ao lado") {
                        store.workspace.openBeside(WorkspaceLocation(route: destination.rawValue))
                    }
                }
            }
            Spacer()
            Text(store.connected ? "Conectado" : "Desconectado")
                .font(.system(size: 7)).foregroundStyle(store.connected ? FrondaTheme.success : FrondaTheme.warning)
                .accessibilityLabel(store.connected ? "Coordenador conectado" : "Coordenador desconectado")
                .accessibilityIdentifier("coordinator.status")
            SettingsLink { Label("Ajustes", systemImage: "gearshape") }.padding(.vertical, 12).help(
                "Abrir ajustes (⌘,)")
        }
        .font(.system(size: 17)).labelStyle(.iconOnly).buttonStyle(.plain)
        .frame(width: 56).padding(.bottom, 8)
        .background(FrondaTheme.canvas)
    }
}
