import SwiftUI

struct RunFlowMapList: View {
    let nodes: [RunFlowMapNodeModel]
    let loops: [RunFlowMapLoop]
    @Binding var selectedStepID: String?
    let selectedLoopID: String?
    let onInspectStep: (String) -> Void
    let onSelectLoop: (String) -> Void

    var body: some View {
        List {
            ForEach(nodes) { node in
                ForEach(loops.filter { $0.stepIDs.first == node.id }) { loop in
                    RunFlowMapListLoop(loop: loop, selected: selectedLoopID == loop.id) {
                        onSelectLoop(loop.id)
                    }
                }
                RunFlowMapListStep(node: node, selected: selectedStepID == node.id) {
                    selectedStepID = node.id
                    onInspectStep(node.id)
                }
            }
        }
        .listStyle(.inset).scrollContentBackground(.hidden)
        .accessibilityLabel("Etapas e dependências do fluxo")
    }
}

private struct RunFlowMapListLoop: View {
    let loop: RunFlowMapLoop
    let selected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) { content }
            .buttonStyle(.plain)
            .accessibilityLabel(loop.title + ", " + loop.summary + ". " + loop.returnLabel)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("flow.list.loop." + loop.id)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(loop.title, systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.callout.weight(.semibold))
            Text(loop.summary).font(.caption).foregroundStyle(.secondary)
            Text(loop.returnLabel).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8).contentShape(Rectangle())
    }
}

private struct RunFlowMapListStep: View {
    let node: RunFlowMapNodeModel
    let selected: Bool
    let select: () -> Void

    private var accessibleTitle: String {
        "\(node.title), \(node.role), \(node.status)"
    }

    private var accessibleDetail: String {
        guard let condition = node.condition else { return node.dependencyDescription }
        return "\(node.dependencyDescription). \(condition)"
    }

    private var rowBackground: Color { selected ? Color.primary.opacity(0.06) : Color.clear }
    private var selectionTraits: AccessibilityTraits { selected ? .isSelected : [] }
    private var accessibilityID: String { "flow.list.node.\(node.id)" }

    var body: some View {
        accessibleButton
            .listRowBackground(rowBackground)
            .accessibilityAddTraits(selectionTraits)
            .accessibilityIdentifier(accessibilityID)
    }

    private var accessibleButton: some View {
        Button(action: select) { content }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibleTitle))
            .accessibilityValue(Text(accessibleDetail))
            .accessibilityHint("Abrir a atividade e os resultados desta etapa")
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: node.statusSymbol)
                .foregroundStyle(node.appearance.color).frame(width: 20).padding(.top, 2)
            text.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 9).contentShape(Rectangle())
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(node.title).font(.callout.weight(.semibold))
            Text(node.role + " · " + node.status)
                .font(.caption).foregroundStyle(node.appearance.color)
            Text(node.dependencyDescription).font(.caption).foregroundStyle(.secondary)
            if let condition = node.condition {
                Text(condition).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
