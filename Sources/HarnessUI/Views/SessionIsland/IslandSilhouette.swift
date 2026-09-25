import SwiftUI

/// Concave shoulders join the screen edge; the lower corners stay continuous as the island grows.
struct IslandSilhouette: Shape {
    var radius: CGFloat
    var attached: Bool
    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard attached else { return RoundedRectangle(cornerRadius: radius).path(in: rect) }
        let shoulder: CGFloat = 8
        let corner = min(radius, max(0, rect.height - shoulder))
        let left = rect.minX + shoulder
        let right = rect.maxX - shoulder
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: right, y: rect.minY + shoulder), control: CGPoint(x: right, y: rect.minY))
        path.addLine(to: CGPoint(x: right, y: rect.maxY - corner))
        path.addQuadCurve(to: CGPoint(x: right - corner, y: rect.maxY), control: CGPoint(x: right, y: rect.maxY))
        path.addLine(to: CGPoint(x: left + corner, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: left, y: rect.maxY - corner), control: CGPoint(x: left, y: rect.maxY))
        path.addLine(to: CGPoint(x: left, y: rect.minY + shoulder))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: left, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
