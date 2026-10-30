import AppKit

@MainActor
enum FrondaMenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let branches = NSBezierPath()
            branches.lineWidth = 1.35
            branches.lineCapStyle = .round
            branches.lineJoinStyle = .round

            branches.move(to: NSPoint(x: 3.2, y: 15.7))
            branches.curve(
                to: NSPoint(x: 6.5, y: 10),
                controlPoint1: NSPoint(x: 6.8, y: 16.1), controlPoint2: NSPoint(x: 6.5, y: 12.5))
            branches.line(to: NSPoint(x: 6.5, y: 6.4))
            branches.curve(
                to: NSPoint(x: 12.1, y: 2.3),
                controlPoint1: NSPoint(x: 6.5, y: 3.2), controlPoint2: NSPoint(x: 9.4, y: 1.7))
            branches.curve(
                to: NSPoint(x: 14.5, y: 5.5),
                controlPoint1: NSPoint(x: 14.5, y: 2.6), controlPoint2: NSPoint(x: 15, y: 4))

            branches.move(to: NSPoint(x: 6.6, y: 7))
            branches.curve(
                to: NSPoint(x: 11.7, y: 4.2),
                controlPoint1: NSPoint(x: 7.7, y: 4.9), controlPoint2: NSPoint(x: 9.6, y: 3.6))
            branches.line(to: NSPoint(x: 11.7, y: 5.6))

            branches.move(to: NSPoint(x: 6.5, y: 10.7))
            branches.curve(
                to: NSPoint(x: 11.4, y: 8.3),
                controlPoint1: NSPoint(x: 8, y: 8.7), controlPoint2: NSPoint(x: 9.6, y: 7.7))
            branches.curve(
                to: NSPoint(x: 13, y: 10.6),
                controlPoint1: NSPoint(x: 12.8, y: 8.5), controlPoint2: NSPoint(x: 13.5, y: 9.5))

            NSColor.black.setStroke()
            branches.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Fronda"
        return image
    }()
}
