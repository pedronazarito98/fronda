import AppKit
import SwiftUI

/// Shared reader for authored prose; exact payloads and process output keep their literal viewers.
struct MarkdownView: View {
    let source: String
    @State private var document = MarkdownDocument("")

    init(_ source: String) { self.source = source }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(document.blocks) { block in
                MarkdownBlockView(block: block)
            }
        }
        .font(.system(size: 14))
        .lineSpacing(5)
        .textSelection(.enabled)
        .tint(HarnessTheme.accent)
        .frame(maxWidth: 820, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button("Copiar Markdown", systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(source, forType: .string)
            }
        }
        .environment(
            \.openURL,
            OpenURLAction { url in
                MarkdownInlineText.allowedLink(url) ? .systemAction : .discarded
            }
        )
        .task(id: source) {
            let source = source
            let parsed = await Task.detached(priority: .userInitiated) { MarkdownDocument(source) }.value
            guard !Task.isCancelled else { return }
            document = parsed
        }
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if block.quoted {
                RoundedRectangle(cornerRadius: 2).fill(HarnessTheme.accent.opacity(0.6)).frame(width: 3)
            }
            if block.listDepth > 0 {
                Group {
                    if let checked = block.checked {
                        Image(systemName: checked ? "checkmark.square.fill" : "square")
                            .foregroundStyle(checked ? HarnessTheme.accent : .secondary)
                            .accessibilityLabel(checked ? "Concluído" : "Pendente")
                    } else {
                        Text(block.marker ?? "").monospacedDigit().foregroundStyle(.secondary)
                    }
                }.frame(minWidth: 24, alignment: .trailing)
            }
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, CGFloat(max(0, block.listDepth - 1)) * 24)
        .padding(.vertical, block.quoted ? 4 : 0)
    }

    @ViewBuilder private var content: some View {
        switch block.kind {
        case .paragraph:
            MarkdownInlineText(block.text)
        case .heading(let level):
            MarkdownInlineText(block.text)
                .font(.system(size: level == 1 ? 24 : level == 2 ? 20 : level == 3 ? 17 : 15, weight: .semibold))
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)
        case .code(let language):
            MarkdownCodeBlock(code: String(block.text.characters), language: language)
        case .divider:
            Divider().padding(.vertical, 4)
        case .table:
            MarkdownTableView(block: block)
        }
    }
}

struct MarkdownInlineText: View {
    private var value: AttributedString

    init(_ text: AttributedString) {
        var styled = text
        for run in text.runs {
            if run.inlinePresentationIntent?.contains(.code) == true {
                styled[run.range].font = .system(size: 12, design: .monospaced)
                styled[run.range].backgroundColor = Color.secondary.opacity(0.12)
            }
            if let imageURL = run.imageURL {
                // Keep attachments explicit: Markdown does not fetch remote media while scrolling.
                styled[run.range].imageURL = nil
                if Self.allowedLink(imageURL) { styled[run.range].link = imageURL }
            }
            if let link = run.link, !Self.allowedLink(link) { styled[run.range].link = nil }
        }
        value = styled
    }

    static func allowedLink(_ url: URL) -> Bool {
        ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "")
    }

    var body: some View {
        Text(value).fixedSize(horizontal: false, vertical: true)
    }
}
