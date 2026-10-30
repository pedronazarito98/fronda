import Foundation

// The crown coordinates follow the same growth/curve transform as the Metal shader.
enum MascotHitRegions {
    static let pivots: [CGPoint] = [
        .init(x: 0.443, y: 0.54), .init(x: 0.412, y: 0.455), .init(x: 0.414, y: 0.666), .init(x: 0.566, y: 0.665),
        .init(x: 0.533, y: 0.737),
    ]
    static let crowns: [CGPoint] = [
        .init(x: 0.695, y: 0.16), .init(x: 0.245, y: 0.265), .init(x: 0.237, y: 0.51), .init(x: 0.822, y: 0.445),
        .init(x: 0.722, y: 0.647),
    ]

    static func branch(at point: CGPoint, frame: [Float]) -> Int {
        guard frame.count == 64 else { return -1 }
        var best = -1
        var distance: CGFloat = 0.105
        for index in 0..<5 {
            let pivot = pivots[index]
            let crown = crowns[index]
            let dx = crown.x - pivot.x
            let dy = crown.y - pivot.y
            let length = hypot(dx, dy)
            let bend = CGFloat(frame[10 + index])
            let growth = 1 + CGFloat(frame[15 + index])
            let along = abs(bend) < 0.0001 ? length : length * sin(bend) / bend
            let across = abs(bend) < 0.0001 ? 0 : length * (1 - cos(bend)) / bend
            var p = CGPoint(
                x: pivot.x + (dx * along - dy * across) / length * growth,
                y: pivot.y + (dy * along + dx * across) / length * growth)
            p = rotate(p, pivot: pivot, angle: CGFloat(frame[index]))
            p.x = 0.5 + (p.x - 0.5) * (1 - (CGFloat(frame[56]) - 1) * 0.32)
            p.y = 0.932 + (p.y - 0.932) * CGFloat(frame[56])
            p = rotate(p, pivot: .init(x: 0.5, y: 0.932), angle: CGFloat(frame[55]))
            p = .init(
                x: (p.x - 0.5) * 0.78 + 0.5, y: (p.y - 0.5 - CGFloat(frame[57]) - CGFloat(frame[58])) * 0.78 + 0.5)
            let candidate = hypot(point.x - p.x, point.y - p.y)
            if candidate < distance {
                distance = candidate
                best = index
            }
        }
        return best
    }
    private static func rotate(_ point: CGPoint, pivot: CGPoint, angle: CGFloat) -> CGPoint {
        let x = point.x - pivot.x
        let y = point.y - pivot.y
        return .init(x: pivot.x + x * cos(angle) - y * sin(angle), y: pivot.y + x * sin(angle) + y * cos(angle))
    }
}
