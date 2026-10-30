import HarnessDomain
import SwiftUI

struct ValidationView: View {
    var store: AppStore
    let run: Run
    private var validators: [Validator] {
        store.snapshot.projects.first { $0.id == run.projectID }.map { run.runbook.validators(for: $0) } ?? []
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                HStack {
                    SectionHeading(title: "Validação", detail: "SNAPSHOT \(run.revision.prefix(8))")
                    Button("Executar gates") { store.perform("validation.run", id: run.id) }.disabled(
                        run.state.active || store.busy.contains(run.id)
                    ).buttonStyle(.borderedProminent).accessibilityIdentifier("validation.execute")
                }
                Text(
                    "PASS exige comando concluído, saída, código de término e o mesmo snapshot. Edições posteriores tornam o resultado STALE."
                ).font(.callout).foregroundStyle(.secondary)
                if validators.isEmpty {
                    EmptyPanel(
                        symbol: "checkmark.diamond", title: "Nenhum gate cadastrado",
                        detail:
                            "Configure comandos no projeto. A ausência de validação não será apresentada como sucesso.")
                }
                ForEach(validators) { validator in
                    let result = run.validations.last { $0.validator.id == validator.id }
                    let displayedStatus: GateStatus =
                        result.map { $0.validator == validator ? $0.status : .stale } ?? .notRun
                    Surface {
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
                            HStack {
                                if let result {
                                    Text(
                                        "\(result.duration, specifier: "%.2f")s · exit \(result.exitCode.map(String.init) ?? "não observado")"
                                    ).font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Text(
                                        validator.approved
                                            ? "Comando aprovado, ainda não executado" : "Requer aprovação no projeto"
                                    ).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Executar") {
                                    store.perform("validation.run", id: run.id) { $0.relatedID = validator.id }
                                }.disabled(run.state.active).accessibilityIdentifier(
                                    "validation.execute." + validator.id)
                            }
                            if let result, !result.output.isEmpty {
                                DisclosureGroup("Saída redigida do processo") {
                                    MonospaceBlock(text: result.output).frame(height: 220)
                                }
                            }
                            if let result, [.fail, .blocked].contains(result.status) {
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
            }.padding(24)
        }
    }
}
