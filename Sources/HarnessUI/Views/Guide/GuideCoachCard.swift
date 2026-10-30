import SwiftUI

struct GuideCoachCard: View {
    let journey: FirstTaskJourney
    var confirmation: String?
    var canConfirm = true
    var confirm: () -> Void = {}
    var pause: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                FrondaMascot(size: 72, state: .guide)
                VStack(alignment: .leading, spacing: 6) {
                    Text("COM VOCÊ · \(journey.step.number) DE \(FirstTaskStep.allCases.count)")
                        .font(.system(size: 9, weight: .semibold)).tracking(0.7).foregroundStyle(FrondaTheme.accent)
                    Text(journey.step.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                }.padding(.top, 8)
                Spacer(minLength: 0)
                Button(action: pause) { Image(systemName: "xmark") }
                    .buttonStyle(.plain).help("Sair do guia e salvar o progresso")
                    .accessibilityLabel("Sair do guia").accessibilityIdentifier("guide.coach.exit")
            }
            Text(journey.step.explanation).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("guide.coach.explanation")
            if let confirmation {
                Button(confirmation, action: confirm).buttonStyle(.borderedProminent)
                    .disabled(!canConfirm).accessibilityIdentifier("guide.coach.confirm")
            }
            HStack {
                Button("Pausar", action: pause).help("Guardar o progresso e continuar por conta própria")
                    .accessibilityIdentifier("guide.coach.pause")
                Spacer()
                Button(journey.step.confirmation == nil ? "Continuar sem guia" : "Pular orientação") {
                    journey.skip()
                }.accessibilityIdentifier("guide.coach.skip")
            }.buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).frame(width: 300, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(FrondaTheme.border))
        .tint(FrondaTheme.accent)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide.coach." + journey.step.rawValue)
    }
}
