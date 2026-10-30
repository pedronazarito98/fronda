import HarnessDomain
import SwiftUI

struct NewRunFlowPreview: View {
    let book: Runbook
    let steps: [RunbookStep]
    let mode: AutonomyMode
    let validationError: String?
    @State private var selectedStepID: String?
    @State private var showsAllSteps = false

    private var selected: RunbookStep? { steps.first { $0.id == selectedStepID } ?? steps.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Percurso da tarefa").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(book.steps.count) etapas").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            if let validationError {
                Label("Fluxo precisa de ajustes", systemImage: "exclamationmark.circle")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(FrondaTheme.warning)
                Text(validationError).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Escolha outro fluxo ou ajuste suas etapas antes de criar a tarefa.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 5) {
                    ForEach(Array(steps.prefix(3).enumerated()), id: \.element.id) { index, step in
                        stepButton(step, number: index + 1)
                    }
                }
                if steps.count > 3 {
                    Button {
                        showsAllSteps = true
                    } label: {
                        HStack {
                            Text("Ver percurso completo")
                            Spacer()
                            Text("+\(steps.count - 3)").monospacedDigit()
                            Image(systemName: "arrow.up.right")
                        }
                    }.font(.system(size: 11, weight: .medium)).buttonStyle(.plain)
                        .foregroundStyle(FrondaTheme.accent)
                        .popover(isPresented: $showsAllSteps) { completeRoute }
                }
                if let selected {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selected.title).font(.system(size: 11, weight: .semibold))
                        Text(description(for: selected)).font(.system(size: 11)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .onChange(of: book.id) { _, _ in selectedStepID = nil }
    }

    private var completeRoute: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(book.name).font(.headline)
                Spacer()
                Button("Concluir") { showsAllSteps = false }.controlSize(.small)
            }
            Text("Selecione uma etapa para conferir o que acontece nela.").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 7) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        VStack(alignment: .leading, spacing: 8) {
                            stepButton(step, number: index + 1)
                            if selected?.id == step.id {
                                Text(description(for: step)).font(.caption).foregroundStyle(.secondary)
                                    .padding(.horizontal, 12).padding(.bottom, 7)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }.padding(18).frame(width: 355, height: 430).tint(FrondaTheme.accent)
    }

    private func stepButton(_ step: RunbookStep, number: Int) -> some View {
        Button {
            selectedStepID = step.id
        } label: {
            HStack(spacing: 10) {
                Text(number.formatted()).font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(FrondaTheme.accent).frame(width: 23, height: 23)
                    .background(FrondaTheme.accent.opacity(0.08), in: Circle())
                Text(step.title).font(.system(size: 11, weight: selected?.id == step.id ? .semibold : .regular))
                    .foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: selected?.id == step.id ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected?.id == step.id ? FrondaTheme.accent.opacity(0.07) : .clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Etapa \(number): \(step.title)")
        .accessibilityAddTraits(selected?.id == step.id ? .isSelected : [])
    }

    private func description(for step: RunbookStep) -> String {
        switch step.kind {
        case "context": "Você confere os arquivos e autoriza o contexto antes do envio."
        case "investigation": "O executor investiga o projeto e registra o diagnóstico."
        case "reproduction": "O problema precisa ser reproduzido e registrado antes da correção."
        case "plan": "Você revisa a proposta e aprova o plano de trabalho."
        case "implementation":
            mode.writes
                ? "O executor aplica as alterações em uma worktree exclusiva."
                : "A análise continua em modo de leitura."
        case "validation": "Os comandos do projeto verificam o resultado e registram as saídas."
        case "verification": "Você confere o cenário e registra evidências do resultado."
        case "review": "O resultado passa por revisão e os achados ficam disponíveis."
        case "evidence": "Critérios, arquivos e evidências são reunidos para a entrega."
        default: "Os resultados desta etapa ficam disponíveis na jornada da tarefa."
        }
    }
}
