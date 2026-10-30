import SwiftUI

struct HomeEditingGrid: View {
    var body: some View {
        Canvas { context, size in
            let metrics = HomeGridMetrics(width: size.width)
            let color = FrondaTheme.accent
            for column in 0..<metrics.columns {
                let x = CGFloat(column) * (metrics.unit + HomeGridMetrics.gap)
                let rect = CGRect(x: x, y: 0, width: metrics.unit, height: size.height)
                context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(color.opacity(0.045)))
                var edges = Path()
                edges.move(to: CGPoint(x: x, y: 0))
                edges.addLine(to: CGPoint(x: x, y: size.height))
                edges.move(to: CGPoint(x: rect.maxX, y: 0))
                edges.addLine(to: CGPoint(x: rect.maxX, y: size.height))
                context.stroke(edges, with: .color(color.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            var rows = Path()
            for y in stride(from: CGFloat.zero, through: size.height, by: 32) {
                rows.move(to: CGPoint(x: 0, y: y))
                rows.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(rows, with: .color(color.opacity(0.12)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
