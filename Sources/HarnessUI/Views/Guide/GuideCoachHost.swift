import SwiftUI

// Keep the Metal-backed character and its SwiftUI background in the same native
// hosting surface when this card is presented above a sheet's content.
struct GuideCoachHost: NSViewRepresentable {
    let card: GuideCoachCard
    @Environment(\.colorScheme) private var colorScheme
    func makeNSView(context: Context) -> NSHostingView<GuideCoachCard> {
        let view = NSHostingView(rootView: card)
        view.wantsLayer = true
        return view
    }
    func updateNSView(_ view: NSHostingView<GuideCoachCard>, context: Context) {
        view.rootView = card
        view.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSHostingView<GuideCoachCard>, context: Context) -> CGSize?
    {
        nsView.fittingSize
    }
}
