import AppKit
import SwiftUI

/// TextKit keeps long source files selectable and searchable without creating a SwiftUI view per line.
struct RunFileLiteralText: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let view = scroll.documentView as? NSTextView else { return scroll }
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = false
        view.drawsBackground = false
        view.usesFindBar = true
        view.isAutomaticLinkDetectionEnabled = false
        view.textContainerInset = NSSize(width: 18, height: 14)
        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textColor = .labelColor
        view.setAccessibilityLabel("Conteúdo do arquivo")
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView, view.string != text else { return }
        view.string = text
        view.setSelectedRange(NSRange(location: 0, length: 0))
        view.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }
}
