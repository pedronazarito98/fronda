import AppKit
import SwiftUI

struct MarkdownCodeBlock: View {
    let code: String
    let language: String?
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.flatMap { $0.isEmpty ? nil : $0 } ?? "Código")
                    .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Button(copied ? "Copiado" : "Copiar código", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    copied = NSPasteboard.general.setString(code, forType: .string)
                }.buttonStyle(.borderless).font(.caption)
                    .accessibilityLabel(copied ? "Código copiado" : "Copiar código")
            }.padding(.horizontal, 14).padding(.vertical, 10)
            Divider()
            ScrollView(.horizontal) {
                Text(verbatim: code).font(.system(size: 12, design: .monospaced))
                    .lineSpacing(4).textSelection(.enabled).fixedSize(horizontal: true, vertical: false)
                    .padding(14)
            }
        }
        .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary, lineWidth: 1))
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }
}
