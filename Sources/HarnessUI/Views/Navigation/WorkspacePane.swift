import AppKit
import SwiftUI

struct WorkspacePane: View {
    let store: AppStore
    let navigation: WorkspaceNavigation
    var isSecondary = false

    private var route: String { navigation.location.route }

    var body: some View {
        VStack(spacing: 0) {
            if store.workspace.selected.secondary != nil && !route.hasPrefix("run:") { sideControls }
            destination
                .id(route)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(FrondaTheme.surface)
        .environment(\.workspaceNavigation, navigation)
        .environment(\.workspaceIsSidePane, isSecondary)
        .background(WorkspacePaneFocus { store.workspace.focus(navigation) })
        .background(WorkspaceSwipeNavigation(navigation: navigation))
        .overlay { WorkspaceSwipeFeedback(navigation: navigation) }
        .focusSection()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isSecondary ? "workspace.secondary" : "workspace.primary")
    }

    @ViewBuilder private var destination: some View {
        if route.hasPrefix("run:") {
            RunWorkspace(store: store, runID: String(route.dropFirst(4)), namespace: navigation.id.uuidString)
        } else if route.hasPrefix("project:") {
            ProjectDetailView(store: store, projectID: String(route.dropFirst(8)))
        } else {
            switch route {
            case WorkspaceLocation.newTab.route: WorkspaceStartPage(store: store, navigation: navigation)
            case "runs": RunsView(store: store, navigation: navigation)
            case "projects": ProjectsView(store: store)
            case "runbooks": RunbooksView(store: store)
            case "diary": DiaryView(store: store)
            case "decisions": DecisionsView(store: store)
            case "guide": GuideView(store: store)
            default: CommandCenterView(store: store)
            }
        }
    }

    private var sideControls: some View {
        HStack {
            Text(WorkspaceTabBar.title(for: route, store: store)).font(.callout).foregroundStyle(.secondary).lineLimit(
                1)
            Spacer()
            Button("Escolher conteúdo", systemImage: "square.grid.2x2") { navigation.visit(.newTab) }
                .help("Escolher outra página, projeto ou tarefa para este painel")
                .disabled(route == WorkspaceLocation.newTab.route)
            Button("Abrir em nova aba", systemImage: "arrow.up.forward.square") {
                store.workspace.openTab(navigation.location)
            }.help("Abrir o conteúdo deste painel em uma nova aba")
            if isSecondary {
                Button("Fechar painel", systemImage: "xmark") { store.workspace.closeSide() }
                    .help("Fechar o painel direito sem interromper a execução")
            }
        }
        .labelStyle(.iconOnly).buttonStyle(.plain).padding(.horizontal, 20).padding(.vertical, 10)
    }
}

/// Focus before SwiftUI dispatches the button action, including a click on an inactive pane.
private struct WorkspacePaneFocus: NSViewRepresentable {
    let focus: () -> Void

    func makeNSView(context: Context) -> FocusView {
        let view = FocusView()
        view.focus = focus
        return view
    }

    func updateNSView(_ nsView: FocusView, context: Context) { nsView.focus = focus }

    static func dismantleNSView(_ nsView: FocusView, coordinator: ()) { nsView.stopMonitoring() }

    final class FocusView: NSView {
        var focus: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .scrollWheel]) {
                [weak self] event in
                guard let self, event.window === self.window,
                    self.bounds.contains(self.convert(event.locationInWindow, from: nil))
                else { return event }
                self.focus?()
                return event
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
