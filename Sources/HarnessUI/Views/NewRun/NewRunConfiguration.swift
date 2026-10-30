import HarnessDomain
import SwiftUI

struct NewRunConfiguration: View {
    @Binding var draft: NewRunDraft
    let projects: [Project]
    let runbooks: [Runbook]
    let providers: [ProviderInfo]
    let addProject: () -> Void
    var focusedField: FocusState<NewRunField?>.Binding

    private var project: Project? { projects.first { $0.id == draft.projectID } }
    private var book: Runbook? { runbooks.first { $0.id == draft.bookID } }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            projectSelection.frame(maxWidth: .infinity, alignment: .leading).guideTarget(.project)
            Divider().frame(height: 70)
            flowSelection.frame(maxWidth: .infinity, alignment: .leading).guideTarget(.flow)
            Divider().frame(height: 70)
            NewRunProviderPicker(draft: $draft, providers: providers, defaultProvider: book?.provider)
                .frame(width: 224, alignment: .leading)
                .guideTarget(.executor)
        }
        .pickerStyle(.menu)
        .padding(.horizontal, 24).padding(.vertical, 16)
        .background(FrondaTheme.surface)
    }

    private var projectSelection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Projeto", systemImage: "folder").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: addProject) { Image(systemName: "plus") }
                    .buttonStyle(.plain).help("Adicionar projeto").accessibilityLabel("Adicionar projeto")
            }
            Picker("Projeto", selection: $draft.projectID) {
                Text("Selecione um projeto").tag("")
                ForEach(projects) { Text($0.name).tag($0.id) }
            }
            .labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
            .focused(focusedField, equals: .project).accessibilityIdentifier("composer.project")
            if let project {
                Label(
                    project.dirty
                        ? "Base limpa · alterações locais preservadas"
                        : project.branch.isEmpty ? "Base Git do projeto" : project.branch,
                    systemImage: project.dirty ? "info.circle" : "arrow.triangle.branch"
                ).font(.system(size: 10)).foregroundStyle(project.dirty ? FrondaTheme.warning : .secondary)
                    .lineLimit(1).help(project.path)
            } else {
                Button(projects.isEmpty ? "Adicionar primeiro projeto…" : "Escolher um projeto") {
                    if projects.isEmpty { addProject() } else { focusedField.wrappedValue = .project }
                }.buttonStyle(.link).font(.system(size: 10))
            }
        }
    }

    private var flowSelection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Fluxo de trabalho", systemImage: book?.symbol ?? "point.3.connected.trianglepath.dotted")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            Picker("Fluxo de trabalho", selection: $draft.bookID) {
                Text("Selecione um fluxo").tag("")
                ForEach(runbooks) { Text($0.name).tag($0.id) }
            }
            .labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
            .focused(focusedField, equals: .flow).accessibilityIdentifier("composer.flow")
            Text(book?.subtitle ?? "Escolha como a tarefa será conduzida")
                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                .help(book?.subtitle ?? "")
        }
    }
}
