import Observation
import SwiftUI

@MainActor @Observable
final class HomeCardInteraction {
    enum Mode { case move, resize }

    struct Session {
        let kind: HomeCardKind
        let mode: Mode
        let initialSize: HomeCardSize
        let origin: CGRect
        var translation = CGSize.zero
        var lockedTarget: CGRect?
    }

    private(set) var session: Session?
    private var cancelledUntilRelease = false

    func update(
        _ mode: Mode, card: HomeCardConfiguration, value: DragGesture.Value,
        frames: [HomeCardKind: CGRect], width: CGFloat, layout: HomeLayoutStore
    ) {
        guard !cancelledUntilRelease else { return }
        if session == nil {
            guard let frame = frames[card.kind] else { return }
            layout.beginEditing()
            session = Session(kind: card.kind, mode: mode, initialSize: card.size, origin: frame)
        }
        guard var current = session, current.kind == card.kind, current.mode == mode else { return }
        current.translation = value.translation
        session = current

        if mode == .resize {
            let metrics = HomeGridMetrics(width: width)
            let desiredWidth = current.origin.width + value.translation.width
            let expanded = metrics.columns > 1 && desiredWidth > metrics.unit * 1.5
            layout.resizePhysical(
                card.kind, expanded: expanded,
                height: Double(current.origin.height + value.translation.height))
        } else {
            move(current, pointer: value.location, frames: frames, layout: layout)
        }
    }

    func previewFrame(width: CGFloat) -> CGRect? {
        guard let session else { return nil }
        if session.mode == .move {
            return session.origin.offsetBy(dx: session.translation.width, dy: session.translation.height)
        }
        let metrics = HomeGridMetrics(width: width)
        let maximumWidth =
            CGFloat(min(2, metrics.columns)) * metrics.unit
            + CGFloat(min(2, metrics.columns) - 1) * HomeGridMetrics.gap
        let previewWidth = min(maximumWidth, max(metrics.unit, session.origin.width + session.translation.width))
        return CGRect(
            x: min(session.origin.minX, width - previewWidth), y: session.origin.minY,
            width: previewWidth,
            height: max(220, min(session.origin.height + 210, session.origin.height + session.translation.height)))
    }

    func finish(layout: HomeLayoutStore, cancelled: Bool = false) {
        if !cancelled, let session, session.mode == .resize,
            let card = layout.cards.first(where: { $0.kind == session.kind }), let height = card.height
        {
            layout.resizePhysical(card.kind, expanded: card.size == .expanded, height: (height / 16).rounded() * 16)
        }
        layout.finishEditing(cancelled: cancelled)
        session = nil
        cancelledUntilRelease = false
    }

    func cancel(layout: HomeLayoutStore) {
        guard session != nil else { return }
        finish(layout: layout, cancelled: true)
        cancelledUntilRelease = true
    }

    private func move(
        _ current: Session, pointer: CGPoint, frames: [HomeCardKind: CGRect], layout: HomeLayoutStore
    ) {
        // Keep the destination stable while the neighboring cards move underneath the pointer.
        if current.lockedTarget?.contains(pointer) == true { return }
        if frames[current.kind]?.contains(pointer) == true {
            session?.lockedTarget = nil
            return
        }
        guard
            let target = layout.visible.first(where: {
                $0.kind != current.kind && frames[$0.kind]?.insetBy(dx: 8, dy: 8).contains(pointer) == true
            }), let targetFrame = frames[target.kind]
        else { return }
        session?.lockedTarget = targetFrame
        layout.move(current.kind, to: target.kind)
    }
}
