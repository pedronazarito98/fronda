import AppKit
import QuickLook
import SwiftUI

struct NewRunAttachments: View {
    @Binding var paths: [String]
    @Environment(\.isEnabled) private var isEnabled
    @State private var previewURL: URL?
    @State private var dropTargeted = false
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    expanded.toggle()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right").font(
                            .system(size: 9, weight: .semibold))
                        Label("Referências", systemImage: "paperclip").font(.system(size: 12, weight: .semibold))
                        if !paths.isEmpty { Text("\(paths.count)").font(.caption).foregroundStyle(.secondary) }
                    }
                }.buttonStyle(.plain).accessibilityLabel(expanded ? "Recolher referências" : "Expandir referências")
                Spacer()
                Button("Adicionar…", action: chooseFiles).controlSize(.small)
            }
            if !expanded {
                Text(
                    paths.isEmpty
                        ? "Anexe arquivos, imagens ou pastas; também pode arrastar aqui."
                        : paths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
                )
                .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
            } else if paths.isEmpty {
                VStack(spacing: 7) {
                    Image(systemName: "doc.badge.plus").font(.system(size: 23, weight: .light))
                    Text("Arraste arquivos ou pastas aqui").font(.system(size: 12, weight: .medium))
                    Text("Imagens, documentos e contexto do projeto").font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }.foregroundStyle(FrondaTheme.accent).frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ForEach(paths, id: \.self) { path in
                    attachmentRow(path)
                }
                Text("\(paths.count) \(paths.count == 1 ? "anexo" : "anexos") · clique no olho para visualizar")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 7)
        .background(dropTargeted ? FrondaTheme.accent.opacity(0.08) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13).strokeBorder(
                dropTargeted ? FrondaTheme.accent : .clear,
                style: StrokeStyle(lineWidth: 1, dash: paths.isEmpty ? [5, 4] : []))
        }
        .dropDestination(for: URL.self) { urls, _ in
            addFiles(urls)
        } isTargeted: {
            dropTargeted = $0
            if $0 { expanded = true }
        }
        .quickLookPreview($previewURL)
        .onChange(of: paths.count) { _, count in if count > 0 { expanded = true } }
    }

    private func attachmentRow(_ path: String) -> some View {
        let url = URL(fileURLWithPath: path)
        return HStack(spacing: 10) {
            Image(systemName: "doc").foregroundStyle(FrondaTheme.accent)
            Text(url.lastPathComponent).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                .help(path)
            Spacer(minLength: 4)
            Button {
                previewURL = url
            } label: {
                Image(systemName: "eye")
            }.buttonStyle(.plain).help("Visualizar \(url.lastPathComponent)")
                .accessibilityLabel("Visualizar \(url.lastPathComponent)")
            Button {
                paths.removeAll { $0 == path }
                if previewURL == url { previewURL = nil }
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }.buttonStyle(.plain).help("Remover \(url.lastPathComponent)")
                .accessibilityLabel("Remover \(url.lastPathComponent)")
        }.padding(.vertical, 5)
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.title = "Arquivos de referência"
        panel.prompt = "Anexar"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK { _ = addFiles(panel.urls) }
    }

    private func addFiles(_ urls: [URL]) -> Bool {
        guard isEnabled else { return false }
        let localURLs = urls.filter(\.isFileURL)
        guard !localURLs.isEmpty else { return false }
        var knownPaths = Set(paths)
        let additions = localURLs.map { $0.standardizedFileURL.path }.filter { knownPaths.insert($0).inserted }
        paths.append(contentsOf: additions)
        return true
    }
}
