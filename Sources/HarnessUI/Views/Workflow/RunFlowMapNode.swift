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
            .accessibilityLabel("\(node.title), \(node.role), \(node.status)")
            .accessibilityValue(node.dependencyDescription + (node.condition.map { ". " + $0 } ?? ""))
            .accessibilityHint("Abrir a atividade e os resultados desta etapa")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("flow.node." + node.id)
    }

    private var surface: some View {
        content
            .padding(.horizontal, 14).padding(.vertical, 8)
            .frame(width: RunFlowMapLayout.nodeSize.width, height: RunFlowMapLayout.nodeSize.height)
            .background(FrondaTheme.surfaceRaised)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .fill(node.appearance.color.opacity(node.appearance == .running ? 0.08 : 0.025))
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(node.appearance.color.opacity(node.appearance == .waiting ? 0.3 : 0.7))
            }
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(node.appearance.color.opacity(0.9), lineWidth: 1.5)
                        .padding(-4)
                }
            }
            .shadow(color: .black.opacity(hovered ? 0.10 : 0.035), radius: 5, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }

    private var content: some View {
        HStack(spacing: 12) {
            Image(systemName: node.roleSymbol)
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(node.appearance.color)
                .frame(width: 29)
                .accessibilityHidden(true)
            text
                .frame(maxWidth: .infinity, alignment: .leading)
            statusIndicator
        }
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(node.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary).lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(node.role).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(node.status)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(node.appearance.color).lineLimit(2)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(node.appearance.color.opacity(0.12), in: Capsule())
        }
    }

    @ViewBuilder private var statusIndicator: some View {
        if node.appearance == .running && !reduceMotion {
            ProgressView().controlSize(.small).tint(node.appearance.color).frame(width: 20)
                .accessibilityHidden(true)
        } else {
            Image(systemName: node.statusSymbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(node.appearance.color).frame(width: 20)
                .accessibilityHidden(true)
        }
    }
}
