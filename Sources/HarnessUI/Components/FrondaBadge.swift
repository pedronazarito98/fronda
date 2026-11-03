import SwiftUI

struct FrondaBadge: View {
    let title: String
    let symbol: String
    let color: Color
    @Environment(\.colorSchemeContrast) private var contrast

    init(_ title: String, symbol: String, color: Color) {
        self.title = title
        self.symbol = symbol
        self.color = color
    }

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.10), in: Capsule())
            .overlay {
                if contrast == .increased { Capsule().strokeBorder(color.opacity(0.7)) }
            }
            .accessibilityElement(children: .ignore).accessibilityLabel(title)
    }
}
