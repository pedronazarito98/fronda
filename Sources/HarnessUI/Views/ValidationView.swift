import HarnessDomain
import SwiftUI

struct ValidationView: View {
    var store: AppStore
    let run: Run
    @State private var reviewingCommand: Validator?

    private var project: Project? { store.snapshot.projects.first { $0.id == run.projectID } }
    private var validators: [Validator] {
        project.map { run.runbook.validators(for: $0) } ?? []
    }
    private var canExecute: Bool {
        store.connected && !run.state.active && !store.busy.contains(run.id) && !run.workspace.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                HStack {
                    SectionHeading(title: "Validação", detail: "SNAPSHOT \(run.revision.prefix(8))")
                    Button("Executar verificações") { store.perform("validation.run", id: run.id) }
                        .disabled(!canExecute || validators.isEmpty)
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("validation.execute")
                }
                Text(
                    "PASS exige comando concluído, saída, código de término e o mesmo snapshot. Edições posteriores tornam o resultado STALE."
                ).font(.callout).foregroundStyle(.secondary)
                if project == nil {
                    EmptyPanel(
                        symbol: "folder.badge.questionmark", title: "Projeto indisponível",
                        detail: "As verificações aparecerão quando o projeto estiver disponível.")
                } else if validators.isEmpty
                    || (run.runbook.loopPolicy != nil && !validators.contains(where: \.required))
                {
                    missingRequiredCommand
                }
                ForEach(validators, content: commandCard)
            }.padding(24)
        }
        .sheet(item: $reviewingCommand) { command in
            if let project {
                ProjectSettingsView(
                    store: store, project: project, initialSection: .validation, reviewingCommand: command)
            }
        }
    }

    private func commandCard(_ validator: Validator) -> some View {
        let result = run.validations.last { $0.validator.id == validator.id }
        let displayedStatus: GateStatus =
            result.map { $0.validator == validator ? $0.status : .stale } ?? .notRun
        return Surface {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(validator.name).font(.headline)
                    if validator.required {
                        Text("OBRIGATÓRIO").font(.system(size: 8, design: .monospaced)).foregroundStyle(
                            .secondary)
                    }
                    Spacer()
                    StatusBadge(text: displayedStatus.rawValue).accessibilityIdentifier(
                        "validation.status." + validator.id)
                }
                Text(validator.displayCommand).font(.system(size: 11, design: .monospaced)).textSelection(
                    .enabled)
                if !validator.approved {
                    approvalAction(for: validator)
                }
                HStack {
                    if let result {
                        Text(
                            "\(result.duration, specifier: "%.2f")s · exit \(result.exitCode.map(String.init) ?? "não observado")"
                        ).font(.caption).foregroundStyle(.secondary)
                    } else if validator.approved {
                        Text("Comando aprovado, ainda não executado").font(.caption).foregroundStyle(
                            .secondary)
                    }
                    Spacer()
                    Button(validator.approved ? "Executar" : "Tentar executar") {
                        store.perform("validation.run", id: run.id) { $0.relatedID = validator.id }
                    }
                    .disabled(!canExecute)
                    .help(
                        validator.approved
                            ? "Executar a verificação"
                            : "Enquanto a aprovação estiver pendente, a tentativa será registrada como bloqueada."
                    )
                    .accessibilityIdentifier("validation.execute." + validator.id)
                }
                if let result, !result.output.isEmpty {
                    DisclosureGroup("Saída redigida do processo") {
                        MonospaceBlock(text: result.output).frame(height: 220)
                    }
                }
                if let result, [.fail, .blocked].contains(displayedStatus) {
                    Button("Criar run a partir desta falha") {
                        var source = SourceIntent()
                        source.kind = .validation
                        source.revision = result.revision
                        source.sourceURL = "fronda://run/" + run.id
                        source.text =
                            "Comando: \(validator.displayCommand)\nEstado: \(result.status.rawValue)\nExit: \(result.exitCode.map(String.init) ?? "não observado")\n\(result.output)"
                        store.draft(
                            title: "Recuperar \(validator.name)", source: source, projectID: run.projectID,
                            runbook: "Recuperar CI")
                    }
                }
            }
        }
    }

    private var missingRequiredCommand: some View {
        Surface {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    validators.isEmpty
                        ? "Nenhuma verificação cadastrada" : "O ciclo precisa de uma verificação obrigatória",
                    systemImage: "checkmark.diamond"
                ).font(.headline)
                Text(
                    "Cadastre um comando de build, lint ou teste no projeto e confira o que ele executa antes de aprovar."
                )
                .font(.callout).foregroundStyle(.secondary)
                Button("Cadastrar verificação no projeto…") {
                    var command = Validator()
                    command.name = "Nova verificação"
                    reviewingCommand = command
                }.buttonStyle(.borderedProminent).disabled(!store.connected || run.state.active)
                    .accessibilityIdentifier("validation.configure-project")
            }
        }
    }

    private func approvalAction(for validator: Validator) -> some View {
        let isProjectCommand = project?.validators.contains(where: { $0.id == validator.id }) == true
        return VStack(alignment: .leading, spacing: 8) {
            Label("Precisa da sua aprovação", systemImage: "hand.raised")
                .font(.callout.weight(.semibold)).foregroundStyle(FrondaTheme.warning)
            Text(
                isProjectCommand
                    ? "Confira o comando nos ajustes do projeto, marque a aprovação e salve."
                    : "Revise uma cópia do comando do fluxo. Aprovar e salvar autoriza o uso em todas as tarefas do projeto. Cancelar descarta o rascunho."
            )
            .font(.caption).foregroundStyle(.secondary)
            Button(isProjectCommand ? "Revisar comando no projeto…" : "Revisar para adicionar ao projeto…") {
                reviewingCommand = validator
            }.buttonStyle(.bordered).disabled(!store.connected || run.state.active)
                .accessibilityIdentifier("validation.review-command." + validator.id)
        }
    }
}
