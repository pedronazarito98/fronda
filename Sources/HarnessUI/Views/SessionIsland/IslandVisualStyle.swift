import SwiftUI

enum IslandMotion {
    static let morph = Animation.spring(duration: 0.46, bounce: 0.13)
    static let response = Animation.spring(duration: 0.26, bounce: 0.12)
    static let settleMilliseconds = 620
}

struct IslandGlassSurface: ViewModifier {
    let shape: IslandSilhouette
    let namespace: Namespace.ID
    let revealed: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(revealed ? Color(nsColor: .windowBackgroundColor) : .black, in: shape)
        } else if #available(macOS 26, *) {
            content.glassEffect(revealed ? .regular : .regular.tint(.black), in: shape)
                .glassEffectID("session-island", in: namespace)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}

struct IslandRowStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.primary.opacity(configuration.isPressed ? 0.09 : 0.025), in: .rect(cornerRadius: 14))
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.98)
            .animation(reduceMotion ? nil : IslandMotion.response, value: configuration.isPressed)
    }
}

struct IslandReveal: ViewModifier {
    let visible: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: reduceMotion || visible ? 0 : -8)
            .blur(radius: reduceMotion || visible ? 0 : 3)
            .animation(reduceMotion ? nil : .smooth(duration: 0.3).delay(visible ? delay : 0), value: visible)
    }
}
