import SwiftUI

struct GuideTargetsKey: PreferenceKey {
    static let defaultValue: [FirstTaskStep: Anchor<CGRect>] = [:]
    static func reduce(
        value: inout [FirstTaskStep: Anchor<CGRect>], nextValue: () -> [FirstTaskStep: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

extension View {
    func guideTarget(_ step: FirstTaskStep) -> some View {
        anchorPreference(key: GuideTargetsKey.self, value: .bounds) { [step: $0] }
    }
}

struct GuideSpotlight: View {
    let journey: FirstTaskJourney
    let targets: [FirstTaskStep: CGRect]
    var confirmation: String?
    var canConfirm = true
    var confirm: () -> Void = {}
    var pause: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cardSize = CGSize(width: 300, height: 290)

    var body: some View {
        GeometryReader { proxy in
            let target = targets[journey.step]
            if let target {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(FrondaTheme.accent, lineWidth: 2)
                    .background(FrondaTheme.accent.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                    .frame(width: target.width + 8, height: target.height + 8)
                    .position(x: target.midX, y: target.midY)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            GuideCoachHost(
                card: GuideCoachCard(
                    journey: journey, confirmation: confirmation, canConfirm: canConfirm, confirm: confirm, pause: pause
                )
            )
            .onGeometryChange(for: CGSize.self) {
                $0.size
            } action: {
                cardSize = $0
            }
            .position(position(near: target, in: proxy.size))
            .zIndex(1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: journey.step)
        }
    }

    private func position(near target: CGRect?, in size: CGSize) -> CGPoint {
        let width = cardSize.width
        let height = cardSize.height
        let gap: CGFloat = 20
        let fallback = CGPoint(x: size.width - width / 2 - gap, y: size.height - height / 2 - gap)
        guard let target else { return clamp(fallback, in: size) }
        let candidates = [
            CGPoint(x: target.maxX + gap + width / 2, y: target.midY),
            CGPoint(x: target.minX - gap - width / 2, y: target.midY),
            CGPoint(x: target.midX, y: target.maxY + gap + height / 2),
            CGPoint(x: target.midX, y: target.minY - gap - height / 2),
        ]
        for candidate in candidates {
            let point = clamp(candidate, in: size)
            let rect = CGRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height)
            if !rect.intersects(target.insetBy(dx: -8, dy: -8)) { return point }
        }
        return clamp(fallback, in: size)
    }

    private func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(
                max(point.x, cardSize.width / 2 + 12),
                max(cardSize.width / 2 + 12, size.width - cardSize.width / 2 - 12)),
            y: min(
                max(point.y, cardSize.height / 2 + 12),
                max(cardSize.height / 2 + 12, size.height - cardSize.height / 2 - 12)))
    }
}

private struct GuideFramesKey: PreferenceKey {
    static let defaultValue: [FirstTaskStep: CGRect] = [:]
    static func reduce(value: inout [FirstTaskStep: CGRect], nextValue: () -> [FirstTaskStep: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

struct GuideOverlay: ViewModifier {
    let journey: FirstTaskJourney
    let presented: Bool
    var confirmation: String?
    var canConfirm = true
    var confirm: () -> Void = {}
    var pause: () -> Void
    @State private var targets: [FirstTaskStep: CGRect] = [:]

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(GuideTargetsKey.self) { anchors in
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: GuideFramesKey.self, value: presented ? anchors.mapValues { proxy[$0] } : [:])
                }.allowsHitTesting(false)
            }
            .onPreferenceChange(GuideFramesKey.self) { targets = $0 }
            .overlay {
                if presented {
                    GuideSpotlight(
                        journey: journey, targets: targets, confirmation: confirmation,
                        canConfirm: canConfirm, confirm: confirm, pause: pause)
                }
            }
    }
}
