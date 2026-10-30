import SwiftUI

struct FrondaMascot: View {
    var size: CGFloat = 112
    var state = MascotState.idle
    @Environment(\.accessibilityReduceMotion) private var reduced

    var body: some View {
        Group {
            if size >= 60 {
                FrondaAnimatedMascot(state: state, reduced: reduced)
            } else if let image = MascotResources.image ?? FrondaAssets.mascot {
                Image(nsImage: image).resizable().renderingMode(.original).interpolation(.high).scaledToFit()
            }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

private struct FrondaAnimatedMascot: NSViewRepresentable {
    let state: MascotState
    let reduced: Bool
    func makeNSView(context: Context) -> MascotMetalView { MascotMetalView() }
    func updateNSView(_ view: MascotMetalView, context: Context) {
        view.configure(state: state.rawValue, reduced: reduced)
    }
    static func dismantleNSView(_ view: MascotMetalView, coordinator: ()) { view.stop() }
}
