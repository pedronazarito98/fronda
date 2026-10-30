import HarnessDomain
import SwiftUI

struct RunJourneyCoach: ViewModifier {
    let store: AppStore
    let run: Run
    @Binding var section: RunWorkspaceSection
    private var journey: FirstTaskJourney { store.firstTaskJourney }
    private var active: Bool { journey.isActive && journey.runID == run.id }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if active && section != .context {
                    HStack(spacing: 12) {
                        Label("Vamos conferir o contexto antes de executar.", systemImage: "leaf")
                        Spacer()
                        Button("Ver contexto") { section = .context }.accessibilityIdentifier("guide.open-context")
                        Button("Pausar guia") { journey.pause() }
                    }.font(.caption).padding(12).background(FrondaTheme.accent.opacity(0.07))
                }
            }
            .modifier(
                GuideOverlay(
                    journey: journey, presented: active && section == .context,
                    confirmation: run.pack == nil ? "Aguardando contexto…" : "Contexto conferido · concluir guia",
                    canConfirm: store.connected && run.pack != nil,
                    confirm: {
                        guard store.connected, run.pack != nil else { return }
                        journey.complete()
                        store.notice = "Jornada concluída. A autorização para executar continua nas suas mãos."
                    }, pause: { journey.pause() }))
    }
}
