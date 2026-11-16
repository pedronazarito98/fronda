import HarnessDomain
import HarnessInfrastructure
import SwiftUI

struct RunFilesView: View {
    let store: AppStore
    let run: Run
    @Binding var section: RunWorkspaceSection
    @State private var reading: RunFileSource?
    @State private var query = ""
    @State private var category: FileCategory = .changed

    private enum FileCategory: String, CaseIterable, Identifiable {
        case changed = "Alterados"
        case context = "Contexto"
        case evidence = "Evidências"

        var id: Self { self }
    }

    private var changed: [ChangedFile] { run.changedFiles.filter { matches($0.path) } }
    private var included: [ContextItem] {
        (run.pack?.items ?? []).filter { $0.included && matches($0.path) }
    }
    private var artifacts: [EvidenceArtifact] { (run.evidenceArtifacts ?? []).filter { matches($0.title) } }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 900
            if let reading {
                if wide {
                    HStack(spacing: 0) {
                        fileList.frame(width: geometry.size.width * 0.42)
                        Divider()
                        reader(reading)
                    }
                } else {
                    VStack(spacing: 0) {
                        fileList.frame(height: min(geometry.size.height * 0.42, 310))
                        Divider()
                        reader(reading)
                    }
                }
            } else {
                fileList
            }
        }
        .accessibilityIdentifier("run.files")
    }

    private func reader(_ source: RunFileSource) -> some View {
        let showChanges: (() -> Void)? = {
            guard case .workspace(_, let path) = source,
                run.changedFiles.contains(where: { $0.path == path })
            else { return nil }
            return { section = .changes }
        }()
        return RunFileReader(source: source, onClose: { reading = nil }, onShowChanges: showChanges)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Arquivos alterados, contexto utilizado e evidências da tarefa.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Picker("Categoria de arquivos", selection: $category) {
                ForEach(FileCategory.allCases) { item in
                    Text("\(item.rawValue) (\(count(item)))").tag(item)
                }
            }
            .pickerStyle(.segmented).labelsHidden()
            .accessibilityLabel("Categoria de arquivos")
            .onChange(of: category) { _, _ in reading = nil }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
                TextField("Buscar em \(category.rawValue.lowercased())…", text: $query).textFieldStyle(.plain)
                    .accessibilityLabel("Filtrar " + category.rawValue.lowercased())
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain).accessibilityLabel("Limpar busca de arquivos")
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(FrondaTheme.border))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    categoryContent
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                destinationButton
                Spacer(minLength: 8)
                Button("Abrir arquivo externo…", systemImage: "folder") {
                    reading = RunFileSource.chooseExternal()
                }
                .help("Escolher um documento do Mac para ler sem anexá-lo à tarefa")
                .accessibilityIdentifier("files.open-external")
            }
            .font(.caption)
            .buttonStyle(.link)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FrondaTheme.surface)
    }

    @ViewBuilder private var categoryContent: some View {
        switch category {
        case .changed:
            if changed.isEmpty {
                empty(
                    query.isEmpty
                        ? "Os arquivos aparecem aqui quando a tarefa produz alterações." : "Nenhum arquivo encontrado.")
            }
            ForEach(changed) { file in
                let source: RunFileSource? =
                    file.status != "D" && !run.workspace.isEmpty
                        && ContextFirewall.exclusion(file.path) == nil
                    ? .workspace(root: run.workspace, path: file.path) : nil
                fileRow(path: file.path, badge: .change(file.status), source: source) {
                    if source == nil {
                        Text(file.status == "D" ? "Removido da pasta" : "Só metadados")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        case .context:
            if included.isEmpty {
                empty(
                    query.isEmpty
                        ? "As cópias ficam disponíveis depois da preparação do contexto." : "Nenhum arquivo encontrado."
                )
            }
            ForEach(included) { item in
                fileRow(
                    path: item.path, badge: .context(item), source: .snapshot(name: item.path, content: item.content)
                ) {
                    EmptyView()
                }
            }
        case .evidence:
            if artifacts.isEmpty {
                empty(
                    query.isEmpty ? "Os artefatos recebidos pela tarefa aparecem aqui." : "Nenhum arquivo encontrado.")
            }
            ForEach(artifacts) { artifact in
                fileRow(path: artifact.title, badge: .artifact(artifact, revision: run.revision), source: nil) {
                    ArtifactReadButton(store: store, runID: run.id, artifact: artifact, onRead: { reading = $0 })
                }
            }
        }
    }

    private func count(_ item: FileCategory) -> Int {
        switch item {
        case .changed: run.changedFiles.count
        case .context: (run.pack?.items ?? []).filter(\.included).count
        case .evidence: (run.evidenceArtifacts ?? []).count
        }
    }

    private var destinationButton: some View {
        let destination: RunWorkspaceSection =
            switch category {
            case .changed: .changes
            case .context: .context
            case .evidence: .evidence
            }
        let title =
            switch category {
            case .changed: "Ver alterações"
            case .context: "Revisar contexto"
            case .evidence: "Ver evidências"
            }
        return Button(title) { section = destination }
    }

    private func matches(_ title: String) -> Bool {
        query.isEmpty || title.localizedCaseInsensitiveContains(query)
    }

    private func empty(_ message: String) -> some View {
        Text(message).font(.callout).foregroundStyle(.secondary)
            .padding(.vertical, 10).fixedSize(horizontal: false, vertical: true)
    }

    private func fileRow<Control: View>(
        path: String, badge: RunFileBadge, source: RunFileSource?, @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "doc.text").foregroundStyle(FrondaTheme.textMuted)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                if let source {
                    Button {
                        reading = source
                    } label: {
                        Text(verbatim: path).font(.callout.weight(.medium)).lineLimit(2).truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .help("Ler " + path)
                    .accessibilityLabel("Ler " + path)
                } else {
                    Text(verbatim: path).font(.callout.weight(.medium)).lineLimit(2).truncationMode(.middle)
                        .textSelection(.enabled).help(path)
                }
                Label(badge.title, systemImage: badge.symbol)
                    .font(.caption2).foregroundStyle(badge.color)
            }
            Spacer(minLength: 4)
            control()
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            source != nil && source == reading ? FrondaTheme.accent.opacity(0.11) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .accessibilityElement(children: .contain)
    }
}

private struct RunFileBadge {
    let title: String
    let symbol: String
    let color: Color

    static func change(_ status: String) -> Self {
        switch status {
        case "D": Self(title: "Removido", symbol: "minus.circle", color: FrondaTheme.danger)
        case "A", "?": Self(title: "Adicionado", symbol: "plus.circle", color: FrondaTheme.success)
        default: Self(title: "Alterado", symbol: "pencil.circle", color: FrondaTheme.running)
        }
    }

    static func context(_ item: ContextItem) -> Self {
        let title = item.path.hasPrefix("attachments/") ? "Texto do anexo" : "Cópia do contexto"
        return Self(title: title, symbol: "doc.on.doc", color: FrondaTheme.reference)
    }

    static func artifact(_ artifact: EvidenceArtifact, revision: String) -> Self {
        let current = artifact.revision == revision
        return Self(
            title: current ? "Evidência" : "Revisão anterior", symbol: current ? "paperclip" : "clock",
            color: current ? FrondaTheme.reference : FrondaTheme.warning)
    }
}
