import CoreGraphics
import HarnessDomain

/// Geometry depends only on topology and plan order, never on activity or selection.
struct RunFlowMapLayout {
    struct Node: Identifiable {
        let id: String
        var frame: CGRect
        let level: Int
    }

    struct Edge: Identifiable {
        let sourceID: String
        let targetID: String
        let start: CGPoint
        let end: CGPoint
        let condition: String?
        var id: String { sourceID + ":" + targetID }
        var labelPoint: CGPoint { CGPoint(x: end.x, y: end.y - 27) }
    }

    struct Group: Identifiable {
        let loop: RunFlowMapLoop
        let frame: CGRect
        let returnStart: CGPoint
        let returnEnd: CGPoint
        var id: String { loop.id }
    }

    static let nodeSize = CGSize(width: 240, height: 96)
    private static let horizontalGap: CGFloat = 96
    private static let verticalGap: CGFloat = 42
    private static let padding: CGFloat = 36

    let nodes: [Node]
    let edges: [Edge]
    let groups: [Group]
    let size: CGSize
    let hasInvalidDependencies: Bool

    init(steps: [RunbookStep], loops: [RunFlowMapLoop]) {
        var seen = Set<String>()
        let unique = steps.filter { seen.insert($0.id).inserted }
        let identifiers = Set(unique.map(\.id))
        var levels = [String: Int]()
        var remaining = unique
        var invalid = unique.count != steps.count
        while !remaining.isEmpty {
            let ready = remaining.filter { step in
                step.dependencies.allSatisfy { levels[$0] != nil }
            }
            guard !ready.isEmpty else {
                invalid = true
                let next = (levels.values.max() ?? -1) + 1
                for (offset, step) in remaining.enumerated() { levels[step.id] = next + offset }
                break
            }
            for step in ready {
                levels[step.id] = (step.dependencies.compactMap { levels[$0] }.max() ?? -1) + 1
            }
            let readyIDs = Set(ready.map(\.id))
            remaining.removeAll { readyIDs.contains($0.id) }
        }
        let rows = Dictionary(grouping: unique, by: { levels[$0.id] ?? 0 })
        let columns = max(1, rows.values.map(\.count).max() ?? 1)
        let stride = Self.nodeSize.width + Self.horizontalGap
        let width = CGFloat(columns - 1) * stride + Self.nodeSize.width
        let topPadding = Self.padding + (loops.isEmpty ? 0 : 22)
        let rowPlacements = rows.keys.sorted().flatMap { level -> [Node] in
            let row = rows[level] ?? []
            let inset = CGFloat(columns - row.count) * stride / 2
            return row.enumerated().map { index, step in
                Node(
                    id: step.id,
                    frame: CGRect(
                        x: Self.padding + inset + CGFloat(index) * stride,
                        y: topPadding + CGFloat(level) * (Self.nodeSize.height + Self.verticalGap),
                        width: Self.nodeSize.width, height: Self.nodeSize.height),
                    level: level)
            }
        }
        let placements = Self.aligningLoops(in: rowPlacements, loops: loops)
        let frames = Dictionary(uniqueKeysWithValues: placements.map { ($0.id, $0.frame) })
        nodes = placements
        var grouped = Set<String>()
        let loopGroups = loops.compactMap { loop -> Group? in
            guard grouped.insert(loop.id).inserted else { return nil }
            let members = placements.filter { loop.stepIDs.contains($0.id) }.sorted { $0.frame.minY < $1.frame.minY }
            guard let first = members.first, let last = members.last else { return nil }
            let bounds = members.dropFirst().reduce(first.frame) { $0.union($1.frame) }
            let frame = CGRect(
                x: bounds.minX - 18, y: bounds.minY - 58,
                width: bounds.width + 146, height: bounds.height + 80)
            return Group(
                loop: loop, frame: frame,
                returnStart: CGPoint(x: last.frame.maxX, y: last.frame.midY),
                returnEnd: CGPoint(x: first.frame.maxX, y: first.frame.midY))
        }
        groups = loopGroups
        edges = unique.flatMap { step in
            var dependencies = Set<String>()
            return step.dependencies.compactMap { sourceID -> Edge? in
                guard dependencies.insert(sourceID).inserted,
                    let source = frames[sourceID], let target = frames[step.id]
                else { return nil }
                return Edge(
                    sourceID: sourceID, targetID: step.id,
                    start: CGPoint(x: source.midX, y: source.maxY),
                    end: CGPoint(x: target.midX, y: target.minY),
                    condition: RunFlowMapNodeModel.conditionLabel(step.condition))
            }
        }
        let groupRight = groups.map { $0.frame.maxX }.max() ?? 0
        let groupBottom = groups.map { $0.frame.maxY }.max() ?? 0
        size = CGSize(
            width: max(
                width + Self.padding * 2, groupRight + Self.padding,
                (placements.map { $0.frame.maxX }.max() ?? 0) + Self.padding),
            height: max(placements.map { $0.frame.maxY }.max() ?? 0, groupBottom) + Self.padding)
        hasInvalidDependencies = invalid || unique.contains { !Set($0.dependencies).isSubset(of: identifiers) }
    }

    /// A bounded loop occupies one lane; unrelated branches remain outside its outline.
    private static func aligningLoops(in nodes: [Node], loops: [RunFlowMapLoop]) -> [Node] {
        var result = nodes
        for loop in loops {
            let memberIDs = Set(loop.stepIDs)
            let members = result.filter { memberIDs.contains($0.id) }
            guard let first = members.min(by: { $0.level < $1.level }),
                let last = members.max(by: { $0.level < $1.level })
            else { continue }
            for index in result.indices where memberIDs.contains(result[index].id) {
                result[index].frame.origin.x = first.frame.minX
            }
            for level in first.level...last.level {
                let siblings = result.indices.filter {
                    result[$0].level == level && !memberIDs.contains(result[$0].id)
                        && result[$0].frame.maxX > first.frame.minX - 18
                }.sorted { result[$0].frame.minX < result[$1].frame.minX }
                var occupiedRight = first.frame.maxX + 128
                for index in siblings {
                    result[index].frame.origin.x = max(result[index].frame.minX, occupiedRight + 44)
                    occupiedRight = result[index].frame.maxX
                }
            }
        }
        return result
    }

    func neighbor(of id: String, horizontal: Int, vertical: Int) -> String? {
        guard let node = nodes.first(where: { $0.id == id }) else { return nodes.first?.id }
        let candidates = nodes.filter { candidate in
            if horizontal != 0 {
                return candidate.level == node.level
                    && (horizontal > 0
                        ? candidate.frame.midX > node.frame.midX : candidate.frame.midX < node.frame.midX)
            }
            return vertical > 0 ? candidate.level > node.level : candidate.level < node.level
        }
        return candidates.min { left, right in
            let leftDistance = abs(left.frame.midY - node.frame.midY) * 2 + abs(left.frame.midX - node.frame.midX)
            let rightDistance = abs(right.frame.midY - node.frame.midY) * 2 + abs(right.frame.midX - node.frame.midX)
            return leftDistance < rightDistance
        }?.id
    }
}
