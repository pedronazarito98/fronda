import SwiftUI

struct CommandJourneyGuide: View {
    @State private var selected = CommandJourneyStage.prepare

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("Como sua tarefa avança").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("EXPLORE O PERCURSO")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1).foregroundStyle(.secondary)
            }
            HStack(spacing: 5) {
                ForEach(CommandJourneyStage.allCases) { stage in
                    stageButton(stage)
                    if stage != .review {
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary).accessibilityHidden(true)
                    }
                }
            }
            Text(selected.explanation).font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
                .padding(.horizontal, 3)
                .accessibilityIdentifier("home.journey-explanation")
        }
    }

    private func stageButton(_ stage: CommandJourneyStage) -> some View {
        Button {
            selected = stage
        } label: {
            HStack(spacing: 10) {
                Text(stage.number).font(.system(size: 10, weight: .medium, design: .monospaced))
                    .frame(width: 29, height: 29)
                    .background(FrondaTheme.accent.opacity(selected == stage ? 0.15 : 0.05), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(stage.rawValue).font(.system(size: 12, weight: .semibold))
                    Text(stage.detail).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected == stage ? FrondaTheme.accent : .primary)
            .padding(.horizontal, 11).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected == stage ? FrondaTheme.accent.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 11)
            )
            .overlay(alignment: .bottom) {
                Capsule().fill(selected == stage ? FrondaTheme.accent.opacity(0.65) : .clear)
                    .frame(height: 2).padding(.horizontal, 11)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Como funciona: \(stage.rawValue)")
        .accessibilityHint("Mostrar a explicação desta parte do percurso")
        .accessibilityAddTraits(selected == stage ? .isSelected : [])
        .accessibilityRemoveTraits(selected == stage ? [] : .isSelected)
        .accessibilityIdentifier("home.journey." + stage.id)
    }
}

private enum CommandJourneyStage: String, CaseIterable, Identifiable {
    case prepare = "Preparar"
    case execute = "Executar"
    case review = "Conferir"

    var id: String { rawValue }
    var number: String {
        switch self {
        case .prepare: "01"
        case .execute: "02"
        case .review: "03"
        }
    }
    var detail: String {
        switch self {
        case .prepare: "Objetivo e contexto"
        case .execute: "Etapas e decisões"
        case .review: "Resultado e evidências"
        }
    }
    var explanation: String {
        switch self {
        case .prepare:
            "Escolha o projeto e um fluxo. Confira os arquivos selecionados e autorize o contexto antes de iniciar a investigação."
        case .execute:
            "Acompanhe a etapa atual e a proposta. Você aprova a implementação e pode orientar ou pausar o trabalho."
        case .review:
            "Confira as alterações, as validações e as evidências. Commit, push e publicação pedem uma aprovação própria."
        }
    }
}
