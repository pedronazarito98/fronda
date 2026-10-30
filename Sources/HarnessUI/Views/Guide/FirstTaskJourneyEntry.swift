import SwiftUI

struct FirstTaskJourneyEntry: View {
    let store: AppStore
    private var journey: FirstTaskJourney { store.firstTaskJourney }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.title2).foregroundStyle(FrondaTheme.accent)
            VStack(alignment: .leading, spacing: 6) {
                Text("Vamos preparar uma tarefa juntos?").font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(journey.entryTitle) { store.openFirstTaskJourney() }
                .buttonStyle(.borderedProminent)
                .disabled(!store.connected || store.showComposer || store.showPalette)
                .accessibilityIdentifier("guide.first-task.start")
        }.padding(22).background(FrondaTheme.accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 18))
    }

    private var detail: String {
        switch journey.status {
        case .new: "O mascote acompanha suas escolhas, do projeto à conferência do contexto."
        case .active, .paused: "Etapa \(journey.step.number) de 7 · \(journey.step.title) · seu progresso está salvo."
        case .completed: "Jornada concluída. Você pode repetir quando quiser preparar outra tarefa."
        }
    }
}

struct FirstTaskJourneyReminder: View {
    let store: AppStore
    var body: some View {
        HStack(spacing: 12) {
            Label(store.firstTaskJourney.step.title, systemImage: "leaf")
            Spacer()
            Button("Voltar ao guia") { store.openFirstTaskJourney() }
                .disabled(!store.connected).accessibilityIdentifier("guide.return")
            Button("Pausar") { store.firstTaskJourney.pause() }.accessibilityIdentifier("guide.pause")
        }.font(.caption).padding(12).background(FrondaTheme.accent.opacity(0.07))
    }
}
