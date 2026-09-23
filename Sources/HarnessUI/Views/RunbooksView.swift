import HarnessDomain
import HarnessInfrastructure
import SwiftUI

struct RunbooksView: View {
    var store: AppStore
    @State private var editing: Runbook?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    PageHeading(
                        eyebrow: "Método que se repete", title: "Runbooks",
                        subtitle: "Etapas, critérios e permissões. Uma revisão preservada em cada run.")
                    Button("Novo runbook") {
                        var book = Runbook()
                        book.name = "Novo runbook"
                        book.steps = [RunbookStep(title: "Investigar", kind: "implementation")]
                        editing = book
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                    ForEach(store.snapshot.runbooks) { book in
                        Button {
                            editing = book
                        } label: {
                            Surface {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Image(systemName: book.symbol).font(.system(size: 24, weight: .light))
                                            .foregroundStyle(HarnessTheme.accent)
                                        Spacer()
                                        Text("v\(book.version)").font(.caption.monospaced()).foregroundStyle(.tertiary)
                                    }
                                    Text(book.name).font(.headline)
                                    Text(book.subtitle).font(.callout).foregroundStyle(.secondary).frame(
                                        height: 38, alignment: .topLeading)
                                    Divider()
                                    HStack {
                                        Text("\(book.steps.count) etapas")
                                        Spacer()
                                        Text(book.mode.rawValue)
                                    }.font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(32)
        }.sheet(item: $editing) { book in RunbookEditorView(store: store, book: book) }
    }
}

struct RunbookEditorView: View {
    var store: AppStore
    @State var book: Runbook
    @Environment(\.dismiss) private var dismiss
    @State private var issue: String?
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Editor de runbook").font(.title2.weight(.semibold))
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Salvar revisão") { save() }.buttonStyle(.borderedProminent)
            }.padding(24)
            Form {
                Section("Identidade") {
                    TextField("Nome", text: $book.name)
                    TextField("Descrição", text: $book.subtitle)
                    Picker("Modo padrão", selection: $book.mode) {
                        ForEach(AutonomyMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Stepper("Orçamento: \(book.budget)", value: $book.budget, in: 1000...500000, step: 1000)
                }
                Section("Grafo de etapas") {
                    Picker("Provider", selection: $book.provider) {
                        ForEach(ProviderKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Stepper("Retries por etapa: \(book.retries)", value: $book.retries, in: 0...10)
                    ForEach($book.steps) { $step in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("Título", text: $step.title)
                                Button(role: .destructive) {
                                    book.steps.removeAll { $0.id == step.id }
                                } label: {
                                    Image(systemName: "trash")
                                }.buttonStyle(.borderless)
                            }
                            HStack {
                                Text(step.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                                Spacer()
                                Picker("Tipo", selection: $step.kind) {
                                    ForEach(
                                        ["context", "plan", "implementation", "validation", "review", "evidence"],
                                        id: \.self
                                    ) { Text($0) }
                                }
                            }
                            TextField(
                                "Dependências (IDs separados por vírgula)",
                                text: Binding(
                                    get: { step.dependencies.joined(separator: ",") },
                                    set: {
                                        step.dependencies = $0.split(separator: ",").map {
                                            $0.trimmingCharacters(in: .whitespaces)
                                        }
                                    }))
                            Picker("Condição", selection: $step.condition) {
                                Text("Sempre").tag("always")
                                Text("Dependências passaram").tag("on_pass")
                                Text("Dependência falhou").tag("on_failure")
                                Text("Há alterações").tag("has_changes")
                            }
                        }.padding(.vertical, 7)
                    }
                    Button("Adicionar etapa") { book.steps.append(RunbookStep(title: "Nova etapa")) }
                    Button("Validar e simular ordem") {
                        do {
                            let sorted = try book.orderedSteps()
                            issue = "Ordem válida: " + sorted.map(\.title).joined(separator: " → ")
                        } catch { issue = error.localizedDescription }
                    }
                    if let issue { Text(issue).font(.caption).foregroundStyle(.secondary) }
                }
                Section("Gates adicionais desta revisão") {
                    RunbookValidatorsEditor(
                        commands: Binding(get: { book.validationCommands ?? [] }, set: { book.validationCommands = $0 })
                    )
                }
            }.formStyle(.grouped)
        }.frame(width: 760, height: 760)
    }
    private func save() {
        do {
            _ = try book.orderedSteps()
            store.perform("runbook.save") { $0.runbook = book }
            dismiss()
        } catch { issue = error.localizedDescription }
    }
}
