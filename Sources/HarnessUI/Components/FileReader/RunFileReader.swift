import SwiftUI

struct RunFileReader: View {
    let source: RunFileSource
    var onClose: (() -> Void)? = nil
    var onShowChanges: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var document: RunFileDocument?
    @State private var error: String?
    @State private var showsSource = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: source.format.symbol)
                    .foregroundStyle(formatColor).frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: source.name).font(.callout.weight(.semibold)).lineLimit(2)
                        .accessibilityAddTraits(.isHeader)
                    Text(source.origin).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let onShowChanges {
                    Button("Ver todas as alterações", action: onShowChanges)
                        .buttonStyle(.link).font(.caption)
                        .help("Abrir as alterações desta execução")
                }
                Button {
                    if let onClose { onClose() } else { dismiss() }
                } label: {
                    Image(systemName: "xmark")
                }.buttonStyle(.plain).keyboardShortcut(.cancelAction)
                    .help("Fechar leitura").accessibilityLabel("Fechar leitura")
                    .accessibilityIdentifier("file-reader.close")
            }.padding(16)
            Divider()
            if let document {
                if document.hasFormattedView && !document.source.isEmpty {
                    HStack {
                        Picker("Apresentação", selection: $showsSource) {
                            Text("Leitura").tag(false)
                            Text("Fonte").tag(true)
                        }.pickerStyle(.segmented).labelsHidden().frame(width: 174)
                            .accessibilityIdentifier("file-reader.mode")
                        Spacer()
                    }.padding(.horizontal, 18).padding(.vertical, 10)
                    Divider()
                }
                if document.isRedacted {
                    note("O Fronda ocultou dados protegidos nesta leitura.", symbol: "lock.shield")
                }
                reader(document)
            } else if let error {
                EmptyPanel(symbol: "doc.badge.ellipsis", title: "Não foi possível ler o arquivo", detail: error)
                    .frame(maxHeight: .infinity)
            } else {
                ProgressView("Abrindo arquivo…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FrondaTheme.surface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("file-reader")
        .task(id: source) { await load() }
    }

    private var formatColor: Color {
        switch source.format {
        case .markdown: FrondaTheme.accent
        case .json, .code: FrondaTheme.running
        case .csv, .tsv: FrondaTheme.clay
        case .text: FrondaTheme.textMuted
        }
    }

    @ViewBuilder private func reader(_ document: RunFileDocument) -> some View {
        if document.source.isEmpty {
            EmptyPanel(symbol: "doc", title: "Arquivo vazio", detail: "Ainda não há conteúdo nesta versão.")
                .frame(maxHeight: .infinity)
        } else if showsSource {
            RunFileLiteralText(text: document.source)
        } else {
            switch document.preview {
            case .markdown:
                ScrollView {
                    MarkdownView(document.source).padding(24)
                }
            case .json(let text): RunFileLiteralText(text: text)
            case .table(let table): RunFileTableView(table: table)
            case .literal: RunFileLiteralText(text: document.source)
            case .sourceOnly(let message):
                note(message, symbol: "info.circle")
                RunFileLiteralText(text: document.source)
            }
        }
    }

    private func note(_ message: String, symbol: String) -> some View {
        Label(message, systemImage: symbol).font(.callout)
            .foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18).padding(.vertical, 8)
    }

    private func load() async {
        document = nil
        error = nil
        showsSource = false
        let selection = source
        let job = Task.detached(priority: .userInitiated) { try RunFileLoader.load(selection) }
        do {
            let result = try await withTaskCancellationHandler {
                try await job.value
            } onCancel: {
                job.cancel()
            }
            guard !Task.isCancelled else { return }
            document = result
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }
}
