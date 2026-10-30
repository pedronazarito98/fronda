import SwiftUI

struct HomeCardBoard<Content: View>: View {
    let layout: HomeLayoutStore
    let organizing: Bool
    let count: (HomeCardKind) -> Int?
    @ViewBuilder let content: (HomeCardConfiguration) -> Content
    @State private var interaction = HomeCardInteraction()
    @State private var frames: [HomeCardKind: CGRect] = [:]
    @State private var width: CGFloat = 960
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        HomeCardGrid {
            // Stable view order keeps the active gesture alive while Layout repositions its slot.
            ForEach(layout.visible.sorted { $0.kind.rawValue < $1.kind.rawValue }) { card in
                HomeCard(
                    configuration: card, layout: layout, organizing: organizing, count: count(card.kind),
                    onDrag: { mode, value in
                        interaction.update(mode, card: card, value: value, frames: frames, width: width, layout: layout)
                    },
                    onDragEnded: { interaction.finish(layout: layout) },
                    onDragCancelled: {
                        if interaction.session == nil || interaction.session?.kind == card.kind {
                            interaction.finish(layout: layout, cancelled: true)
                        }
                    }
                ) { content(card) }
                .opacity(interaction.session?.kind == card.kind && interaction.session?.mode == .move ? 0 : 1)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named("home-card-board"))
                } action: {
                    frames[card.kind] = $0
                }
                .layoutValue(key: HomeCardSpan.self, value: card.size.span)
                .layoutValue(key: HomeCardOrder.self, value: layout.cards.firstIndex(of: card) ?? 0)
            }
        }
        .animation(
            reduceMotion || interaction.session?.mode == .resize ? nil : .easeOut(duration: 0.14), value: layout.cards
        )
        .padding(.bottom, organizing ? 32 : 0)
        .background { if organizing { HomeEditingGrid() } }
        .overlay(alignment: .topLeading) { editingOverlay.allowsHitTesting(false).accessibilityHidden(true) }
        .coordinateSpace(name: "home-card-board")
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: { newWidth in
            if width != newWidth { interaction.cancel(layout: layout) }
            width = newWidth
        }
        .onExitCommand { interaction.cancel(layout: layout) }
        .onChange(of: organizing) { _, _ in interaction.finish(layout: layout) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { interaction.cancel(layout: layout) }
        }
        .onDisappear { interaction.finish(layout: layout, cancelled: true) }
    }

    @ViewBuilder private var editingOverlay: some View {
        if let session = interaction.session, session.mode == .move,
            let card = layout.cards.first(where: { $0.kind == session.kind }),
            let preview = interaction.previewFrame(width: width)
        {
            if let destination = frames[session.kind] {
                RoundedRectangle(cornerRadius: 12)
                    .fill(FrondaTheme.accent.opacity(0.1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(FrondaTheme.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }
                    .overlay(alignment: .topLeading) {
                        Label(
                            session.mode == .move ? "Solte para posicionar" : card.size.title,
                            systemImage: "rectangle.dashed"
                        ).font(.caption.weight(.medium)).padding(16).foregroundStyle(FrondaTheme.accent)
                    }
                    .frame(width: destination.width, height: destination.height)
                    .offset(x: destination.minX, y: destination.minY)
            }
            HomeCard(configuration: card, layout: layout, organizing: true, count: count(card.kind)) { content(card) }
                .frame(width: preview.width, height: preview.height, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(FrondaTheme.accent, lineWidth: 2)
                }
                .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
                .offset(x: preview.minX, y: preview.minY)
                .transaction { $0.animation = nil }
                .allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}
