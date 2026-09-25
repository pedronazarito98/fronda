import SwiftUI

struct MarkdownPreviewContent: Identifiable {
    let id: String
    let title: String
    let source: String
}

struct MarkdownPreview: View {
    let content: MarkdownPreviewContent
    @Environment(\.dismiss) private var dismiss
    @State private var formatted = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(content.title).font(.title2.weight(.semibold)).lineLimit(2)
                Spacer()
                Button("Fechar") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Picker("Exibição", selection: $formatted) {
                Text("Formatado").tag(true)
                Text("Markdown original").tag(false)
            }.labelsHidden().pickerStyle(.segmented).frame(width: 280)
            if formatted {
                ScrollView { MarkdownView(content.source).padding(16) }
            } else {
                MonospaceBlock(text: content.source)
            }
        }.padding(24).frame(width: 760, height: 680)
    }
}
