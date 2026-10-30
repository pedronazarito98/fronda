import AppKit
import SwiftUI

struct WorkspaceSwipeNavigation: NSViewRepresentable {
    let navigation: WorkspaceNavigation

    func makeNSView(context: Context) -> SwipeView {
        let view = SwipeView()
        view.navigation = navigation
        return view
    }

    func updateNSView(_ nsView: SwipeView, context: Context) { nsView.navigation = navigation }

    static func dismantleNSView(_ nsView: SwipeView, coordinator: ()) { nsView.stopMonitoring() }

    final class SwipeView: NSView {
        var navigation: WorkspaceNavigation?
        private var monitor: Any?
        private var tracking = false
        private var rejectedGesture = false

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .swipe]) { [weak self] event in
                let consumed = MainActor.assumeIsolated {
                    guard let self else { return false }
                    return self.handle(event) == nil
                }
                return consumed ? nil : event
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            tracking = false
            navigation?.swipeProgress = 0
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let navigation, let window, event.window === window, window.isKeyWindow,
                window.attachedSheet == nil, !navigation.isSuspended,
                bounds.contains(convert(event.locationInWindow, from: nil))
            else { return event }
            if event.type == .swipe {
                guard !tracking, !hasHorizontalContent(at: event.locationInWindow),
                    abs(event.deltaX) > abs(event.deltaY)
                else { return event }
                if event.deltaX > 0 && navigation.canGoBack {
                    navigation.goBack()
                    return nil
                }
                if event.deltaX < 0 && navigation.canGoForward {
                    navigation.goForward()
                    return nil
                }
                return event
            }
            if event.phase == .began { rejectedGesture = false }
            guard !tracking, !rejectedGesture, event.hasPreciseScrollingDeltas,
                NSEvent.isSwipeTrackingFromScrollEventsEnabled,
                event.phase == .began || event.phase == .changed
            else { return event }
            let horizontal = abs(event.scrollingDeltaX)
            let vertical = abs(event.scrollingDeltaY)
            if vertical > horizontal && vertical > 2 {
                rejectedGesture = true
                return event
            }
            guard horizontal > 3, horizontal > vertical * 1.5 else { return event }
            guard !hasHorizontalContent(at: event.locationInWindow) else {
                rejectedGesture = true
                return event
            }
            guard event.scrollingDeltaX > 0 ? navigation.canGoBack : navigation.canGoForward else { return event }
            tracking = true
            event.trackSwipeEvent(
                options: [.lockDirection, .clampGestureAmount],
                dampenAmountThresholdMin: navigation.canGoForward ? -1 : 0,
                max: navigation.canGoBack ? 1 : 0
            ) { [weak self, weak navigation] amount, phase, completed, stop in
                guard let self, let navigation, self.window?.isKeyWindow == true,
                    self.window?.attachedSheet == nil, !navigation.isSuspended
                else {
                    stop.pointee = true
                    self?.tracking = false
                    navigation?.swipeProgress = 0
                    return
                }
                navigation.swipeProgress = amount
                // AppKit confirms the physical swipe before its settling animation completes.
                // Navigate at that confirmation, and cancel without touching history otherwise.
                if phase.contains(.ended) {
                    stop.pointee = true
                    self.tracking = false
                    self.rejectedGesture = true
                    navigation.swipeProgress = 0
                    if amount > 0 { navigation.goBack() } else if amount < 0 { navigation.goForward() }
                } else if phase.contains(.cancelled) || completed {
                    self.tracking = false
                    navigation.swipeProgress = 0
                    if phase.contains(.cancelled) { stop.pointee = true }
                }
            }
            return nil
        }

        private func hasHorizontalContent(at point: NSPoint) -> Bool {
            guard let root = window?.contentView else { return false }
            var view = root.hitTest(root.convert(point, from: nil))
            while let current = view {
                if let scroll = current as? NSScrollView,
                    scroll.hasHorizontalScroller
                        || (scroll.documentView?.frame.width ?? 0) > scroll.contentSize.width + 2
                {
                    return true
                }
                if current is NSTextView || current is NSTextField { return true }
                view = current.superview
            }
            return false
        }
    }
}
