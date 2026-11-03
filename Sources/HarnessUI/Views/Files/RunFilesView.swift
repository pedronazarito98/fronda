import HarnessDomain
import HarnessInfrastructure
import SwiftUI

struct RunFilesView: View {
    let store: AppStore
    let run: Run
    @Binding var section: RunWorkspaceSection
    @State private var reading: RunFileSource?
    @State private var query = ""

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 900
            HStack(spacing: 0) {
                fileList
                    .frame(maxWidth: wide && reading != nil ? geometry.size.width * 0.46 : .infinity)
                if wide, let reading {
                    Divider()
                    RunFileReader(source: reading, onClose: { self.reading = nil })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .sheet(
                item: Binding(
                    get: { wide ? nil : reading },
                    set: { reading = $0 }
                )
            ) { RunFileReader(source: $0) }
        }
        .accessibilityIdentifier("run.files")
    }

    private var fileList: some View {
        let changed = run.changedFiles.filter { matches($0.path) }
        let included = (run.pack?.items ?? []).filter { $0.included && matches($0.path) }
        let artifacts = (run.evidenceArtifacts ?? []).filter { matches($0.title) }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        heading
                        Spacer(minLength: 12)
                        chooseFile
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        heading
                        chooseFile
                    }
                }
                TextField("Filtrar por nome ou caminho", text: $query)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Filtrar arquivos da tarefa")
                if !query.isEmpty && changed.isEmpty && included.isEmpty && artifacts.isEmpty {
                    EmptyPanel(
                        symbol: "magnifyingglass", title: "Nenhum arquivo encontrado",
                        detail: "Altere o filtro para procurar em alterações, contexto e evidências.")
                } else {
                    if query.isEmpty || !changed.isEmpty {
                        group(
                            "Arquivos alterados", count: changed.count, action: "Ver alterações", destination: .changes)
                        if changed.isEmpty { note("Os arquivos aparecem aqui quando a tarefa produz alterações.") }
                        ForEach(changed) { file in
                            fileRow(path: file.path, badge: .change(file.status)) {
                                if file.status == "D" {
                                    Text("Removido da pasta").font(.caption).foregroundStyle(.secondary)
                                } else if !run.workspace.isEmpty && ContextFirewall.exclusion(file.path) == nil {
                                    readButton("Ler atual") {
                                        reading = .workspace(root: run.workspace, path: file.path)
                                    }
                                } else {
                                    Text("Só metadados").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    if query.isEmpty || !included.isEmpty {
                        group(
                            "Contexto preparado", count: included.count, action: "Revisar contexto",
                            destination: .context)
                        if included.isEmpty { note("As cópias ficam disponíveis depois da preparação do contexto.") }
                        ForEach(included) { item in
                            fileRow(path: item.path, badge: .context(item)) {
                                readButton("Ler cópia") { reading = .snapshot(name: item.path, content: item.content) }
                            }
                        }
                    }
                    if query.isEmpty || !artifacts.isEmpty {
                        group(
                            "Evidências registradas", count: artifacts.count, action: "Ver evidências",
                            destination: .evidence)
                        if artifacts.isEmpty { note("Os artefatos recebidos pela tarefa aparecem aqui.") }
                        ForEach(artifacts) { artifact in
                            fileRow(path: artifact.title, badge: .artifact(artifact, revision: run.revision)) {
                                ArtifactReadButton(store: store, runID: run.id, artifact: artifact)
                            }
                        }
                    }
                }
            }
            .padding(22).frame(maxWidth: 920, alignment: .leading).frame(maxWidth: .infinity)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Arquivos da tarefa").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
            Text("Leia a versão atual ou a cópia registrada em cada etapa.").font(.callout).foregroundStyle(.secondary)
        }
    }

    private var chooseFile: some View {
        Button("Abrir arquivo externo…", systemImage: "folder") {
            reading = RunFileSource.chooseExternal()
        }
        .help("Escolher um documento do Mac para ler sem anexá-lo à tarefa")
        .accessibilityIdentifier("files.open-external")
    }

    private func matches(_ title: String) -> Bool {
        query.isEmpty || title.localizedCaseInsensitiveContains(query)
    }

    private func group(_ title: String, count: Int, action: String, destination: RunWorkspaceSection) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                groupTitle(title, count: count)
                Spacer(minLength: 8)
                destinationButton(action, destination)
            }
            VStack(alignment: .leading, spacing: 5) {
                groupTitle(title, count: count)
                destinationButton(action, destination)
            }
        }
    }

    private func groupTitle(_ title: String, count: Int) -> some View {
        HStack(spacing: 7) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            Text(count, format: .number).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func destinationButton(_ title: String, _ destination: RunWorkspaceSection) -> some View {
        Button(title) { section = destination }.buttonStyle(.link)
    }

    private func note(_ message: String) -> some View {
        Text(message).font(.callout).foregroundStyle(.secondary)
    }

    private func readButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action).controlSize(.small)
    }

    private func fileRow<Control: View>(
        path: String, badge: RunFileBadge, @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: path).font(.callout.weight(.medium)).lineLimit(2).truncationMode(.middle)
                    .textSelection(.enabled).help(path)
                FrondaBadge(badge.title, symbol: badge.symbol, color: badge.color)
            }
            Spacer(minLength: 6)
            control()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(FrondaTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 10))
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
