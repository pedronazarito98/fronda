import SwiftUI

struct HomeCard<Content: View>: View {
    let configuration: HomeCardConfiguration
    let layout: HomeLayoutStore
    let organizing: Bool
    let count: Int?
    var onDrag: (HomeCardInteraction.Mode, DragGesture.Value) -> Void = { _, _ in }
    var onDragEnded: () -> Void = {}
    var onDragCancelled: () -> Void = {}
    @ViewBuilder let content: () -> Content
    @GestureState private var dragging = false

    private var kind: HomeCardKind { configuration.kind }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            cardContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .disabled(organizing)
            if organizing { editingFooter }
        }
        .padding(20)
        .frame(
            maxWidth: .infinity,
            minHeight: configuration.height == nil
                ? (count == 0 ? configuration.size.emptyHeight : configuration.size.minimumHeight) : nil,
            alignment: .topLeading
        )
        .frame(height: configuration.height.map { CGFloat($0) })
        .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    organizing ? FrondaTheme.accent.opacity(0.45) : FrondaTheme.border,
                    style: StrokeStyle(lineWidth: 1, dash: organizing ? [5, 4] : [])
                )
                .allowsHitTesting(false)
        }
        .onChange(of: dragging) { _, active in if !active { onDragCancelled() } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.card." + kind.rawValue)
    }

    @ViewBuilder private var cardContent: some View {
        if configuration.height != nil {
            ScrollView { content().frame(maxWidth: .infinity, alignment: .topLeading) }
        } else {
            content()
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: kind.symbol)
                .foregroundStyle(kind == .attention ? FrondaTheme.clay : FrondaTheme.accent)
                .accessibilityHidden(true)
            Text(kind.title).font(.headline)
            if let count {
                Text(count.formatted()).font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if organizing {
                Image(systemName: "line.3.horizontal")
                    .frame(width: 30, height: 30).contentShape(Rectangle())
                    .gesture(dragGesture(.move))
                    .help("Arraste para reposicionar \(kind.title)")
                    .accessibilityLabel("Mover \(kind.title)")
                    .accessibilityIdentifier("home.move." + kind.rawValue)
            }
            Menu {
                ForEach(HomeCardSize.allCases) { size in
                    Button {
                        layout.resize(kind, to: size)
                    } label: {
                        Label(size.title, systemImage: size == configuration.size ? "checkmark" : "rectangle")
                    }
                }
                Divider()
                Button("Mover para antes") { layout.move(kind, offset: -1) }
                    .disabled(layout.visible.first?.kind == kind)
                Button("Mover para depois") { layout.move(kind, offset: 1) }
                    .disabled(layout.visible.last?.kind == kind)
                Divider()
                Button("Ocultar card") { layout.toggle(kind) }.disabled(layout.visible.count == 1)
            } label: {
                Image(systemName: "ellipsis").frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel("Opções de \(kind.title)")
            .help("Alterar tamanho, posição ou visibilidade de \(kind.title)")
            .accessibilityIdentifier("home.card-options." + kind.rawValue)
        }
    }

    private var editingFooter: some View {
        HStack {
            Text(
                configuration.height.map { "\(Int($0)) pt · \(configuration.size.span) col." }
                    ?? configuration.size.title
            )
            .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.callout).foregroundStyle(FrondaTheme.accent)
                .frame(width: 30, height: 30).contentShape(Rectangle())
                .gesture(dragGesture(.resize))
                .help("Arraste para ampliar ou compactar")
                .accessibilityLabel("Tamanho de \(kind.title)")
                .accessibilityValue(configuration.size.title)
                .accessibilityAdjustableAction { direction in
                    let delta: CGFloat = direction == .increment ? 100 : -100
                    layout.resize(kind, to: configuration.size.resized(by: CGSize(width: delta, height: 0)))
                }
                .accessibilityIdentifier("home.resize." + kind.rawValue)
        }
    }

    private func dragGesture(_ mode: HomeCardInteraction.Mode) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("home-card-board"))
            .updating($dragging) { _, state, _ in state = true }
            .onChanged { onDrag(mode, $0) }
            .onEnded { _ in onDragEnded() }
    }
}
