import Observation
import SwiftUI

struct WorkspaceLocation: Codable, Equatable {
    var route: String
    var section: RunWorkspaceSection?

    static let newTab = WorkspaceLocation(route: "new-tab")
}

@MainActor @Observable
final class WorkspaceNavigation {
    let id: UUID
    private(set) var location: WorkspaceLocation
    private(set) var previous: [WorkspaceLocation] = []
    private(set) var following: [WorkspaceLocation] = []
    var isEditingLayout = false
    var isPresenting = false
    var swipeProgress: CGFloat = 0
    var viewState: [String: String] = [:]
    var scrollOffsets: [String: Double] = [:]
    var isSuspended: Bool { isEditingLayout || isPresenting }

    init(route: String = "center") {
        id = UUID()
        location = WorkspaceLocation(route: route)
    }

    struct Saved: Codable {
        var id: UUID
        var location: WorkspaceLocation
        var previous: [WorkspaceLocation]
        var following: [WorkspaceLocation]
        var viewState: [String: String]
        var scrollOffsets: [String: Double]
    }

    var saved: Saved {
        Saved(
            id: id, location: location, previous: previous, following: following,
            viewState: viewState, scrollOffsets: scrollOffsets)
    }

    init(saved: Saved) {
        id = saved.id
        location = saved.location
        previous = Array(saved.previous.suffix(60))
        following = Array(saved.following.suffix(60))
        viewState = saved.viewState
        scrollOffsets = saved.scrollOffsets
    }

    var canGoBack: Bool { !isSuspended && !previous.isEmpty }
    var canGoForward: Bool { !isSuspended && !following.isEmpty }

    func visit(_ route: String) {
        guard route != location.route else { return }
        visit(WorkspaceLocation(route: route))
    }

    func visit(_ destination: WorkspaceLocation) {
        guard destination != location else { return }
        previous.append(location)
        if previous.count > 60 { previous.removeFirst() }
        location = destination
        following.removeAll()
    }

    func restore(_ route: String) {
        location = WorkspaceLocation(route: route)
        previous.removeAll()
        following.removeAll()
    }

    func goBack() {
        guard canGoBack, let destination = previous.popLast() else { return }
        following.append(location)
        location = destination
    }

    func goForward() {
        guard canGoForward, let destination = following.popLast() else { return }
        previous.append(location)
        location = destination
    }
}

extension EnvironmentValues {
    @Entry var workspaceNavigation: WorkspaceNavigation?
}

private struct WorkspaceNavigationKey: FocusedValueKey {
    typealias Value = WorkspaceNavigation
}

extension FocusedValues {
    var workspaceNavigation: WorkspaceNavigation? {
        get { self[WorkspaceNavigationKey.self] }
        set { self[WorkspaceNavigationKey.self] = newValue }
    }
}
