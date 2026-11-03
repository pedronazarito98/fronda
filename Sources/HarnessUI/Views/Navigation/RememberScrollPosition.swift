import SwiftUI

private struct RememberScrollPosition: ViewModifier {
    @Environment(\.workspaceNavigation) private var navigation
    private let key: String
    private let startAtTop: Bool
    @SceneStorage private var savedOffset: Double
    @State private var position = ScrollPosition(edge: .top)
    @State private var isReady = false

    init(key: String, startAtTop: Bool) {
        self.key = key
        self.startAtTop = startAtTop
        _savedOffset = SceneStorage(wrappedValue: 0, "fronda.scroll." + key)
    }

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: Double.self) { geometry in
                max(0, geometry.contentOffset.y + geometry.contentInsets.top)
            } action: { _, offset in
                if isReady {
                    if let navigation { navigation.scrollOffsets[key] = offset } else { savedOffset = offset }
                }
            }
            .task {
                position.scrollTo(y: startAtTop ? 0 : navigation?.scrollOffsets[key] ?? savedOffset)
                await Task.yield()
                isReady = true
            }
            .onDisappear { isReady = false }
    }
}

extension View {
    func rememberScrollPosition(_ key: String, startAtTop: Bool = false) -> some View {
        modifier(RememberScrollPosition(key: key, startAtTop: startAtTop))
    }
}
