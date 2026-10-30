import SwiftUI

struct WorkspaceSplitHandle: View {
    @Binding var fraction: Double
    let width: CGFloat
    let coordinateSpace: String
    let swap: () -> Void
    @State private var hovering = false

    var body: some View {
        Rectangle().fill(hovering ? FrondaTheme.accent.opacity(0.35) : .clear)
            .frame(width: 3)
            .frame(width: 10)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpace))
                    .onChanged { setPosition($0.location.x) }
            )
            .help("Arraste para ajustar a largura dos painéis")
            .accessibilityLabel("Largura dos painéis")
            .accessibilityValue("\(Int(fraction * 100))% para o painel principal")
            .accessibilityAdjustableAction { direction in
                setPosition(width * fraction + (direction == .increment ? 40 : -40))
            }
            .overlay {
                Button("Trocar painéis", systemImage: "arrow.left.arrow.right", action: swap)
                    .labelStyle(.iconOnly).buttonStyle(.plain).font(.system(size: 11))
                    .frame(width: 26, height: 28)
                    .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(FrondaTheme.border))
                    .help("Trocar os painéis esquerdo e direito")
                    .accessibilityIdentifier("workspace.swap")
            }
    }

    private func setPosition(_ position: CGFloat) {
        guard width > 0 else { return }
        fraction = Double(min(width - 360, max(420, position)) / width)
    }
}
