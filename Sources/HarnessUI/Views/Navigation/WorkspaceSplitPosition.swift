import AppKit
import SwiftUI

/// Keeps the native split position in sync with its accessible resize handle.
struct WorkspaceSplitPosition: NSViewRepresentable {
    @Binding var fraction: Double

    func makeNSView(context: Context) -> Reader {
        let view = Reader()
        view.requestedFraction = fraction
        view.save = { fraction = $0 }
        return view
    }

    func updateNSView(_ nsView: Reader, context: Context) {
        nsView.save = { fraction = $0 }
        nsView.requestedFraction = fraction
        nsView.schedulePosition()
    }
    static func dismantleNSView(_ nsView: Reader, coordinator: ()) { nsView.stopObserving() }

    final class Reader: NSView {
        var requestedFraction = 0.63
        var save: ((Double) -> Void)?
        private weak var split: NSSplitView?
        private var observer: NSObjectProtocol?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                stopObserving()
                return
            }
            DispatchQueue.main.async { [weak self] in self?.configure() }
        }

        override func layout() {
            super.layout()
            if split == nil { DispatchQueue.main.async { [weak self] in self?.configure() } }
        }

        private func configure() {
            guard split == nil, window != nil else { return }
            if let root = window?.contentView, let splitView = findSplit(in: root) {
                split = splitView
                schedulePosition()
                observer = NotificationCenter.default.addObserver(
                    forName: NSSplitView.didResizeSubviewsNotification, object: splitView, queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self, let split = self.split, split.bounds.width > 0,
                            let first = split.arrangedSubviews.first
                        else { return }
                        self.save?(Double(first.frame.width / split.bounds.width))
                    }
                }
                return
            }
        }

        func schedulePosition() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let split = self.split, let first = split.arrangedSubviews.first else { return }
                let position = split.bounds.width * self.requestedFraction
                if abs(first.frame.width - position) >= 1 { split.setPosition(position, ofDividerAt: 0) }
            }
        }

        private func findSplit(in view: NSView) -> NSSplitView? {
            if let split = view as? NSSplitView, split.isVertical, split.arrangedSubviews.count == 2,
                split.bounds.width > 0
            {
                return split
            }
            for child in view.subviews {
                if let split = findSplit(in: child) { return split }
            }
            return nil
        }

        func stopObserving() {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            split = nil
        }
    }
}
