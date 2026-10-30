import HarnessDomain
import SwiftUI

struct RunbookStepDetail: View {
    let book: Runbook
    let step: RunbookStep
    let number: Int
    let total: Int
    let selectDependency: (String) -> Void

    private var description: RunbookStepDescription { RunbookStepDescription(book: book, step: step) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: description.symbol)
                    Text("ETAPA \(number) DE \(total)").tracking(1)
                }.font(.system(size: 10, weight: .semibold)).foregroundStyle(description.tint)
                Text(step.title).font(.system(size: 21, weight: .semibold)).tracking(-0.4)
                    .fixedSize(horizontal: false, vertical: true)
                Text(description.purpose).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                detailHeading("Quando acontece", symbol: "arrow.triangle.branch")
                Text(description.condition).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            dependencies
            VStack(alignment: .leading, spacing: 8) {
                detailHeading("Executor", symbol: "terminal")
                Text(step.provider?.rawValue ?? book.provider.rawValue).font(.callout)
                if let model = step.model, !model.isEmpty {
                    Text(model).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            if !step.criteria.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    detailHeading("Critérios da etapa", symbol: "checklist")
                    ForEach(Array(step.criteria.enumerated()), id: \.offset) { _, criterion in
                        Label(criterion, systemImage: "circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if !step.paths.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    detailHeading("Arquivos e pastas previstos", symbol: "folder")
                    Text(step.paths.joined(separator: "\n")).font(.caption.monospaced())
                        .foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            if let commands = book.validationCommands, !commands.isEmpty {
                Divider()
                DisclosureGroup("Validações do fluxo · \(commands.count)") {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(commands) { command in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(command.name).font(.callout.weight(.medium))
                                Text(command.displayCommand).font(.caption.monospaced())
                                    .foregroundStyle(.secondary).textSelection(.enabled)
                                Text(command.approved ? "Comando aprovado" : "Requer aprovação")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Text("Somam-se às validações do projeto selecionado na tarefa.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 12)
                }.font(.caption.weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dependencies: some View {
        VStack(alignment: .leading, spacing: 9) {
            detailHeading("Depende de", symbol: "point.3.connected.trianglepath.dotted")
            if step.dependencies.isEmpty {
                Text("Nenhuma outra etapa.").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(Array(step.dependencies.enumerated()), id: \.offset) { _, id in
                    if let dependency = book.steps.first(where: { $0.id == id }) {
                        Button {
                            selectDependency(id)
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: "arrow.turn.up.left").font(.caption)
                                Text(dependency.title).font(.callout).multilineTextAlignment(.leading)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                            }.padding(10)
                                .background(FrondaTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).foregroundStyle(FrondaTheme.accent)
                        .accessibilityLabel("Ver etapa \(dependency.title)")
                        .accessibilityIdentifier("runbooks.dependency." + id)
                    } else {
                        Label("Dependência não encontrada", systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(FrondaTheme.warning)
                    }
                }
            }
        }
    }

    private func detailHeading(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.caption.weight(.semibold))
    }
}
