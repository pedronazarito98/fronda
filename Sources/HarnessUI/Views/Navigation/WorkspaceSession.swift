import Observation
import SwiftUI

@MainActor @Observable
final class WorkspaceTab: Identifiable {
    let id: UUID
    var primary: WorkspaceNavigation
    var secondary: WorkspaceNavigation?
    var secondaryFocused = false
    var showsSummary = true
    var splitFraction = 0.63

    var navigation: WorkspaceNavigation { secondaryFocused ? (secondary ?? primary) : primary }

    init(route: String) {
        id = UUID()
        primary = WorkspaceNavigation(route: route)
    }

    struct Saved: Codable {
        var id: UUID
        var primary: WorkspaceNavigation.Saved
        var secondary: WorkspaceNavigation.Saved?
        var secondaryFocused: Bool
        var showsSummary: Bool
        var splitFraction: Double?
    }

    var saved: Saved {
        Saved(
            id: id, primary: primary.saved, secondary: secondary?.saved,
            secondaryFocused: secondaryFocused, showsSummary: showsSummary, splitFraction: splitFraction)
    }

    init(saved: Saved) {
        id = saved.id
        primary = WorkspaceNavigation(saved: saved.primary)
        secondary = saved.secondary.map(WorkspaceNavigation.init(saved:))
        secondaryFocused = saved.secondaryFocused && secondary != nil
        showsSummary = saved.showsSummary
        splitFraction = min(0.8, max(0.2, saved.splitFraction ?? 0.63))
    }
}

@MainActor @Observable
final class WorkspaceSession {
    static var storageKey: String {
        let arguments = CommandLine.arguments
        let rootIndex = arguments.firstIndex { ["--harness-data-root", "--fronda-data-root"].contains($0) }
        let root = rootIndex.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        return "fronda.workspace.tabs.v1" + (root.map { ":" + $0 } ?? "")
    }
    private(set) var tabs: [WorkspaceTab]
    var selectedID: UUID
    private var closed: [WorkspaceTab.Saved] = []

    init() {
        let tab = WorkspaceTab(route: "center")
        tabs = [tab]
        selectedID = tab.id
    }

    var selected: WorkspaceTab { tabs.first { $0.id == selectedID } ?? tabs[0] }
    var navigation: WorkspaceNavigation { selected.navigation }
    var canReopen: Bool { !closed.isEmpty }

    @discardableResult
    func openTab(_ location: WorkspaceLocation = .newTab) -> WorkspaceTab {
        let tab = WorkspaceTab(route: location.route)
        tab.primary.visit(location)
        tabs.append(tab)
        selectedID = tab.id
        return tab
    }

    func openBeside(_ location: WorkspaceLocation, from navigation: WorkspaceNavigation? = nil) {
        let tab = selected
        if let navigation, tab.secondary?.id == navigation.id {
            tab.primary.visit(location)
            tab.secondaryFocused = false
        } else {
            if let secondary = tab.secondary {
                secondary.visit(location)
            } else {
                tab.secondary = WorkspaceNavigation(route: location.route)
                tab.secondary?.visit(location)
            }
            tab.secondaryFocused = true
        }
    }

    func focus(_ navigation: WorkspaceNavigation) {
        let isSecondary = selected.secondary?.id == navigation.id
        if selected.secondaryFocused != isSecondary { selected.secondaryFocused = isSecondary }
    }

    func closeSide() {
        selected.secondary = nil
        selected.secondaryFocused = false
    }

    func swapPanes() {
        let tab = selected
        guard let secondary = tab.secondary else { return }
        tab.secondary = tab.primary
        tab.primary = secondary
        tab.secondaryFocused.toggle()
    }

    func closeTab(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        closed.append(tabs[index].saved)
        if closed.count > 12 { closed.removeFirst() }
        tabs.remove(at: index)
        if tabs.isEmpty { tabs = [WorkspaceTab(route: "center")] }
        if selectedID == id { selectedID = tabs[min(index, tabs.count - 1)].id }
    }

    func reopen() {
        guard let saved = closed.popLast() else { return }
        let tab = WorkspaceTab(saved: saved)
        tabs.append(tab)
        selectedID = tab.id
    }

    func cycle(_ offset: Int) {
        guard let index = tabs.firstIndex(where: { $0.id == selectedID }) else { return }
        selectedID = tabs[(index + offset + tabs.count) % tabs.count].id
    }

    private struct Saved: Codable {
        var tabs: [WorkspaceTab.Saved]
        var selectedID: UUID
    }

    var encoded: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(Saved(tabs: tabs.map(\.saved), selectedID: selectedID)) else {
            return ""
        }
        return String(decoding: data, as: UTF8.self)
    }

    @discardableResult
    func restore(_ value: String) -> Bool {
        guard let saved = try? JSONDecoder().decode(Saved.self, from: Data(value.utf8)),
            !saved.tabs.isEmpty, Set(saved.tabs.map(\.id)).count == saved.tabs.count
        else { return false }
        tabs = saved.tabs.map(WorkspaceTab.init(saved:))
        selectedID = tabs.contains { $0.id == saved.selectedID } ? saved.selectedID : tabs[0].id
        return true
    }
}

extension EnvironmentValues {
    @Entry var workspaceShowsSummary = true
    @Entry var workspaceIsSidePane = false
}

private struct WorkspaceSessionKey: FocusedValueKey {
    typealias Value = WorkspaceSession
}

extension FocusedValues {
    var workspaceSession: WorkspaceSession? {
        get { self[WorkspaceSessionKey.self] }
        set { self[WorkspaceSessionKey.self] = newValue }
    }
}
