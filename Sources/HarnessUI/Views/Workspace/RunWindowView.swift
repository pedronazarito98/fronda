import SwiftUI

struct RunWindowView: View {
    let store: AppStore
    let runID: String
    @State private var navigation: WorkspaceNavigation

    init(store: AppStore, runID: String) {
        self.store = store
        self.runID = runID
        _navigation = State(initialValue: WorkspaceNavigation(route: "run:" + runID))
    }

    var body: some View {
        RunWorkspace(store: store, runID: runID)
            .environment(\.workspaceNavigation, navigation)
            .focusedSceneValue(\.workspaceNavigation, navigation)
            .toolbar {
                WorkspaceHistoryControls(navigation: navigation)
            }
            .background(WorkspaceSwipeNavigation(navigation: navigation))
            .overlay { WorkspaceSwipeFeedback(navigation: navigation) }
    }
}
