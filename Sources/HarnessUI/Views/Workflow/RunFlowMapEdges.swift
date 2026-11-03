import SwiftUI

struct RunFlowMapEdges: View {
    let layout: RunFlowMapLayout
    let nodes: [String: RunFlowMapNodeModel]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var labeledEdges: [RunFlowMapLayout.Edge] {
        var seen = Set<String>()
        return layout.edges.filter { $0.condition != nil && seen.insert($0.targetID).inserted }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.15, paused: reduceMotion || !hasActiveEdge)) { timeline in
            Canvas { context, _ in
                for edge in layout.edges {
                    let target = nodes[edge.targetID]
                    let traversed = target?.finished == true && target?.journey.state != .skipped
                    let active = target?.appearance == .running
                    let color =
                        active ? FrondaTheme.running : traversed ? Color.secondary : Color.secondary.opacity(0.55)
                    context.stroke(
                        path(for: edge), with: .color(color),
                        style: StrokeStyle(lineWidth: active ? 1.7 : 1.2, dash: traversed || active ? [] : [4, 4]))
                    if active && !reduceMotion {
                        let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) / 2
                        context.stroke(
                            path(for: edge).trimmedPath(from: phase, to: min(1, phase + 0.09)),
                            with: .color(FrondaTheme.running.opacity(0.9)),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                    var arrow = Path()
                    arrow.move(to: CGPoint(x: edge.end.x - 3.5, y: edge.end.y - 6))
                    arrow.addLine(to: edge.end)
                    arrow.addLine(to: CGPoint(x: edge.end.x + 3.5, y: edge.end.y - 6))
                    context.stroke(arrow, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
            }
        }
        .overlay(alignment: .topLeading) {
            ForEach(labeledEdges) { edge in
                Text(edge.condition ?? "")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(FrondaTheme.surface)
                    .fixedSize()
                    .position(edge.labelPoint)
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    private var hasActiveEdge: Bool {
        layout.edges.contains { nodes[$0.targetID]?.appearance == .running }
    }

    private func path(for edge: RunFlowMapLayout.Edge) -> Path {
        var path = Path()
        path.move(to: edge.start)
        if abs(edge.start.x - edge.end.x) < 1 && edge.end.y - edge.start.y > 140 {
            let lane = edge.start.x - RunFlowMapLayout.nodeSize.width / 2 - 28
            path.addCurve(
                to: CGPoint(x: lane, y: edge.start.y + 35),
                control1: CGPoint(x: edge.start.x, y: edge.start.y + 25),
                control2: CGPoint(x: lane, y: edge.start.y + 10))
            path.addLine(to: CGPoint(x: lane, y: edge.end.y - 35))
            path.addCurve(
                to: edge.end,
                control1: CGPoint(x: lane, y: edge.end.y - 10),
                control2: CGPoint(x: edge.end.x, y: edge.end.y - 25))
        } else {
            let middle = (edge.start.y + edge.end.y) / 2
            path.addCurve(
                to: edge.end,
                control1: CGPoint(x: edge.start.x, y: middle),
                control2: CGPoint(x: edge.end.x, y: middle))
        }
        return path
    }
}

struct RunFlowMapGroup: View {
    let group: RunFlowMapLayout.Group
    let selected: Bool
    let select: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            returnConnection
            Button(action: select) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 12, weight: .medium))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.loop.didRepeat ? "Repetição" : "Ciclo de correção")
                            .font(.system(size: 10, weight: .semibold))
                        Text(group.loop.didRepeat ? group.loop.summary : "Ainda não iniciado")
                            .font(.system(size: 9)).lineLimit(2)
                    }
                }
                .foregroundStyle(loopColor)
                .padding(.horizontal, 9).padding(.vertical, 7)
                .frame(width: 116, alignment: .leading)
                .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(loopColor.opacity(selected ? 1 : 0.65), lineWidth: selected ? 1.5 : 1)
                }
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
            .help(group.loop.returnLabel + ". " + group.loop.summary)
            .accessibilityLabel(group.loop.title + ", " + group.loop.summary)
            .accessibilityHint("Mostrar motivo, critérios e histórico do ciclo")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("flow.loop." + group.id)
            .position(x: group.frame.width - 60, y: badgeY)
        }
        .frame(width: group.frame.width, height: group.frame.height)
        .position(x: group.frame.midX, y: group.frame.midY)
    }

    private var loopColor: Color { group.loop.didRepeat ? FrondaTheme.danger : FrondaTheme.reference }

    private var badgeY: CGFloat {
        ((group.returnStart.y + group.returnEnd.y) / 2) - group.frame.minY
    }

    private var returnConnection: some View {
        let start = CGPoint(x: group.returnStart.x - group.frame.minX, y: group.returnStart.y - group.frame.minY)
        let end = CGPoint(x: group.returnEnd.x - group.frame.minX, y: group.returnEnd.y - group.frame.minY)
        let lane = group.frame.width - 20
        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: start)
                path.addCurve(
                    to: end,
                    control1: CGPoint(x: lane, y: start.y),
                    control2: CGPoint(x: lane, y: end.y))
            }
            .stroke(
                loopColor.opacity(0.85),
                style: StrokeStyle(
                    lineWidth: group.loop.didRepeat ? 1.7 : 1.3,
                    lineCap: .round, dash: group.loop.didRepeat ? [] : [4, 3]))
            Path { path in
                path.move(to: CGPoint(x: end.x + 6, y: end.y - 3.5))
                path.addLine(to: end)
                path.addLine(to: CGPoint(x: end.x + 6, y: end.y + 3.5))
            }.stroke(loopColor.opacity(0.85), lineWidth: 1.4)
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
