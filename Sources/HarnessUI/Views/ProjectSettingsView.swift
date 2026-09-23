import HarnessDomain
import HarnessInfrastructure
import SwiftUI

struct ProjectSettingsView: View {
    var store: AppStore
    @State var project: Project
    @Environment(\.dismiss) private var dismiss
    @State private var exclusions = ""
    @State private var allowed = ""
    @State private var locked = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Configurar \(project.name)").font(.title2.weight(.semibold))
                Spacer()
                Button("Concluir") { save() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }.padding(24)
            Form {
                Section("Acesso à pasta") {
                    Text(project.path).font(.caption.monospaced()).textSelection(.enabled)
                    Button("Selecionar pasta e renovar acesso…") {
                        store.renewProjectAccess(project.id)
                        dismiss()
                    }
                }
                Section("Política do projeto") {
                    ForEach(ProviderKind.allCases) { provider in
                        Toggle(
                            "Permitir \(provider.rawValue)",
                            isOn: Binding(
                                get: { !(project.disabledProviders ?? []).contains(provider) },
                                set: { enabled in
                                    var disabled = project.disabledProviders ?? []
                                    disabled.removeAll { $0 == provider }
                                    if !enabled { disabled.append(provider) }
                                    project.disabledProviders = disabled
                                }))
                    }
                    TextField("Paths permitidos (um por linha)", text: $allowed, axis: .vertical)
                    TextField("Arquivos travados", text: $locked, axis: .vertical)
                    TextField("Exclusões do índice", text: $exclusions, axis: .vertical)
                    Toggle("Exigir isolamento forte comprovado", isOn: $project.requireStrongIsolation)
                    Text(
                        "Se o provider não comprovar isolamento, a run fica BLOCKED. A configuração não amplia as permissões nativas do provider."
                    ).font(.caption).foregroundStyle(.secondary)
                }
                Section("Pesos de relevância do contexto") {
                    ForEach(ContextRelations.defaultWeights.keys.sorted(), id: \.self) { key in
                        Stepper(
                            "\(key): \(project.contextWeights?[key] ?? ContextRelations.defaultWeights[key] ?? 1)",
                            value: Binding(
                                get: { project.contextWeights?[key] ?? ContextRelations.defaultWeights[key] ?? 1 },
                                set: { value in
                                    var weights = project.contextWeights ?? ContextRelations.defaultWeights
                                    weights[key] = value
                                    project.contextWeights = weights
                                }), in: 0...10)
                    }
                }
                Section("Critérios do Jira") {
                    TextField(
                        "ID do campo de aceite, por exemplo customfield_10042",
                        text: Binding(
                            get: { project.jiraAcceptanceField ?? "" },
                            set: { project.jiraAcceptanceField = $0.trimmingCharacters(in: .whitespacesAndNewlines) }))
                    Text(
                        "O campo original é preservado na fonte. Os critérios extraídos ficam editáveis antes da criação da run."
                    ).font(.caption).foregroundStyle(.secondary)
                }
                Section("Catálogo de comandos") {
                    ForEach($project.validators) { $validator in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                TextField("Nome", text: $validator.name)
                                Spacer()
                                Button(role: .destructive) {
                                    project.validators.removeAll { $0.id == validator.id }
                                } label: {
                                    Image(systemName: "trash")
                                }.buttonStyle(.borderless)
                            }
                            TextField("Executável", text: $validator.executable)
                            TextField(
                                "Argumentos, um por linha",
                                text: Binding(
                                    get: { validator.arguments.joined(separator: "\n") },
                                    set: {
                                        validator.arguments = $0.split(
                                            separator: "\n", omittingEmptySubsequences: false
                                        ).map(String.init)
                                    }), axis: .vertical
                            )
                            .font(.system(size: 11, design: .monospaced))
                            HStack {
                                Toggle("Obrigatório", isOn: $validator.required)
                                Toggle("Somente leitura", isOn: $validator.readOnly)
                            }
                            Stepper(
                                "Timeout: \(validator.timeoutSeconds)s", value: $validator.timeoutSeconds, in: 1...3600,
                                step: 30)
                            Toggle("Aprovo a execução deste comando literal", isOn: $validator.approved).tint(.green)
                        }.padding(.vertical, 8)
                    }
                    Button("Adicionar validador") { project.validators.append(Validator()) }
                }
            }.formStyle(.grouped)
        }.frame(width: 740, height: 760)
            .onAppear {
                exclusions = project.exclusions.joined(separator: "\n")
                allowed = project.allowedPaths.joined(separator: "\n")
                locked = project.lockedPaths.joined(separator: "\n")
            }
    }
    private func save() {
        project.exclusions = exclusions.split(separator: "\n").map(String.init)
        project.allowedPaths = allowed.split(separator: "\n").map(String.init)
        project.lockedPaths = locked.split(separator: "\n").map(String.init)
        store.perform("project.update") { $0.project = project }
        dismiss()
    }
}
