import HarnessDomain
import SwiftUI

struct RunbookStepPreview: View {
    let book: Runbook
    let step: RunbookStep
    let number: Int
    let total: Int
    let selected: Bool
    let select: () -> Void
    @State private var hovering = false

    private var description: RunbookStepDescription { RunbookStepDescription(book: book, step: step) }

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                ZStack {
                    VStack(spacing: 0) {
                        Rectangle().fill(number == 1 ? .clear : FrondaTheme.border)
                        Rectangle().fill(number == total ? .clear : FrondaTheme.border)
                    }.frame(width: 1)
                    Text(number.formatted())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(selected ? FrondaTheme.surface : description.tint)
                        .frame(width: 25, height: 25)
                        .background(selected ? description.tint : FrondaTheme.surface, in: Circle())
                        .overlay(Circle().strokeBorder(description.tint.opacity(selected ? 0 : 0.28), lineWidth: 1))
                }.frame(width: 29)
                Text(step.title)
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? .primary : .secondary)
                    .multilineTextAlignment(.leading).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: description.symbol)
                    .font(.system(size: 12)).foregroundStyle(description.tint)
                    .frame(width: 18)
            }
            .padding(.horizontal, 9).frame(height: 46)
            .background(
                selected ? description.tint.opacity(0.09) : hovering ? FrondaTheme.surface : .clear,
                in: RoundedRectangle(cornerRadius: 9)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(selected ? description.tint.opacity(0.32) : .clear, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("Etapa \(number) de \(total): \(step.title)")
        .accessibilityHint("Mostrar objetivo, condição e dependências")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityRemoveTraits(selected ? [] : .isSelected)
        .accessibilityIdentifier("runbooks.step." + step.id)
    }
}
