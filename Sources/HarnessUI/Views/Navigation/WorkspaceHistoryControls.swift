import SwiftUI

struct WorkspaceHistoryControls: ToolbarContent {
    let navigation: WorkspaceNavigation

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button("Voltar", systemImage: "chevron.left", action: navigation.goBack)
                .disabled(!navigation.canGoBack)
                .help("Voltar à página anterior (⌘[)")
                .accessibilityLabel("Voltar")
                .accessibilityIdentifier("navigation.back")
                .labelStyle(.iconOnly)
            Button("Avançar", systemImage: "chevron.right", action: navigation.goForward)
                .disabled(!navigation.canGoForward)
                .help("Avançar à próxima página (⌘])")
                .accessibilityLabel("Avançar")
                .accessibilityIdentifier("navigation.forward")
                .labelStyle(.iconOnly)
        }
    }
}

struct WorkspaceSwipeFeedback: View {
    let navigation: WorkspaceNavigation

    var body: some View {
        if navigation.swipeProgress != 0 {
            HStack {
                if navigation.swipeProgress < 0 { Spacer() }
                Image(systemName: navigation.swipeProgress > 0 ? "chevron.left" : "chevron.right")
                    .font(.title3.weight(.semibold))
                    .padding(15).background(.regularMaterial, in: Circle())
                    .opacity(min(1, abs(navigation.swipeProgress) * 3))
                    .accessibilityHidden(true)
                if navigation.swipeProgress > 0 { Spacer() }
            }.padding(16).allowsHitTesting(false)
        }
    }
}
