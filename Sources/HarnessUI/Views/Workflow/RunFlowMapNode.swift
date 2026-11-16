import SwiftUI

struct RunFlowMapNode: View {
    let node: RunFlowMapNodeModel
    let selected: Bool
    let select: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false

    private var helpText: String {
        [node.title, node.status, node.dependencyDescription, node.condition]
            .compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        Button(action: select) { surface }
            .buttonStyle(.plain)
            .onHover { hovered = $0 }
            .help(helpText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(node.isCurrent ? "Etapa atual, " : "")\(node.title), \(node.role), \(node.status)")
            .accessibilityValue(node.dependencyDescription + (node.condition.map { ". " + $0 } ?? ""))
            .accessibilityHint("Selecionar esta etapa para ver detalhes")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("flow.node." + node.id)
    }

    private var surface: some View {
        content
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(width: RunFlowMapLayout.nodeSize.width, height: RunFlowMapLayout.nodeSize.height)
            .background(
                node.journey.state == .passed ? FrondaTheme.accent.opacity(0.09) : FrondaTheme.surface,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        selected || node.isCurrent ? node.appearance.color : FrondaTheme.border,
                        lineWidth: selected || node.isCurrent ? 1.5 : 1)
            }
            .shadow(color: .black.opacity(hovered ? 0.08 : 0.025), radius: hovered ? 6 : 3, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var content: some View {
        HStack(spacing: 12) {
            statusIndicator
                .frame(width: 30, height: 30)
                .background(node.appearance.color.opacity(0.08), in: Circle())
            text
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(node.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary).lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(node.isCurrent ? "Etapa atual · " + node.status : node.status)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(node.appearance.color).lineLimit(2)
        }
    }

    @ViewBuilder private var statusIndicator: some View {
        if node.appearance == .running && !reduceMotion {
            ProgressView().controlSize(.small).tint(node.appearance.color).frame(width: 20)
                .accessibilityHidden(true)
        } else {
            Image(systemName: node.journey.state == .notStarted ? "circle" : node.statusSymbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(node.appearance.color).frame(width: 20)
                .accessibilityHidden(true)
        }
    }
}
